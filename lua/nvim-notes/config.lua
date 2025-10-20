local M = {}

M.defaults = {
    notes_dir = vim.fn.expand("~/.notes"),
    git_remote = nil, -- Optional remote URL
    date_format = "%Y/%m/%d",
    file_extension = ".md",
    template = [[# {title}

Date: {date}
Tags: 

---

]]
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

    -- Create notes directory if it doesn't exist
    vim.fn.mkdir(M.options.notes_dir, "p")

    -- Always initialize git repo
    require('notes.git').init_repo()
end

return M
