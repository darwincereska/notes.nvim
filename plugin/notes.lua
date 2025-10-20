if vim.g.loaded_notes then
    return
end
vim.g.loaded_notes = 1

-- Create user commands
vim.api.nvim_create_user_command('Note', function()
    require('notes').create_note()
end, { desc = 'Create a new note' })

vim.api.nvim_create_user_command('Notes', function()
    require('notes').list_notes()
end, { desc = 'List and open notes' })

vim.api.nvim_create_user_command('NotesTags', function()
    require('notes').list_notes_by_tag()
end, { desc = 'Browse notes by tags' })

vim.api.nvim_create_user_command('NotesBackup', function()
    require('notes').backup_notes()
end, { desc = 'Backup notes to git' })

vim.api.nvim_create_user_command('NotesFetch', function()
    require('notes').fetch_notes()
end, { desc = 'Fetch notes from git' })

vim.api.nvim_create_user_command('NotesHistory', function()
    require('notes').show_notes_history()
end, { desc = 'Show all notes history' })

vim.api.nvim_create_user_command('NoteHistory', function()
    require('notes').show_file_history()
end, { desc = 'Show current note history' })
