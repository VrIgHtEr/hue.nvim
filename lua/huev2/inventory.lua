package.loaded['huev2.rest'] = nil
package.loaded['huev2.inventory'] = nil

local M = { inventory = {} }

local rest = require 'huev2.rest'
local hue = require 'huev2'
local a = require 'toolshed.async'

local inventory = M.inventory

local adders = {
    light = function(_) end,
    scene = function(_) end,
    room = function(_) end,
    zone = function(_) end,
    bridge_home = function(_) end,
    grouped_light = function(_) end,
    device = function(_) end,
    bridge = function(_) end,
    device_power = function(_) end,
    zigbee_connectivity = function(_) end,
    zgp_connectivity = function(_) end,
    motion = function(_) end,
    temperature = function(_) end,
    light_level = function(_) end,
    button = function(_) end,
    behavior_script = function(_) end,
    behavior_instance = function(_) end,
    geofence_client = function(_) end,
    geolocation = function(_) end,
    entertainment_configuration = function(_) end,
    entertainment = function(_) end,
    homekit = function(_) end,
}

local function add_resource(x)
    local adder = adders[x.type]
    if adder then
        local folder = inventory[x.type]
        if not folder then
            folder = {}
            inventory[x.type] = folder
        end
        if folder[x.id] then
            return false
        end
        folder[x.id] = x
        adder(x)
        return true
    else
        print('UNKNOWN RESOURCE TYPE: ' .. x.type)
        return false
    end
end

local function populate_inventory(response)
    if response.data then
        for _, v in ipairs(response.data) do
            add_resource(v)
        end
    end
end

a.run(function()
    vim.api.nvim_exec('mes clear', true)
    local ret, err = a.wait(rest.request_async(hue.url_api .. '/resource', {
        method = 'GET',
        headers = {
            ['hue-application-key'] = hue.appkey,
        },
    }))
    if not ret then
        return nil, 'ERROR: ' .. err
    end
    if ret.status ~= 200 then
        return nil, 'HTTP_STATUS:' .. tostring(ret.status)
    end
    if ret.headers['content-type'] ~= 'application/json' then
        return nil, 'CONTENT_FORMAT:' .. ret.headers['Content-Type']
    end
    a.main_loop()
    local success, response = pcall(vim.fn.json_decode, ret.body)
    if not success then
        return nil, 'MALFORMED_RESPONSE'
    end
    populate_inventory(response)
    return response
end)

return M
