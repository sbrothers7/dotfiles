return {
	{
		"folke/tokyonight.nvim",
		priority = 1000, -- load this first
		config = function()
			require("tokyonight").setup({
				style = "night",
				on_colors = function(colors)
					colors.fg = "#CBE0F0"
					colors.fg_dark = "#B4D0E9"
					colors.fg_gutter = "#627E97"
				end,

				transparent = true,
				styles = {
					sidebars = "transparent", -- e.g. NvimTree, vista, etc.
					floats = "transparent", -- popups, Telescope, LSP windows
				},
			})

			-- finally load the scheme
			vim.cmd([[colorscheme tokyonight]])
		end,
	},
}
