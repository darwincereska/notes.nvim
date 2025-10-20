local config = require('notes.config')

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

    -- Initialize git repo
    local init_success, _ = run_git_command("git init")
    if not init_success then
        vim.notify("Failed to initialize git repo", vim.log.levels.ERROR)
        return false
    end

    -- Set default branch to main
    run_git_command("git branch -M main")

    -- Add remote if configured
    if config.options.git_remote then
        M.setup_remote()
    end

    vim.notify("Git repo initialized in notes directory", vim.log.levels.INFO)
    return true
end

function M.setup_remote()
    -- Check if origin already exists
    local check_success, _ = run_git_command("git remote get-url origin")

    if check_success then
        -- Update existing remote
        local update_success, _ = run_git_command("git remote set-url origin " .. config.options.git_remote)
        if update_success then
            vim.notify("Updated git remote origin", vim.log.levels.INFO)
        end
    else
        -- Add new remote
        local add_success, _ = run_git_command("git remote add origin " .. config.options.git_remote)
        if add_success then
            vim.notify("Added git remote origin", vim.log.levels.INFO)
        else
            vim.notify("Failed to add remote origin", vim.log.levels.WARN)
        end
    end
end

function M.backup()
    -- Add all files
    local add_success, _ = run_git_command("git add .")
    if not add_success then
        vim.notify("Failed to stage files", vim.log.levels.ERROR)
        return
    end

    -- Commit with timestamp
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local commit_msg = "Notes backup: " .. timestamp
    local commit_success, _ = run_git_command('git commit -m "' .. commit_msg .. '"')

    if not commit_success then
        vim.notify("No changes to commit", vim.log.levels.INFO)
        return
    end

    -- Push to remote if configured
    if config.options.git_remote then
        local push_success, result = run_git_command("git push origin main")
        if push_success then
            vim.notify("Notes backed up successfully", vim.log.levels.INFO)
        else
            vim.notify("Failed to push: " .. result, vim.log.levels.ERROR)
        end
    else
        vim.notify("Notes committed locally (no remote configured)", vim.log.levels.INFO)
    end
end

function M.fetch()
    if not config.options.git_remote then
        vim.notify("No git remote configured", vim.log.levels.WARN)
        return
    end

    local success, result = run_git_command("git pull origin main")
    if success then
        vim.notify("Notes fetched successfully", vim.log.levels.INFO)
    else
        vim.notify("Failed to fetch: " .. result, vim.log.levels.ERROR)
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
        vim.notify("Restored file from commit " .. commit_hash, vim.log.levels.INFO)
        return true
    else
        vim.notify("Failed to restore file: " .. result, vim.log.levels.ERROR)
        return false
    end
end

return M
