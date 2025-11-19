vim.g.mapleader = " "

do
	local dotnet9 = vim.fn.expand("$HOME/.dotnet9")
	if
		vim.fn.isdirectory(dotnet9) == 1 and not vim.env.PATH:find(dotnet9, 1, true) -- avoid duplicates
	then
		vim.env.PATH = dotnet9 .. ":" .. vim.env.PATH
	end
end

vim.opt.termguicolors = true
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "NONE" })

vim.opt.spell = true
vim.opt.spelllang = "en_us"

vim.wo.number = true
vim.wo.relativenumber = true

vim.opt.textwidth = 72

vim.wo.signcolumn = "number"

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		-- add your plugins here
		{
			"nvim-telescope/telescope.nvim",
			tag = "0.1.8",
			dependencies = { "nvim-lua/plenary.nvim" },
		},
		{
			"nvim-treesitter/nvim-treesitter",
			branch = "master",
			lazy = false,
			build = ":TSUpdate",
		},
		{
			"nvim-neo-tree/neo-tree.nvim",
			branch = "v3.x",
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-tree/nvim-web-devicons",
				"MunifTanjim/nui.nvim",
			},
		},
		{ "nvim-lualine/lualine.nvim" },
		{ "mason-org/mason.nvim" },
		{ "mason-org/mason-lspconfig.nvim" },
		{ "neovim/nvim-lspconfig" },
		{ "nvim-telescope/telescope-ui-select.nvim" },
		{ "nvimtools/none-ls.nvim", dependencies = { "nvimtools/none-ls-extras.nvim" } },
		{ "goolord/alpha-nvim" },
		{ "hrsh7th/nvim-cmp" },
		{ "L3MON4D3/LuaSnip" },
		{ "saadparwaiz1/cmp_luasnip" },
		{ "rafamadriz/friendly-snippets" },
		{ "hrsh7th/cmp-nvim-lsp" },
		{
			"folke/noice.nvim",
			event = "VeryLazy",
			opts = {
				-- add any options here
			},
			dependencies = {
				-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
				"MunifTanjim/nui.nvim",
				-- OPTIONAL:
				--   `nvim-notify` is only needed, if you want to use the notification view.
				--   If not available, we use `mini` as the fallback
				"rcarriga/nvim-notify",
			},
		},
		{
			"echasnovski/mini.pairs",
			opts = {
				modes = { insert = true, command = true, terminal = false },
				-- skip autopair when next character is one of these
				skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
				-- skip autopair when the cursor is inside these treesitter nodes
				skip_ts = { "string" },
				-- skip autopair when next character is closing pair
				-- and there are more closing pairs than opening pairs
				skip_unbalanced = true,
				-- better deal with markdown code blocks
				markdown = true,
			},
		},
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	-- install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})

local cmp = require("cmp")
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
	snippet = {
		-- REQUIRED - you must specify a snippet engine
		expand = function(args)
			require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
		end,
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" }, -- For luasnip users.
	}, {
		{ name = "buffer" },
	}),
})

-- Alpha-nvim configuration
local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

-- Load the header from test.lua in the same directory as init.lua
-- Since init.lua is in ~/.config/nvim/, we need to adjust the path
local config_path = vim.fn.stdpath("config")
package.path = package.path .. ";" .. config_path .. "/?.lua"
local test = require("test")
local logo = test.header

-- Set the header
dashboard.section.header.val = logo.val
dashboard.section.header.opts = {
	position = "center",
	hl = logo.opts.hl,
}

-- Configure buttons
dashboard.section.buttons.val = {
	dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
	dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
	dashboard.button("r", "  Recent files", ":Telescope oldfiles <CR>"),
	dashboard.button("c", "  Configuration", ":e $MYVIMRC <CR>"),
	dashboard.button("q", "  Quit", ":qa<CR>"),
}

local lazy_stats = require("lazy").stats() -- Get Lazy.nvim stats
dashboard.section.footer.val = {
	" " .. os.date("📅 %Y-%m-%d                     ⏰ %H:%M:%S") .. " ",
	" ",
	"             Plugins loaded: " .. lazy_stats.loaded .. " / " .. lazy_stats.count,
}
dashboard.section.footer.opts = {
	position = "center",
}
dashboard.section.footer.opts.hl = "Constant"

