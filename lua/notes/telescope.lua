local M = {}

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

function M.find_notes(opts)
	opts = opts or {}
	local core = require("notes.core")
	local notes = core.get_all_notes()

	pickers
		.new(opts, {
			prompt_title = "Notes",
			finder = finders.new_table({
				results = notes,
				entry_maker = function(entry)
					local frontmatter = core.parse_frontmatter(entry)
					local title = frontmatter and frontmatter.title or "Untitled"
					local date = frontmatter and frontmatter.date or ""

					return {
						value = entry,
						display = string.format("%s  [%s]", title, date),
						ordinal = title .. " " .. date .. " " .. entry,
						path = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = previewers.cat.new(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.cmd("edit " .. selection.value)
				end)
				return true
			end,
		})
		:find()
end

function M.find_notes_by_tag(opts)
	opts = opts or {}
	local core = require("notes.core")
	local notes = core.get_notes_with_tags()

	pickers
		.new(opts, {
			prompt_title = "Notes by Tag",
			finder = finders.new_table({
				results = notes,
				entry_maker = function(entry)
					local frontmatter = core.parse_frontmatter(entry)
					local title = frontmatter and frontmatter.title or "Untitled"
					local tags = frontmatter and frontmatter.tags or ""
					local date = frontmatter and frontmatter.date or ""

					return {
						value = entry,
						display = string.format("%s  [%s]  %s", title, tags, date),
						ordinal = title .. " " .. tags .. " " .. date .. " " .. entry,
						path = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = previewers.cat.new(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.cmd("edit " .. selection.value)
				end)
				return true
			end,
		})
		:find()
end

function M.delete_note(opts)
	opts = opts or {}
	local core = require("notes.core")
	local notes = core.get_all_notes()

	pickers
		.new(opts, {
			prompt_title = "Delete Note",
			finder = finders.new_table({
				results = notes,
				entry_maker = function(entry)
					local frontmatter = core.parse_frontmatter(entry)
					local title = frontmatter and frontmatter.title or "Untitled"
					local date = frontmatter and frontmatter.date or ""

					return {
						value = entry,
						display = string.format("%s  [%s]", title, date),
						ordinal = title .. " " .. date .. " " .. entry,
						path = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = previewers.cat.new(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					local filepath = selection.value

					vim.ui.select({ "Yes", "No" }, {
						prompt = string.format("Delete note: %s?", selection.display),
					}, function(choice)
						if choice == "Yes" then
							actions.close(prompt_bufnr)
							
							local git_enabled = require("notes").config.git_enabled
							if git_enabled then
								local git = require("notes.git")
								local notes_dir = core.get_notes_dir()
								local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
								
								local handle = io.popen(string.format('git -C "%s" rm "%s" 2>&1', notes_dir, relative_path))
								if handle then
									handle:read("*all")
									handle:close()
								end
								
								git.commit_and_push()
								vim.notify("Note deleted: " .. filepath, vim.log.levels.INFO)
							else
								if core.delete_note(filepath) then
									vim.notify("Note deleted: " .. filepath, vim.log.levels.INFO)
								else
									vim.notify("Failed to delete note", vim.log.levels.ERROR)
								end
							end
						end
					end)
				end)
				return true
			end,
		})
		:find()
end

function M.view_file_history(filepath, opts)
	opts = opts or {}
	local git = require("notes.git")
	local commits = git.get_file_history(filepath)
	
	if #commits == 0 then
		vim.notify("No history found for this note", vim.log.levels.WARN)
		return
	end
	
	pickers
		.new(opts, {
			prompt_title = "Note History",
			finder = finders.new_table({
				results = commits,
				entry_maker = function(entry)
					return {
						value = entry,
						display = string.format("%s  %s  %s", entry.hash:sub(1, 7), entry.date, entry.message),
						ordinal = entry.hash .. " " .. entry.date .. " " .. entry.message,
						commit = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					local commit = selection.commit
					
					vim.ui.select({ "View", "Revert to this version", "Cancel" }, {
						prompt = "Choose action:",
					}, function(choice)
						actions.close(prompt_bufnr)
						if choice == "View" then
							local notes_dir = require("notes.core").get_notes_dir()
							local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
							local cmd = string.format('git -C "%s" show %s:"%s"', notes_dir, commit.hash, relative_path)
							
							local buf = vim.api.nvim_create_buf(false, true)
							vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
							vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
							vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
							
							local handle = io.popen(cmd)
							if handle then
								local content = handle:read("*all")
								handle:close()
								local lines = {}
								for line in content:gmatch("[^\r\n]+") do
									table.insert(lines, line)
								end
								vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
							end
							
							vim.api.nvim_set_current_buf(buf)
							vim.api.nvim_buf_set_name(buf, string.format("[History] %s (%s)", relative_path, commit.hash:sub(1, 7)))
						elseif choice == "Revert to this version" then
							git.revert_file(filepath, commit.hash)
							vim.cmd("edit! " .. filepath)
						end
					end)
				end)
				return true
			end,
		})
		:find()
end

function M.view_all_history(opts)
	opts = opts or {}
	local git = require("notes.git")
	local commits = git.get_all_history()
	
	if #commits == 0 then
		vim.notify("No history found", vim.log.levels.WARN)
		return
	end
	
	pickers
		.new(opts, {
			prompt_title = "Notes History",
			finder = finders.new_table({
				results = commits,
				entry_maker = function(entry)
					local files_str = table.concat(entry.files, ", ")
					return {
						value = entry,
						display = string.format("%s  %s  %s  [%s]", entry.hash:sub(1, 7), entry.date, entry.message, files_str),
						ordinal = entry.hash .. " " .. entry.date .. " " .. entry.message .. " " .. files_str,
						commit = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					local commit = selection.commit
					
					vim.notify(string.format("Commit: %s\nFiles: %s", commit.message, table.concat(commit.files, ", ")), vim.log.levels.INFO)
				end)
				return true
			end,
		})
		:find()
end

return M
