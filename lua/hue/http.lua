local http = {}

local a = require 'toolshed.async'
local uv = vim.loop

local stringstream = require 'hue.stringstream'

local parserstate = {start = 0, headers = 1, body = 2, finished = 3, err = -1}

local function http_parser()
    local state = parserstate.start
    local ret = {}
    ret = {
        process_line = function(line)
            if not line then state = parserstate.finished end
            if state == parserstate.start then
                local index = line:find(" ")
                if not index then
                    state = parserstate.err
                else
                    line = line:sub(index + 1)
                    index = line:find(" ")
                    if not index then
                        state = parserstate.err
                    else
                        line = line:sub(1, index - 1)
                        ret.status = tonumber(line)
                        if not ret.status then
                            state = parserstate.err
                        else
                            state = parserstate.headers
                        end
                    end
                end
            elseif state == parserstate.headers then
                if line == "" then
                    state = parserstate.body
                else
                    local index = line:find ':'
                    if not index then
                        state = parserstate.err
                    else
                        local key, value = string.lower(
                                               line:sub(1, index - 1):trim()),
                                           line:sub(index + 1):trim()
                        ret.headers[key] = value
                    end
                end
            elseif state == parserstate.body then
                table.insert(ret.body, line)
            end
        end,
        status = 0,
        headers = {},
        body = {}
    }
    return ret
end

http.request_async = function(host, path, opts)
    return function(step)
        if opts == nil then
            opts = {}
        elseif type(opts) ~= 'table' then
            return step(nil, "invalid opts")
        end
        if host == nil or type(host) ~= 'string' or host == "" then
            return step(nil, "invalid host")
        end
        if path == nil then path = "/" end
        if type(path) ~= 'string' or path == "" then
            return step(nil, "invalid path")
        end
        if opts.method == nil then
            opts.method = "GET"
        elseif not (opts.method == "GET" or opts.method == "POST" or opts.method ==
            "OPTIONS" or opts.method == "PUT" or opts.method == "DELETE" or
            opts.method == "HEAD") then
            return step(nil, "invalid method")
        end
        if opts.body == nil then
            opts.body = ""
        elseif type(opts.body) ~= "string" then
            if type(opts.body) ~= "table" then
                return step(nil, "invalid body")
            else
                for _, x in ipairs(opts.body) do
                    if type(x) ~= "string" then
                        return step(nil, "invalid body line")
                    end
                end
            end
        end
        if opts.headers == nil then
            opts.headers = {}
        elseif type(opts.headers) ~= "table" then
            return step(nil, "invalid headers")
        end
        for k, v in pairs(opts.headers) do
            if type(k) ~= 'string' or k == "" then
                return step(nil, "invalid header key")
            end
            if type(v) ~= 'string' then
                return step(nil, "invalid header value")
            end
        end
        if not opts.headers.Host then opts.headers.Host = host end
        return a.run(function()
            local addr, err = a.getaddrinfo_a(host, "http", {
                family = 'inet',
                protocol = 'tcp',
                socktype = 'stream'
            })
            if err then return step(nil, err) end
            if #addr == 0 then return step(nil, "host not found") end
            addr = addr[1]

            local client = uv.new_tcp('inet')
            if not client then return step(nil, client) end

            local function close() a.close_a(client) end
            local function shutdown()
                uv.read_stop(client)
                a.shutdown_a(client)
                close()
            end

            local success = a.tcp_connect_a(client, addr.addr, addr.port)
            if not success then
                close()
                return step(nil,
                            "failed to connect to " .. vim.inspect(addr.addr))
            end

            local streambuilder, finished, line, parser = stringstream.new(),
                                                          false, {},
                                                          http_parser()
            local function emit()
                parser.process_line(table.concat(line))
                line = {}
            end
            success = uv.read_start(client, function(e, data)
                if finished then return end
                if e then
                    finished = true
                    return a.run(function()
                        shutdown()
                        return step(nil, e)
                    end)
                end
                for x in streambuilder(data) do
                    if x == '\n' then
                        emit()
                    else
                        table.insert(line, x)
                    end
                end
                if data == nil then
                    finished = true
                    if #line > 0 then emit() end
                    parser.process_line()
                    return a.run(function()
                        shutdown()
                        return step(parser)
                    end)
                end
            end)
            if not success then
                shutdown()
                return step(nil, "failed to read")
            end

            local data = {opts.method .. " " .. path .. " HTTP/1.1"}

            if type(opts.body) == "string" then
                opts.headers["content-length"] = tostring(#opts.body)
            elseif #opts.body == 0 then
                opts.headers["content-length"] = "0"
            else
                local size = 0
                for _, x in ipairs(opts.body) do size = size + #x end
                size = size + 2 * (#opts.body - 1)
                opts.headers["content-length"] = tostring(size)
            end
            for k, v in pairs(opts.headers) do
                table.insert(data, k .. ": " .. v)
            end
            table.insert(data, "")

            if type(opts.body) == "string" then
                table.insert(data, opts.body)
            elseif #opts.body == 0 then
                table.insert(data, "")
            else
                for _, x in ipairs(opts.body) do
                    table.insert(data, x)
                end
            end
            success = a.write_a(client, table.concat(data, "\r\n"))
            if not success then
                shutdown()
                return step(nil, "failed to write")
            end
        end)
    end
end

a.create_await_wrappers(http)

return http
