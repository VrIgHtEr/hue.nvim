local M = {}

if type(_G['hue-application-key']) ~= 'string' or type(_G['hue-url']) ~= 'string' then
    M.misconfigured = true
    return M
end

M.appkey = _G['hue-application-key']
M.host = _G['hue-url']
M.url_head = 'https://' .. M.host
M.url_tail = '/clip/v2'
M.url_api = M.url_head .. M.url_tail
M.url_event = M.url_head .. '/eventstream' .. M.url_tail

M.url_resource = M.url_api .. '/resource'

M.url_resources = {
    light = M.url_resource .. '/light',
    scene = M.url_resource .. '/scene',
    room = M.url_resource .. '/room',
    zone = M.url_resource .. '/zone',
    bridge_home = M.url_resource .. '/bridge_home',
    grouped_light = M.url_resource .. '/grouped_light',
    device = M.url_resource .. '/device',
    bridge = M.url_resource .. '/bridge',
    device_power = M.url_resource .. '/device_power',
    zigbee_connectivity = M.url_resource .. '/zigbee_connectivity',
    zgp_connectivity = M.url_resource .. '/zgp_connectivity',
    motion = M.url_resource .. '/motion',
    temperature = M.url_resource .. '/temperature',
    light_level = M.url_resource .. '/light_level',
    button = M.url_resource .. '/button',
    behavior_script = M.url_resource .. '/behavior_script',
    behavior_instance = M.url_resource .. '/behavior_instance',
    geofence_client = M.url_resource .. '/geofence_client',
    geolocation = M.url_resource .. '/geolocation',
    entertainment_configuration = M.url_resource .. '/entertainment_configuration',
    entertainment = M.url_resource .. '/entertainment',
    homekit = M.url_resource .. '/homekit',
}

return M
