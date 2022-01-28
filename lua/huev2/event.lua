local M = {}
local hue = require 'huev2.constants'

local user_events = {}

local function get_table(key)
    local keys = {}
    while key:len() > 0 do
        local i = key:find '[.]'
        if not i then
            table.insert(keys, key)
            key = ''
        elseif i == 1 or i == key:len() then
            return
        else
            table.insert(keys, key:sub(1, i - 1))
            key = key:sub(i + 1)
        end
    end
    if #keys > 0 then
        local ret = user_events
        for _, k in ipairs(keys) do
            local next = ret[k]
            if not next then
                next = {}
                ret[k] = next
            end
            ret = next
        end
        return ret
    end
end

function M.subscribe(key, cb)
    if type(key) ~= 'string' or type(cb) ~= 'function' then
        return false
    end
    local tbl = get_table(key)
    if not tbl or tbl[cb] then
        return false
    end
    tbl[cb] = true
    return true
end

function M.unsubscribe(key, cb)
    if type(key) ~= 'string' or type(cb) ~= 'function' then
        return false
    end
    local tbl = get_table(key)
    if not tbl or not tbl[cb] then
        return false
    end
    tbl[cb] = nil
    return true
end

function M.fire(r, key)
    local handlers = user_events[r.type]
    if handlers then
        local handler = handlers[key]
        if handler then
            for k in pairs(handler) do
                if type(k) == 'function' then
                    k(r, r[key])
                end
            end
        end
    end
end

return M