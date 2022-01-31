local M = {}

local options = {
    setup_pending = true,
    rows = 20,
    cols = 20,
    ns = nil,
}

local win = nil
local buf = nil
local hlindex = 0
local grid = {}
local highlights = {}

local freelist = {}
local hlcache = {}
local hlgroups = {}

function math.round(x)
    if x >= 0 then
        return math.floor(x + 0.5)
    else
        return -math.floor(-x + 0.5)
    end
end

function M.int_to_rgb(i)
    return bit.band(bit.rshift(i, 16), 255, bit.band(bit.rshift(i, 8), 255, bit.band(i, 255)))
end

function M.rgb_to_int(r, g, b)
    return bit.lshift(math.round(math.min(255, math.max(0, r))), 16)
        + bit.lshift(math.round(math.min(255, math.max(0, g))), 8)
        + math.round(math.min(255, math.max(0, b)))
end

local function velocityvector()
    local scaling = 0.025
    return { x = (math.random() * -0.5) * 2 * scaling, y = (math.random() * -0.5) * 2 * scaling }
end

local vertices = {
    { pos = { x = math.random(), y = math.random() }, vel = velocityvector(), color = M.rgb_to_int(255, 0, 0) },
    { pos = { x = math.random(), y = math.random() }, vel = velocityvector(), color = M.rgb_to_int(0, 255, 0) },
    { pos = { x = math.random(), y = math.random() }, vel = velocityvector(), color = M.rgb_to_int(0, 0, 255) },
    { pos = { x = math.random(), y = math.random() }, vel = velocityvector(), color = M.rgb_to_int(255, 255, 0) },
    { pos = { x = math.random(), y = math.random() }, vel = velocityvector(), color = M.rgb_to_int(0, 255, 255) },
    { pos = { x = math.random(), y = math.random() }, vel = velocityvector(), color = M.rgb_to_int(255, 0, 255) },
}

local function update_vertex(v)
    v.pos.x = v.pos.x + v.vel.x
    if v.pos.x < 0 then
        v.pos.x = -v.pos.x
        v.vel.x = -v.vel.x
    end
    if v.pos.x > 1 then
        v.pos.x = 2 - v.pos.x
        v.vel.x = -v.vel.x
    end
    v.pos.y = v.pos.y + v.vel.y
    if v.pos.y < 0 then
        v.pos.y = -v.pos.y
        v.vel.y = -v.vel.y
    end
    if v.pos.y > 1 then
        v.pos.y = 2 - v.pos.y
        v.vel.y = -v.vel.y
    end
end

local function redraw()
    vim.schedule(function()
        if win then
            M.drawing.clear()
            for i, x in ipairs(vertices) do
                update_vertex(x)
            end
            for i, x in ipairs(vertices) do
                local j
                if i == 1 then
                    j = #vertices
                else
                    j = i - 1
                end
                local a, b = vertices[j], x
                M.drawing.line(
                    a.pos.x * (options.cols - 1) + 1,
                    a.pos.y * (options.rows - 1) + 1,
                    b.pos.x * (options.cols - 1) + 1,
                    b.pos.y * (options.rows - 1) + 1,
                    a.color
                )
            end
            return M.show()
        end
    end)
end

local function refresh_highlights()
    for group, pair in pairs(hlgroups) do
        vim.api.nvim_exec('highlight ' .. group .. ' guifg=' .. M.int_to_hex(pair.a) .. ' guibg=' .. M.int_to_hex(pair.b), true)
    end
end

M.drawing = {}

function M.drawing.clear(col)
    if not col then
        col = 0
    end
    for r = 1, options.rows do
        for c = 1, options.cols do
            M.setpixel(r, c, col)
        end
    end
end

function M.drawing.line(x0, y0, x1, y1, col)
    if not col then
        col = 16777215
    end
    x0, y0, x1, y1 = math.round(x0), math.round(y0), math.round(x1), math.round(y1)

    local dx = math.abs(x1 - x0)
    local sx
    if x0 < x1 then
        sx = 1
    else
        sx = -1
    end
    local dy = -math.abs(y1 - y0)
    local sy
    if y0 < y1 then
        sy = 1
    else
        sy = -1
    end
    local err = dx + dy
    while true do
        grid[y0][x0] = col
        --M.setpixel(y0, x0, col)
        if x0 == x1 and y0 == y1 then
            break
        end
        local e2 = 2 * err
        if e2 >= dy then
            if x0 == x1 then
                break
            end
            err = err + dy
            x0 = x0 + sx
        end
        if e2 <= dx then
            if y0 == y1 then
                break
            end
            err = err + dx
            y0 = y0 + sy
        end
    end
