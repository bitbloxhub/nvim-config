-- Clone 'mini.nvim' manually in a way that it gets managed by 'mini.deps'
local path_package = vim.fn.stdpath("data") .. "/site/"
local mini_path = path_package .. "pack/deps/start/mini.nvim"
if not vim.loop.fs_stat(mini_path) then
	vim.cmd('echo "Installing `mini.nvim`" | redraw')
	local clone_cmd = { "git", "clone", "--filter=blob:none", "https://github.com/echasnovski/mini.nvim", mini_path }
	vim.fn.system(clone_cmd)
	vim.cmd("packadd mini.nvim | helptags ALL")
	vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- Set up 'mini.deps' (customize to your liking)
require("mini.deps").setup({ path = { package = path_package } })

-- Use 'mini.deps'. `now()` and `later()` are helpers for a safe two-stage
-- startup and are optional.
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

local function base64(data)
	data = tostring(data)
	local bit = require("bit")
	local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local b64, len = "", #data
	local rshift, lshift, bor = bit.rshift, bit.lshift, bit.bor

	for i = 1, len, 3 do
		local a, b, c = data:byte(i, i + 2)
		b = b or 0
		c = c or 0

		local buffer = bor(lshift(a, 16), lshift(b, 8), c)
		for j = 0, 3 do
			local index = rshift(buffer, (3 - j) * 6) % 64
			b64 = b64 .. b64chars:sub(index + 1, index + 1)
		end
	end

	local padding = (3 - len % 3) % 3
	b64 = b64:sub(1, -1 - padding) .. ("="):rep(padding)

	return b64
end

local function set_user_var(key, value)
	io.write(string.format("\027]1337;SetUserVar=%s=%s\a", key, base64(value)))
end

local function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

-- Safely execute immediately
now(function()
	vim.o.termguicolors = true
	--vim.cmd('colorscheme randomhue')
	add({ source = "catppuccin/nvim" })
	require("catppuccin").setup({
		flavour = "mocha",
		transparent_background = true,
	})
	vim.cmd.colorscheme("catppuccin")
end)
now(function()
	local group = vim.api.nvim_create_augroup("wezterm", {})
	set_user_var("NEOVIM", "true")
	vim.api.nvim_create_autocmd({ "BufEnter", "TabEnter" }, {
		callback = function(args)
			local nvim_file = split(args.file, "/")
			set_user_var("NEOVIM_FILE", nvim_file[#nvim_file])
		end,
		group = group,
	})
	vim.api.nvim_create_autocmd("ExitPre", {
		callback = function()
			set_user_var("NEOVIM", "false")
		end,
		group = group,
	})
end)
now(function()
	add({ source = "j-hui/fidget.nvim" })
	local fidget = require("fidget")
	fidget.setup({
		notification = {
			override_vim_notify = true,
			window = {
				winblend = 0,
			},
		},
	})
end)
now(function()
	require("mini.icons").setup()
end)
now(function()
	require("mini.tabline").setup()
end)
now(function()
	require("mini.statusline").setup()
end)
now(function()
	vim.o.expandtab = false
	vim.o.tabstop = 4
	vim.o.softtabstop = 4
	vim.o.shiftwidth = 4
	vim.o.number = true
end)
now(function()
	add({ source = "neovim/nvim-lspconfig" })
	local lspconfig = require("lspconfig")
	lspconfig.basedpyright.setup({})
	lspconfig.ts_ls.setup({
		cmd = { "bunx", "--bun", "typescript-language-server", "--stdio" },
	})
	lspconfig.svelte.setup({}) -- unfortunately using bun does not work
	lspconfig.lua_ls.setup({})
end)
now(function()
	add({
		source = "nvim-treesitter/nvim-treesitter",
		-- Use 'master' while monitoring updates in 'main'
		checkout = "master",
		monitor = "main",
		-- Perform action after every checkout
		hooks = {
			post_checkout = function()
				vim.cmd("TSUpdate")
			end,
		},
	})
	-- Possible to immediately execute code which depends on the added plugin
	require("nvim-treesitter.configs").setup({
		ensure_installed = { "lua", "vimdoc" },
		highlight = { enable = true },
	})
end)
now(function()
	local function build_blink(params)
		vim.notify("Building blink.cmp", vim.log.levels.INFO)
		local obj = vim.system({ "cargo", "build", "--release" }, { cwd = params.path }):wait()
		if obj.code == 0 then
			vim.notify("Building blink.cmp done", vim.log.levels.INFO)
		else
			vim.notify("Building blink.cmp failed", vim.log.levels.ERROR)
		end
	end
	add({
		source = "Saghen/blink.cmp",
		depends = {
			"rafamadriz/friendly-snippets",
		},
		hooks = {
			post_install = build_blink,
			post_checkout = build_blink,
		},
	})
	require("blink.cmp").setup({
		keymap = {
			preset = "super-tab",
		},
		completion = {
			menu = {
				draw = {
					components = {
						kind_icon = {
							ellipsis = false,
							text = function(ctx)
								local kind_icon, _, _ = require("mini.icons").get("lsp", ctx.kind)
								return kind_icon
							end,
							-- Optionally, you may also use the highlights from mini.icons
							highlight = function(ctx)
								local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
								return hl
							end,
						},
					},
				},
			},
		},
	})
	require("blink.cmp")
end)
now(function()
	add({ source = "direnv/direnv.vim" })
end)
now(function()
	add({
		source = "nvim-neo-tree/neo-tree.nvim",
		depends = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
		},
	})
	require("neo-tree").setup({
		default_component_configs = {
			icon = {
				provider = function(icon, node) -- setup a custom icon provider
					local text, hl
					local mini_icons = require("mini.icons")
					if node.type == "file" then -- if it's a file, set the text/hl
						text, hl = mini_icons.get("file", node.name)
					elseif node.type == "directory" then -- get directory icons
						text, hl = mini_icons.get("directory", node.name)
						-- only set the icon text if it is not expanded
						if node:is_expanded() then
							text = nil
						end
					end
					-- set the icon text/highlight only if it exists
					if text then
						icon.text = text
					end
					if hl then
						icon.highlight = hl
					end
				end,
			},
		},
	})
end)
now(function()
	add({ source = "ibhagwan/fzf-lua" })
	require("fzf-lua").setup({})
end)
now(function()
	add({ source = "MeanderingProgrammer/render-markdown.nvim" })
	require("render-markdown").setup({})
end)
-- Safely execute later
later(function()
	require("mini.ai").setup()
end)
later(function()
	require("mini.comment").setup()
end)
later(function()
	require("mini.pick").setup()
end)
later(function()
	require("mini.surround").setup()
end)
