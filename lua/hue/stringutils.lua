local M = {}

function M.chars(str)
    local i, max = 0, #str
    return function()
        if i < max then
            i = i + 1
            return str:sub(i, i)
        end
    end
end
string.chars = M.chars

function M.bytes(str)
    local i, max = 0, #str
    return function()
        if i < max then
            i = i + 1
            return str:byte(i)
        end
    end
end
string.bytes = M.bytes

function M.codepoints(str)
    local nxt, cache = str:bytes()
    return function()
        local c = cache or nxt()
        cache = nil
        if c == nil then return end
        if c <= 127 then return string.char(c) end
        assert(c >= 194 and c <= 244,
               "invalid byte in utf-8 sequence: " .. tostring(c))
        local ret = {c}
        c = nxt()
        assert(c, "unexpected eof in utf-8 string")
        assert(c >= 128 and c <= 191,
               "expected multibyte sequence: " .. tostring(c))
        table.insert(ret, c)
        local count = 2
        while true do
            cache = nxt()
            if not cache or cache < 128 or cache > 191 then break end
            count = count + 1
            if count > 4 then
                error "multibyte sequence too long in utf-8 string"
            end
            table.insert(ret, cache)
        end
        return string.char(unpack(ret))
    end
end
string.codepoints = M.codepoints

function M.filteredcodepoints(str)
    local codepoint, cache = str:codepoints()
    return function()
        local cp = cache or codepoint()
        cache = nil
        if cp == '\r' then
            cache = codepoint()
            if cache == "\n" then cache = nil end
            return "\n"
        elseif cp then
            return cp
        end
    end
end
string.filteredcodepoints = M.filteredcodepoints

function M.lines(str)
    local codepoints = str:filteredcodepoints()
    return function()
        local line = {}
        for c in codepoints do
            if c == nil or c == '\n' then
                if c or #line > 0 then return table.concat(line) end
                return
            end
            table.insert(line, c)
        end
    end
end
string.lines = M.lines

function M.trim(s)
    local from = s:match "^%s*()"
    return from > #s and "" or s:match(".*%S", from)
end
string.trim = M.trim

function M.distance(A, B)
    local la, lb, x = A:len(), B:len(), {}
    if la == 0 then return lb end
    if lb == 0 then return la end
    if la < lb then A, la, B, lb = B, lb, A, la end
    for i = 1, lb do x[i] = i end
    for r = 1, la do
        local t, l, v = r - 1, r, A:sub(r, r)
        for c = 1, lb do
            if v ~= B:sub(c, c) then
                if x[c] < t then t = x[c] end
                if l < t then t = l end
                t = t + 1
            end
            x[c], l, t = t, t, x[c]
        end
    end
    return x[lb]
end
string.distance = M.distance
return M
