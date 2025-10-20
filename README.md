# notes.nvim

A Neovim plugin for managing markdown notes with git version control, Telescope fuzzy finding, and an interactive commit browser using NUI.

## Features

- 📝 Create notes with titles and optional tags
- 📁 Organize notes by date (Year/Month/Day/title.md structure)
- 🔍 Browse and search notes with Telescope
- 🏷️ Filter notes by tags
- 🔄 Git version control with automatic backup
- 🗑️ Delete notes with confirmation (git-aware)
- 🌐 Optional remote repository sync
- 📜 Interactive commit browser with NUI menus
- ⏪ Revert notes to previous versions from commit browser
- 🔀 View diffs between commits
- 📂 Browse files in specific commits
- ⚡ Async operations with Plenary

## Requirements

- Neovim >= 0.8.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- git (for version control features)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "darwincereska/notes.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
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
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
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
Open Telescope picker to browse all notes with preview. Press `<CR>` to open a note. Fully vim-navigable with `j`/`k`.

#### `:NoteTags`
Open Telescope picker showing only notes that have tags. Filter and search by tag names with live preview.

#### `:NotesBackup`
Commit all changes to git and push to remote (if configured). Automatically stages all files.

#### `:NotesFetch`
Fetch updates from the remote repository (if configured).

#### `:NoteDelete`
Open Telescope picker to select a note for deletion. Confirmation prompt will appear before deletion. If git is enabled, uses `git rm` to properly remove the file from version control and commits the change.

#### `:NoteHistory`
Interactive commit browser for the currently open note using Telescope + NUI menus:
1. Browse commits with Telescope (vim-navigable with `j`/`k`)
2. Press `Enter` to open an interactive menu with options:
   - **View at this commit** - Opens the note content in a buffer
   - **Revert to this commit** - Restores note to selected version (with confirmation)
   - **Show diff** - Displays diff between selected commit and HEAD

Only works when the current buffer is a note file.

#### `:NotesHistory`
Interactive commit browser for all notes using Telescope + NUI menus:
1. Browse all commits with Telescope (vim-navigable with `j`/`k`)
2. Press `Enter` to open an interactive menu with options:
   - **Show commit details** - View commit message and stats
   - **Browse files in commit** - Opens Telescope to browse modified files
   - **Show diff** - View full commit diff

When browsing files in a commit:
- Press `Enter` to open menu with:
  - **View file at this commit** - Opens file content in buffer
  - **Revert file to this commit** - Restores file (with confirmation)

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
- Full commit history accessible via `:NoteHistory` and `:NotesHistory`
- Interactive browsing with previews and diffs
- Easy reversion to previous versions

You can manually trigger backups with `:NotesBackup`.

## Interactive Commit Browser

The commit browser provides a powerful interface using Telescope and NUI for exploring your notes history:

### Single Note History (`:NoteHistory`)
1. **Telescope View**: Browse commits with live preview
   - Navigate with `j`/`k` or arrow keys
   - Preview shows note content at selected commit
   - Search/filter commits in real-time

2. **NUI Action Menu**: Press `Enter` to open interactive menu
   ```
   ┌─ Actions ─────────────────────┐
   │ View at this commit            │
   │ Revert to this commit          │
   │ Show diff                      │
   │ ──────────────────────────     │
   │ Cancel                         │
   └────────────────────────────────┘
   ```
   - Navigate with `j`/`k`
   - Select with `Enter`
   - Cancel with `Esc` or `q`

### All Notes History (`:NotesHistory`)
1. **Telescope View**: Browse all commits
   - Shows commit hash, date, author, and message
   - Live preview of commit stats and changes
   - Async loading with Plenary

2. **NUI Action Menu**: Press `Enter` for options
   ```
   ┌─ Actions ─────────────────────┐
   │ Show commit details            │
   │ Browse files in commit         │
   │ Show diff                      │
   │ ──────────────────────────     │
   │ Cancel                         │
   └────────────────────────────────┘
   ```

3. **File Browser**: If you select "Browse files in commit"
   - Opens another Telescope picker with files
   - Preview shows file content at that commit
   - Press `Enter` for file-specific actions

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
