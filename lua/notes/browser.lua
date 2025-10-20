local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local Menu = require("nui.menu")
local Popup = require("nui.popup")
local Job = require("plenary.job")
local core = require("notes.core")
local git = require("notes.git")

local function execute_git_async(args, cwd, callback)
	Job:new({
		command = "git",
		args = args,
		cwd = cwd,
		on_exit = function(j, return_val)
			vim.schedule(function()
				callback(j:result(), return_val == 0)
			end)
		end,
	}):start()
end

function M.file_history(filepath, opts)
	opts = opts or {}
	local notes_dir = core.get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	execute_git_async(
		{ "log", "--pretty=format:%H|%an|%ar|%s", "--follow", "--", relative_path },
		notes_dir,
		function(result, success)
			if not success or #result == 0 then
				vim.notify("No history found for this note", vim.log.levels.WARN)
				return
			end
			
			local commits = {}
			for _, line in ipairs(result) do
				local hash, author, date, message = line:match("([^|]+)|([^|]+)|([^|]+)|(.+)")
				if hash then
					table.insert(commits, {
						hash = hash,
						author = author,
						date = date,
						message = message,
						filepath = filepath,
					})
				end
			end
			
			pickers.new(opts, {
				prompt_title = "Note History: " .. relative_path,
				finder = finders.new_table({
					results = commits,
					entry_maker = function(entry)
						return {
							value = entry,
							display = string.format("%s  %s  %s", entry.hash:sub(1, 7), entry.date, entry.message),
							ordinal = entry.hash .. " " .. entry.date .. " " .. entry.message,
						}
					end,
				}),
				sorter = conf.generic_sorter(opts),
				previewer = previewers.new_buffer_previewer({
					title = "Commit Content",
					define_preview = function(self, entry)
						Job:new({
							command = "git",
							args = { "show", entry.value.hash .. ":" .. relative_path },
							cwd = notes_dir,
							on_exit = function(j)
								vim.schedule(function()
									vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, j:result())
									vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
								end)
							end,
						}):start()
					end,
				}),
				attach_mappings = function(prompt_bufnr, map)
					local function show_actions()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						
						local menu = Menu({
							position = "50%",
							size = {
								width = 40,
								height = 5,
							},
							border = {
								style = "rounded",
								text = {
									top = " Actions ",
									top_align = "center",
								},
							},
							win_options = {
								winhighlight = "Normal:Normal,FloatBorder:Normal",
							},
						}, {
							lines = {
								Menu.item("View at this commit"),
								Menu.item("Revert to this commit"),
								Menu.item("Show diff"),
								Menu.separator(""),
								Menu.item("Cancel"),
							},
							max_width = 40,
							keymap = {
								focus_next = { "j", "<Down>", "<Tab>" },
								focus_prev = { "k", "<Up>", "<S-Tab>" },
								close = { "<Esc>", "<C-c>", "q" },
								submit = { "<CR>", "<Space>" },
							},
							on_submit = function(item)
								if item.text == "View at this commit" then
									Job:new({
										command = "git",
										args = { "show", selection.value.hash .. ":" .. relative_path },
										cwd = notes_dir,
										on_exit = function(j)
											vim.schedule(function()
												local buf = vim.api.nvim_create_buf(false, true)
												vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
												vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
												vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
												vim.api.nvim_buf_set_lines(buf, 0, -1, false, j:result())
												vim.api.nvim_set_current_buf(buf)
												vim.api.nvim_buf_set_name(buf, string.format("[%s] %s", selection.value.hash:sub(1, 7), relative_path))
											end)
										end,
									}):start()
								elseif item.text == "Revert to this commit" then
									vim.ui.select({ "Yes", "No" }, {
										prompt = "Revert to commit " .. selection.value.hash:sub(1, 7) .. "?",
									}, function(choice)
										if choice == "Yes" then
											git.revert_file(filepath, selection.value.hash)
											vim.cmd("edit! " .. vim.fn.fnameescape(filepath))
										end
									end)
								elseif item.text == "Show diff" then
									Job:new({
										command = "git",
										args = { "diff", selection.value.hash, "HEAD", "--", relative_path },
										cwd = notes_dir,
										on_exit = function(j)
											vim.schedule(function()
												local buf = vim.api.nvim_create_buf(false, true)
												vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
												vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
												vim.api.nvim_buf_set_option(buf, "filetype", "diff")
												vim.api.nvim_buf_set_lines(buf, 0, -1, false, j:result())
												vim.api.nvim_set_current_buf(buf)
												vim.api.nvim_buf_set_name(buf, string.format("[Diff] %s vs HEAD", selection.value.hash:sub(1, 7)))
											end)
										end,
									}):start()
								end
							end,
						})
						
						menu:mount()
					end
					
					actions.select_default:replace(show_actions)
					return true
				end,
			}):find()
		end
	)
