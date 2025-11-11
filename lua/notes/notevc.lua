local M = {}

-- Execute notevc command and return result
local function execute_notevc(args, cwd)
	local config = require("notes").config
	local notevc_cmd = config.notevc_path or "notevc"
	
	-- Build full command
	local cmd_parts = { notevc_cmd }
	for _, arg in ipairs(args) do
		table.insert(cmd_parts, arg)
	end
	
	local full_cmd = table.concat(cmd_parts, " ")
	if cwd then
		full_cmd = string.format("cd '%s' && %s", cwd, full_cmd)
	end
	
	full_cmd = full_cmd .. " 2>&1"
	
	local handle = io.popen(full_cmd)
	if not handle then
		return nil, "Failed to execute notevc command"
	end

	local result = handle:read("*all")
	local success = handle:close()
	return result, success
end

-- Initialize notevc repository
function M.init_repo()
	local notes_dir = require("notes.core").get_notes_dir()

	local notevc_dir = string.format("%s/.notevc", notes_dir)
	if vim.fn.isdirectory(notevc_dir) == 0 then
		local result, success = execute_notevc({ "init" }, notes_dir)
		if success then
			vim.notify("Initialized notevc repository in notes directory", vim.log.levels.INFO)
		else
			vim.notify("Failed to initialize notevc: " .. (result or ""), vim.log.levels.ERROR)
		end
	end
end

-- Commit changes with message
function M.commit(message, filepath)
	local notes_dir = require("notes.core").get_notes_dir()
	
	local args = { "commit" }
	
	-- Add file-specific flag if filepath provided
	if filepath then
		local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
		table.insert(args, "--file")
		table.insert(args, relative_path)
	end
	
	-- Add message
	table.insert(args, string.format('"%s"', message))
	
	local result, success = execute_notevc(args, notes_dir)
	
	if result and result:match("No changes detected") then
		vim.notify("No changes to commit", vim.log.levels.INFO)
		return false
	end

	if success then
		vim.notify("Changes committed successfully", vim.log.levels.INFO)
		return true
	else
		vim.notify("Failed to commit: " .. (result or ""), vim.log.levels.ERROR)
		return false
	end
end

-- Get commit log with options
function M.get_log(opts)
	opts = opts or {}
	local notes_dir = require("notes.core").get_notes_dir()
	
	local args = { "log" }
	
	if opts.max_count then
		table.insert(args, "--max-count")
		table.insert(args, tostring(opts.max_count))
	end
	
	if opts.since then
		table.insert(args, "--since")
		table.insert(args, opts.since)
	end
	
	if opts.file then
		table.insert(args, "--file")
		table.insert(args, opts.file)
	end
	
	if opts.oneline then
		table.insert(args, "--oneline")
	end
	
	local result, success = execute_notevc(args, notes_dir)
	
	if not success or not result or result == "" then
		return {}
	end
	
	-- Parse log output
	return M.parse_log_output(result, opts.oneline)
end

-- Parse notevc log output into structured data
function M.parse_log_output(output, is_oneline)
	local commits = {}
	local lines = vim.split(output, "\n")
	
	local current_commit = nil
	
	for _, line in ipairs(lines) do
		-- Match commit hash line (starts with commit hash)
		local hash = line:match("^commit%s+([a-f0-9]+)")
		if hash then
			if current_commit then
				table.insert(commits, current_commit)
			end
			current_commit = {
				hash = hash,
				author = "",
				date = "",
				message = "",
			}
		elseif current_commit then
			-- Parse other fields
			local author = line:match("^Author:%s+(.+)")
			if author then
				current_commit.author = author
			end
			
			local date = line:match("^Date:%s+(.+)")
			if date then
				current_commit.date = date
			end
			
			-- Message lines are indented
			if line:match("^%s+%S") then
				local msg = line:match("^%s+(.+)")
				if msg and msg ~= "" then
					if current_commit.message ~= "" then
						current_commit.message = current_commit.message .. " " .. msg
					else
						current_commit.message = msg
					end
				end
			end
		end
	end
	
	-- Add last commit
	if current_commit then
		table.insert(commits, current_commit)
	end
	
	return commits
