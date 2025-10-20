local M = {}
local core = require("notes.core")
local git = require("notes.git")

function M.find_notes()
	local notes_dir = core.get_notes_dir()
	
	local find_cmd = string.format('find "%s" -name "*.md" -type f | sort -r', notes_dir)
	local handle = io.popen(find_cmd)
	if not handle then
		vim.notify("Failed to list notes", vim.log.levels.ERROR)
		return
	end
	
	local notes = {}
	for file in handle:lines() do
		local frontmatter = core.parse_frontmatter(file)
		local title = frontmatter and frontmatter.title or "Untitled"
		local date = frontmatter and frontmatter.date or ""
		local relative = file:gsub("^" .. notes_dir .. "/", "")
		
		table.insert(notes, {
			display = string.format("%-50s  %s  %s", title, date, relative),
			filepath = file,
			title = title,
		})
	end
	handle:close()
	
	if #notes == 0 then
		vim.notify("No notes found", vim.log.levels.INFO)
		return
	end
	
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_set_current_buf(buf)
	
	local lines = {}
	for _, note in ipairs(notes) do
		table.insert(lines, note.display)
	end
	
	local preview_script = vim.fn.tempname()
	local script = io.open(preview_script, "w")
	if script then
		script:write(string.format([[
#!/bin/bash
line="$1"
path=$(echo "$line" | awk '{print $NF}')
full_path="%s/$path"
if [ -f "$full_path" ]; then
	bat --style=numbers --color=always "$full_path" 2>/dev/null || cat "$full_path"
fi
]], notes_dir))
		script:close()
		vim.fn.system("chmod +x " .. preview_script)
	end
	
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, "w")
	if file then
		for _, line in ipairs(lines) do
			file:write(line .. "\n")
		end
		file:close()
	end
	
	local cmd = string.format(
		"fzf --ansi --prompt='Notes> ' --preview='%s {}' --preview-window=right:50%%:wrap --height=100%% --layout=reverse --border < %s",
		preview_script,
		temp_file
	)
	
	vim.fn.termopen(cmd, {
		on_exit = function(_, exit_code)
			vim.fn.delete(temp_file)
			vim.fn.delete(preview_script)
			
			if exit_code == 0 then
				vim.schedule(function()
					local selected = vim.fn.getreg('"')
					if selected and selected ~= "" then
						for _, note in ipairs(notes) do
							if note.display == vim.trim(selected) then
								vim.cmd("edit " .. note.filepath)
								return
							end
						end
					end
				end)
			else
				vim.schedule(function()
					vim.cmd("bdelete!")
				end)
			end
		end,
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				local output = table.concat(data, "")
				if output and output ~= "" then
					vim.fn.setreg('"', vim.trim(output))
				end
			end
		end,
	})
end

function M.find_notes_by_tag()
	local notes_dir = core.get_notes_dir()
	local notes = core.get_notes_with_tags()
	
	if #notes == 0 then
		vim.notify("No notes with tags found", vim.log.levels.INFO)
		return
	end
	
	local items = {}
	for _, file in ipairs(notes) do
		local frontmatter = core.parse_frontmatter(file)
		local title = frontmatter and frontmatter.title or "Untitled"
		local tags = frontmatter and frontmatter.tags or ""
		local date = frontmatter and frontmatter.date or ""
		local relative = file:gsub("^" .. notes_dir .. "/", "")
		
		table.insert(items, {
			display = string.format("%-40s  %-30s  %s  %s", title, tags, date, relative),
			filepath = file,
		})
	end
	
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_set_current_buf(buf)
	
	local lines = {}
	for _, item in ipairs(items) do
		table.insert(lines, item.display)
	end
	
	local preview_script = vim.fn.tempname()
	local script = io.open(preview_script, "w")
	if script then
		script:write(string.format([[
#!/bin/bash
line="$1"
path=$(echo "$line" | awk '{print $NF}')
full_path="%s/$path"
if [ -f "$full_path" ]; then
	bat --style=numbers --color=always "$full_path" 2>/dev/null || cat "$full_path"
fi
]], notes_dir))
		script:close()
		vim.fn.system("chmod +x " .. preview_script)
	end
	
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, "w")
	if file then
		for _, line in ipairs(lines) do
			file:write(line .. "\n")
		end
		file:close()
	end
	
	local cmd = string.format(
		"fzf --ansi --prompt='Tags> ' --preview='%s {}' --preview-window=right:50%%:wrap --height=100%% --layout=reverse --border < %s",
		preview_script,
		temp_file
	)
	
	vim.fn.termopen(cmd, {
		on_exit = function(_, exit_code)
			vim.fn.delete(temp_file)
			vim.fn.delete(preview_script)
			
			if exit_code == 0 then
				vim.schedule(function()
					local selected = vim.fn.getreg('"')
					if selected and selected ~= "" then
						for _, item in ipairs(items) do
							if item.display == vim.trim(selected) then
								vim.cmd("edit " .. item.filepath)
								return
							end
						end
					end
				end)
			else
				vim.schedule(function()
					vim.cmd("bdelete!")
				end)
			end
		end,
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				local output = table.concat(data, "")
				if output and output ~= "" then
					vim.fn.setreg('"', vim.trim(output))
				end
			end
		end,
	})
