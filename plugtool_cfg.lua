return {
    needs = { 'nvim-telescope/telescope.nvim' },
    after = { 'nvim-telescope/telescope.nvim' },
    before = { 'nvim-lualine/lualine.nvim' },
    config = {
        function()
            nnoremap('<leader>sS', ':lua require"huev1/telescope".toggle_lights()()<cr>', 'silent', 'Hue: switch on and off individual lights')
            nnoremap('<leader>ss', ':lua require"huev1/telescope".toggle_groups()()<cr>', 'silent', 'Hue: switch on and off room lights')
            nnoremap('<leader>sm', ':lua require"hue.map".toggle()<cr>', 'silent', 'Hue: switch on and off room lights')
            nnoremap('<leader>sp', ':lua require"hue.pixel".toggle()<cr>', 'silent', 'Hue: switch on and off pixel display')
            vim.api.nvim_exec("augroup hue_event_close_group\nautocmd!\nautocmd VimLeave * lua require'hue'.stop()\naugroup END", true)
            require('hue').start()

            local rows = 30
            require('hue.map').setup { rows = rows, cols = math.floor(rows * 1.4857143) }
            require('hue.pixel').setup { rows = 120, cols = 160 }
        end,
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
