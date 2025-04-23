return {
	"xiyaowong/transparent.nvim",
	-- make sure it loads after your colorscheme
	dependencies = { "folke/tokyonight.nvim" },
	config = function()
		require("transparent").setup({
			enable = true,
			-- you can fine‑tune which highlight groups to keep or clear
			extra_groups = {
				"Normal",
				"NormalFloat",
				"TelescopeNormal",
				"WhichKey",
			},
			exclude = { "Comment", "LineNr" },
		})

		require("transparent").clear_prefix("BufferLine")
	end,
}
