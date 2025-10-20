# notes.nvim

A beautiful, feature-rich notes management plugin for Neovim with git integration and an elegant UI.

## Features

- 📝 **Note Management**: Create and organize notes with automatic date-based folder structure
- 🏷️ **Tag System**: Tag notes and browse by tags with `["tag1", "tag2"]` format
- 🔍 **Telescope Integration**: Beautiful UI with live preview panel
- 📜 **Git Integration**: Full version control with backup, fetch, and history viewing
- 🎨 **Customizable UI**: Configurable borders and notification styles
- ⏰ **History**: View and restore previous versions of notes

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'darwincereska/notes.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('notes').setup({
      notes_dir = "~/.notes",
      git_remote = nil, -- Optional: "git@github.com:user/notes.git"
      date_format = "%Y/%m/%d",
      file_extension = ".md",
      use_telescope = true,
      ui = {
        border = "rounded", -- "single", "double", "solid", "shadow"
        use_native_notify = false,
      }
    })
  end
}
```

## Commands

- `:Note` - Create a new note (prompts for name and optional tags)
- `:Notes` - List all notes with Telescope preview
- `:NotesTags` - Browse notes by tags
- `:NotesBackup` - Commit and push notes to git remote
- `:NotesFetch` - Pull latest notes from git remote
- `:NotesHistory` - Browse all commit history
- `:NoteHistory` - View history of current note (with restore capability)

## Usage

### Creating Notes

```vim
:Note
```

1. Enter note name
2. Choose whether to add tags (Yes/No)
3. If yes, enter comma-separated tags
4. Note is created with template

### Note Template

Notes are created with this structure:

```markdown
# Note Title

Date: 2025-10-20 14:30:00
Tags: ["productivity", "vim"]

---

[Your content here]
```

### Browsing Notes

```vim
:Notes
```

Opens Telescope with:
- Live preview of note content
- Shows title, tags, and date
- Search through all notes
- Press `Enter` to open

### Version Control

View previous versions and restore:

```vim
:NoteHistory
```

Press `r` to restore a previous version, `q` to close.

## Configuration

### Default Configuration

```lua
{
  notes_dir = vim.fn.expand("~/.notes"),
  git_remote = nil,
  date_format = "%Y/%m/%d",
  file_extension = ".md",
  use_telescope = true,
  template = [[# {title}

Date: {date}
Tags: {tags}

---

]],
  ui = {
    border = "rounded",
    use_native_notify = false,
  }
}
```

### UI Customization

Available border styles:
- `"none"` - No border
- `"single"` - Single line border
- `"double"` - Double line border
- `"rounded"` - Rounded corners (default)
- `"solid"` - Solid border
- `"shadow"` - Shadow effect

## Features in Detail

### Tag System

- Tags are stored as `["tag1", "tag2"]` in notes
- Empty tags show as `[]` and are hidden in listings
- Browse all notes by tag with `:NotesTags`
- Tags display in Telescope listings

### Git Integration

- Automatic git repo initialization
- Commit with timestamps
- Push/pull to remote repository
- Full commit history with file viewing
- Restore any previous version

### Telescope Preview

- Live preview of note content when browsing
- Clean interface without "process exited" messages
- Shows metadata (title, tags, date) in listings
- Fast fuzzy finding

## License

MIT
