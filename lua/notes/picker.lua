local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local core = require("notes.core")
local notevc = require("notes.notevc")

function M.find_notes(opts)
    opts = opts or {}
    local notes = core.get_all_notes()

    if #notes == 0 then
        vim.notify("No notes found", vim.log.levels.INFO)
        return
    end

    pickers.new(opts, {
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
                vim.cmd("edit " .. vim.fn.fnameescape(selection.value))
            end)
            return true
        end,
    }):find()
end

function M.find_notes_by_tag(opts)
    opts = opts or {}
    local notes = core.get_notes_with_tags()

    if #notes == 0 then
        vim.notify("No notes with tags found", vim.log.levels.INFO)
        return
    end

    pickers.new(opts, {
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
                    display = string.format("%s %s %s", title, tags, date),
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
                vim.cmd("edit " .. vim.fn.fnameescape(selection.value))
            end)
            return true
        end,
    }):find()
end

function M.delete_note(opts)
    opts = opts or {}
    local notes = core.get_all_notes()

    if #notes == 0 then
        vim.notify("No notes found", vim.log.levels.INFO)
        return
    end

    pickers.new(opts, {
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
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Note Preview",
            define_preview = function(self, entry)
                local lines = vim.fn.readfile(entry.value)
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            local handle_delete = function()
                local selection = action_state.get_selected_entry()
                if not selection then
                    return
                end

                local filepath = selection.value

                actions.close(prompt_bufnr)

                vim.schedule(function()
                    vim.ui.select({ "Yes", "No" }, {
                        prompt = "Delete note: " .. filepath .. "?",
                    }, function(choice)
						if choice == "Yes" then
							local notes_dir = core.get_notes_dir()
							local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
							local notevc_enabled = require("notes").config.notevc_enabled

							if vim.fn.delete(filepath) == 0 then
								vim.notify("Note deleted: " .. filepath, vim.log.levels.INFO)
								
								-- Commit the deletion if notevc is enabled
								if notevc_enabled then
									local frontmatter = core.parse_frontmatter(filepath)
									local title = frontmatter and frontmatter.title or "note"
									notevc.commit("Deleted note: " .. title)
								end
							else
								vim.notify("Failed to delete note", vim.log.levels.ERROR)
							end
						end
                        end)
                end)
            end

            map('i', '<CR>', handle_delete)
            map('n', '<CR>', handle_delete)

            return true
        end,
    }):find()
end

return M
