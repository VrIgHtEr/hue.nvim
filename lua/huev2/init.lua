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

return M
