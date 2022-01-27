local M = {}

local cleanup = nil
local resources = { light = {}, grouped_light = {} }
local function hue_event_handler(event)
    local etype = event.type
    event.type = nil
    if etype == 'update' then
        for _, update in ipairs(event.data) do
            local res_id = update.id
            local res_type = update.type
            update.id, update.type, update.id_v1, update.owner = nil, nil, nil, nil
            if not resources[res_id] then
                resources[res_id] = {}
            end
            if not resources[res_type] then
                resources[res_type] = {}
            end
            if not resources[res_type][res_id] then
                resources[res_type][res_id] = resources[res_id]
            end
            for k, v in pairs(update) do
                resources[res_id][k] = v
            end
        end
    end
end

local function process_events(events, event_cb)
    if event_cb then
        for _, event in ipairs(events) do
            event.creationtime = nil
            event.id = nil
            event_cb(event)
        end
    end
end

local function listen_event_async_cancelable(event_cb, status_cb, header_cb)
    local cmd = {
        'curl',
        '-vskNH',
        'hue-application-key: ' .. _G['hue-application-key'],
        '-H',
        'Accept: text/event-stream',
        'https://vrighter.com/eventstream/clip/v2',
    }
    local firstheader = true
    local previd = nil
    local skipping = true
    return a.spawn_lines_async(cmd, function(line)
        if line:len() == 0 or line:sub(1, 1) == ':' then
            return
        end
        local idx = line:find ': '
        if idx then
            local linetype = line:sub(1, idx - 1)
            line = line:sub(idx + 2)

            if linetype == 'id' then
                idx = line:find ':'
                if idx then
                    line = line:sub(1, idx - 1)
                    local id = tonumber(line)
                    if previd == nil or id > previd then
                        previd = id
                        skipping = false
                    else
                        skipping = true
                    end
                else
                    skipping = true
                end
            elseif linetype == 'data' and not skipping and event_cb then
                return vim.schedule(function()
                    local success, lua_events = pcall(vim.fn.json_decode, line)
                    if success then
                        return process_events(lua_events, event_cb)
                    end
                end)
            end
        end
    end, function(line)
        if #line >= 3 and line:sub(1, 1) == '<' then
            line = line:sub(3)
            local protocol, status = nil, nil
            if firstheader then
                firstheader = false
                local idx = line:find ' '
                if idx then
                    protocol = line:sub(1, idx - 1)
                    line = line:sub(idx + 1)
                    idx = line:find ' '
                    if idx then
                        status = tonumber(line:sub(1, idx - 1))
                    end
                end
                if status_cb then
                    return vim.schedule(function()
                        return status_cb(status, protocol)
                    end)
                end
            else
                local idx = line:find ': '
                if idx then
                    if header_cb then
                        return vim.schedule(function()
                            return header_cb(line:sub(1, idx - 1), line:sub(idx + 2))
                        end)
                    end
                end
            end
        end
    end)
end

require 'toolshed.util.string.global'
function M.start()
    a.run(function()
        local task, cancel = listen_event_async_cancelable(hue_event_handler, function(status, protocol)
            print(protocol .. ' ' .. status)
        end)
        cleanup = cancel
        a.wait(task)
    end)
end

function M.stop()
    if cleanup then
        cleanup()
    end
end

return M