end

-- Get file history
function M.get_file_history(filepath)
	local notes_dir = require("notes.core").get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	return M.get_log({ file = relative_path })
end

-- Get all history
function M.get_all_history()
	return M.get_log({})
end

-- Show commit details
function M.show_commit(commit_hash, opts)
	opts = opts or {}
	local notes_dir = require("notes.core").get_notes_dir()
	
	local args = { "show", commit_hash }
	
	if opts.file then
		table.insert(args, "--file")
		table.insert(args, opts.file)
	end
	
	if opts.content then
		table.insert(args, "--content")
	end
	
	if opts.block then
		table.insert(args, "--block")
		table.insert(args, opts.block)
	end
	
	local result, success = execute_notevc(args, notes_dir)
	
	if success and result then
		return result
	else
		return nil
	end
end

-- Get file content at specific commit
function M.get_file_at_commit(filepath, commit_hash)
	local notes_dir = require("notes.core").get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	return M.show_commit(commit_hash, { file = relative_path, content = true })
end

-- Get diff between commits or working directory
function M.diff(commit1, commit2, opts)
	opts = opts or {}
	local notes_dir = require("notes.core").get_notes_dir()
	
	local args = { "diff" }
	
	if commit1 then
		table.insert(args, commit1)
	end
	
	if commit2 then
		table.insert(args, commit2)
	end
	
	if opts.file then
		table.insert(args, "--file")
		table.insert(args, opts.file)
	end
	
	if opts.block then
		table.insert(args, "--block")
		table.insert(args, opts.block)
	end
	
	local result, success = execute_notevc(args, notes_dir)
	
	if success and result then
		return result
	else
		return nil
	end
end

-- Restore file or block from commit
function M.restore_file(filepath, commit_hash, block_hash)
	local notes_dir = require("notes.core").get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	local args = { "restore", commit_hash, relative_path }
	
	if block_hash then
		table.insert(args, "--block")
		table.insert(args, block_hash)
	end
	
	local result, success = execute_notevc(args, notes_dir)
	
	if success then
		if block_hash then
			vim.notify("Block restored to commit " .. commit_hash:sub(1, 7), vim.log.levels.INFO)
		else
			vim.notify("File restored to commit " .. commit_hash:sub(1, 7), vim.log.levels.INFO)
		end
		return true
	else
		vim.notify("Failed to restore: " .. (result or ""), vim.log.levels.ERROR)
		return false
	end
end

-- Parse blocks from file content
function M.parse_blocks(content)
	local blocks = {}
	local lines = vim.split(content, "\n")
	local current_block = nil
	local block_start = 1
	
	for i, line in ipairs(lines) do
		-- Check if line is a heading
		local heading_level, heading_text = line:match("^(#+)%s+(.+)")
		
		if heading_level then
			-- Save previous block if exists
			if current_block then
				current_block.end_line = i - 1
				table.insert(blocks, current_block)
			end
			
			-- Start new block
			current_block = {
				heading = line,
				level = #heading_level,
				text = heading_text,
				start_line = i,
				end_line = i,
			}
		elseif current_block then
			-- Extend current block
			current_block.end_line = i
		end
	end
	
	-- Add last block
	if current_block then
		table.insert(blocks, current_block)
	end
	
	return blocks
end

-- Get blocks from file at current state
function M.get_file_blocks(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return {}
	end
	
	local content = file:read("*all")
	file:close()
	
	return M.parse_blocks(content)
end

-- Get blocks from file at specific commit
function M.get_commit_blocks(commit_hash, filepath)
	local content = M.get_file_at_commit(filepath, commit_hash)
	if not content then
		return {}
	end
	
	return M.parse_blocks(content)
end

-- Get status of repository
function M.get_status()
	local notes_dir = require("notes.core").get_notes_dir()
	local result, success = execute_notevc({ "status" }, notes_dir)
	
	if success and result then
		return result
	else
		return nil
	end
end

return M
