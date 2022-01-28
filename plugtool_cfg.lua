return {
    needs = { 'nvim-telescope/telescope.nvim' },
    after = { 'nvim-telescope/telescope.nvim' },
    before = { 'nvim-lualine/lualine.nvim' },
    config = {
        function()
            nnoremap('<leader>sS', ':lua require"hue/telescope".toggle_lights()()<cr>', 'silent', 'Hue: switch on and off individual lights')
            nnoremap('<leader>ss', ':lua require"hue/telescope".toggle_groups()()<cr>', 'silent', 'Hue: switch on and off room lights')
            vim.api.nvim_exec("augroup hue_event_close_group\nautocmd!\nautocmd VimLeave * lua require'huev2'.stop()\naugroup END", true)
            require('huev2').start()
        end,
        {
            before = 'nvim-lualine/lualine.nvim',
            function()
                local config = require('plugtool').state 'nvim-lualine/lualine.nvim'
                if config.sections == nil then
                    config.sections = {}
                end
                if config.sections.lualine_c == nil then
                    config.sections.lualine_c = {}
                end
                table.insert(config.sections.lualine_c, "require'huev2.statusline'()")
            end,
        },
        {
            after = 'nvim-lualine/lualine.nvim',
            function()
                local statusline = require('lualine').statusline
                require('huev2').subscribe('light.on', function()
                    vim.schedule(statusline)
                end)
            end,
        },
    },
}
