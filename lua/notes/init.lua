local config = require('notes.config')
local git = require('notes.git')

local M = {}

function M.setup(opts)
    config.setup(opts)
end

local function get_date_path()
    return os.date(config.options.date_format)
end

local function create_note_path(name)
    local date_path = get_date_path()
    local full_dir = config.options.notes_dir .. "/" .. date_path
    vim.fn.mkdir(full_dir, "p")

    local filename = name:gsub("%s+", "-"):lower() .. config.options.file_extension
    return full_dir .. "/" .. filename
end

local function create_note_content(title)
    local template = config.options.template
    local date = os.date("%Y-%m-%d %H:%M:%S")

    return template:gsub("{title}", title):gsub("{date}", date)
end

function M.create_note()
    vim.ui.input({ prompt = "Note name: " }, function(name)
        if not name or name == "" then
            return
        end

        local note_path = create_note_path(name)

        -- Check if file already exists
        if vim.fn.filereadable(note_path) == 1 then
            vim.notify("Note already exists: " .. note_path, vim.log.levels.WARN)
            vim.cmd("edit " .. note_path)
            return
        end

        -- Create note with template
        local content = create_note_content(name)
        local file = io.open(note_path, "w")
        if file then
            file:write(content)
            file:close()
            vim.cmd("edit " .. note_path)
            vim.notify("Created note: " .. note_path, vim.log.levels.INFO)
        else
            vim.notify("Failed to create note", vim.log.levels.ERROR)
        end
    end)
end

function M.list_notes()
    local notes_dir = config.options.notes_dir

    -- Use telescope if available, otherwise use vim.ui.select
    local has_telescope, telescope = pcall(require, 'telescope.builtin')

    if has_telescope then
        telescope.find_files({
            prompt_title = "Notes",
            cwd = notes_dir,
            find_command = { "find", notes_dir, "-name", "*" .. config.options.file_extension, "-type", "f" }
        })
    else
        -- Fallback to basic file listing
        local files = vim.fn.systemlist("find " .. notes_dir .. " -name '*" .. config.options.file_extension .. "' -type f")

        if #files == 0 then
            vim.notify("No notes found", vim.log.levels.INFO)
            return
        end

        vim.ui.select(files, {
            prompt = "Select note:",
            format_item = function(item)
                return vim.fn.fnamemodify(item, ":t:r") .. " (" .. vim.fn.fnamemodify(item, ":h:t") .. ")"
            end
        }, function(choice)
                if choice then
                    vim.cmd("edit " .. choice)
                end
            end)
    end
end

function M.backup_notes()
    git.backup()
end

function M.fetch_notes()
    git.fetch()
end

function M.show_file_history()
    local current_file = vim.fn.expand("%:p")

    -- Check if current file is in notes directory
    if not current_file:match("^" .. config.options.notes_dir) then
        vim.notify("Current file is not a note", vim.log.levels.WARN)
        return
    end

    local commits = git.get_commit_history(current_file)

    if #commits == 0 then
        vim.notify("No history found for this note", vim.log.levels.INFO)
        return
    end

    vim.ui.select(commits, {
        prompt = "Select commit to view:",
        format_item = function(item)
            return item.full_line
        end
    }, function(choice)
            if choice then
                M.view_file_at_commit(current_file, choice.hash, choice.message)
            end
        end)
end

function M.view_file_at_commit(file_path, commit_hash, commit_message)
    local content = git.get_file_at_commit(file_path, commit_hash)

    if not content then
        vim.notify("Could not retrieve file at commit " .. commit_hash, vim.log.levels.ERROR)
        return
    end

    -- Create a new buffer with the historical content
    local buf = vim.api.nvim_create_buf(false, true)
    local filename = vim.fn.fnamemodify(file_path, ":t")
    local buf_name = filename .. " @ " .. commit_hash

    vim.api.nvim_buf_set_name(buf, buf_name)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)

    -- Set the content
    local lines = vim.split(content, '\n')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Open in a new window
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, buf)

    -- Add buffer-local keymaps for restoration
    vim.keymap.set('n', 'r', function()
        M.restore_from_history(file_path, commit_hash)
    end, { buffer = buf, desc = 'Restore this version' })

    vim.keymap.set('n', 'q', function()
        vim.cmd('close')
    end, { buffer = buf, desc = 'Close history view' })

    vim.notify("Viewing: " .. commit_message .. " (press 'r' to restore, 'q' to close)", vim.log.levels.INFO)
end

function M.restore_from_history(file_path, commit_hash)
    vim.ui.input({
        prompt = "Restore this version? This will overwrite current file (y/N): "
    }, function(input)
            if input and input:lower() == 'y' then
                if git.restore_file_from_commit(file_path, commit_hash) then
                    vim.cmd('close') -- Close history view
                    vim.cmd('edit!') -- Reload the file
                end
            end
        end)
end

function M.show_notes_history()
    local commits = git.get_all_commits()

    if #commits == 0 then
        vim.notify("No commit history found", vim.log.levels.INFO)
        return
    end

    vim.ui.select(commits, {
        prompt = "Select commit to explore:",
        format_item = function(item)
            return item.full_line
        end
    }, function(choice)
            if choice then
                M.show_commit_files(choice.hash, choice.message)
            end
        end)
end

function M.show_commit_files(commit_hash, commit_message)
    local files = git.get_files_changed_in_commit(commit_hash)

    if #files == 0 then
        vim.notify("No note files in this commit", vim.log.levels.INFO)
        return
    end

    vim.ui.select(files, {
        prompt = "Files in commit (" .. commit_message .. "):",
        format_item = function(item)
            return item
        end
    }, function(choice)
            if choice then
                local full_path = config.options.notes_dir .. "/" .. choice
                M.view_file_at_commit(full_path, commit_hash, commit_message)
            end
        end)
end

return M
