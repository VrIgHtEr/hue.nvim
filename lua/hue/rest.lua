local M = {}
local a = require 'toolshed.async'
local defaultFlags = { '-kvs' }

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

return M
