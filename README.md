# notes.nvim

A Neovim plugin for managing markdown notes with **block-level version control** using NoteVC, Telescope fuzzy finding, and an interactive commit browser using NUI.

## Features

- 📝 Create notes with titles and optional tags
- 📁 Organize notes by date (Year/Month/Day/title.md structure)
- 🔍 Browse and search notes with Telescope
- 🏷️ Filter notes by tags
- 🧱 **Block-level version control** - Track changes at heading granularity
- 🔄 Automatic version control with NoteVC
- 🗑️ Delete notes with confirmation (version-aware)
- 📜 Interactive commit browser with NUI menus
- ⏪ Revert notes to previous versions from commit browser
- 🎯 **Revert specific blocks** - Restore individual sections without affecting entire file
- 🔀 View diffs between commits and blocks
- 📂 Browse blocks in files and commits
- 🔬 **Block history tracking** - See which sections changed over time
- ⚡ Async operations with Plenary

## Requirements

- Neovim >= 0.8.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- [notevc](https://github.com/darwincereska/notevc) (for block-level version control)

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
      notevc_enabled = true,
      notevc_path = "notevc", -- Path to notevc binary (optional, defaults to "notevc")
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
      notevc_enabled = true,
      notevc_path = "notevc", -- Path to notevc binary (optional, defaults to "notevc")
    })
  end,
}
```

## Configuration

Default configuration:

```lua
{
  notes_dir = "~/.notes",        -- Directory to store notes
  notevc_enabled = true,          -- Enable notevc block-level version control
  notevc_path = "notevc",         -- Path to notevc binary (finds in PATH by default)
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
Commit all changes to notevc repository. Automatically includes all changed notes with block-level tracking.

#### `:NoteDelete`
Open Telescope picker to select a note for deletion. Confirmation prompt will appear before deletion. If notevc is enabled, commits the deletion to version history.

#### `:NoteHistory`
Interactive commit browser for the currently open note using Telescope + NUI menus:
1. Browse commits with Telescope (vim-navigable with `j`/`k`)
2. Press `Enter` to open an interactive menu with options:
   - **View at this commit** - Opens the note content in a buffer
   - **View blocks changed** - Shows which heading sections changed in this commit
   - **Revert to this commit** - Restores note to selected version (with confirmation)
   - **Revert specific block** - Restore just one heading section from this commit
   - **Show diff** - Displays diff between selected commit and current state

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

#### `:NoteBlocks`
Browse all blocks (heading sections) in the current note:
- Shows hierarchical view of all headings in the note
- Preview shows the content of each section
- Select a block to:
  - **View block history** - See all commits that modified this section
  - **Jump to block** - Navigate to that heading in the file

Only works when the current buffer is a note file.

#### `:NoteStatus`
Shows the current status of the notevc repository:
- Lists which notes have been modified
- Shows which blocks within files have changed
- Displays files ready to commit

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

## NoteVC Integration

When `notevc_enabled` is `true`:
- A notevc repository is automatically initialized in `notes_dir/.notevc`
- Notes are automatically version-controlled at the block level after creation and deletion
- Each heading section is tracked independently
- Full commit history accessible via `:NoteHistory` and `:NotesHistory`
- Interactive browsing with previews and block-level diffs
- Easy reversion to previous versions (entire file or specific blocks)
- Efficient storage with automatic compression

You can manually trigger backups with `:NotesBackup`.

### Block-Level Version Control

NoteVC splits markdown files into blocks based on headings. This means:
- See exactly which sections changed in each commit
- Restore individual heading sections without affecting the rest of the file
- Track the history of specific sections over time
- More efficient storage - only changed blocks are stored
- Perfect for large, evolving notes and documentation

## Interactive Commit Browser

The commit browser provides a powerful interface using Telescope and NUI for exploring your notes history with block-level granularity:

### Single Note History (`:NoteHistory`)
1. **Telescope View**: Browse commits with live preview
   - Navigate with `j`/`k` or arrow keys
   - Preview shows note content at selected commit
   - Search/filter commits in real-time

2. **NUI Action Menu**: Press `Enter` to open interactive menu
   ```
   ┌─ Actions ─────────────────────────┐
   │ View at this commit                │
   │ View blocks changed                │  ← Block-level view
   │ Revert to this commit              │
   │ Revert specific block              │  ← Surgical restoration
   │ Show diff                          │
   │ ────────────────────────────────── │
   │ Cancel                             │
   └────────────────────────────────────┘
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

### Basic setup

```lua
require("notes").setup({
  notes_dir = vim.fn.expand("~/Documents/notes"),
  notevc_enabled = true,
})
```

### Custom notevc binary path

```lua
require("notes").setup({
  notes_dir = vim.fn.expand("~/.notes"),
  notevc_enabled = true,
  notevc_path = "/usr/local/bin/notevc", -- Custom path to notevc binary
})
```

### Disable version control

```lua
require("notes").setup({
  notes_dir = vim.fn.expand("~/.notes"),
  notevc_enabled = false,
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
vim.keymap.set("n", "<leader>nB", ":NoteBlocks<CR>", { desc = "Browse note blocks" })
vim.keymap.set("n", "<leader>ns", ":NoteStatus<CR>", { desc = "Repository status" })
```

## License

MIT