-- Setup alpha with the dashboard theme
alpha.setup(dashboard.config)

require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗",
		},
	},
})

require("mason-lspconfig").setup({
	automatic_enable = true,
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

vim.lsp.config("lua_ls", {
	capabilities = capabilities,
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if
				path ~= vim.fn.stdpath("config")
				and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
			then
				return
			end
		end

		client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
			runtime = {
				-- Tell the language server which version of Lua you're using (most
				-- likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
				-- Tell the language server how to find Lua modules same way as Neovim
				-- (see `:h lua-module-load`)
				path = {
					"lua/?.lua",
					"lua/?/init.lua",
				},
			},
			-- Make the server aware of Neovim runtime files
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME,
					-- Depending on the usage, you might want to add additional paths
					-- here.
					-- '${3rd}/luv/library'
					-- '${3rd}/busted/library'
				},
				-- Or pull in all of 'runtimepath'.
				-- NOTE: this is a lot slower and will cause issues when working on
				-- your own configuration.
				-- See https://github.com/neovim/nvim-lspconfig/issues/3189
				-- library = {
				--   vim.api.nvim_get_runtime_file('', true),
				-- }
			},
		})
	end,
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
			},
		},
	},
})
vim.lsp.enable("lua_ls")

vim.lsp.config("clangd", { capabilities = capabilities })
vim.lsp.enable("clangd")

vim.lsp.config("cmake", { capabilities = capabilities })
vim.lsp.enable("cmake")

vim.lsp.config("csharp_ls", { capabilities = capabilities })
vim.lsp.enable("csharp_ls")

vim.lsp.config("cspell_ls", { capabilities = capabilities })
vim.lsp.enable("cspell_ls")

vim.lsp.config("cspell", { capabilities = capabilities })
vim.lsp.enable("cspell")

vim.lsp.config("ruby_lsp", { capabilities = capabilities })
vim.lsp.enable("ruby_lsp")

vim.lsp.config("rust_analyzer", { capabilities = capabilities })
vim.lsp.enable("rust_analyzer")

vim.lsp.config("docker_compose_language_service", { capabilities = capabilities })
vim.lsp.enable("docker_compose_language_service")

vim.lsp.config("dockerls", { capabilities = capabilities })
vim.lsp.enable("dockerls")

vim.lsp.config("gopls", { capabilities = capabilities })
vim.lsp.enable("gopls")

vim.lsp.config("html", { capabilities = capabilities })
vim.lsp.enable("html")

vim.lsp.config("jsonls", { capabilities = capabilities })
vim.lsp.enable("jsonls")

vim.lsp.config("markdown_oxide", { capabilities = capabilities })
vim.lsp.enable("markdown_oxide")

vim.lsp.config("pylsp", { capabilities = capabilities })
vim.lsp.enable("pylsp")

vim.lsp.config("ts_ls", { capabilities = capabilities })
vim.lsp.enable("ts_ls")

vim.lsp.config("yamlls", { capabilities = capabilities })
vim.lsp.enable("yamlls")

vim.lsp.config("sqlls", { capabilities = capabilities })
vim.lsp.enable("sqlls")

vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
vim.keymap.set({ "n" }, "<leader>ca", vim.lsp.buf.code_action, {})
vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, {})

