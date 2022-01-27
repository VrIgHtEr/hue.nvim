local M = {}
local a = require 'toolshed.async'
local defaultFlags = { '-kvs' }

local cleanup = function() end

function M.request_async(url, opts)
    if type(url) ~= 'string' then
        error('Invalid url type. Expected string but got ' .. type(url))
    end

    if opts == nil then
        opts = {}
    elseif type(opts) ~= 'table' then
        error('Invalid opts type. Expected table but got ' .. type(opts))
    end

    if opts.method == nil then
        opts.method = 'GET'
    elseif type(opts.method) ~= 'string' then
        error('Invalid method type. Expected string but got ' .. type(opts.method))
    elseif opts.method ~= 'GET' and opts.method ~= 'POST' and opts.method ~= 'PUT' and opts.method ~= 'PATCH' and opts.method ~= 'DELETE' then
        error('Invalid method. Must be one of GET, POST, PUT, PATCH, DELETE but got ' .. opts.method)
    end

    if opts.headers == nil then
        opts.headers = {}
    elseif type(opts.headers) ~= 'table' then
        error('Invalid headers type. Expected table but got ' .. type(opts.headers))
    else
        for k, v in pairs(opts.headers) do
            if type(k) ~= 'string' then
                error('Invalid header key. Expected string but got ' .. type(k))
            end
            if type(v) ~= 'string' then
                error('Invalid header value (' .. k .. '). Expected string but got ' .. type(v))
            end
        end
    end

    if opts.flags == nil then
        opts.flags = {}
        for _, x in ipairs(defaultFlags) do
            table.insert(opts.flags, x)
        end
    elseif type(opts.flags) ~= 'table' then
        error('Invalid flags type. Expected table but got ' .. type(opts.flags))
    else
        for _, x in ipairs(opts.flags) do
            if type(x) ~= 'string' then
                error('Invalid flags item type. Expected string but got ' .. type(x))
            end
        end
    end

    if opts.body ~= nil then
        if type(opts.body) ~= 'string' then
            error('Invalid body type. Expected string but got ' .. type(opts.body))
        end
    end

    local cmd = { 'curl' }
    for _, x in ipairs(opts.flags) do
        table.insert(cmd, x)
    end
    table.insert(cmd, '-X')
    table.insert(cmd, opts.method)
    for k, v in pairs(opts.headers) do
        table.insert(cmd, '-H')
        table.insert(cmd, k .. ': ' .. v)
    end
    if opts.body then
        table.insert(cmd, '-d')
        table.insert(cmd, opts.body)
    end
    table.insert(cmd, url)

    local rxout = { '' }
    cmd.stdout = function(_, data)
        if data then
            table.insert(rxout, data)
        end
    end

    local rxerr = {}
    cmd.stderr = function(_, data)
        if data then
            table.insert(rxerr, data)
        end
    end

    return function(callback)
        a.run(function()
            local err = a.wait(a.spawn_async(cmd))
            if err == 0 then
                rxout = table.concat(rxout)
                rxerr = table.concat(rxerr)
                local headers = {}
                for x in rxerr:lines() do
                    if #x >= 2 and x:sub(1, 1) == '<' then
                        table.insert(headers, x:sub(3))
                    end
                end

                if #headers < 1 then
                    callback(nil, 'invalid http response')
                end
                local index = headers[1]:find ' '
                local meta = {
                    protocol = headers[1]:sub(1, index - 1),
                    status = tonumber(headers[1]:sub(index + 1)),
                    headers = {},
                    body = rxout,
                }
                for i = 2, #headers do
                    local x = headers[i]
                    index = x:find ': '
                    if index then
                        local key = x:sub(1, index - 1)
                        local value = x:sub(index + 2)
                        meta.headers[key] = value
                    end
                end

                return callback(meta)
            else
                return callback(nil, err)
            end
        end)
    end
end

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
vim.api.nvim_exec('mes clear', true)
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

vim.api.nvim_exec(
    [[
augroup hue_event_close_group
    autocmd!
    autocmd VimLeave * lua require'hue.curl'.stop()
augroup END
]],
    true
)
return M