end

function M.delete_note()
	local notes_dir = core.get_notes_dir()
	
	local find_cmd = string.format('find "%s" -name "*.md" -type f | sort -r', notes_dir)
	local handle = io.popen(find_cmd)
	if not handle then
		vim.notify("Failed to list notes", vim.log.levels.ERROR)
		return
	end
	
	local notes = {}
	for file in handle:lines() do
		local frontmatter = core.parse_frontmatter(file)
		local title = frontmatter and frontmatter.title or "Untitled"
		local date = frontmatter and frontmatter.date or ""
		local relative = file:gsub("^" .. notes_dir .. "/", "")
		
		table.insert(notes, {
			display = string.format("%-50s  %s  %s", title, date, relative),
			filepath = file,
		})
	end
	handle:close()
	
	if #notes == 0 then
		vim.notify("No notes found", vim.log.levels.INFO)
		return
	end
	
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_set_current_buf(buf)
	
	local lines = {}
	for _, note in ipairs(notes) do
		table.insert(lines, note.display)
	end
	
	local preview_script = vim.fn.tempname()
	local script = io.open(preview_script, "w")
	if script then
		script:write(string.format([[
#!/bin/bash
line="$1"
path=$(echo "$line" | awk '{print $NF}')
full_path="%s/$path"
if [ -f "$full_path" ]; then
	bat --style=numbers --color=always "$full_path" 2>/dev/null || cat "$full_path"
fi
]], notes_dir))
		script:close()
		vim.fn.system("chmod +x " .. preview_script)
	end
	
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, "w")
	if file then
		for _, line in ipairs(lines) do
			file:write(line .. "\n")
		end
		file:close()
	end
	
	local cmd = string.format(
		"fzf --ansi --prompt='Delete> ' --preview='%s {}' --preview-window=right:50%%:wrap --height=100%% --layout=reverse --border < %s",
		preview_script,
		temp_file
	)
	
	vim.fn.termopen(cmd, {
		on_exit = function(_, exit_code)
			vim.fn.delete(temp_file)
			vim.fn.delete(preview_script)
			
			if exit_code == 0 then
				vim.schedule(function()
					local selected = vim.fn.getreg('"')
					if selected and selected ~= "" then
						for _, note in ipairs(notes) do
							if note.display == vim.trim(selected) then
								vim.ui.select({ "Yes", "No" }, {
									prompt = "Delete note: " .. note.filepath .. "?",
								}, function(choice)
									if choice == "Yes" then
										local relative_path = note.filepath:gsub("^" .. notes_dir .. "/", "")
										local git_enabled = require("notes").config.git_enabled
										
										if git_enabled then
											local delete_cmd = string.format('git -C "%s" rm -f "%s" 2>&1', notes_dir, relative_path)
											local result = vim.fn.system(delete_cmd)
											
											if vim.v.shell_error == 0 then
												git.commit_and_push()
												vim.notify("Note deleted: " .. note.filepath, vim.log.levels.INFO)
											else
												vim.notify("Failed to delete note: " .. result, vim.log.levels.ERROR)
											end
										else
											if vim.fn.delete(note.filepath) == 0 then
												vim.notify("Note deleted: " .. note.filepath, vim.log.levels.INFO)
											else
												vim.notify("Failed to delete note", vim.log.levels.ERROR)
											end
										end
									end
									vim.cmd("bdelete!")
								end)
								return
							end
						end
					end
				end)
			else
				vim.schedule(function()
					vim.cmd("bdelete!")
				end)
			end
		end,
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				local output = table.concat(data, "")
				if output and output ~= "" then
					vim.fn.setreg('"', vim.trim(output))
				end
			end
		end,
	})
end

return M
