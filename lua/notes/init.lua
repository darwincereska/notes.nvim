local config = require('notes.config')
local git = require('notes.git')
local ui = require('notes.ui')

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

local function create_note_content(title, tags)
    local template = config.options.template
    local date = os.date("%Y-%m-%d %H:%M:%S")
    local tag_string = tags and #tags > 0 and table.concat(tags, ", ") or ""

    return template:gsub("{title}", title):gsub("{date}", date):gsub("{tags}", tag_string)
end

local function parse_tags_from_content(content)
    local tags = {}
    -- Look for "Tags: tag1, tag2, tag3" pattern
    local tag_line = content:match("Tags:%s*([^\n\r]*)")
    if tag_line and tag_line ~= "" then
        for tag in tag_line:gmatch("([^,]+)") do
            local trimmed = tag:match("^%s*(.-)%s*$") -- trim whitespace
            if trimmed ~= "" then
                table.insert(tags, trimmed)
            end
        end
    end
    return tags
end

local function get_note_metadata(file_path)
    local file = io.open(file_path, "r")
    if not file then return nil end

    local content = file:read("*all")
    file:close()

    local title = content:match("^#%s*([^\n\r]*)")
    local date = content:match("Date:%s*([^\n\r]*)")
    local tags = parse_tags_from_content(content)

    return {
        title = title or vim.fn.fnamemodify(file_path, ":t:r"),
        date = date,
        tags = tags,
        path = file_path
    }
end

function M.create_note()
    ui.input({ prompt = "Note name" }, function(name)
        if not name or name == "" then
            return
        end

        ui.confirm({ 
            prompt = "Add tags?",
            choices = { 'Yes', 'No' }
        }, function(choice)
            if choice == 'Yes' then
                ui.input({ prompt = "Tags (comma-separated)" }, function(tag_input)
                    local tags = {}
                    if tag_input and tag_input ~= "" then
                        for tag in tag_input:gmatch("([^,]+)") do
                            local trimmed = tag:match("^%s*(.-)%s*$")
                            if trimmed ~= "" then
                                table.insert(tags, trimmed)
                            end
                        end
                    end
                    M._create_note_with_tags(name, tags)
                end)
            else
                M._create_note_with_tags(name, {})
            end
        end)
    end)
end

function M._create_note_with_tags(name, tags)
    local note_path = create_note_path(name)

    if vim.fn.filereadable(note_path) == 1 then
        ui.notify("Note already exists", vim.log.levels.WARN)
        vim.cmd("edit " .. note_path)
        return
    end

    local content = create_note_content(name, tags)
    local file = io.open(note_path, "w")
    if file then
        file:write(content)
        file:close()
        vim.cmd("edit " .. note_path)
        ui.notify("Created note", vim.log.levels.INFO)
    else
        ui.notify("Failed to create note", vim.log.levels.ERROR)
    end
end

function M.list_notes()
    local notes_dir = config.options.notes_dir
    local files = vim.fn.systemlist("find " .. notes_dir .. " -name '*" .. config.options.file_extension .. "' -type f")

    if #files == 0 then
        ui.notify("No notes found", vim.log.levels.INFO)
        return
    end

    local notes_with_metadata = {}
    for _, file_path in ipairs(files) do
        local metadata = get_note_metadata(file_path)
        if metadata then
            table.insert(notes_with_metadata, metadata)
        end
    end

    local has_telescope, telescope_pickers = pcall(require, 'telescope.pickers')
    local has_finders, finders = pcall(require, 'telescope.finders')
    local has_conf, conf = pcall(require, 'telescope.config')
    local has_actions, actions = pcall(require, 'telescope.actions')
    local has_action_state, action_state = pcall(require, 'telescope.actions.state')

    if has_telescope and has_finders and has_conf and has_actions and has_action_state and config.options.use_telescope then
        telescope_pickers.new({}, {
            prompt_title = "Notes",
            finder = finders.new_table({
                results = notes_with_metadata,
                entry_maker = function(note)
                    local tag_str = #note.tags > 0 and " [" .. table.concat(note.tags, ", ") .. "]" or ""
                    return {
                        value = note,
                        display = note.title .. tag_str,
                        ordinal = note.title,
                        path = note.path
                    }
                end
            }),
            sorter = conf.values.generic_sorter({}),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        vim.cmd("edit " .. selection.value.path)
                    end
                end)
                return true
            end,
        }):find()
    else
        ui.select(notes_with_metadata, {
            prompt = "Select note",
            format_item = function(item)
                local tag_str = #item.tags > 0 and " [" .. table.concat(item.tags, ", ") .. "]" or ""
                return item.title .. tag_str
            end
        }, function(choice)
            if choice then
                vim.cmd("edit " .. choice.path)
            end
        end)
    end
end

