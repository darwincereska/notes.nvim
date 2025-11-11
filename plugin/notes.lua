if vim.g.loaded_notes then
    return
end
vim.g.loaded_notes = true

require("notes.commands").setup()
