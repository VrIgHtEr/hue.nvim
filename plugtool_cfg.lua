return {
    needs = { 'nvim-telescope/telescope.nvim' },
    after = { 'nvim-telescope/telescope.nvim' },
    config = function()
        require('huev2').start()
        nnoremap('<leader>sS', ':lua require"hue/telescope".toggle_lights()()<cr>', 'silent', 'Hue: switch on and off individual lights')
        nnoremap('<leader>ss', ':lua require"hue/telescope".toggle_groups()()<cr>', 'silent', 'Hue: switch on and off room lights')
    end,
}
