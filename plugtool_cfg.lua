return {
    needs = { 'nvim-telescope/telescope.nvim' },
    after = { 'nvim-telescope/telescope.nvim' },
    before = { 'nvim-lualine/lualine.nvim' },
    config = {
        function()
            nnoremap('<leader>sS', ':lua require"huev1/telescope".toggle_lights()()<cr>', 'silent', 'Hue: switch on and off individual lights')
            nnoremap('<leader>ss', ':lua require"huev1/telescope".toggle_groups()()<cr>', 'silent', 'Hue: switch on and off room lights')
            nnoremap('<leader>sm', ':lua require"hue/map".toggle(30,30)<cr>', 'silent', 'Hue: switch on and off room lights')
            vim.api.nvim_exec("augroup hue_event_close_group\nautocmd!\nautocmd VimLeave * lua require'hue'.stop()\naugroup END", true)
            require('hue').start()
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
                table.insert(config.sections.lualine_c, "require'hue.statusline'()")
            end,
        },
        {
            after = 'nvim-lualine/lualine.nvim',
            function()
                local statusline = require('lualine').statusline
                require('hue').subscribe('light.on', function()
                    vim.schedule(statusline)
                end)
            end,
        },
        {
            function()
                local state = require('plugtool').state 'lukas-reineke/indent-blankline.nvim'
                if not state.excludedfiletypes then
                    state.excludedfiletypes = {}
                end
                table.insert(state.excludedfiletypes, 'philips_hue_map')
            end,
            before = 'lukas-reineke/indent-blankline.nvim',
        },
    },
}
