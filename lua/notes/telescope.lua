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
							if core.delete_note(filepath) then
								vim.notify("Note deleted: " .. filepath, vim.log.levels.INFO)
								actions.close(prompt_bufnr)

								local git_enabled = require("notes").config.git_enabled
								if git_enabled then
									local git = require("notes.git")
									git.commit_and_push()
								end
							else
								vim.notify("Failed to delete note", vim.log.levels.ERROR)
							end
						end
					end)
				end)
				return true
			end,
		})
		:find()
end

return M
