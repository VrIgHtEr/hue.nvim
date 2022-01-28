return {
    needs = { 'nvim-telescope/telescope.nvim' },
    after = { 'nvim-telescope/telescope.nvim' },
    config = function()
        nnoremap('<leader>sS', ':lua require"hue/telescope".toggle_lights()()<cr>', 'silent', 'Hue: switch on and off individual lights')
        nnoremap('<leader>ss', ':lua require"hue/telescope".toggle_groups()()<cr>', 'silent', 'Hue: switch on and off room lights')

        require('huev2').subscribe('light.on', function(r, c)
            local str = 'Turned '
            if c.on then
                str = str .. 'on '
            else
                str = str .. 'off '
            end
            str = str .. r.owner.metadata.name
            require('huev2.notify').log(str)
        end)
        vim.api.nvim_exec("augroup hue_event_close_group\nautocmd!\nautocmd VimLeave * lua require'huev2'.stop()\naugroup END", true)
        require('huev2').start()
    end,
}
