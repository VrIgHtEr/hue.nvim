local M = {}

if type(_G['hue-application-key']) ~= 'string' or type(_G['hue-url']) ~= 'string' then
    M.misconfigured = true
    return M
end
local cachePath = vim.fn.stdpath 'cache'
M.headersPath = cachePath .. '/hue.nvim.curl.conf'
do
    local uv = vim.loop
    local stat = uv.fs_stat(cachePath)
    if stat then
        if stat.type ~= 'directory' then
            error 'cache path is not a directory'
        end
    else
        if not uv.fs_mkdir(cachePath) then
            error 'could not create cache directory'
        end
    end

    local file = uv.fs_open(M.headersPath, 'w', tonumber('600', 8))
    if not file then
        error 'could not open cache file'
    end
    if not uv.fs_write(file, '-H "hue-application-key: ' .. _G['hue-application-key'] .. '"') then
        uv.fs_close(file)
        error 'could not write authentication header file'
    end
    uv.fs_close(file)
end

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
