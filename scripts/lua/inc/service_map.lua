--
-- (C) 2013-20 - ntop.org
--

require "flow_utils"

print('<link href="'.. ntop.getHttpPrefix()..'/datatables/datatables.min.css" rel="stylesheet"/>')

print ('<div class="d-flex justify-content-start"><H3>' .. i18n("service_map") .. "</H3>")

if(_GET["host"] ~= nil) then
   print('&nbsp; <A HREF="/lua/if_stats.lua?page=service_map"><span class="fas fa-ethernet"></span></A>')
end

print [[
</div>
<div class='table-responsive'>
<table id="service_map" class="table table-bordered table-striped w-100">
        <thead>
            <tr>
                <th>]] print(i18n("protocol")) print [[</th>
                <th>]] print(i18n("client")) print [[</th>
                <th>]] print(i18n("server")) print [[</th>
                <th>]] print(i18n("vlan_id")) print [[</th>
                <th>]] print(i18n("port")) print [[</th>
                <th>]] print(i18n("num_uses")) print [[</th>
                <th>]] print(i18n("last_seen")) print [[</th>
                <th>]] print(i18n("info")) print [[</th>
            </tr>
        </thead>
</table>
</div>
]]

if(isAdministrator()) then
   if(_GET["action"] == "reset") then
      interface.flushServiceMap()
   end


   if(ifid ~= nil) then
     print [[
<div class="d-flex justify-content-start">
<form>
	      <input type=hidden name="ifid" value="]] print(ifid.."") print [[">
<input type=hidden name="page" value="service_map">
<input type=hidden name="action" value="reset">

<button id="btn-factory-reset" data-target='#reset-modal' data-toggle="modal" class="btn btn-danger" onclick="return confirm(']] print(i18n("data_flush_confirm")) print [[')">
 <i class="fas fa-undo-alt"></i> ]] print(i18n("flush_service_map_data")) print [[
</button>
</form>
&nbsp;
<a href="]] print(ntop.getHttpPrefix()) print [[ /lua/get_service_map.lua" target="_blank" class="btn btn-primary" role="button" aria-disabled="true"><i class="fas fa-download"></i></a>
</div>
]]
     end
   end

print [[
<script>
$(document).ready(function() {
  const filters = [
]]

local p = interface.serviceMap() or {}

local keys = {}
local keys_regex = {}

local host_ip = _GET["host"]

for k,v in pairs(p) do
   if((host_ip == nil)
	 or (v.client == host_ip)
      or (v.server == host_ip) ) then
      local k = "^".. getL4ProtoName(v.l4_proto) .. ":" .. v.l7_proto .."$"

      keys_regex[v.l7_proto] = k

      k = v.l7_proto
      if(keys[k] == nil) then
	 keys[k] = 0
      end
      keys[k] = keys[k] + 1
   end
end

local id = 0
for k,v in pairsByKeys(keys, asc) do
   print("{ key: 'filter_"..id.."', regex: '"..keys_regex[k].."', label: '"..k.." ("..v..")', countable: false },\n")
   id = id + 1
end

print [[
   ];
  let url    = ']] print(ntop.getHttpPrefix()) print [[/lua/get_service_map.lua]]

if(_GET["host"] ~= nil) then print("?host=".._GET["host"]) end

print [[';
  let config = DataTableUtils.getStdDatatableConfig( [ {
            text: '<i class="fas fa-sync"></i>',
            action: function(e, dt, node, config) {
                $serviceTable.ajax.reload();
            }
        } ]);

  config = DataTableUtils.setAjaxConfig(config, url, 'data');

  config["initComplete"] = function(settings, rows) {
    const tableAPI = settings.oInstance.api();
  }

  const $serviceTable = $('#service_map').DataTable(config);
  const columnProtocolIndex = 0; /* Filter on protocol column */

  const periodicityMenuFilters = new DataTableFiltersMenu({
    filterTitle: "]] print(i18n("protocol")) print[[",
    tableAPI: $serviceTable,
    filters: filters,
    filterMenuKey: 'protocol',
    columnIndex: columnProtocolIndex
  });

} );

 i18n.all = "]] print(i18n("all")) print [[";
 i18n.showing_x_to_y_rows = "]] print(i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'})) print[[";

</script>

]]