end

function M.all_history(opts)
	opts = opts or {}
	local notes_dir = core.get_notes_dir()
	
	execute_git_async(
		{ "log", "--all", "--pretty=format:%H|%an|%ar|%s" },
		notes_dir,
		function(result, success)
			if not success or #result == 0 then
				vim.notify("No history found", vim.log.levels.WARN)
				return
			end
			
			local commits = {}
			for _, line in ipairs(result) do
				local hash, author, date, message = line:match("([^|]+)|([^|]+)|([^|]+)|(.+)")
				if hash then
					table.insert(commits, {
						hash = hash,
						author = author,
						date = date,
						message = message,
					})
				end
			end
			
			pickers.new(opts, {
				prompt_title = "All Commits",
				finder = finders.new_table({
					results = commits,
					entry_maker = function(entry)
						return {
							value = entry,
							display = string.format("%s  %s  %s  %s", entry.hash:sub(1, 7), entry.date, entry.author, entry.message),
							ordinal = entry.hash .. " " .. entry.date .. " " .. entry.author .. " " .. entry.message,
						}
					end,
				}),
				sorter = conf.generic_sorter(opts),
				previewer = previewers.new_buffer_previewer({
					title = "Commit Details",
					define_preview = function(self, entry)
						Job:new({
							command = "git",
							args = { "show", "--stat", entry.value.hash },
							cwd = notes_dir,
							on_exit = function(j)
								vim.schedule(function()
									vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, j:result())
									vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "git")
								end)
							end,
						}):start()
					end,
				}),
				attach_mappings = function(prompt_bufnr, map)
					local function show_actions()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						
						local menu = Menu({
							position = "50%",
							size = {
								width = 40,
								height = 5,
							},
							border = {
								style = "rounded",
								text = {
									top = " Actions ",
									top_align = "center",
								},
							},
							win_options = {
								winhighlight = "Normal:Normal,FloatBorder:Normal",
							},
						}, {
							lines = {
								Menu.item("Show commit details"),
								Menu.item("Browse files in commit"),
								Menu.item("Show diff"),
								Menu.separator(""),
								Menu.item("Cancel"),
							},
							max_width = 40,
							keymap = {
								focus_next = { "j", "<Down>", "<Tab>" },
								focus_prev = { "k", "<Up>", "<S-Tab>" },
								close = { "<Esc>", "<C-c>", "q" },
								submit = { "<CR>", "<Space>" },
							},
							on_submit = function(item)
								if item.text == "Show commit details" then
									Job:new({
										command = "git",
										args = { "show", "--stat", selection.value.hash },
										cwd = notes_dir,
										on_exit = function(j)
											vim.schedule(function()
												local buf = vim.api.nvim_create_buf(false, true)
												vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
												vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
												vim.api.nvim_buf_set_option(buf, "filetype", "git")
												vim.api.nvim_buf_set_lines(buf, 0, -1, false, j:result())
												vim.api.nvim_set_current_buf(buf)
												vim.api.nvim_buf_set_name(buf, string.format("[Commit] %s", selection.value.hash:sub(1, 7)))
											end)
										end,
									}):start()
								elseif item.text == "Browse files in commit" then
									M.browse_commit_files(selection.value.hash, opts)
								elseif item.text == "Show diff" then
									Job:new({
										command = "git",
										args = { "show", selection.value.hash },
										cwd = notes_dir,
										on_exit = function(j)
											vim.schedule(function()
												local buf = vim.api.nvim_create_buf(false, true)
												vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
												vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
												vim.api.nvim_buf_set_option(buf, "filetype", "diff")
												vim.api.nvim_buf_set_lines(buf, 0, -1, false, j:result())
												vim.api.nvim_set_current_buf(buf)
												vim.api.nvim_buf_set_name(buf, string.format("[Diff] %s", selection.value.hash:sub(1, 7)))
											end)
										end,
									}):start()
								end
							end,
						})
						
						menu:mount()
					end
					
					actions.select_default:replace(show_actions)
					return true
				end,
			}):find()
		end
	)
