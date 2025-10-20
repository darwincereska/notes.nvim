# notes.nvim

A Neovim plugin for managing markdown notes with git version control, fzf fuzzy finding, and an interactive commit browser.

## Features

- 📝 Create notes with titles and optional tags
- 📁 Organize notes by date (Year/Month/Day/title.md structure)
- 🔍 Browse and search notes with fzf and ripgrep
- 🏷️ Filter notes by tags
- 🔄 Git version control with automatic backup
- 🗑️ Delete notes with confirmation (git-aware)
- 🌐 Optional remote repository sync
- 📜 Interactive commit browser with previews
- ⏪ Revert notes to previous versions from commit browser
- 🔀 View diffs between commits
- 📂 Browse files in specific commits

## Requirements

- Neovim >= 0.8.0
- [fzf](https://github.com/junegunn/fzf) - fuzzy finder
- git (for version control features)
- [bat](https://github.com/sharkdp/bat) - optional, for syntax highlighting in previews
- [ripgrep](https://github.com/BurntSushi/ripgrep) - optional, for content search

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "darwincereska/notes.nvim",
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
Open fzf picker to browse all notes with preview. Uses bat for syntax highlighting if available. Press `<CR>` to open a note.

#### `:NoteTags`
Open fzf picker showing only notes that have tags. Filter and search by tag names with live preview.

#### `:NotesBackup`
Commit all changes to git and push to remote (if configured). Automatically stages all files.

#### `:NotesFetch`
Fetch updates from the remote repository (if configured).

#### `:NoteDelete`
Open fzf picker to select a note for deletion. Confirmation prompt will appear before deletion. If git is enabled, uses `git rm` to properly remove the file from version control and commits the change.

#### `:NoteHistory`
Interactive commit browser for the currently open note. Keyboard shortcuts:
- `Enter` - View note content at selected commit
- `Ctrl-r` - Revert to selected commit (with confirmation)
- `Ctrl-d` - Show diff between selected commit and HEAD

Only works when the current buffer is a note file.

#### `:NotesHistory`
Interactive commit browser for all notes in the repository. Keyboard shortcuts:
- `Enter` - Show commit details and stats
- `Ctrl-f` - Browse files modified in selected commit
- `Ctrl-d` - Show full diff for selected commit

When browsing commit files:
- `Enter` - View file content at that commit
- `Ctrl-r` - Revert file to that commit (with confirmation)

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

The commit browser provides a powerful interface for exploring your notes history:

### Single Note History (`:NoteHistory`)
```
Commit Hash  Date       Author    Message
abc1234      2 days ago John Doe  Updated project notes
def5678      1 week ago John Doe  Initial version

Preview: Shows the note content at the selected commit
Actions:
  - Enter: View full note at commit
  - Ctrl-r: Revert to this version
  - Ctrl-d: Show diff vs current
```

### All Notes History (`:NotesHistory`)
```
Commit Hash  Date        Author    Message              Files
abc1234      2 days ago  John Doe  Backup notes         [2025/10/20/meeting.md, ...]
def5678      1 week ago  John Doe  Added new ideas     [2025/10/15/ideas.md]

Preview: Shows commit details and file changes
Actions:
  - Enter: View commit details
  - Ctrl-f: Browse files in commit
  - Ctrl-d: Show full diff
```

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
