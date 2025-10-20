local M = {}

function M.get_notes_dir()
	return require("notes").config.notes_dir
end

function M.sanitize_filename(title)
	local sanitized = title:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
	return sanitized
end

function M.get_note_path(date, title)
	local notes_dir = M.get_notes_dir()
	local year = os.date("%Y", date)
	local month = os.date("%m", date)
	local day = os.date("%d", date)

	local dir = string.format("%s/%s/%s/%s", notes_dir, year, month, day)
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	return dir
end

function M.create_note(title, tags)
	local timestamp = os.time()
	local dir = M.get_note_path(timestamp, title)
	local sanitized_title = M.sanitize_filename(title or "untitled")
	local filename = string.format("%s.md", sanitized_title)
	local filepath = string.format("%s/%s", dir, filename)
	
	if vim.fn.filereadable(filepath) == 1 then
		local counter = 1
		while vim.fn.filereadable(filepath) == 1 do
			filename = string.format("%s-%d.md", sanitized_title, counter)
			filepath = string.format("%s/%s", dir, filename)
			counter = counter + 1
		end
	end

	local lines = {}
	table.insert(lines, "---")
	table.insert(lines, string.format('title: "%s"', title or "Untitled"))
	if tags and #tags > 0 then
		table.insert(lines, string.format("tags: [%s]", table.concat(tags, ", ")))
	end
	table.insert(lines, string.format("date: %s", os.date("%Y-%m-%d %H:%M:%S", timestamp)))
	table.insert(lines, "---")
	table.insert(lines, "")
	table.insert(lines, "")

	vim.fn.writefile(lines, filepath)
	return filepath
end

function M.get_all_notes()
	local notes_dir = M.get_notes_dir()
	local notes = {}

	local find_cmd = string.format('find "%s" -name "*.md" -type f', notes_dir)
	local handle = io.popen(find_cmd)
	if handle then
		for file in handle:lines() do
			table.insert(notes, file)
		end
		handle:close()
	end

	return notes
end

function M.parse_frontmatter(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	local frontmatter = {}
	local in_frontmatter = false
	local fm_lines = {}

	for line in content:gmatch("[^\r\n]+") do
		if line == "---" then
			if not in_frontmatter then
				in_frontmatter = true
			else
				break
			end
		elseif in_frontmatter then
			table.insert(fm_lines, line)
		end
	end

	for _, line in ipairs(fm_lines) do
		local key, value = line:match("^(%w+):%s*(.+)$")
		if key and value then
			value = value:gsub('^"', ""):gsub('"$', "")
			frontmatter[key] = value
		end
	end

	return frontmatter
end

function M.get_notes_with_tags()
	local all_notes = M.get_all_notes()
	local notes_with_tags = {}

	for _, note in ipairs(all_notes) do
		local frontmatter = M.parse_frontmatter(note)
		if frontmatter and frontmatter.tags then
			table.insert(notes_with_tags, note)
		end
	end

	return notes_with_tags
end

function M.delete_note(filepath)
	if vim.fn.filereadable(filepath) == 1 then
		vim.fn.delete(filepath)
		return true
	end
	return false
end

return M