require("lualine").setup({
	options = {
		icons_enabled = true,
		theme = "ayu_mirage",
		component_separators = { left = "", right = "" },
		section_separators = { left = "", right = "" },
		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		always_show_tabline = true,
		globalstatus = false,
		refresh = {
			statusline = 1000,
			tabline = 1000,
			winbar = 1000,
			refresh_time = 16, -- ~60fps
			events = {
				"WinEnter",
				"BufEnter",
				"BufWritePost",
				"SessionLoadPost",
				"FileChangedShellPost",
				"VimResized",
				"Filetype",
				"CursorMoved",
				"CursorMovedI",
				"ModeChanged",
			},
		},
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = { "branch", "diff", "diagnostics" },
		lualine_c = { "filename" },
		lualine_x = { "filesize", "encoding", "fileformat", "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { "filename" },
		lualine_x = { "location" },
		lualine_y = {},
		lualine_z = {},
	},
	tabline = {},
	winbar = {},
	inactive_winbar = {},
	extensions = {},
})

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

vim.keymap.set("n", "<leader>e", ":Neotree filesystem reveal left<CR>", {})

require("neo-tree").setup({})

local config = require("nvim-treesitter.configs")
config.setup({
	auto_install = true,
	highlight = { enable = true },
	indent = { enable = true },
})

-- This is your opts table
require("telescope").setup({
	extensions = {
		["ui-select"] = {
			require("telescope.themes").get_dropdown({
				-- even more opts
			}),

			-- pseudo code / specification for writing custom displays, like the one
			-- for "codeactions"
			-- specific_opts = {
			--   [kind] = {
			--     make_indexed = function(items) -> indexed_items, width,
			--     make_displayer = function(widths) -> displayer
			--     make_display = function(displayer) -> function(e)
			--     make_ordinal = function(e) -> string
			--   },
			--   -- for example to disable the custom builtin "codeactions" display
			--      do the following
			--   codeactions = false,
			-- }
		},
	},
})
-- To get ui-select loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("ui-select")

local null_ls = require("null-ls")

null_ls.setup({
	sources = {
		null_ls.builtins.formatting.rubocop,
		null_ls.builtins.diagnostics.rubocop,
		null_ls.builtins.formatting.stylua,
		null_ls.builtins.formatting.csharpier,
	},
	on_attach = function(client, bufnr)
		client.offset_encoding = "utf-8"
	end,
})

vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})

require("noice").setup({
	lsp = {
		-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
		override = {
			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			["vim.lsp.util.stylize_markdown"] = true,
			["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
		},
	},
	-- you can enable a preset for easier configuration
	presets = {
		bottom_search = true, -- use a classic bottom cmdline for search
		command_palette = true, -- position the cmdline and popupmenu together
		long_message_to_split = true, -- long messages will be sent to a split
		inc_rename = false, -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = false, -- add a border to hover docs and signature help
	},
})

require("notify").setup({
	background_colour = "#000000",
	stages = "static",
})

vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = "#BD0013" })
vim.api.nvim_set_hl(0, "NotifyWARNBorder", { fg = "#E7741D" })
vim.api.nvim_set_hl(0, "NotifyINFOBorder", { fg = "#4AB118" })
vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { fg = "#4E7CBF" })
vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { fg = "#66598F" })

vim.api.nvim_set_hl(0, "NotifyERRORIcon", { fg = "#FC5F5A" })
vim.api.nvim_set_hl(0, "NotifyWARNIcon", { fg = "#EFC21A" })
vim.api.nvim_set_hl(0, "NotifyINFOIcon", { fg = "#9EFF6E" })
vim.api.nvim_set_hl(0, "NotifyDEBUGIcon", { fg = "#4E7CBF" })
vim.api.nvim_set_hl(0, "NotifyTRACEIcon", { fg = "#9B5953" })

vim.api.nvim_set_hl(0, "NotifyERRORTitle", { fg = "#FC5F5A" })
vim.api.nvim_set_hl(0, "NotifyWARNTitle", { fg = "#EFC21A" })
vim.api.nvim_set_hl(0, "NotifyINFOTitle", { fg = "#9EFF6E" })
vim.api.nvim_set_hl(0, "NotifyDEBUGTitle", { fg = "#4E7CBF" })
vim.api.nvim_set_hl(0, "NotifyTRACETitle", { fg = "#9B5953" })

vim.api.nvim_set_hl(0, "NotifyERRORBody", { link = "Normal" })
vim.api.nvim_set_hl(0, "NotifyWARNBody", { link = "Normal" })
vim.api.nvim_set_hl(0, "NotifyINFOBody", { link = "Normal" })
vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { link = "Normal" })
vim.api.nvim_set_hl(0, "NotifyTRACEBody", { link = "Normal" })

vim.keymap.set("n", "<leader>N?", ":Notifications<CR>", {})

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]])
vim.keymap.set({ "n", "v" }, "<leader>P", [["+P]])
