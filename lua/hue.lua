-- username:  "VvK6VXe-OW-AVeaE-KBf08aro9ohw9qiOAvI5UZF"
-- clientkey: "2031F8B38804A3823110B1D08AAED1A1"
local M = {lights = {}}
require 'hue.stringutils'
local http = require 'http'
local a = require 'toolshed.async'

local function new_http_request_opts()
    return {method = "GET", headers = {['content-type'] = "application/json"}}
end

function M.new(host)
    assert(host ~= nil, "host cannot be nil")
    assert(type(host) == "string", "host must be a string")
    local U = "VvK6VXe-OW-AVeaE-KBf08aro9ohw9qiOAvI5UZF"
    local P = {base = '/api'}
    P.api = P.base .. "/" .. U

    local N = {lights = {}, groups = {}}

    local request_async = function(method, path, request)
        return function(step)
            return a.run(function()
                local opts = new_http_request_opts()
                opts.method = method
                if request then
                    a.main_loop()
                    opts.body = vim.fn.json_encode(request)
                end
                local req, err = http.request_a(host, P.api .. path, opts)
                if not req then return step(nil, err) end
                if req.status ~= 200 then
                    return step(nil, "invalid return status: " ..
                                    tostring(req.status))
                end
                if req.headers["content-type"] ~= "application/json" then
                    return step(nil, "invalid content-type: " ..
                                    vim.inspect(req.headers["content-type"]))
                end
                a.main_loop()
                local ret = vim.fn.json_decode(table.concat(req.body, '\n'))
                if not ret then
                    return step(nil, "failed to decode json")
                end
                return step(ret)
            end)
        end
    end

    local function new_group(id, group)
        local L = {id = id, data = group}
        L.path = "/groups/" .. tostring(id)

        function L.action_async(state)
            return request_async("PUT", L.path .. '/action', state)
        end
        function L.refresh_async()
            return function(step)
                return a.run(function()
                    local resp, err = a.wait(request_async("GET", L.path))
                    if not resp then return step(nil, err) end
                    L.data = resp
                    return step(L)
                end)
            end
        end

        return a.create_await_wrappers(L)
    end

    local function new_light(id, light)
        local L = {id = id, data = light}
        L.path = "/lights/" .. tostring(id)

        function L.state_async(state)
            return request_async("PUT", L.path .. '/state', state)
        end
        function L.refresh_async()
            return function(step)
                return a.run(function()
                    local resp, err = a.wait(request_async("GET", L.path))
                    if not resp then return step(nil, err) end
                    L.data = resp
                    return step(L)
                end)
            end
        end

        return a.create_await_wrappers(L)
    end

    N.lights.get_async = function(id)
        assert(id == nil or type(id) == 'string', "id must be a string")
        return function(step)
            return a.run(function()
                local path = "/lights"
                if id then path = path .. '/' .. id end
                local response, err = a.wait(request_async("GET", path))
                if not response then return step(nil, err) end
                local ret
                if not id then
                    ret = {}
                    for k, v in pairs(response) do
                        ret[k] = new_light(k, v)
                    end
                else
                    ret = new_light(id, response)
                end
                return step(ret)
            end)
        end
    end

    N.groups.get_async = function(id)
        assert(id == nil or type(id) == 'string', "id must be a string")
        return function(step)
            return a.run(function()
                local path = "/groups"
                if id then path = path .. '/' .. id end
                local response, err = a.wait(request_async("GET", path))
                if not response then return step(nil, err) end
                local ret
                if not id then
                    ret = {}
                    for k, v in pairs(response) do
                        ret[k] = new_group(k, v)
                    end
                else
                    ret = new_group(id, response)
                end
                return step(ret)
            end)
        end
    end

    N.lights.find_by_name_async = function(name)
        assert(name, "name must be provided")
        assert(type(name) == "string", "name must be a string")
        return function(step)
            return a.run(function()
                local lights, err = N.lights.get_a()
                if not lights then
                    return step(nil,
                                "could not retrieve lights: " .. tostring(err))
                end
                local best, distance = nil, nil
                for _, v in pairs(lights) do
                    local dist = name:distance(v.data.name)
                    if not distance or dist < distance then
                        best, distance = v, dist
                    end
                end
                if not best then return -1 end
                return step(best)
            end)
        end
    end

    return a.create_await_wrappers(N)
end

a.create_await_wrappers(M)

M = M.new("hue")
return M
