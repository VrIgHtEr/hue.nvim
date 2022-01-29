local M = {}
local hue = require 'hue'
local coordinates = {
    ['study light'] = { 0.9, 0.2 },
    ['The Sun'] = { 0.8, 0.1 },
    ['front door light'] = { 0.05, 0.95 },
}

function M.get_map_entries()
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

function M.get_quantized_map_entries(rows, cols)
    local entries = M.get_map_entries()
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

function M.get_map(rows, cols)
    local entries = M.get_quantized_map_entries(rows, cols)
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
                    line[c * 2 - 1] = ' '
                    line[c * 2] = ' '
                else
                    if n.on then
                        line[c * 2 - 1] = 'O'
                        line[c * 2] = 'O'
                    else
                        line[c * 2 - 1] = '.'
                        line[c * 2] = '.'
                    end
                    repeat
                        n = next()
                    until not n or n[1] > r or n[2] > c
                end
            end
            lines[r] = table.concat(line)
        end
        return lines
    end
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

    local lines = M.get_map(rows, cols)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'philips_hue_map')
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    local win = vim.api.nvim_open_win(buf, false, {
        width = cols * 2,
        height = rows,
        relative = 'editor',
        col = 1073741824,
        row = 0,
        anchor = 'NE',
        style = 'minimal',
        focusable = false,
        border = 'rounded',
    })
    vim.api.nvim_set_current_win(win)
    vim.bo.filetype = 'philips_hue_map'
    vim.bo.modifiable = false
end

return M
--[[
package.loaded['hue.map'] = nil print(require'hue.map'.show(20, 20))
--]]
