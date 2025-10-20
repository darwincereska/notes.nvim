# notes.nvim

A Neovim plugin for managing markdown notes with git version control and Telescope integration.

## Features

- 📝 Create notes with titles and optional tags
- 📁 Organize notes by date (Year/Month/Day/title.md structure)
- 🔍 Browse and search notes with Telescope
- 🏷️ Filter notes by tags
- 🔄 Git version control with automatic backup
- 🗑️ Delete notes with confirmation (git-aware)
- 🌐 Optional remote repository sync
- 📜 View commit history for individual notes or all notes
- ⏪ Revert notes to previous versions

## Requirements

- Neovim >= 0.8.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- git (for version control features)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "darwincereska/notes.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("notes").setup({
      notes_dir = vim.fn.expand("~/.notes"),
      git_enabled = true,
      git_remote = "git@github.com:username/notes.git", -- optional
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "darwincereska/notes.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("notes").setup({
      notes_dir = vim.fn.expand("~/.notes"),
      git_enabled = true,
      git_remote = "git@github.com:username/notes.git", -- optional
    })
  end,
}
```

## Configuration

Default configuration:

```lua
{
  notes_dir = "~/.notes",        -- Directory to store notes
  git_enabled = true,             -- Enable git integration
  git_remote = nil,               -- Optional remote repository URL
}
```

## Usage

### Commands

#### `:Note`
Create a new note. You'll be prompted for:
1. Note title
2. Tags (optional, comma-separated)

The note will be created in `~/.notes/YYYY/MM/DD/title.md` format with frontmatter:

```markdown
---
title: "My Note"
tags: ["tag1", "tag2"]
date: 2025-10-20 14:30:00
---

```

#### `:Notes`
Open Telescope picker to browse all notes with preview. Press `<CR>` to open a note.

#### `:NoteTags`
Open Telescope picker showing only notes that have tags. Filter and search by tag names.

#### `:NotesBackup`
Commit all changes to git and push to remote (if configured). Automatically stages all files.

#### `:NotesFetch`
Fetch updates from the remote repository (if configured).

#### `:NoteDelete`
Open Telescope picker to select a note for deletion. Confirmation prompt will appear before deletion. If git is enabled, uses `git rm` to properly remove the file from version control.

#### `:NoteHistory`
View the git commit history for the currently open note. Select a commit to:
- **View**: See the note content at that commit
- **Revert to this version**: Restore the note to that version (creates a new commit)

Only works when the current buffer is a note file.

#### `:NotesHistory`
View the git commit history for all notes. Shows commits with the files that were modified.

## File Structure

Notes are organized by date:

```
~/.notes/
├── .git/
├── 2025/
│   ├── 10/
│   │   ├── 20/
│   │   │   ├── meeting-notes.md
│   │   │   └── project-ideas.md
│   │   └── 21/
│   │       └── daily-log.md
│   └── 11/
│       └── 01/
│           └── todo-list.md
```

## Note Format

Each note contains YAML frontmatter:

```markdown
---
title: "Meeting Notes"
tags: ["work", "meetings", "project-x"]
date: 2025-10-20 14:30:00
---

Your note content here...
```

## Git Integration

When `git_enabled` is `true`:
- A git repository is automatically initialized in `notes_dir`
- Notes are automatically committed after creation and deletion
- If `git_remote` is set, commits are automatically pushed

You can manually trigger backups with `:NotesBackup`.

## Examples

### Basic setup without remote

```lua
require("notes").setup({
  notes_dir = vim.fn.expand("~/Documents/notes"),
  git_enabled = true,
})
```

### Setup with GitHub remote

```lua
require("notes").setup({
  notes_dir = vim.fn.expand("~/.notes"),
  git_enabled = true,
  git_remote = "git@github.com:username/my-notes.git",
})
```

### Disable git

```lua
require("notes").setup({
  notes_dir = vim.fn.expand("~/.notes"),
  git_enabled = false,
})
```

## Keybindings

You can add custom keybindings in your config:

```lua
vim.keymap.set("n", "<leader>nn", ":Note<CR>", { desc = "New note" })
vim.keymap.set("n", "<leader>nl", ":Notes<CR>", { desc = "List notes" })
vim.keymap.set("n", "<leader>nt", ":NoteTags<CR>", { desc = "Notes by tag" })
vim.keymap.set("n", "<leader>nb", ":NotesBackup<CR>", { desc = "Backup notes" })
vim.keymap.set("n", "<leader>nd", ":NoteDelete<CR>", { desc = "Delete note" })
vim.keymap.set("n", "<leader>nh", ":NoteHistory<CR>", { desc = "Note history" })
vim.keymap.set("n", "<leader>nH", ":NotesHistory<CR>", { desc = "All notes history" })
```

## License

MIT
