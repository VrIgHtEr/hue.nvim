local M = {}

local rest = require 'huev2.rest'
local hue = require 'huev2'
local a = require 'toolshed.async'
local json = require 'toolshed.util.json'

local inventory = {}
local resource_tables = {}

local function get_resource(rtype, rid)
    if rtype and rid then
        local folder = inventory[rtype]
        if folder then
            return folder[rid]
        end
    end
end

local function find(tbl)
    if type(tbl) == 'table' and vim.tbl_count(tbl) == 2 and type(tbl.rid) == 'string' and type(tbl.rtype) == 'string' then
        return get_resource(tbl.rtype, tbl.rid)
    end
end

local function link(x)
    local s = { x }
    while #s > 0 do
        local c = table.remove(s)
        for k, v in pairs(c) do
            if type(v) == 'table' then
                local l = find(v)
                if l then
                    c[k] = l
                else
                    table.insert(s, v)
                end
            end
        end
    end
end

local function add_resource(x)
    if hue.url_resources[x.type] then
        local folder = inventory[x.type]
        if not folder then
            folder = {}
            inventory[x.type] = folder
        end
        if folder[x.id] then
            return false
        end
        folder[x.id] = x
        x.id_v1 = nil
        resource_tables[x] = true
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

local function unlink_event(e)
    local q = { e }
    while #q > 0 do
        local x = table.remove(q)
        if type(x) == 'table' then
            for k, v in pairs(x) do
                if resource_tables[v] then
                    x[k] = v.type .. '/' .. v.id
                else
                    table.insert(q, v)
                end
            end
        end
    end
end

local update_events = {
    light = function(r, e)
        local str = { 'Updated ' .. r.type .. ': ' .. r.owner.metadata.name }
        unlink_event(e)
        table.insert(str, vim.inspect(e))
        hue.log(table.concat(str, '\n'))
    end,
}

local function update_resource(r, e)
    local R, E = r, e

    local q = { { r, e } }
    while #q > 0 do
        r, e = unpack(table.remove(q))
        for k, v in pairs(e) do
            if type(v) == 'table' then
                if resource_tables[v] then
                    r[k] = v
                else
                    table.insert(q, { r[k], v })
                end
            else
                r[k] = v
            end
        end
    end
    local handler = update_events[R.type]
    if handler then
        handler(R, E)
    else
        print('UPDATE:' .. R.type .. '/' .. R.id)
    end
end

local refreshing = false
local function process_update(e)
    local r = get_resource(e.type, e.id)
    e.type, e.id = nil, nil
    link(e)
    if r then
        update_resource(r, e)
    end
end

local function process_add(e)
    print(vim.inspect(e))
    print('ADD:' .. e.type .. '/' .. e.id)
end

local function process_delete(e)
    print(vim.inspect(e))
    print('DELETE:' .. e.type .. '/' .. e.id)
end

local function process_error(e)
    print(vim.inspect(e))
    print('ERROR:' .. e.type .. '/' .. e.id)
end

local processing = false

local q = require('toolshed.util.generic.queue').new()

local function event_loop()
    if not processing and not refreshing then
        processing = true
        while not refreshing and q:size() > 0 do
            local e = q:dequeue()
            if e.type == 'update' then
                process_update(e.event)
            elseif e.type == 'add' then
                process_add(e.event)
            elseif e.type == 'delete' then
                process_delete(e.event)
            elseif e.type == 'error' then
                process_error(e.event)
            end
        end
        processing = false
    end
end

function M.on_event(etype, e)
    q:enqueue { type = etype, event = e }
    event_loop()
end

function M.refresh()
    if not refreshing then
        refreshing = true
        a.run(function()
            local ret, err = a.wait(rest.request_async(hue.url_resource, {
                method = 'GET',
                headers = { ['hue-application-key'] = hue.appkey },
            }))
            if not ret then
                refreshing = false
                event_loop()
                return nil, 'ERROR: ' .. err
            end
            if ret.status ~= 200 then
                refreshing = false
                event_loop()
                return nil, 'HTTP_STATUS:' .. tostring(ret.status)
            end
            if ret.headers['content-type'] ~= 'application/json' then
                refreshing = false
                event_loop()
                return nil, 'CONTENT_FORMAT:' .. ret.headers['Content-Type']
            end
            a.main_loop()
            local success, response = pcall(json.decode, ret.body)
            if not success then
                refreshing = false
                event_loop()
                return nil, 'MALFORMED_RESPONSE'
            end
            populate_inventory(response)
            link(inventory)
            refreshing = false
            event_loop()
            return response
        end)
    end
end

return M
