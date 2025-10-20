local M = {}

M.config = {
	notes_dir = vim.fn.expand("~/.notes"),
	git_enabled = true,
	git_remote = nil,
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local notes_dir = M.config.notes_dir
	if vim.fn.isdirectory(notes_dir) == 0 then
		vim.fn.mkdir(notes_dir, "p")
	end

	if M.config.git_enabled then
		require("notes.git").init_repo()
	end
end

return M
