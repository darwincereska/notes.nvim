local M = {}
local git = require("notes.git")
local core = require("notes.core")

function M.file_history(filepath)
	local notes_dir = core.get_notes_dir()
	local relative_path = filepath:gsub("^" .. notes_dir .. "/", "")
	
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_set_current_buf(buf)
	
	local preview_script = vim.fn.tempname()
	local script = io.open(preview_script, "w")
	if script then
		script:write(string.format([[
#!/bin/bash
line="$1"
hash=$(echo "$line" | awk '{print $1}')
cd "%s"
git show "$hash:%s" 2>/dev/null | bat --style=numbers --color=always -l markdown 2>/dev/null || git show "$hash:%s"
]], notes_dir, relative_path, relative_path))
		script:close()
		vim.fn.system("chmod +x " .. preview_script)
	end
	
	local log_cmd = string.format(
		'git -C "%s" log --pretty=format:"%%h  %%ar  %%an  %%s" --follow -- "%s" 2>/dev/null',
		notes_dir,
		relative_path
	)
	
	local fzf_cmd = string.format(
		"%s | fzf --ansi --prompt='History> ' --preview='%s {}' --preview-window=right:60%%:wrap --height=100%% --layout=reverse --border --header='[Enter]=View [Ctrl-r]=Revert [Ctrl-d]=Diff' --expect=ctrl-r,ctrl-d",
		log_cmd,
		preview_script
	)
	
	vim.fn.termopen(fzf_cmd, {
		on_exit = function(_, exit_code)
			vim.fn.delete(preview_script)
			
			if exit_code == 0 then
				vim.schedule(function()
					local output = vim.fn.getreg('"')
					if output and output ~= "" then
						local lines = vim.split(output, "\n", { trimempty = true })
						local key = lines[1] or ""
						local selected = lines[2] or ""
						
						if selected ~= "" then
							local hash = vim.split(selected, "%s+")[1]
							
							if key == "ctrl-r" then
								vim.ui.select({ "Yes", "No" }, {
									prompt = "Revert to commit " .. hash .. "?",
								}, function(choice)
									if choice == "Yes" then
										git.revert_file(filepath, hash)
										vim.cmd("edit! " .. filepath)
									end
									vim.cmd("bdelete!")
								end)
							elseif key == "ctrl-d" then
								local diff_buf = vim.api.nvim_create_buf(false, true)
								vim.api.nvim_buf_set_option(diff_buf, "buftype", "nofile")
								vim.api.nvim_buf_set_option(diff_buf, "bufhidden", "wipe")
								vim.api.nvim_buf_set_option(diff_buf, "filetype", "diff")
								
								local diff_cmd = string.format('git -C "%s" diff "%s" "%s" -- "%s"', notes_dir, hash, "HEAD", relative_path)
								local handle = io.popen(diff_cmd)
								if handle then
									local diff_content = handle:read("*all")
									handle:close()
									
									local diff_lines = vim.split(diff_content, "\n")
									vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, diff_lines)
								end
								
								vim.cmd("bdelete!")
								vim.api.nvim_set_current_buf(diff_buf)
								vim.api.nvim_buf_set_name(diff_buf, string.format("[Diff] %s vs %s", hash, "HEAD"))
							else
								local view_buf = vim.api.nvim_create_buf(false, true)
								vim.api.nvim_buf_set_option(view_buf, "buftype", "nofile")
								vim.api.nvim_buf_set_option(view_buf, "bufhidden", "wipe")
								vim.api.nvim_buf_set_option(view_buf, "filetype", "markdown")
								
								local show_cmd = string.format('git -C "%s" show "%s:%s"', notes_dir, hash, relative_path)
								local handle = io.popen(show_cmd)
								if handle then
									local content = handle:read("*all")
									handle:close()
									
									local content_lines = vim.split(content, "\n")
									vim.api.nvim_buf_set_lines(view_buf, 0, -1, false, content_lines)
								end
								
								vim.cmd("bdelete!")
								vim.api.nvim_set_current_buf(view_buf)
								vim.api.nvim_buf_set_name(view_buf, string.format("[History] %s @ %s", relative_path, hash))
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
					vim.fn.setreg('"', output)
				end
			end
		end,
	})
end

