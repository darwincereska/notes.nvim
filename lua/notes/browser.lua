local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local Menu = require("nui.menu")
local Job = require("plenary.job")
local core = require("notes.core")
local notevc = require("notes.notevc")

-- Helper function to execute notevc commands asynchronously
local function execute_notevc_async(args, cwd, callback)
    local config = require("notes").config
    local notevc_cmd = config.notevc_path or "notevc"

    Job:new({
        command = notevc_cmd,
        args = args,
        cwd = cwd,
        on_exit = function(j, return_val)
            vim.schedule(function()
                callback(j:result(), return_val == 0)
            end)
        end,
    }):start()
end

-- Show history for a specific file
function M.file_history(filepath, opts)
    opts = opts or {}
    local notes_dir = core.get_notes_dir()
    local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")

    local commits = notevc.get_file_history(filepath)

    if #commits == 0 then
        vim.notify("No history found for this note", vim.log.levels.WARN)
        return
    end

    pickers.new(opts, {
        prompt_title = "Note History: " .. relative_path,
        finder = finders.new_table({
            results = commits,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = string.format("%s  %s  %s", entry.hash:sub(1, 8), entry.date, entry.message),
                    ordinal = entry.hash .. " " .. entry.date .. " " .. entry.message,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Commit Content",
            define_preview = function(self, entry)
                local content = notevc.get_file_at_commit(filepath, entry.value.hash)
                if content then
                    local lines = vim.split(content, "\n")
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                    end)
                end
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            local function show_actions()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                local menu = Menu({
                    position = "50%",
                    size = {
                        width = 45,
                        height = 7,
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
                            Menu.item("View blocks changed"),
                            Menu.item("Revert to this commit"),
                            Menu.item("Revert specific block"),
                            Menu.item("Show diff"),
                            Menu.separator(""),
                            Menu.item("Cancel"),
                        },
                        max_width = 45,
                        keymap = {
                            focus_next = { "j", "<Down>", "<Tab>" },
                            focus_prev = { "k", "<Up>", "<S-Tab>" },
                            close = { "<Esc>", "<C-c>", "q" },
                            submit = { "<CR>", "<Space>" },
                        },
                        on_submit = function(item)
                            if item.text == "View at this commit" then
                                local content = notevc.get_file_at_commit(filepath, selection.value.hash)
                                if content then
                                    local buf = vim.api.nvim_create_buf(false, true)
                                    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
                                    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
                                    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
                                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
                                    vim.api.nvim_set_current_buf(buf)
                                    vim.api.nvim_buf_set_name(buf, string.format("[%s] %s", selection.value.hash:sub(1, 7), relative_path))
                                end
                            elseif item.text == "View blocks changed" then
                                M.browse_commit_blocks(selection.value.hash, filepath, opts)
                            elseif item.text == "Revert to this commit" then
                                vim.ui.select({ "Yes", "No" }, {
                                    prompt = "Revert to commit " .. selection.value.hash:sub(1, 7) .. "?",
                                }, function(choice)
                                        if choice == "Yes" then
                                            notevc.restore_file(filepath, selection.value.hash)
                                            vim.cmd("edit! " .. vim.fn.fnameescape(filepath))
                                        end
                                    end)
                            elseif item.text == "Revert specific block" then
                                M.select_block_to_restore(filepath, selection.value.hash, opts)
                            elseif item.text == "Show diff" then
                                local diff_output = notevc.diff(selection.value.hash, nil, { file = relative_path })
                                if diff_output then
                                    local buf = vim.api.nvim_create_buf(false, true)
                                    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
                                    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
                                    vim.api.nvim_buf_set_option(buf, "filetype", "diff")
                                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(diff_output, "\n"))
                                    vim.api.nvim_set_current_buf(buf)
                                    vim.api.nvim_buf_set_name(buf, string.format("[Diff] %s vs HEAD", selection.value.hash:sub(1, 7)))
                                end
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

-- Show all commit history
function M.all_history(opts)
    opts = opts or {}
    local notes_dir = core.get_notes_dir()

    local commits = notevc.get_all_history()

    if #commits == 0 then
        vim.notify("No history found", vim.log.levels.WARN)
        return
    end

    pickers.new(opts, {
        prompt_title = "All Commits",
        finder = finders.new_table({
            results = commits,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = string.format("%s  %s  %s  %s", entry.hash:sub(1, 8), entry.date, entry.author, entry.message),
                    ordinal = entry.hash .. " " .. entry.date .. " " .. entry.author .. " " .. entry.message,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Commit Details",
            define_preview = function(self, entry)
                local details = notevc.show_commit(entry.value.hash, {})
                if details then
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(details, "\n"))
                        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "git")
                    end)
                end
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
                                local details = notevc.show_commit(selection.value.hash, {})
                                if details then
                                    local buf = vim.api.nvim_create_buf(false, true)
                                    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
                                    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
                                    vim.api.nvim_buf_set_option(buf, "filetype", "git")
                                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(details, "\n"))
                                    vim.api.nvim_set_current_buf(buf)
                                    vim.api.nvim_buf_set_name(buf, string.format("[Commit] %s", selection.value.hash:sub(1, 7)))
                                end
                            elseif item.text == "Browse files in commit" then
                                M.browse_commit_files(selection.value.hash, opts)
                            elseif item.text == "Show diff" then
                                local diff_output = notevc.diff(selection.value.hash, nil, {})
                                if diff_output then
                                    local buf = vim.api.nvim_create_buf(false, true)
                                    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
                                    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
                                    vim.api.nvim_buf_set_option(buf, "filetype", "diff")
                                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(diff_output, "\n"))
                                    vim.api.nvim_set_current_buf(buf)
                                    vim.api.nvim_buf_set_name(buf, string.format("[Diff] %s", selection.value.hash:sub(1, 7)))
                                end
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

-- Browse files in a specific commit (stub for now - notevc needs file listing)
function M.browse_commit_files(commit_hash, opts)
    vim.notify("Browse commit files - Coming soon with notevc update", vim.log.levels.INFO)
    -- This would require notevc to expose which files were changed in a commit
end

-- NEW: Browse blocks in a commit for a specific file
function M.browse_commit_blocks(commit_hash, filepath, opts)
    opts = opts or {}
    local notes_dir = core.get_notes_dir()
    local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")

    local blocks = notevc.get_commit_blocks(commit_hash, filepath)

    if #blocks == 0 then
        vim.notify("No blocks found in this commit", vim.log.levels.WARN)
        return
    end

    pickers.new(opts, {
        prompt_title = "Blocks at " .. commit_hash:sub(1, 7),
        finder = finders.new_table({
            results = blocks,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = string.format("%s %s", string.rep(" ", entry.level - 1), entry.text),
                    ordinal = entry.text,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Block Content",
            define_preview = function(self, entry)
                local content = notevc.get_file_at_commit(filepath, commit_hash)
                if content then
                    local lines = vim.split(content, "\n")
                    local block_lines = {}
                    for i = entry.value.start_line, entry.value.end_line do
                        table.insert(block_lines, lines[i])
                    end
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, block_lines)
                        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                    end)
                end
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                vim.notify("Selected block: " .. selection.value.text, vim.log.levels.INFO)
            end)
            return true
        end,
    }):find()
end

-- NEW: Browse blocks in the current file
function M.browse_file_blocks(filepath, opts)
    opts = opts or {}
    local notes_dir = core.get_notes_dir()
    local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")

    local blocks = notevc.get_file_blocks(filepath)

    if #blocks == 0 then
        vim.notify("No blocks found in this file", vim.log.levels.WARN)
        return
    end

    pickers.new(opts, {
        prompt_title = "Blocks in " .. relative_path,
        finder = finders.new_table({
            results = blocks,
            entry_maker = function(entry)
                local indent = string.rep("  ", entry.level - 1)
                return {
                    value = entry,
                    display = string.format("%s%s", indent, entry.text),
                    ordinal = entry.text,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Block Content",
            define_preview = function(self, entry)
                local file = io.open(filepath, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    local lines = vim.split(content, "\n")
                    local block_lines = {}
                    for i = entry.value.start_line, entry.value.end_line do
                        if lines[i] then
                            table.insert(block_lines, lines[i])
                        end
                    end
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, block_lines)
                        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                    end)
                end
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            local function show_block_actions()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                local menu = Menu({
                    position = "50%",
                    size = {
                        width = 35,
                        height = 4,
                    },
                    border = {
                        style = "rounded",
                        text = {
                            top = " Block Actions ",
                            top_align = "center",
                        },
                    },
                    win_options = {
                        winhighlight = "Normal:Normal,FloatBorder:Normal",
                    },
                }, {
                        lines = {
                            Menu.item("View block history"),
                            Menu.item("Jump to block"),
                            Menu.separator(""),
                            Menu.item("Cancel"),
                        },
                        max_width = 35,
                        keymap = {
                            focus_next = { "j", "<Down>", "<Tab>" },
                            focus_prev = { "k", "<Up>", "<S-Tab>" },
                            close = { "<Esc>", "<C-c>", "q" },
                            submit = { "<CR>", "<Space>" },
                        },
                        on_submit = function(item)
                            if item.text == "Jump to block" then
                                vim.cmd("normal! " .. selection.value.start_line .. "G")
                            elseif item.text == "View block history" then
                                vim.notify("Block history - Coming soon", vim.log.levels.INFO)
                                -- This would show commits that affected this specific block
                            end
                        end,
                    })

                menu:mount()
            end

            actions.select_default:replace(show_block_actions)
            return true
        end,
    }):find()
end

-- NEW: Select a block to restore from a commit
function M.select_block_to_restore(filepath, commit_hash, opts)
    opts = opts or {}
    local notes_dir = core.get_notes_dir()

    local blocks = notevc.get_commit_blocks(commit_hash, filepath)

    if #blocks == 0 then
        vim.notify("No blocks found in this commit", vim.log.levels.WARN)
        return
    end

    pickers.new(opts, {
        prompt_title = "Select Block to Restore",
        finder = finders.new_table({
            results = blocks,
            entry_maker = function(entry)
                local indent = string.rep("  ", entry.level - 1)
                return {
                    value = entry,
                    display = string.format("%s%s", indent, entry.text),
                    ordinal = entry.text,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Block Content",
            define_preview = function(self, entry)
                local content = notevc.get_file_at_commit(filepath, commit_hash)
                if content then
                    local lines = vim.split(content, "\n")
                    local block_lines = {}
                    for i = entry.value.start_line, entry.value.end_line do
                        if lines[i] then
                            table.insert(block_lines, lines[i])
                        end
                    end
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, block_lines)
                        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                    end)
                end
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                vim.ui.select({ "Yes", "No" }, {
                    prompt = "Restore block '" .. selection.value.text .. "' from commit " .. commit_hash:sub(1, 7) .. "?",
                }, function(choice)
                        if choice == "Yes" then
                            -- For now, we'll note this needs a block ID from notevc
                            -- The actual restore would be: notevc.restore_file(filepath, commit_hash, block_id)
                            vim.notify("Block restoration requires block hash from notevc - feature coming soon", vim.log.levels.INFO)
                        end
                    end)
            end)
            return true
        end,
    }):find()
end

return M
