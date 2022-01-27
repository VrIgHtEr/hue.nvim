local M = {}

require 'toolshed.util.string.global'
local a = require 'toolshed.async'

local cleanup = nil

local resources = { grouped_light = {}, device = {}, bridge = {}, light = {}, scene = {}, room = {}, motion = {}, button = {} }

local function notify(message, is_error)
    if type(message) ~= 'string' then
        message = ''
    end
    if is_error then
        is_error = 'error'
    else
        is_error = 'info'
    end
    vim.schedule(function()
        vim.notify(message, is_error, { title = 'Philips Hue' })
    end)
end

local function log(message)
    notify(message)
end
local function logerr(message)
    notify(message, true)
end

local function create_signals_table()
    local decode, encode = {}, {}
    for k, v in pairs(vim.loop.constants) do
        if k:len() > 3 and k:sub(1, 3) == 'SIG' then
            decode[k] = v
            encode[v] = k
        end
    end
    return encode, decode
end

local signal_encode, signal_decode = create_signals_table()

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
            print(vim.inspect(update))
            print('UPDATE:' .. res_type .. '/' .. res_id)
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
        'https://' .. _G['hue-url'] .. '/eventstream/clip/v2',
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
                        if event_cb then
                            for _, event in ipairs(lua_events) do
                                event.creationtime = nil
                                event.id = nil
                                event_cb(event)
                            end
                        end
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

function M.start()
    a.run(function()
        local function check_missing_global(key)
            return type(_G[key]) ~= 'string'
        end
        if check_missing_global 'hue-application-key' or check_missing_global 'hue-url' then
            return
        end
        local task, cancel = listen_event_async_cancelable(hue_event_handler, function(status, protocol)
            if status ~= 200 then
                logerr('Failed to start event listener.\n Connected with ' .. protocol .. ' but got status code ' .. status)
            end
        end)
        cleanup = cancel
        local code, signal = a.wait(task)
        pcall(function()
            if signal_encode(signal) then
                signal = signal_encode[signal]
            end
            log('Event listener has stopped\n' .. 'RETURN: ' .. code .. '\nSIGNAL: ' .. signal)
        end)
    end)
end

function M.stop()
    if cleanup then
        cleanup()
    end
end

return M