function M.list_notes_by_tag()
    local notes_dir = config.options.notes_dir
    local files = vim.fn.systemlist("find " .. notes_dir .. " -name '*" .. config.options.file_extension .. "' -type f")

    if #files == 0 then
        ui.notify("No notes found", vim.log.levels.INFO)
        return
    end

    -- Collect all tags and notes
    local all_tags = {}
    local notes_by_tag = {}

    for _, file_path in ipairs(files) do
        local metadata = get_note_metadata(file_path)
        if metadata then
            for _, tag in ipairs(metadata.tags) do
                if not all_tags[tag] then
                    all_tags[tag] = true
                    notes_by_tag[tag] = {}
                end
                table.insert(notes_by_tag[tag], metadata)
            end
        end
    end

    local tag_list = {}
    for tag, _ in pairs(all_tags) do
        table.insert(tag_list, tag)
    end
    table.sort(tag_list)

    if #tag_list == 0 then
        ui.notify("No tagged notes found", vim.log.levels.INFO)
        return
    end

    -- Use telescope for tag selection if available
    local has_telescope, telescope = pcall(require, 'telescope.pickers')
    local has_finders, finders = pcall(require, 'telescope.finders')
    local has_conf, conf = pcall(require, 'telescope.config')
    local has_actions, actions = pcall(require, 'telescope.actions')
    local has_action_state, action_state = pcall(require, 'telescope.actions.state')

    if has_telescope and has_finders and has_conf and has_actions and has_action_state and config.options.use_telescope then
        telescope.new({}, {
            prompt_title = "Select Tag",
            finder = finders.new_table({
                results = tag_list,
                entry_maker = function(tag)
                    return {
                        value = tag,
                        display = tag .. " (" .. #notes_by_tag[tag] .. " notes)",
                        ordinal = tag,
                    }
                end
            }),
            sorter = conf.values.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        M.show_notes_for_tag(selection.value, notes_by_tag[selection.value])
                    end
                end)
                return true
            end,
        }):find()
    else
        ui.select(tag_list, {
            prompt = "Select tag",
            format_item = function(tag)
                return tag .. " (" .. #notes_by_tag[tag] .. " notes)"
            end
        }, function(choice)
            if choice then
                M.show_notes_for_tag(choice, notes_by_tag[choice])
            end
        end)
    end
end

function M.show_notes_for_tag(tag, notes)
    ui.select(notes, {
        prompt = "Notes tagged with '" .. tag .. "'",
        format_item = function(item)
            return item.title .. " (" .. (item.date or "no date") .. ")"
        end
    }, function(choice)
        if choice then
            vim.cmd("edit " .. choice.path)
        end
    end)
end

function M.backup_notes()
    git.backup()
end

function M.fetch_notes()
    git.fetch()
end

function M.show_file_history()
    local current_file = vim.fn.expand("%:p")

    if not current_file:match("^" .. config.options.notes_dir) then
        ui.notify("Current file is not a note", vim.log.levels.WARN)
        return
    end

    local commits = git.get_commit_history(current_file)

    if #commits == 0 then
        ui.notify("No history found for this note", vim.log.levels.INFO)
        return
    end

    -- Use telescope for history if available
    local has_telescope, telescope = pcall(require, 'telescope.pickers')
    local has_finders, finders = pcall(require, 'telescope.finders')
    local has_conf, conf = pcall(require, 'telescope.config')
    local has_actions, actions = pcall(require, 'telescope.actions')
    local has_action_state, action_state = pcall(require, 'telescope.actions.state')

    if has_telescope and has_finders and has_conf and has_actions and has_action_state and config.options.use_telescope then
        telescope.new({}, {
            prompt_title = "Note History",
            finder = finders.new_table({
                results = commits,
                entry_maker = function(commit)
                    return {
                        value = commit,
                        display = commit.full_line,
                        ordinal = commit.full_line,
                    }
                end
            }),
            sorter = conf.values.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        M.view_file_at_commit(current_file, selection.value.hash, selection.value.message)
                    end
                end)
                return true
            end,
        }):find()
    else
        ui.select(commits, {
            prompt = "Select commit to view",
            format_item = function(item)
                return item.full_line
            end
        }, function(choice)
            if choice then
                M.view_file_at_commit(current_file, choice.hash, choice.message)
            end
        end)
    end
end

function M.view_file_at_commit(file_path, commit_hash, commit_message)
    local content = git.get_file_at_commit(file_path, commit_hash)

    if not content then
        ui.notify("Could not retrieve file at commit " .. commit_hash, vim.log.levels.ERROR)
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

    ui.notify("Viewing: " .. commit_message .. " (press 'r' to restore, 'q' to close)", vim.log.levels.INFO)
end

function M.restore_from_history(file_path, commit_hash)
    ui.confirm({
        prompt = "Restore this version? (overwrites current file)",
        choices = { 'Yes', 'No' }
    }, function(choice)
        if choice == 'Yes' then
            if git.restore_file_from_commit(file_path, commit_hash) then
                vim.cmd('close')
                vim.cmd('edit!')
            end
        end
    end)
end

function M.show_notes_history()
    local commits = git.get_all_commits()

    if #commits == 0 then
        ui.notify("No commit history found", vim.log.levels.INFO)
        return
    end

    -- Use telescope for commit history if available
    local has_telescope, telescope = pcall(require, 'telescope.pickers')
    local has_finders, finders = pcall(require, 'telescope.finders')
    local has_conf, conf = pcall(require, 'telescope.config')
    local has_actions, actions = pcall(require, 'telescope.actions')
    local has_action_state, action_state = pcall(require, 'telescope.actions.state')

    if has_telescope and has_finders and has_conf and has_actions and has_action_state and config.options.use_telescope then
        telescope.new({}, {
            prompt_title = "Notes History",
            finder = finders.new_table({
                results = commits,
                entry_maker = function(commit)
                    return {
                        value = commit,
                        display = commit.full_line,
                        ordinal = commit.full_line,
                    }
                end
            }),
            sorter = conf.values.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        M.show_commit_files(selection.value.hash, selection.value.message)
                    end
                end)
                return true
            end,
        }):find()
    else
        ui.select(commits, {
            prompt = "Select commit to explore",
            format_item = function(item)
                return item.full_line
            end
        }, function(choice)
            if choice then
                M.show_commit_files(choice.hash, choice.message)
            end
        end)
    end
end

function M.show_commit_files(commit_hash, commit_message)
    local files = git.get_files_changed_in_commit(commit_hash)

    if #files == 0 then
        ui.notify("No note files in this commit", vim.log.levels.INFO)
        return
    end

    ui.select(files, {
        prompt = "Files in commit (" .. commit_message .. ")",
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
