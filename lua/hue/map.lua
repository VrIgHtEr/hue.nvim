local M = {}
local hue = require 'hue'
local coordinates = {
    ['study light'] = { 0.9, 0.2 },
    ['The Sun'] = { 0.8, 0.1 },
    ['front door light'] = { 0.05, 0.95 },
}

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
        return a[2] < b[2]
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

function M.show(rows, cols)
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

    local lines = render(rows, cols)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'philips_hue_map')
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    local win = vim.api.nvim_open_win(buf, false, {
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
    nnoremap('q', function()
        vim.api.nvim_buf_delete(buf, { force = true })
    end, 'buffer', 'silent', 'Closes the light map')
    vim.bo.modifiable = false
end

return M
--[[
package.loaded['hue.map'] = nil print(require'hue.map'.show(20, 20))
--]]
