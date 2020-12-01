--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_common = require "graph_common"
local graph_utils = require "graph_utils"
local ts_utils = require("ts_utils")
local ts_common = require("ts_common")
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Read timeseries data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 3, "ts_schema":"host:traffic", "ts_query": "host:192.168.1.98", "epoch_begin": "1532180495", "epoch_end": "1548839346"}' http://localhost:3000/lua/rest/v1/get/timeseries/ts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local query            = _GET["ts_query"]
local ts_schema        = _GET["ts_schema"]
local tstart           = _GET["epoch_begin"]
local tend             = _GET["epoch_end"]
local compare_backward = _GET["ts_compare"]
local extended_times   = _GET["extended"]
local ts_aggregation   = _GET["ts_aggregation"]
local no_fill = tonumber(_GET["no_fill"])

if isEmptyString(ifid) then
  rc = rest_utils.consts.err.invalid_interface
  rest_utils.answer(rc)
  return
end

interface.select(ifid)

-- Epochs in _GET are assumed to be adjusted to UTC. This is always the case when the browser submits epoch using a
-- datetimepicker (e.g., from any chart page).

-- This is what happens for example when drawing a chart from firefox set on three different timezones

-- TZ=UTC firefox.        12 May 2020 11:00:00 -> 1589281200 (sent by browser in _GET)
-- TZ=Europe/Rome.        12 May 2020 11:00:00 -> 1589274000 (sent by browser in _GET)
-- TZ=America/Sao_Paulo   12 May 2020 11:00:00 -> 1589292000 (sent by browser in _GET)

-- Basically, timestamps are adjusted to UTC before being sent in _GET:

-- - 1589274000 (Rome) - 1589281200 (UTC) = -7200: As Rome (CEST) is at +2 from UTC, then UTC is 2 hours ahead Rome
--   - 12 May 2020 11:00:00 in Rome (UTC) is 12 May 2020 09:00:00 UTC (-2)
-- - 1589292000 (Sao Paulo) - 1589281200 (UTC) = +10800: As Sao Paulo is at -3 from UTC, then UTC is 3 hours after UTC
--    - 12 May 2020 11:00:00 in Sao Paolo is 12 May 2020 14:00:00 UTC (+3)

-- As timeseries epochs are always written adjusted to UTC, there is no need to do any extra processing to the received epochs.
-- They are valid from any timezone, provided they are sent in the _GET as UTC adjusted.

tstart = tonumber(tstart) or (os.time() - 3600)
tend = tonumber(tend) or os.time()
tags = tsQueryToTags(query)

tags.ifid = ifid

if _GET["tskey"] then
  -- this can contain a MAC address for local broadcast domain hosts
  tags.host = _GET["tskey"]
end

local driver = ts_utils.getQueryDriver()

local options = {
  max_num_points = tonumber(_GET["limit"]) or 60,
  initial_point = toboolean(_GET["initial_point"]),
  with_series = true,
  target_aggregation = ts_aggregation,
}

if(no_fill == 1) then
  options.fill_value = 0/0 -- NaN
end

if((ts_schema == "top:flow_user_script:duration")
    or (ts_schema == "top:elem_user_script:duration")
    or (ts_schema == "custom:flow_user_script:total_stats")
    or (ts_schema == "custom:elem_user_script:total_stats")) then
  -- NOTE: Temporary fix for top user scripts page
  tags.user_script = nil
end

sendHTTPHeader('application/json')

local function performQuery(tstart, tend, keep_total, additional_options)
  local res
  additional_options = additional_options or {}
  local options = table.merge(options, additional_options)

  if starts(ts_schema, "top:") then
    local ts_schema = split(ts_schema, "top:")[2]

    res = ts_utils.queryTopk(ts_schema, tags, tstart, tend, options)
  else
    res = ts_utils.query(ts_schema, tags, tstart, tend, options)

    if(not keep_total) and (res) and (res.additional_series) then
      -- no need for total serie in normal queries
      res.additional_series.total = nil
    end
  end

  return res
end

local res

if(ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation") == "1") then
  if(ts_schema == "host:ndpi") then
    ts_schema = "custom:host_ndpi_and_flows"
  elseif(ts_schema == "iface:ndpi") then
    ts_schema = "custom:iface_ndpi_and_flows"
  end
end

if starts(ts_schema, "custom:") and graph_utils.performCustomQuery then
  res = graph_utils.performCustomQuery(ts_schema, tags, tstart, tend, options)
  compare_backward = nil
else
  res = performQuery(tstart, tend)
end

if res == nil then
  if(ts_utils.getLastError() ~= nil) then
    res["tsLastError"] = ts_utils.getLastError()
    res["error"] = ts_utils.getLastErrorMessage()
  end

  rc = rest_utils.consts.err.internal_error
  rest_utils.answer(rc, res)
  return
end

-- Add metadata
res.schema = ts_schema
res.query = tags
res.max_points = options.max_num_points

if not isEmptyString(compare_backward) and compare_backward ~= "1Y" and (res.step ~= nil) then
  local backward_sec = graph_common.getZoomDuration(compare_backward)
  local tstart_cmp = res.start - backward_sec
  local tend_cmp = tstart_cmp + res.step * (res.count - 1)

  -- Try to use the same aggregation as the original query
  local res_cmp = performQuery(tstart_cmp, tend_cmp, true, {target_aggregation=res.source_aggregation})
  local total_cmp_serie = nil

  if res_cmp and res_cmp.additional_series and res_cmp.additional_series.total and (res_cmp.step) and res_cmp.step >= res.step then
    total_cmp_serie = res_cmp.additional_series.total

    if res_cmp.step > res.step then
      -- The steps may not still correspond if the past query overlaps a retention policy
      -- bound (it will have less points, but with an higher step), upscale to solve this
      total_cmp_serie = ts_common.upsampleSerie(total_cmp_serie, res.count)
    end
  end

  if total_cmp_serie then
    res.additional_series = res.additional_series or {}
    res.additional_series[compare_backward.. " " ..i18n("details.ago")] = total_cmp_serie
  end
end

-- TODO make a script parameter?
local extend_labels = true

if extend_labels and graph_utils.extendLabels then
   graph_utils.extendLabels(res)
end

-- Add layout information
local layout = graph_utils.get_timeseries_layout(ts_schema)

for _, serie in pairs(res.series) do

  if not serie.type then
    if layout[serie.label] then
      serie.type = layout[serie.label]
    end
  end

end

if extended_times then
  if res.series and res.step then
    for k, serie in pairs(res.series) do
      serie.data = ts_common.serieWithTimestamp(serie.data, tstart, res.step)
    end
  end
  if res.additional_series and res.step then
    for k, serie in pairs(res.additional_series) do
      res.additional_series[k] = ts_common.serieWithTimestamp(serie, tstart, res.step)
    end
  end
end

rest_utils.answer(rc, res)
