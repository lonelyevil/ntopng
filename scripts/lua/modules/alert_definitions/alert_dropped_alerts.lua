--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param ifid The integer id of the interface which is dropping alerts
-- @param num_dropped The number of alerts dropped
-- @return A table with the alert built
local function createDroppedAlerts(alert_severity, alert_granularity, ifid, num_dropped)
   local threshold_type = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 ifid = ifid,
	 num_dropped = num_dropped,
      },
   }

   return threshold_type
end

-- #######################################################

local function formatDroppedAlerts(ifid, alert, alert_info)
  return(i18n("alert_messages.iface_alerts_dropped", {
    iface = getHumanReadableInterfaceName(alert_info.ifid),
    num_dropped = alert_info.num_dropped,
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. alert_info.ifid
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_dropped_alerts,
  i18n_title = i18n("show_alerts.dropped_alerts"),
  icon = "fas fa-exclamation-triangle",
  i18n_description = formatDroppedAlerts,
  creator = createDroppedAlerts,
}
