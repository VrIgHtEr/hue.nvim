local M = {}
local defrows, defcols = 20, 20
local hue = require 'hue'

local function fanout(coord, radius, lights)
    local amt = #lights
    local angle = math.pi * 2 / amt
    local ret = {}
    for i = 1, amt do
        local x = angle * (i - 1)
        local c = { math.sin(x) * radius + coord[1], math.cos(x) * radius + coord[2] }
        ret[lights[i]] = c
    end
    return ret
end

local coordinates = {
    ['study light'] = { 0.9, 0.2 },
    ['front door light'] = { 0.05, 0.95 },
    ['shower light'] = { 0.9, 0.05 },
    ['The Sun'] = { 0.8, 0.1 },
}

local function merge(tbl)
    for k, v in pairs(tbl) do
        coordinates[k] = v
    end
end

merge(fanout({ 0.3, 0.1 }, 0.05, {
    'spare bedroom light 1',
    'spare bedroom light 2',
    'spare bedroom light 3',
    'spare bedroom light 4',
    'spare bedroom light 5',
    'spare bedroom light 6',
}))

merge(fanout({ 0.4, 0.5 }, 0.05, {
    'living room light 1',
    'living room light 2',
    'living room light 3',
    'living room light 4',
}))

merge(fanout({ 0.75, 0.75 }, 0.05, {
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

local function get_quantized_map_entries(rows, cols)
    local entries = get_map_entries()
    for _, x in ipairs(entries) do
        x[1], x[2] = math.floor(x[1] * (rows - 1) + 0.5) + 1, math.floor(x[2] * (cols - 1) + 0.5) + 1
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

local function get_map(rows, cols)
    local entries = get_quantized_map_entries(rows, cols)
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
        for r = 1, rows do
            local line = {}
            for c = 1, cols do
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

local function render(rows, cols)
    local lines = get_map(rows, cols)
    local max = math.floor((rows + 1) / 2)
    for r = 1, max do
        local rc = lines[r]
        local r2 = r * 2
        local r1 = lines[r2 - 1]
        if r2 > rows then
            for c = 1, cols do
                if r1[c] == '.' then
                    rc[c] = '🮎'
                elseif r1[c] == 'O' then
                    rc[c] = '▀'
                else
                    rc[c] = ' '
                end
            end
        else
            r2 = lines[r2]
            for c = 1, cols do
                if r1[c] == '.' then
                    if r2[c] == '.' then
                        rc[c] = '▒'
                    elseif r2[c] == 'O' then
                        rc[c] = '🮒'
                    else
                        rc[c] = '🮎'
                    end
                elseif r1[c] == 'O' then
                    if r2[c] == '.' then
                        rc[c] = '🮑'
                    elseif r2[c] == 'O' then
                        rc[c] = '█'
                    else
                        rc[c] = '▀'
                    end
                elseif r2[c] == '.' then
                    rc[c] = '🮏'
                elseif r2[c] == 'O' then
                    rc[c] = '▄'
                else
                    rc[c] = ' '
                end
            end
        end
    end
    for r = rows, max + 1, -1 do
        table.remove(lines, r)
    end
    for r = max, 1, -1 do
        lines[r] = table.concat(lines[r])
    end
    return lines
end

local win = nil
local buf = nil

function M.show(rows, cols)
    if rows == nil then
        rows = defrows
    end
    if cols == nil then
        cols = defcols
    end
    if type(rows) ~= 'number' then
        return nil, 'rows is not a number'
    end
    if type(cols) ~= 'number' then
        return nil, 'cols is not a number'
    end
    cols, rows = math.floor(cols), math.floor(rows)
    if rows < 1 then
        return nil, 'rows < 1'
    end
    if cols < 1 then
        return nil, 'cols < 1'
    end
    defrows, defcols = rows, cols

    local cwin = vim.api.nvim_get_current_win()

    if win then
        local success = pcall(vim.api.nvim_set_current_win, win)
        if not success then
            win = nil
        end
    end

    local lines = render(rows, cols)

    if not buf then
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, 'filetype', 'philips_hue_map')
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    if not win then
        win = vim.api.nvim_open_win(buf, false, {
            width = cols,
            height = math.floor((rows + 1) / 2),
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

    vim.api.nvim_set_current_win(cwin)
end

function M.hide()
    if win then
        vim.api.nvim_win_close(win, true)
        win = nil
    end
end

function M.toggle(rows, cols)
    if win then
        M.hide()
    else
        M.show(rows, cols)
    end
end

local function redraw()
    vim.schedule(function()
        if win then
            return M.show(defrows, defcols)
        end
    end)
end

hue.subscribe('light.on', redraw)

return M