end

function M.setup(opts)
    if not opts then
        opts = {}
    end
    if not opts.rows then
        opts.rows = options.rows
    end
    if not opts.cols then
        opts.cols = options.cols
    end
    if type(opts.rows) ~= 'number' then
        return nil, 'rows is not a number'
    end
    if type(opts.cols) ~= 'number' then
        return nil, 'cols is not a number'
    end
    opts.cols, opts.rows = math.floor(opts.cols), math.floor(opts.rows)
    if opts.rows < 1 then
        return nil, 'rows < 1'
    end
    if opts.cols < 1 then
        return nil, 'cols < 1'
    end
    options.rows, options.cols = opts.rows, opts.cols
    options.ns = vim.api.nvim_create_namespace 'vrighter_hue_map'
    for i = 1, options.rows do
        local row = {}
        grid[i] = row
        for j = 1, options.cols do
            row[j] = 0
        end
    end
    local max = math.floor((options.rows + 1) / 2)
    for i = 1, max do
        local r2 = i * 2
        local r1 = r2 - 1
        local row = {}
        highlights[i] = row
        for j = 1, options.cols do
            local col1 = grid[r1][j]
            local col2
            if r2 <= options.rows then
                col2 = grid[r2][j]
            else
                col2 = 0
            end
            row[j] = M.use_color_pair(col1, col2)
        end
    end
    options.setup_pending = false
end

function M.getpixel(r, c)
    if type(r) ~= 'number' or r < 1 or type(c) ~= 'number' or c < 1 or r > options.rows or c > options.cols then
        return
    end
    return grid[r][c]
end

local function decode_hex(hex)
    local ret = 0
    for i = 1, hex:len() do
        local c, byte = hex:sub(i, i)
        ret = ret * 16
        if c >= '0' and c <= '9' then
            byte = string.byte(c) - string.byte '0'
        elseif c >= 'a' and c <= 'f' then
            byte = string.byte(c) - string.byte 'a'
        elseif c >= 'A' and c <= 'F' then
            byte = string.byte(c) - string.byte 'A'
        else
            return
        end
        ret = ret + byte
    end
    return ret
end

function M.setpixel(r, c, color)
    if type(r) ~= 'number' or r < 1 or type(c) ~= 'number' or c < 1 or r > options.rows or c > options.cols then
        return false
    end
    local col
    if type(color) == 'number' then
        col = bit.band(color, 16777215)
    elseif type(color) == 'string' then
        local len = color:len()
        if len > 1 and color:sub(1, 1) == '#' then
            if len == 4 then
                local red, green, blue = decode_hex(color:sub(2, 2)), decode_hex(color:sub(3, 3)), decode_hex(color:sub(4, 4))
                col = M.rgb_to_int(bit.lshift(red, 4) + red, bit.lshift(green, 4) + green, bit.lshift(blue, 4) + blue)
            elseif len == 7 then
                col = M.rgb_to_int(decode_hex(color:sub(2, 3)), decode_hex(color:sub(4, 5)), decode_hex(color:sub(6, 7)))
            else
                return false
            end
        else
            return false
        end
    elseif type(color) == 'table' then
        if type(color[1]) ~= 'number' or type(color[2]) ~= 'number' or type(color[3]) ~= 'number' then
            if type(color.r) ~= 'number' or type(color.g) ~= 'number' or type(color.b) ~= 'number' then
                return false
            else
                col = M.rgb_to_int(color.r, color.g, color.b)
            end
        else
            col = M.rgb_to_int(col[1], col[2], col[3])
        end
    end
    grid[r][c] = col
    return true
end

local hexstr = '0123456789abcdef'

