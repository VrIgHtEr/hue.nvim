local M = {}
local MT = {}

function MT.size(q)
    if q.parity then
        return q.capacity - (q.tail - q.head)
    else
        return q.head - q.tail
    end
end

local function grow(q)
    local newbuf = {}
    for x in q:iterator() do table.insert(newbuf, x) end
    q.head = q:size()
    q.buf = newbuf
    q.capacity = q.capacity * 2
    q.parity = false
    q.tail = 0
end

function MT.enqueue(q, item)
    if q.parity and q.head == q.tail then grow(q) end
    q.head = q.head + 1
    q.buf[q.head] = item
    if q.head == q.capacity then
        q.parity = not q.parity
        q.head = 0
    end
    q.version = q.version + 1
end

function MT.dequeue(q)
    if q.parity or q.head ~= q.tail then
        q.tail = q.tail + 1
        local ret = q.buf[q.tail]
        q.buf[q.tail] = nil
        if q.tail == q.capacity then
            q.parity = not q.parity
            q.tail = 0
        end
        q.version = q.version + 1
        return ret
    end
end

function MT.iterator(q)
    local head = q.head
    local parity = q.parity
    local version = q.version

    return function()
        if version ~= q.version then
            error "collection modified while being iterated"
        end
        if head == q.tail and not parity then return nil end
        head = head + 1
        local ret = q.buf[head]
        if head == q.capacity then
            parity = not parity
            head = 0
        end
        return ret
    end
end

function M.new()
    return setmetatable({
        parity = false,
        head = 0,
        tail = 0,
        capacity = 1,
        version = 0,
        buf = {}
    }, MT)
end
function MT.__index(o, k) return MT[k] end
return M
