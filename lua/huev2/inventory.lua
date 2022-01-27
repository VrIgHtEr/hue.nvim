package.loaded['huev2.rest'] = nil
package.loaded['huev2.inventory'] = nil

local M = { inventory = {} }

local rest = require 'huev2.rest'
local hue = require 'huev2'
local a = require 'toolshed.async'

local inventory = M.inventory

local function find(tbl)
    if type(tbl) == 'table' and type(tbl.rid) == 'string' and type(tbl.rtype) == 'string' and inventory[tbl.rtype] then
        return inventory[tbl.rtype][tbl.rid]
    end
end

local function link(x, key)
    if type(key) ~= 'string' then
        key = 'owner'
    end
    local owner = find(x[key])
    if not owner then
        return false
    end
    x[key] = owner
    return true
end

local linkers = {
    light = link,
    scene = function(x)
        link(x, 'group')
        for _, y in ipairs(x.actions) do
            link(y, 'target')
        end
    end,
    room = function(_) end,
    zone = function(_) end,
    bridge_home = function(_) end,
    grouped_light = function(_) end,
    device = function(_) end,
    bridge = link,
    device_power = link,
    zigbee_connectivity = link,
    zgp_connectivity = function(_) end,
    motion = link,
    temperature = link,
    light_level = link,
    button = function(_) end,
    behavior_script = function(_) end,
    behavior_instance = function(_) end,
    geofence_client = function(_) end,
    geolocation = function(_) end,
    entertainment_configuration = function(_) end,
    entertainment = link,
    homekit = function(_) end,
}

local function add_resource(x)
    if linkers[x.type] then
        local folder = inventory[x.type]
        if not folder then
            folder = {}
            inventory[x.type] = folder
        end
        if folder[x.id] then
            return false
        end
        folder[x.id] = x
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
    for _, resources in pairs(inventory) do
        for _, x in pairs(resources) do
            if not linkers[x.type](x) then
                print 'ERROR!!!!!'
            end
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

    inventory.scene = nil
    inventory.temperature = nil
    inventory.zigbee_connectivity = nil
    inventory.motion = nil
    inventory.light_level = nil
    inventory.light = nil
    inventory.geolocation = nil
    inventory.homekit = nil
    inventory.grouped_light = nil
    inventory.entertainment = nil
    inventory.device_power = nil
    inventory.behavior_script = nil
    inventory.bridge = nil

    --incomplete
    inventory.room = nil
    inventory.entertainment_configuration = nil
    inventory.device = nil
    inventory.bridge_home = nil
    inventory.behavior_instance = nil
    print(vim.inspect(inventory))
    return response
end)

return M
