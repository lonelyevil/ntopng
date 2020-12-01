--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local page_utils = require("page_utils")
local tracker = require("tracker")
local storage_utils = require("storage_utils")
local cpu_utils = require("cpu_utils")

if not isAllowedSystemInterface() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("error_not_granted").."</div>")
   return
end

sendHTTPContentTypeHeader('application/json')

local stats = cpu_utils.systemHostStats()
stats.epoch = os.time()
stats.storage = storage_utils.storageInfo()

print(json.encode(stats, nil))
