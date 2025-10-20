local M = {}

M.defaults = {
    notes_dir = vim.fn.expand("~/.notes"),
    git_remote = nil,
    date_format = "%Y/%m/%d",
    file_extension = ".md",
    use_telescope = true, -- Prefer telescope when available
    template = [[# {title}

Date: {date}
Tags: {tags}

---

]]
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

    -- Ensure the notes directory path is fully expanded
    M.options.notes_dir = vim.fn.expand(M.options.notes_dir)

    -- Create notes directory if it doesn't exist
    vim.fn.mkdir(M.options.notes_dir, "p")

    -- Always initialize git repo
    require('notes.git').init_repo()
end

return M
