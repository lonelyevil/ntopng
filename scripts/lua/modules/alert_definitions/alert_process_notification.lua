--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param event_type The string with the type of event
-- @param msg_details The details of the event
-- @return A table with the alert built
local function createProcessNotification(alert_severity, event_type, msg_details)
  local built = {
     alert_severity = alert_severity,
     alert_type_params = {
	msg_details = msg_details,
	event_type = event_type,
     },
  }

  return built
end

-- #######################################################

local function processNotificationFormatter(ifid, alert, info)
  if info.event_type == "start" then
    return string.format("%s %s", i18n("alert_messages.ntopng_start"), info.msg_details)
  elseif info.event_type == "stop" then
    return string.format("%s %s", i18n("alert_messages.ntopng_stop"), info.msg_details)
  elseif info.event_type == "update" then
    return string.format("%s %s", i18n("alert_messages.ntopng_update"), info.msg_details)
  elseif info.event_type == "anomalous_termination" then
    return string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), info.msg_details)
  end

  return "Unknown Process Event: " .. (info.event_type or "")
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_process_notification,
  i18n_title = "alerts_dashboard.process",
  i18n_description = processNotificationFormatter,
  icon = "fas fa-truck",
  creator = createProcessNotification,
}
