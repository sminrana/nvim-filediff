local M = {}

-- Helper: setup buffer for diff view
function M.setup_diff_buffer(buf)
	vim.api.nvim_buf_set_option(buf, "diff", true)
	vim.api.nvim_buf_set_option(buf, "list", true)
	vim.api.nvim_buf_set_option(buf, "cursorline", true)
	vim.api.nvim_buf_set_option(buf, "number", true)
	vim.api.nvim_buf_set_option(buf, "relativenumber", false)
	vim.api.nvim_buf_set_option(buf, "filetype", vim.bo.filetype)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "listchars", "tab:»·,trail:·,extends:>,precedes:<,nbsp:␣")
	vim.api.nvim_buf_set_option(buf, "fillchars", "diff: ")
	vim.api.nvim_buf_set_option(buf, "foldmethod", "diff")
end

-- Helper: open and configure diff view for two files

function M.open_diff_view(file1, file2, label1, label2)
	vim.schedule(function()
		local success, err = pcall(function()
			-- open first file in new tab
			vim.cmd("tabnew " .. vim.fn.fnameescape(file1))
			local tabnr = vim.api.nvim_get_current_tabpage()
			local buf1 = vim.api.nvim_get_current_buf()
			vim.cmd("file " .. vim.fn.fnameescape(label1 or file1))
			M.setup_diff_buffer(buf1)

			-- Set statusline for left buffer
			vim.api.nvim_buf_set_option(buf1, "statusline", "DIFF LEFT: %f")

			-- Add virtual text label at the top of left buffer
			local left_name = vim.fn.fnamemodify(label1 or file1, ":t")
			vim.api.nvim_buf_clear_namespace(buf1, -1, 0, 1)
			vim.api.nvim_buf_set_extmark(buf1, vim.api.nvim_create_namespace("DiffLabel"), 0, 0, {
				virt_text = { { "LEFT: " .. left_name, "Title" } },
				virt_text_pos = "overlay",
				hl_mode = "combine",
			})

			-- open second file in vertical diff split
			vim.cmd("vert diffsplit " .. vim.fn.fnameescape(file2))
			local buf2 = vim.api.nvim_get_current_buf()
			vim.cmd("file " .. vim.fn.fnameescape(label2 or file2))
			M.setup_diff_buffer(buf2)

			-- Set statusline for right buffer
			vim.api.nvim_buf_set_option(buf2, "statusline", "DIFF RIGHT: %f")

			-- Add virtual text label at the top of right buffer
			local right_name = vim.fn.fnamemodify(label2 or file2, ":t")
			vim.api.nvim_buf_clear_namespace(buf2, -1, 0, 1)
			vim.api.nvim_buf_set_extmark(buf2, vim.api.nvim_create_namespace("DiffLabel"), 0, 0, {
				virt_text = { { "RIGHT: " .. right_name, "Title" } },
				virt_text_pos = "overlay",
				hl_mode = "combine",
			})

			-- Equalize split sizes
			vim.cmd("wincmd =")

			-- Enable proper diff mode for both
			vim.cmd("windo diffthis")

			-- Highlight whitespace
			vim.cmd("highlight! SpecialKey guifg=#555555 ctermfg=240")
			vim.cmd("highlight! NonText guifg=#555555 ctermfg=240")
			vim.cmd("highlight! ExtraWhitespace guibg=#553333 ctermbg=52")
			vim.fn.matchadd("ExtraWhitespace", "\\s\\+$")

			-- Improved diff highlighting for better visibility
			vim.cmd(
				"highlight DiffAdd    guifg=#00ff5f guibg=NONE gui=bold,underline ctermfg=46 ctermbg=NONE cterm=bold,underline"
			)
			vim.cmd(
				"highlight DiffChange guifg=#ff00ff guibg=NONE gui=bold,italic    ctermfg=201 ctermbg=NONE cterm=bold,italic"
			)
			vim.cmd(
				"highlight DiffDelete guifg=#ff005f guibg=NONE gui=bold           ctermfg=197 ctermbg=NONE cterm=bold"
			)
			vim.cmd(
				"highlight DiffText   guifg=#00dfff guibg=NONE gui=bold,italic    ctermfg=45  ctermbg=NONE cterm=bold,italic"
			)

			-- Sync scrolling in Lua
			vim.api.nvim_create_augroup("DiffSyncScroll", { clear = true })
			vim.api.nvim_create_autocmd("WinScrolled", {
				group = "DiffSyncScroll",
				callback = function()
					if vim.wo.diff then
						vim.cmd("windo diffupdate")
					end
				end,
			})

			-- disable diagnostics initially
			vim.diagnostic.disable(buf1)
			vim.diagnostic.disable(buf2)

			-- ensure diagnostics stay disabled when LSP attaches
			local diag_group = vim.api.nvim_create_augroup("DiffDiagnostics" .. tabnr, { clear = true })
			vim.api.nvim_create_autocmd("LspAttach", {
				group = diag_group,
				buffer = buf1,
				callback = function()
					vim.diagnostic.disable(buf1)
				end,
			})
			vim.api.nvim_create_autocmd("LspAttach", {
				group = diag_group,
				buffer = buf2,
				callback = function()
					vim.diagnostic.disable(buf2)
				end,
			})

			-- toggle diagnostics function
			local diagnostics_enabled = false
			local function toggle_diff_diagnostics()
				if diagnostics_enabled then
					vim.diagnostic.disable(buf1)
					vim.diagnostic.disable(buf2)
					diagnostics_enabled = false
					vim.notify("Diff diagnostics disabled", vim.log.levels.INFO)
				else
					vim.diagnostic.enable(buf1)
					vim.diagnostic.enable(buf2)
					diagnostics_enabled = true
					vim.notify("Diff diagnostics enabled", vim.log.levels.INFO)
				end
			end

			-- keymaps (scoped to buffers in this tab)
			local opts = { buffer = true }
			vim.keymap.set(
				"n",
				"<leader>dt",
				toggle_diff_diagnostics,
				vim.tbl_extend("force", opts, { desc = "Toggle diff diagnostics" })
			)
			vim.keymap.set(
				"n",
				"<leader>dg",
				":diffget<CR>",
				vim.tbl_extend("force", opts, { desc = "Diff get (pull from other side)" })
			)
			vim.keymap.set(
				"n",
				"<leader>dp",
				":diffput<CR>",
				vim.tbl_extend("force", opts, { desc = "Diff put (push to other side)" })
			)
			vim.keymap.set("n", "<leader>dc", ":q<CR>", vim.tbl_extend("force", opts, { desc = "Close diff view" }))
			vim.keymap.set("n", "]c", "]c", vim.tbl_extend("force", opts, { desc = "Next difference" }))
			vim.keymap.set("n", "[c", "[c", vim.tbl_extend("force", opts, { desc = "Previous difference" }))

			-- Autocmd to close diff buffers when tab is closed
			local close_group = vim.api.nvim_create_augroup("DiffTabClose" .. tabnr, { clear = true })
			vim.api.nvim_create_autocmd("TabClosed", {
				group = close_group,
				callback = function(args)
					-- Only act if the closed tab is the one we opened
					if tonumber(args.file) == tabnr then
						pcall(vim.api.nvim_buf_delete, buf1, { force = true })
						pcall(vim.api.nvim_buf_delete, buf2, { force = true })
					end
				end,
			})

			vim.notify(
				"Diff opened for: "
					.. (label1 or file1)
					.. " <-> "
					.. (label2 or file2)
					.. ". Use "
					.. "<leader>td to toggle diagnostics.",
				vim.log.levels.INFO
			)
		end)
		if not success then
			vim.notify("Error: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

-- ================================
-- File diff picker
-- ================================
function M.file_diff()
	local ok, fzf = pcall(require, "fzf-lua")
	if not ok then
		vim.notify("fzf-lua not installed!", vim.log.levels.ERROR)
		return
	end
	local first_file = nil
	fzf.files({
		prompt = "Select first file to diff: ",
		file_icons = false,
		git_icons = false,
		actions = {
			["default"] = function(selected)
				if not selected or #selected == 0 then
					vim.notify("No first file selected", vim.log.levels.WARN)
					return
				end
				first_file = vim.fn.fnamemodify(selected[1], ":p")
				fzf.files({
					prompt = "Select second file to diff: ",
					file_icons = false,
					git_icons = false,
					actions = {
						["default"] = function(selected2)
							if not selected2 or #selected2 == 0 then
								return
							end
							local second_file = vim.fn.fnamemodify(selected2[1], ":p")
							M.open_diff_view(first_file, second_file)
						end,
					},
				})
			end,
		},
	})
end

vim.api.nvim_create_user_command("FileDiff", file_diff, {})

-- ================================
-- File diff input (manual paths)
-- ================================
function M.file_diff_input()
	vim.ui.input({ prompt = "Absolute path to first file: " }, function(first)
		if not first or first == "" then
			return
		end
		vim.ui.input({ prompt = "Absolute path to second file: " }, function(second)
			if not second or second == "" then
				return
			end
			M.open_diff_view(first, second, first, second)
		end)
	end)
end

vim.api.nvim_create_user_command("FileDiffInput", file_diff_input, {})

-- ================================
-- Async folder diff (libuv spawn)
-- ================================
local last_folder_diff = { first = nil, second = nil, diffs = nil, items = nil }

local function run_folder_diff(first, second, callback)
	local exclude = {
		"--exclude=.*",
		"--exclude=.git",
		"--exclude=node_modules",
		"--exclude=vendor",
		"--exclude=__pycache__",
		"--exclude=*.egg-info",
		"--exclude=env",
		"--exclude=venv",
		"--exclude=Library",
	}
	local args = { "-qr" }
	vim.list_extend(args, exclude)
	table.insert(args, first)
	table.insert(args, second)

	local stdout = vim.loop.new_pipe(false)
	local handle
	local output = {}

	handle = vim.loop.spawn("diff", {
		args = args,
		stdio = { nil, stdout, nil },
	}, function(code)
		stdout:close()
		if handle then
			pcall(function()
				handle:close()
			end)
		end

		if code ~= 0 and #output == 0 then
			vim.schedule(function()
				vim.notify("No differing files found.", vim.log.levels.INFO)
			end)
			return
		end

		local diffs = {}
		for _, line in ipairs(output) do
			local f1, f2 = line:match("^Files%s+(.+)%s+and%s+(.+)%s+differ")
			if f1 and f2 then
				table.insert(diffs, { f1, f2 })
			end
		end

		if #diffs == 0 then
			vim.schedule(function()
				vim.notify("No differing files found.", vim.log.levels.INFO)
			end)
			return
		end

		local items = {}
		for _, pair in ipairs(diffs) do
			table.insert(items, pair[1] .. " <-> " .. pair[2])
		end

		last_folder_diff = { first = first, second = second, diffs = diffs, items = items }
		vim.schedule(function()
			callback(diffs, items)
		end)
	end)

	vim.loop.read_start(stdout, function(err, data)
		if err then
			return
		end
		if data then
			for line in data:gmatch("[^\r\n]+") do
				table.insert(output, line)
			end
		end
	end)
end

-- ================================
-- Picker for file pairs
-- ================================
local function select_pair(diffs, items, callback)
	local ok, fzf = pcall(require, "fzf-lua")
	if ok then
		fzf.fzf_exec(items, {
			prompt = "Select file pair to diff: ",
			actions = {
				["default"] = function(selected)
					if not selected or #selected == 0 then
						return
					end
					for i, v in ipairs(items) do
						if v == selected[1] then
							callback(diffs[i], i)
							return
						end
					end
				end,
			},
		})
	else
		vim.ui.select(items, { prompt = "Select file pair to diff:" }, function(choice, idx)
			if choice and idx then
				callback(diffs[idx], idx)
			end
		end)
	end
end

-- ================================
-- Open diff + back to folder
-- ================================
local function open_and_handle(pair)
	if not pair then
		return
	end
	M.open_diff_view(pair[1], pair[2], pair[1], pair[2])

	vim.defer_fn(function()
		local buf = vim.api.nvim_get_current_buf()
		vim.keymap.set("n", "<Esc>", function()
			select_pair(last_folder_diff.diffs, last_folder_diff.items, open_and_handle)
		end, { buffer = buf, desc = "Back to folder diff selection" })
		vim.notify("Press <Esc> to return to folder diff selection.", vim.log.levels.INFO)
	end, 120)
end

-- ================================
-- Folder diff command
-- ================================
function M.folder_diff()
	local ok, fzf = pcall(require, "fzf-lua")
	if not ok then
		vim.notify("fzf-lua not installed!", vim.log.levels.ERROR)
		return
	end

	local function trim(s)
		return (s:gsub("^%s+", ""):gsub("%s+$", ""))
	end

	local fd_cmd = [[fd --type d --follow --exclude .git --exclude '.*' --exclude Library . ]]
		.. vim.fn.expand("~")
		.. [[ | awk -F/ '{print NF,$0}' | sort -n | cut -d' ' -f2-]]

	local function pick_folder(prompt, callback)
		fzf.fzf_exec(fd_cmd, {
			prompt = prompt,
			actions = {
				["default"] = function(selected)
					if not selected or #selected == 0 then
						return
					end
					local sel = trim(selected[1])
					if not sel:match("^/") then
						sel = vim.fn.expand("~") .. "/" .. sel
					end
					local dir = vim.fn.resolve(sel)
					if vim.fn.isdirectory(dir) == 0 then
						vim.notify("Not a directory: " .. dir, vim.log.levels.ERROR)
						return
					end
					callback(dir)
				end,
			},
		})
	end

	pick_folder("Select first folder: ", function(first_dir)
		pick_folder("Select second folder: ", function(second_dir)
			run_folder_diff(first_dir, second_dir, function(diffs, items)
				select_pair(diffs, items, open_and_handle)
			end)
		end)
	end)
end

vim.api.nvim_create_user_command("FolderDiff", folder_diff, {})

return M
