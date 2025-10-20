local config = require('notes.config')
local ui = require('notes.ui')

local M = {}

local function run_git_command(cmd, cwd)
    cwd = cwd or config.options.notes_dir
    local result = vim.fn.system("cd " .. cwd .. " && " .. cmd)
    return vim.v.shell_error == 0, result
end

function M.init_repo()
    local notes_dir = config.options.notes_dir

    -- Check if already a git repo
    local success, _ = run_git_command("git status")
    if success then
        -- Already a git repo, check if we need to add/update remote
        if config.options.git_remote then
            M.setup_remote()
        end
        return true
    end

    local init_success, _ = run_git_command("git init")
    if not init_success then
        ui.notify("Failed to initialize git repo", vim.log.levels.ERROR)
        return false
    end

    run_git_command("git branch -M main")

    if config.options.git_remote then
        M.setup_remote()
    end

    ui.notify("Git repo initialized", vim.log.levels.INFO)
    return true
end

function M.setup_remote()
    local check_success, _ = run_git_command("git remote get-url origin")

    if check_success then
        local update_success, _ = run_git_command("git remote set-url origin " .. config.options.git_remote)
        if update_success then
            ui.notify("Updated git remote", vim.log.levels.INFO)
        end
    else
        local add_success, _ = run_git_command("git remote add origin " .. config.options.git_remote)
        if add_success then
            ui.notify("Added git remote", vim.log.levels.INFO)
        else
            ui.notify("Failed to add remote", vim.log.levels.WARN)
        end
    end
end

function M.backup()
    local add_success, _ = run_git_command("git add .")
    if not add_success then
        ui.notify("Failed to stage files", vim.log.levels.ERROR)
        return
    end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local commit_msg = "Notes backup: " .. timestamp
    local commit_success, _ = run_git_command('git commit -m "' .. commit_msg .. '"')

    if not commit_success then
        ui.notify("No changes to commit", vim.log.levels.INFO)
        return
    end

    if config.options.git_remote then
        local push_success, result = run_git_command("git push origin main")
        if push_success then
            ui.notify("Notes backed up successfully", vim.log.levels.INFO)
        else
            ui.notify("Failed to push: " .. result, vim.log.levels.ERROR)
        end
    else
        ui.notify("Notes committed locally", vim.log.levels.INFO)
    end
end

function M.fetch()
    if not config.options.git_remote then
        ui.notify("No git remote configured", vim.log.levels.WARN)
        return
    end

    local success, result = run_git_command("git pull origin main")
    if success then
        ui.notify("Notes fetched successfully", vim.log.levels.INFO)
    else
        ui.notify("Failed to fetch: " .. result, vim.log.levels.ERROR)
    end
end

function M.get_commit_history(file_path)
    local relative_path = file_path:gsub(config.options.notes_dir .. "/", "")
    local cmd = string.format('git log --oneline --follow "%s"', relative_path)

    local success, result = run_git_command(cmd)
    if not success then
        return {}
    end

    local commits = {}
    for line in result:gmatch("[^\r\n]+") do
        local hash, message = line:match("^(%w+)%s+(.+)$")
        if hash and message then
            -- Get commit date
            local date_cmd = string.format('git show -s --format="%%ci" %s', hash)
            local date_success, date_result = run_git_command(date_cmd)
            local date = date_success and date_result:gsub("\n", "") or "Unknown"

            table.insert(commits, {
                hash = hash,
                message = message,
                date = date,
                full_line = line .. " (" .. date:sub(1, 10) .. ")"
            })
        end
    end

    return commits
end

function M.get_file_at_commit(file_path, commit_hash)
    local relative_path = file_path:gsub(config.options.notes_dir .. "/", "")
    local cmd = string.format('git show %s:"%s"', commit_hash, relative_path)

    local success, result = run_git_command(cmd)
    if success then
        return result
    else
        return nil
    end
end

function M.get_all_commits()
    local cmd = 'git log --oneline --all'
    local success, result = run_git_command(cmd)

    if not success then
        return {}
    end

    local commits = {}
    for line in result:gmatch("[^\r\n]+") do
        local hash, message = line:match("^(%w+)%s+(.+)$")
        if hash and message then
            -- Get commit date
            local date_cmd = string.format('git show -s --format="%%ci" %s', hash)
            local date_success, date_result = run_git_command(date_cmd)
            local date = date_success and date_result:gsub("\n", "") or "Unknown"

            table.insert(commits, {
                hash = hash,
                message = message,
                date = date,
                full_line = line .. " (" .. date:sub(1, 10) .. ")"
            })
        end
    end

    return commits
end

function M.get_files_changed_in_commit(commit_hash)
    local cmd = string.format('git show --name-only --format="" %s', commit_hash)
    local success, result = run_git_command(cmd)

    if not success then
        return {}
    end

    local files = {}
    for line in result:gmatch("[^\r\n]+") do
        if line ~= "" and line:match("%.md$") then
            table.insert(files, line)
        end
    end

    return files
end

function M.restore_file_from_commit(file_path, commit_hash)
    local relative_path = file_path:gsub(config.options.notes_dir .. "/", "")
    local cmd = string.format('git checkout %s -- "%s"', commit_hash, relative_path)

    local success, result = run_git_command(cmd)
    if success then
        ui.notify("Restored file from commit " .. commit_hash, vim.log.levels.INFO)
        return true
    else
        ui.notify("Failed to restore file: " .. result, vim.log.levels.ERROR)
        return false
    end
end

return M
