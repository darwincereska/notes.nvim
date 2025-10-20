local M = {}

function M.create_note()
	vim.ui.input({ prompt = "Note title: " }, function(title)
		if not title or title == "" then
			vim.notify("Note creation cancelled", vim.log.levels.INFO)
			return
		end

		vim.ui.input({ prompt = "Tags (comma-separated, optional): " }, function(tags_input)
			local tags = {}
			if tags_input and tags_input ~= "" then
				for tag in tags_input:gmatch("([^,]+)") do
					table.insert(tags, '"' .. vim.trim(tag) .. '"')
				end
			end

			local core = require("notes.core")
			local filepath = core.create_note(title, tags)

			vim.cmd("edit " .. filepath)
			vim.notify("Note created: " .. filepath, vim.log.levels.INFO)

			local git_enabled = require("notes").config.git_enabled
			if git_enabled then
				local git = require("notes.git")
				git.commit_and_push()
			end
		end)
	end)
end

function M.list_notes()
	require("notes.telescope").find_notes(require("telescope.themes").get_dropdown({}))
end

function M.list_notes_by_tag()
	require("notes.telescope").find_notes_by_tag(require("telescope.themes").get_dropdown({}))
end

function M.backup_notes()
	local git = require("notes.git")
	git.commit_and_push()
end

function M.fetch_notes()
	local git = require("notes.git")
	git.fetch()
end

function M.delete_note()
	require("notes.telescope").delete_note(require("telescope.themes").get_dropdown({}))
end

function M.setup()
	vim.api.nvim_create_user_command("Note", M.create_note, {})
	vim.api.nvim_create_user_command("Notes", M.list_notes, {})
	vim.api.nvim_create_user_command("NoteTags", M.list_notes_by_tag, {})
	vim.api.nvim_create_user_command("NotesBackup", M.backup_notes, {})
	vim.api.nvim_create_user_command("NotesFetch", M.fetch_notes, {})
	vim.api.nvim_create_user_command("NoteDelete", M.delete_note, {})
end

return M
