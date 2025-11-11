local M = {}

M.config = {
    notes_dir = vim.fn.expand("~/.notes"),
    notevc_enabled = true,
    notevc_path = "notevc", -- Path to notevc binary
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    local notes_dir = M.config.notes_dir
    if vim.fn.isdirectory(notes_dir) == 0 then
        vim.fn.mkdir(notes_dir, "p")
    end

    if M.config.notevc_enabled then
        require("notes.notevc").init_repo()
    end
end

return M
