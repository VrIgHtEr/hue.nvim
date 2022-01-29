local M = {}
local hue = require 'huev2'
function M.show()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { 'test', 'text' })
    local opts = {
        relative = 'cursor',
        width = 10,
        height = 2,
        col = 0,
        row = 1,
        anchor = 'NW',
        style = 'minimal',
    }
    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_win_set_option(win, 'winhl', 'Normal:MyHighlight')
end

return M
