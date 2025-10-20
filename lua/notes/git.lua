local M = {}

local function execute_git(cmd, cwd)
	local full_cmd = string.format("git -C '%s' %s", cwd, cmd)
	local handle = io.popen(full_cmd .. " 2>&1")
	if not handle then
		return nil, "Failed to execute git command"
	end

	local result = handle:read("*all")
	local success = handle:close()
	return result, success
end

function M.init_repo()
	local notes_dir = require("notes.core").get_notes_dir()

	local git_dir = string.format("%s/.git", notes_dir)
	if vim.fn.isdirectory(git_dir) == 0 then
		execute_git("init", notes_dir)
		vim.notify("Initialized git repository in notes directory", vim.log.levels.INFO)

		local config = require("notes").config
		if config.git_remote then
			execute_git(string.format('remote add origin "%s"', config.git_remote), notes_dir)
			vim.notify("Added git remote: " .. config.git_remote, vim.log.levels.INFO)
		end
	end
end

function M.commit_and_push()
	local notes_dir = require("notes.core").get_notes_dir()
	local config = require("notes").config

	execute_git("add .", notes_dir)

	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local commit_msg = string.format("Backup notes: %s", timestamp)
	local result, success = execute_git(string.format('commit -m "%s"', commit_msg), notes_dir)

	if result and result:match("nothing to commit") then
		vim.notify("No changes to commit", vim.log.levels.INFO)
		return
	end

	if success then
		vim.notify("Notes committed successfully", vim.log.levels.INFO)

		if config.git_remote then
			local push_result, push_success = execute_git("push origin HEAD", notes_dir)
			if push_success then
				vim.notify("Notes pushed to remote", vim.log.levels.INFO)
			else
				vim.notify("Failed to push to remote: " .. (push_result or ""), vim.log.levels.WARN)
			end
		end
	else
		vim.notify("Failed to commit notes: " .. (result or ""), vim.log.levels.ERROR)
	end
end

function M.fetch()
	local notes_dir = require("notes.core").get_notes_dir()
	local config = require("notes").config

	if not config.git_remote then
		vim.notify("No git remote configured", vim.log.levels.WARN)
		return
	end

	local result, success = execute_git("fetch origin", notes_dir)
	if success then
		vim.notify("Fetched from remote successfully", vim.log.levels.INFO)
	else
		vim.notify("Failed to fetch from remote: " .. (result or ""), vim.log.levels.ERROR)
	end
end

function M.get_file_history(filepath)
	local notes_dir = require("notes.core").get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	local result, success = execute_git(
		string.format('log --pretty=format:"%%H|%%an|%%ar|%%s" --follow -- "%s"', relative_path),
		notes_dir
	)
	
	if not success or not result or result == "" then
		return {}
	end
	
	local commits = {}
	for line in result:gmatch("[^\r\n]+") do
		local hash, author, date, message = line:match("([^|]+)|([^|]+)|([^|]+)|(.+)")
		if hash then
			table.insert(commits, {
				hash = hash,
				author = author,
				date = date,
				message = message,
				filepath = filepath,
			})
		end
	end
	
	return commits
end

function M.get_all_history()
	local notes_dir = require("notes.core").get_notes_dir()
	
	local result, success = execute_git(
		'log --pretty=format:"%H|%an|%ar|%s" --name-only',
		notes_dir
	)
	
	if not success or not result or result == "" then
		return {}
	end
	
	local commits = {}
	local current_commit = nil
	
	for line in result:gmatch("[^\r\n]+") do
		if line:match("|") then
			local hash, author, date, message = line:match("([^|]+)|([^|]+)|([^|]+)|(.+)")
			if hash then
				current_commit = {
					hash = hash,
					author = author,
					date = date,
					message = message,
					files = {}
				}
				table.insert(commits, current_commit)
			end
		elseif line ~= "" and current_commit and line:match("%.md$") then
			table.insert(current_commit.files, line)
		end
	end
	
	return commits
end

function M.revert_file(filepath, commit_hash)
	local notes_dir = require("notes.core").get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	local result, success = execute_git(
		string.format('show %s:"%s"', commit_hash, relative_path),
		notes_dir
	)
	
	if success and result then
		local file = io.open(filepath, "w")
		if file then
			file:write(result)
			file:close()
			
			execute_git("add .", notes_dir)
			execute_git(string.format('commit -m "Revert %s to %s"', relative_path, commit_hash:sub(1, 7)), notes_dir)
			
			vim.notify("File reverted to commit " .. commit_hash:sub(1, 7), vim.log.levels.INFO)
			return true
		end
	end
	
	vim.notify("Failed to revert file", vim.log.levels.ERROR)
	return false
end

return M