function M.all_history()
	local notes_dir = core.get_notes_dir()
	
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_set_current_buf(buf)
	
	local preview_script = vim.fn.tempname()
	local script = io.open(preview_script, "w")
	if script then
		script:write(string.format([[
#!/bin/bash
line="$1"
hash=$(echo "$line" | awk '{print $1}')
cd "%s"
echo "Commit: $hash"
echo ""
git show --stat --pretty=format:"Author: %%an <%%ae>%%nDate: %%ar%%n%%nMessage:%%n  %%s%%n%%n%%b%%n" "$hash" --color=always 2>/dev/null | bat --style=plain --color=always 2>/dev/null || git show --stat "$hash"
]], notes_dir))
		script:close()
		vim.fn.system("chmod +x " .. preview_script)
	end
	
	local log_cmd = string.format(
		'git -C "%s" log --all --pretty=format:"%%h  %%ar  %%an  %%s" --color=always 2>/dev/null',
		notes_dir
	)
	
	local fzf_cmd = string.format(
		"%s | fzf --ansi --prompt='Commits> ' --preview='%s {}' --preview-window=right:60%%:wrap --height=100%% --layout=reverse --border --header='[Enter]=Show [Ctrl-f]=Files [Ctrl-d]=Diff' --expect=ctrl-f,ctrl-d",
		log_cmd,
		preview_script
	)
	
	vim.fn.termopen(fzf_cmd, {
		on_exit = function(_, exit_code)
			vim.fn.delete(preview_script)
			
			if exit_code == 0 then
				vim.schedule(function()
					local output = vim.fn.getreg('"')
					if output and output ~= "" then
						local lines = vim.split(output, "\n", { trimempty = true })
						local key = lines[1] or ""
						local selected = lines[2] or ""
						
						if selected ~= "" then
							local hash = vim.split(selected, "%s+")[1]
							
							if key == "ctrl-f" then
								M.browse_commit_files(hash)
							elseif key == "ctrl-d" then
								local diff_buf = vim.api.nvim_create_buf(false, true)
								vim.api.nvim_buf_set_option(diff_buf, "buftype", "nofile")
								vim.api.nvim_buf_set_option(diff_buf, "bufhidden", "wipe")
								vim.api.nvim_buf_set_option(diff_buf, "filetype", "diff")
								
								local diff_cmd = string.format('git -C "%s" show --color=never "%s"', notes_dir, hash)
								local handle = io.popen(diff_cmd)
								if handle then
									local diff_content = handle:read("*all")
									handle:close()
									
									local diff_lines = vim.split(diff_content, "\n")
									vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, diff_lines)
								end
								
								vim.cmd("bdelete!")
								vim.api.nvim_set_current_buf(diff_buf)
								vim.api.nvim_buf_set_name(diff_buf, string.format("[Commit] %s", hash))
							else
								local show_buf = vim.api.nvim_create_buf(false, true)
								vim.api.nvim_buf_set_option(show_buf, "buftype", "nofile")
								vim.api.nvim_buf_set_option(show_buf, "bufhidden", "wipe")
								
								local show_cmd = string.format('git -C "%s" show --stat "%s"', notes_dir, hash)
								local handle = io.popen(show_cmd)
								if handle then
									local content = handle:read("*all")
									handle:close()
									
									local content_lines = vim.split(content, "\n")
									vim.api.nvim_buf_set_lines(show_buf, 0, -1, false, content_lines)
								end
								
								vim.cmd("bdelete!")
								vim.api.nvim_set_current_buf(show_buf)
								vim.api.nvim_buf_set_name(show_buf, string.format("[Commit] %s", hash))
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
					vim.fn.setreg('"', output)
				end
			end
		end,
	})
end

function M.browse_commit_files(commit_hash)
	local notes_dir = core.get_notes_dir()
	
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_set_current_buf(buf)
	
	local preview_script = vim.fn.tempname()
	local script = io.open(preview_script, "w")
	if script then
		script:write(string.format([[
#!/bin/bash
file="$1"
cd "%s"
git show "%s:$file" 2>/dev/null | bat --style=numbers --color=always -l markdown 2>/dev/null || git show "%s:$file"
]], notes_dir, commit_hash, commit_hash))
		script:close()
		vim.fn.system("chmod +x " .. preview_script)
	end
	
	local files_cmd = string.format(
		'git -C "%s" diff-tree --no-commit-id --name-only -r "%s" 2>/dev/null | grep "\\.md$"',
		notes_dir,
		commit_hash
	)
	
	local fzf_cmd = string.format(
		"%s | fzf --ansi --prompt='Files in %s> ' --preview='%s {}' --preview-window=right:60%%:wrap --height=100%% --layout=reverse --border --header='[Enter]=View [Ctrl-r]=Revert' --expect=ctrl-r",
		files_cmd,
		commit_hash:sub(1, 7),
		preview_script
	)
	
	vim.fn.termopen(fzf_cmd, {
		on_exit = function(_, exit_code)
			vim.fn.delete(preview_script)
			
			if exit_code == 0 then
				vim.schedule(function()
					local output = vim.fn.getreg('"')
					if output and output ~= "" then
						local lines = vim.split(output, "\n", { trimempty = true })
						local key = lines[1] or ""
						local selected = lines[2] or ""
						
						if selected ~= "" then
							local filepath = notes_dir .. "/" .. selected
							
							if key == "ctrl-r" then
								vim.ui.select({ "Yes", "No" }, {
									prompt = "Revert " .. selected .. " to commit " .. commit_hash:sub(1, 7) .. "?",
								}, function(choice)
									if choice == "Yes" then
										git.revert_file(filepath, commit_hash)
										vim.notify("File reverted to " .. commit_hash:sub(1, 7), vim.log.levels.INFO)
									end
									vim.cmd("bdelete!")
								end)
							else
								local view_buf = vim.api.nvim_create_buf(false, true)
								vim.api.nvim_buf_set_option(view_buf, "buftype", "nofile")
								vim.api.nvim_buf_set_option(view_buf, "bufhidden", "wipe")
								vim.api.nvim_buf_set_option(view_buf, "filetype", "markdown")
								
								local show_cmd = string.format('git -C "%s" show "%s:%s"', notes_dir, commit_hash, selected)
								local handle = io.popen(show_cmd)
								if handle then
									local content = handle:read("*all")
									handle:close()
									
									local content_lines = vim.split(content, "\n")
									vim.api.nvim_buf_set_lines(view_buf, 0, -1, false, content_lines)
								end
								
								vim.cmd("bdelete!")
								vim.api.nvim_set_current_buf(view_buf)
								vim.api.nvim_buf_set_name(view_buf, string.format("[%s] %s", commit_hash:sub(1, 7), selected))
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
					vim.fn.setreg('"', output)
				end
			end
		end,
	})
end

return M
