local M = {}
local hue = require 'hue'

local options = {
    setup_pending = true,
    rows = 20,
    cols = 20,
    ns = nil,
}

local win = nil
local buf = nil

local function redraw()
    vim.schedule(function()
        if win then
            return M.show()
        end
    end)
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
    if options.setup_pending then
        hue.subscribe('light.on', redraw)
    end
    options.setup_pending = false
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
        M.show()
    end
end

local function fanout(coord, radius, lights)
    local amt = #lights
    local angle = math.pi * 2 / amt
    local ret = {}
    for i = 1, amt do
        local x = angle * (i - 1) + (angle / 2)
        local c = { math.sin(x) * radius + coord[1], math.cos(x) * radius + coord[2] }
        ret[lights[i]] = c
    end
    return ret
end

local coordinates = {
    ['study light'] = { 0.84813756, 0.31791908 },
    ['front door light'] = { 0.27793694, 0.973025 },
    ['shower light'] = { 0.8338109, 0.17148362 },
    ['The Sun'] = { 0.55300856, 0.18304431 },
}

local function merge(tbl)
    for k, v in pairs(tbl) do
        coordinates[k] = v
    end
end

merge(fanout({ 0.17765045, 0.20809248 }, 0.03, {
    'spare bedroom light 1',
    'spare bedroom light 2',
    'spare bedroom light 3',
    'spare bedroom light 4',
    'spare bedroom light 5',
    'spare bedroom light 6',
}))

merge(fanout({ 0.37535816, 0.5761079 }, 0.025, {
    'living room light 1',
    'living room light 2',
    'living room light 3',
    'living room light 4',
}))

merge(fanout({ 0.6790831, 0.6416185 }, 0.03, {
    'kitchen light 1',
    'kitchen light 2',
    'kitchen light 3',
}))

local function get_map_entries()
    local ret = {}
    local inv = hue.inventory()
    if inv.light then
        for _, light in pairs(inv.light) do
            local bulb = light.owner
            local name = bulb.metadata.name
            local coord = coordinates[name]
            local state = light.on
            if coord then
                local row, col = coord[1], coord[2]
                if row < 0 then
                    row = 0
                elseif row > 1 then
                    row = 1
                end
                if col < 0 then
                    col = 0
                elseif col > 1 then
                    col = 1
                end
                table.insert(ret, { row, col, on = state.on, name = name })
            end
        end
    end
    return ret
end

local function get_quantized_map_entries()
    local entries = get_map_entries()
    for _, x in ipairs(entries) do
        x[1], x[2] = math.floor(x[1] * (options.rows - 1) + 0.5) + 1, math.floor(x[2] * (options.cols - 1) + 0.5) + 1
    end
    table.sort(entries, function(a, b)
        if a[1] < b[1] then
            return true
        elseif a[1] > b[1] then
            return false
        end
        if a[2] < b[2] then
            return true
        elseif a[2] > b[2] then
            return false
        end
        return a.on and not b.on
    end)
    return entries
end

local function get_map()
    local entries = get_quantized_map_entries()
    local idx = 0
    local function next()
        if idx ~= #entries then
            idx = idx + 1
            return entries[idx]
        end
    end

    if entries then
        local n = next()
        local lines = {}
        for r = 1, options.rows do
            local line = {}
            for c = 1, options.cols do
                if not n or n[1] > r or n[2] > c then
                    line[c] = ' '
                else
                    if n.on then
                        line[c] = 'O'
                    else
                        line[c] = '.'
                    end
                    repeat
                        n = next()
                    until not n or n[1] > r or n[2] > c
                end
            end
            lines[r] = line
        end
        return lines
    end
end

local colors = {
    black = 0,
    dark_blue = 1,
    dark_green = 2,
    dark_cyan = 3,
    dark_red = 4,
    dark_magenta = 5,
    dark_yellow = 6,
    light_gray = 7,
    dark_gray = 8,
    blue = 9,
    green = 10,
    cyan = 11,
    red = 12,
    magenta = 13,
    yellow = 14,
    white = 15,
}

local theme = {
    empty = { char = ' ' },
    top_only_off = { char = '▀', hl_def = { guifg = '#555555' } },
    top_only_on = { char = '▀', hl_def = { guifg = '#ffffff' } },
    bottom_only_off = { char = '▄', hl_def = { guifg = '#555555' } },
    bottom_only_on = { char = '▄', hl_def = { guifg = '#ffffff' } },
    both_off = { char = '█', hl_def = { guifg = '#555555' } },
    both_on = { char = '█', hl_def = { guifg = '#ffffff' } },
    top_off_bottom_on = { char = '▄', hl_def = { guifg = '#ffffff', guibg = '#555555' } },
    top_on_bottom_off = { char = '▄', hl_def = { guifg = '#555555', guibg = '#ffffff' } },
}

local function render()
    local highlights = {}
    local lines = get_map()
    local max = math.floor((options.rows + 1) / 2)
    for r = 1, max do
        local rc = lines[r]
        local r2 = r * 2
        local r1 = lines[r2 - 1]
        local chl = 0
        if r2 > options.rows then
            for c = 1, options.cols do
                local th
                if r1[c] == '.' then
                    th = 'top_only_off'
                elseif r1[c] == 'O' then
                    th = 'top_only_on'
                else
                    th = 'empty'
                end
                local t = theme[th]
                rc[c] = t.char
                local nchl = chl + t.char:len()
                if t.hl_def then
                    table.insert(highlights, { row = r - 1, col = chl, col_end = nchl, hl = th })
                end
                chl = nchl
            end
        else
            r2 = lines[r2]
            for c = 1, options.cols do
                local th
                if r1[c] == '.' then
                    if r2[c] == '.' then
                        th = 'both_off'
                    elseif r2[c] == 'O' then
                        th = 'top_off_bottom_on'
                    else
                        th = 'top_only_off'
                    end
                elseif r1[c] == 'O' then
                    if r2[c] == '.' then
                        th = 'top_on_bottom_off'
                    elseif r2[c] == 'O' then
                        th = 'both_on'
                    else
                        th = 'top_only_on'
                    end
                elseif r2[c] == '.' then
                    th = 'bottom_only_off'
                elseif r2[c] == 'O' then
                    th = 'bottom_only_on'
                else
                    th = 'empty'
                end
                local t = theme[th]
                rc[c] = t.char
                local nchl = chl + t.char:len()
                if t.hl_def then
                    table.insert(highlights, { row = r - 1, col = chl, col_end = nchl, hl = th })
                end
                chl = nchl
            end
        end
    end
    for r = options.rows, max + 1, -1 do
        table.remove(lines, r)
    end
    for r = max, 1, -1 do
        lines[r] = table.concat(lines[r])
    end
    return lines, highlights
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

    local lines, highlights = render()

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

    for name, t in pairs(theme) do
        if t.hl_def then
            local cmd = { 'highlight', name }
            if t.hl_def.guifg then
                table.insert(cmd, 'guifg=' .. t.hl_def.guifg)
            end
            if t.hl_def.guibg then
                table.insert(cmd, 'guibg=' .. t.hl_def.guibg)
            end
            vim.api.nvim_exec(table.concat(cmd, ' '), true)
        end
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    for _, h in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, options.ns, h.hl, h.row, h.col, h.col_end)
    end
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    vim.api.nvim_set_current_win(cwin)
end
return M