end

function M.browse_commit_files(commit_hash, opts)
	opts = opts or {}
	local notes_dir = core.get_notes_dir()
	
	execute_git_async(
		{ "diff-tree", "--no-commit-id", "--name-only", "-r", commit_hash },
		notes_dir,
		function(result, success)
			if not success or #result == 0 then
				vim.notify("No files found in commit", vim.log.levels.WARN)
				return
			end
			
			local files = {}
			for _, line in ipairs(result) do
				if line:match("%.md$") then
					table.insert(files, line)
				end
			end
			
			if #files == 0 then
				vim.notify("No markdown files found in commit", vim.log.levels.WARN)
				return
			end
			
			pickers.new(opts, {
				prompt_title = "Files in " .. commit_hash:sub(1, 7),
				finder = finders.new_table({
					results = files,
					entry_maker = function(entry)
						return {
							value = entry,
							display = entry,
							ordinal = entry,
						}
					end,
				}),
				sorter = conf.generic_sorter(opts),
				previewer = previewers.new_buffer_previewer({
					title = "File Content",
					define_preview = function(self, entry)
						Job:new({
							command = "git",
							args = { "show", commit_hash .. ":" .. entry.value },
							cwd = notes_dir,
							on_exit = function(j)
								vim.schedule(function()
									vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, j:result())
									vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
								end)
							end,
						}):start()
					end,
				}),
				attach_mappings = function(prompt_bufnr, map)
					local function show_actions()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						
						local menu = Menu({
							position = "50%",
							size = {
								width = 40,
								height = 4,
							},
							border = {
								style = "rounded",
								text = {
									top = " Actions ",
									top_align = "center",
								},
							},
							win_options = {
								winhighlight = "Normal:Normal,FloatBorder:Normal",
							},
						}, {
							lines = {
								Menu.item("View file at this commit"),
								Menu.item("Revert file to this commit"),
								Menu.separator(""),
								Menu.item("Cancel"),
							},
							max_width = 40,
							keymap = {
								focus_next = { "j", "<Down>", "<Tab>" },
								focus_prev = { "k", "<Up>", "<S-Tab>" },
								close = { "<Esc>", "<C-c>", "q" },
								submit = { "<CR>", "<Space>" },
							},
							on_submit = function(item)
								if item.text == "View file at this commit" then
									Job:new({
										command = "git",
										args = { "show", commit_hash .. ":" .. selection.value },
										cwd = notes_dir,
										on_exit = function(j)
											vim.schedule(function()
												local buf = vim.api.nvim_create_buf(false, true)
												vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
												vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
												vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
												vim.api.nvim_buf_set_lines(buf, 0, -1, false, j:result())
												vim.api.nvim_set_current_buf(buf)
												vim.api.nvim_buf_set_name(buf, string.format("[%s] %s", commit_hash:sub(1, 7), selection.value))
											end)
										end,
									}):start()
								elseif item.text == "Revert file to this commit" then
									vim.ui.select({ "Yes", "No" }, {
										prompt = "Revert " .. selection.value .. " to commit " .. commit_hash:sub(1, 7) .. "?",
									}, function(choice)
										if choice == "Yes" then
											local filepath = notes_dir .. "/" .. selection.value
											git.revert_file(filepath, commit_hash)
											vim.notify("File reverted to " .. commit_hash:sub(1, 7), vim.log.levels.INFO)
										end
									end)
								end
							end,
						})
						
						menu:mount()
					end
					
					actions.select_default:replace(show_actions)
					return true
				end,
			}):find()
		end
	)
end

return M
