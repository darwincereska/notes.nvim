local M = {}

function M.fzf(source, options, callback)
	options = options or {}
	local prompt = options.prompt or "> "
	local preview = options.preview or nil
	local header = options.header or nil
	
	local fzf_opts = {
		"--ansi",
		"--prompt=" .. prompt,
		"--height=40%",
		"--layout=reverse",
		"--border",
		"--info=inline",
	}
	
	if preview then
		table.insert(fzf_opts, "--preview=" .. preview)
		table.insert(fzf_opts, "--preview-window=right:50%:wrap")
	end
	
	if header then
		table.insert(fzf_opts, "--header=" .. header)
	end
	
	if options.multi then
		table.insert(fzf_opts, "--multi")
	end
	
	if options.expect then
		table.insert(fzf_opts, "--expect=" .. options.expect)
	end
	
	local fzf_cmd = "fzf " .. table.concat(fzf_opts, " ")
	
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, "w")
	if not file then
		vim.notify("Failed to create temp file", vim.log.levels.ERROR)
		return
	end
	
	if type(source) == "table" then
		for _, line in ipairs(source) do
			file:write(line .. "\n")
		end
	elseif type(source) == "string" then
		file:write(source)
	end
	file:close()
	
	vim.fn.termopen(string.format("cat %s | %s", temp_file, fzf_cmd), {
		on_exit = function(_, exit_code)
			vim.fn.delete(temp_file)
			if exit_code ~= 0 then
				return
			end
			
			vim.schedule(function()
				local result = vim.fn.getreg('"')
				if result and result ~= "" then
					callback(result)
				end
			end)
		end,
		on_stdout = function(_, data)
			if data then
				local output = table.concat(data, "\n")
				if output ~= "" then
					vim.fn.setreg('"', output)
				end
			end
		end,
	})
end

function M.select_from_list(items, options, callback)
	local lines = {}
	for _, item in ipairs(items) do
		if type(item) == "string" then
			table.insert(lines, item)
		elseif item.display then
			table.insert(lines, item.display)
		end
	end
	
	vim.cmd("enew")
	
	M.fzf(lines, options, function(selected)
		if not selected or selected == "" then
			return
		end
		
		local selected_lines = vim.split(selected, "\n", { trimempty = true })
		if #selected_lines == 0 then
			return
		end
		
		local result = selected_lines[1]
		
		for i, item in ipairs(items) do
			local line = lines[i]
			if line == result then
				callback(item, i)
				return
			end
		end
	end)
end

return M
