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

local function link_inventory()
    local s = { inventory }
    while #s > 0 do
        local c = table.remove(s)
        for k, v in pairs(c) do
            if type(v) == 'table' then
                local link = find(v)
                if link then
                    c[k] = link
                else
                    if v.rid and v.rtype then
                        print 'ERROR!!!!!'
                    end
                    table.insert(s, v)
                end
            end
        end
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
    light = true,
    scene = true,
    room = true,
    zone = true,
    bridge_home = true,
    grouped_light = true,
    device = true,
    bridge = true,
    device_power = true,
    zigbee_connectivity = true,
    zgp_connectivity = true,
    motion = true,
    temperature = true,
    light_level = true,
    button = true,
    behavior_script = true,
    behavior_instance = true,
    geofence_client = true,
    geolocation = true,
    entertainment_configuration = true,
    entertainment = true,
    homekit = true,
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

    link_inventory()
    print(vim.inspect(inventory))
    return response
end)

return M
