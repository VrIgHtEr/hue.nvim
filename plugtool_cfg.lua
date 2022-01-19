return {
	needs = { "nvim-telescope/telescope.nvim", "b0o/mapx.nvim" },
	after = { "nvim-telescope/telescope.nvim" },
	config = {
		{
			function()
				nnoremap(
					"<leader>sS",
					':lua require"hue/telescope".toggle_lights()()<cr>',
					"silent",
					"Hue: switch on and off individual lights"
				)
				nnoremap(
					"<leader>ss",
					':lua require"hue/telescope".toggle_groups()()<cr>',
					"silent",
					"Hue: switch on and off room lights"
				)
			end,
			after = "b0o/mapx.nvim",
		},
	},
}
