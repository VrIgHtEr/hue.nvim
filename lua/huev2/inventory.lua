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
                    table.insert(s, v)
                end
            end
        end
    end
end

local resource_types = {
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
    if resource_types[x.type] then
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

local running = false
function M.refresh()
    if running then
        return
    end
    running = true
    a.run(function()
        local ret, err = a.wait(rest.request_async(hue.url_api .. '/resource', {
            method = 'GET',
            headers = {
                ['hue-application-key'] = hue.appkey,
            },
        }))
        if not ret then
            running = false
            return nil, 'ERROR: ' .. err
        end
        if ret.status ~= 200 then
            running = false
            return nil, 'HTTP_STATUS:' .. tostring(ret.status)
        end
        if ret.headers['content-type'] ~= 'application/json' then
            running = false
            return nil, 'CONTENT_FORMAT:' .. ret.headers['Content-Type']
        end
        a.main_loop()
        local success, response = pcall(vim.fn.json_decode, ret.body)
        if not success then
            running = false
            return nil, 'MALFORMED_RESPONSE'
        end
        populate_inventory(response)
        link_inventory()
        running = false
        return response
    end)
end

local function update_resource(e)
    print(vim.inspect(e))
    print('UPDATE:' .. e.type .. '/' .. e.id)
end

local function process_event(e)
    local owner = find(e.owner)
    if owner then
        e.owner = owner
        update_resource(e)
    end
end

function M.on_event(e)
    -- TODO use queue if inventory scan is running
    process_event(e)
end

return M
