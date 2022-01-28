local M = {}
local hue = require 'huev2.constants'
local inventory = require 'huev2.inventory'
local json = require 'toolshed.util.json'

if hue.misconfigured then
    return M
end

require 'toolshed.util.string.global'
local a = require 'toolshed.async'
local sig = require 'toolshed.util.sys.signal'
local cleanup = nil

local function hue_event_handler(event)
    for _, update in ipairs(event.data) do
        update.id_v1 = nil
        inventory.on_event(event.type, update)
    end
end

local function listen_event_async_cancelable(event_cb, status_cb, header_cb)
    local cmd = {
        'curl',
        '-vskNH',
        'hue-application-key: ' .. hue.appkey,
        '-H',
        'Accept: text/event-stream',
        hue.url_event,
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
                local success, lua_events = pcall(json.decode, line)
                if success then
                    if event_cb then
                        for _, event in ipairs(lua_events) do
                            event.creationtime = nil
                            event.id = nil
                            event_cb(event)
                        end
                    end
                end
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
                    return status_cb(status, protocol)
                end
            else
                local idx = line:find ': '
                if idx then
                    if header_cb then
                        return header_cb(line:sub(1, idx - 1), line:sub(idx + 2))
                    end
                end
            end
        end
    end)
end

local errors = require 'huev2.curl-errors'

local function check_retry(code, signal)
    if code ~= errors.OK then
        return false, 'Listener process returned nonzero return code: ' .. code .. ' ' .. (errors[code] or '')
    else
        if signal == sig.int then
            return false
        end
        return true
    end
end

function M.start()
    a.run(function()
        ::retry::
        local task, cancel = listen_event_async_cancelable(hue_event_handler)
        cleanup = cancel
        inventory.refresh()
        local code, signal = a.wait(task)
        if not code then
            return nil, 'Failed to start listener process' .. tostring(signal)
        end
        local r, err = check_retry(code, signal)
        if r then
            goto retry
        end
        if err then
            return nil, err
        end
        cleanup = nil
    end)
end

function M.stop()
    if cleanup then
        cleanup()
    end
end

return M
