local M = {}

local rest = require 'huev2.rest'
local hue = require 'huev2'
local a = require 'toolshed.async'

local inventory = {}

local function get_resource(rtype, rid)
    local folder = inventory[rtype]
    if folder then
        return folder[rid]
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

local refreshing = false
local function process_update(e)
    print(vim.inspect(e))
    print('UPDATE:' .. e.type .. '/' .. e.id)
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
    if refreshing then
        return
    end
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
        local success, response = pcall(vim.fn.json_decode, ret.body)
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

return M