function M.int_to_hex(x)
    local ret = { '#' }
    for i = 7, 2, -1 do
        local n = bit.band(x, 15) + 1
        ret[i] = hexstr:sub(n, n)
        x = bit.rshift(x, 4)
    end
    return table.concat(ret)
end

function M.group_name(id)
    return 'px' .. tostring(id)
end

function M.use_color_pair(a, b)
    local cached = hlcache[a]
    if not cached then
        cached = { count = 0 }
        hlcache[a] = cached
    end
    cached = cached[b]

    if not cached then
        local id
        if #freelist > 0 then
            id = table.remove(freelist)
        else
            id = hlindex
            hlindex = hlindex + 1
        end
        cached = { refcount = 0, id = id, group = M.group_name(id) }
        hlgroups[cached.group] = { a = a, b = b }

        hlcache[a][b] = cached
        local cmd = 'highlight ' .. cached.group .. ' guifg=' .. M.int_to_hex(a) .. ' guibg=' .. M.int_to_hex(b)
        vim.api.nvim_exec(cmd, true)
    end
    cached.refcount = cached.refcount + 1
    return cached.group
end

function M.unuse_highlight(hl)
    local key = hlgroups[hl]
    if key then
        local cached = hlcache[key.a][key.b]
        cached.refcount = cached.refcount - 1
        if cached.refcount == 0 then
            hlgroups[cached.group] = nil
            local cmd = 'highlight clear ' .. cached.group
            vim.api.nvim_exec(cmd, true)
            table.insert(freelist, cached.id)
            hlcache[key.a][key.b] = nil
            hlcache[key.a].count = hlcache[key.a].count - 1
            if hlcache[key.a].count == 0 then
                hlcache[key.a] = nil
            end
        end
    end
end

function M.hide()
    if options.setup_pending then
        return
    end
    if win then
        vim.api.nvim_win_close(win, true)
        win = nil
    end
end

function M.toggle()
    if options.setup_pending then
        return
    end
    if win then
        M.hide()
    else
        refresh_highlights()
        M.show()
    end
end

local function render()
    local lines = {}
    local hl = {}

    local max = math.floor((options.rows + 1) / 2)
    for r = 1, max do
        local r2 = r * 2
        local r1 = r2 - 1
        local line = {}
        local hl_col_index = 0
        local row = highlights[r]
        for c = 1, options.cols do
            local col1 = grid[r1][c]
            local col2
            if r2 <= options.rows then
                col2 = grid[r2][c]
            else
                col2 = 0
            end
            M.unuse_highlight(row[c])
            row[c] = M.use_color_pair(col1, col2)
            local char = '▀'
            local newhlindex = hl_col_index + char:len()
            table.insert(line, char)
            table.insert(hl, { row = r - 1, col = hl_col_index, col_end = newhlindex, hl = row[c] })
            hl_col_index = newhlindex
        end
        table.insert(lines, table.concat(line))
    end
    return lines, hl
end

function M.show()
    if options.setup_pending then
        return
    end
    local cwin = vim.api.nvim_get_current_win()

    if win then
        local success = pcall(vim.api.nvim_set_current_win, win)
        if not success then
            win = nil
        end
    end

    local lines, hl = render()

    if not buf then
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, 'filetype', 'philips_hue_map')
        vim.api.nvim_buf_set_option(buf, 'fileencoding', 'utf-8')
        vim.api.nvim_buf_set_option(buf, 'undolevels', -1)
    end

    if not win then
        win = vim.api.nvim_open_win(buf, false, {
            width = options.cols,
            height = math.floor((options.rows + 1) / 2),
            relative = 'editor',
            col = 1073741824,
            row = 0,
            anchor = 'NE',
            style = 'minimal',
            focusable = false,
            border = 'rounded',
        })
        vim.api.nvim_set_current_win(win)
    else
        vim.api.nvim_win_set_buf(win, buf)
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_clear_namespace(buf, options.ns, 0, -1)

    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    for _, h in ipairs(hl) do
        vim.api.nvim_buf_add_highlight(buf, options.ns, h.hl, h.row, h.col, h.col_end)
    end
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    vim.api.nvim_set_current_win(cwin)
end

local timer = vim.loop.new_timer()
vim.loop.timer_start(timer, 40, 40, redraw)

return M
