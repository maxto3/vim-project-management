# project-management

A VS Code-like project workspace for Vim 9 / GVim, written in Vim9 script.

```
+------------+-------------------------------+------------------+
|            |                               | file browser     |
|  opencode  |          editor               | (netrw, top)     |
|  (left)    |                               |------------------|
|            |                               | outline (bottom) |
+------------+-------------------------------+------------------+
|                   terminal (project root)                       |
+-----------------------------------------------------------------+
```

## Features

- `:ProjectOpen [path]` opens a project in the current tab; no Vim tabs are
  created.
- The center window is the only editing window. Files chosen in the netrw
  browser open there, and all opened files remain available as buffers.
- The left column runs `opencode` with the project root as its working
  directory.
- The bottom window runs the configured shell with the project root as its
  working directory.
- The right column contains a netrw file browser and a coc outline. Selecting
  an outline symbol jumps to the symbol in the center editor.
- `:ProjectClose` stops the project terminals, wipes project file buffers,
  keeps non-project buffers, restores the startup working directory, and
  leaves one empty `[No Name]` window.
- `:ProjectClose!` forces a full cleanup: all buffers, windows and tabs are
  removed.

## Requirements

- Vim 9.0 or newer with `+terminal` and Vim9 script support (tested on Vim
  9.2 / Windows GVim).
- `coc.nvim` for the outline and LSP.
- The built-in netrw file browser.
- `opencode` in `PATH` for the left panel. See
  <https://opencode.ai> for installation.
- **Vim only.** Vim9 script is not compatible with Neovim.

All plugin source files are Vim9 script and must use UTF-8 without BOM and LF
line endings. CRLF causes `E1173` after `enddef`.

## Installation

Install it through vim-plug:

```vim
Plug 'https://github.com/maxto3/vim-project-management.git'
```

Then run:

```vim
:PlugInstall
```

vim-plug clones the repository into:

```text
C:\Users\<you>\.vim\plugged\project-management
```

and loads the plugin from there.

After changing and committing the source repository, update the installed
copy with:

```vim
:PlugUpdate project-management
```

### Backup

The installed copy is under `~/.vim/plugged`, so `gvim_backup.py` includes it
in the normal `~/.vim` archive. Keep the source repository under Git as the
canonical development copy.

## Commands

| Command | Description |
| --- | --- |
| `:ProjectOpen [path]` | Open the project at `path`; without a path use `PWD`. |
| `:ProjectClose` | Close the project, keeping non-project buffers. |
| `:ProjectClose!` | Close the project and clear every buffer/window/tab. |
| `:ProjectReload` | Rebuild the project layout without losing project buffers. |
| `:ProjectStatus` | Show the root, working directory, window IDs and terminal buffers. |
| `:ProjectOutline` | Open/focus the outline window. |
| `:ProjectToggleOutline` | Toggle the outline in the right column. |

`F2` is project-aware when this plugin is active and calls
`:ProjectToggleOutline`. Outside a project it keeps the normal coc outline
toggle behavior.

## Layout and behavior

- `:ProjectOpen` collapses the current tab to one window, then builds the
  layout with explicit `aboveleft` / `belowright` splits. Existing buffers are
  preserved.
- The plugin temporarily enables `'hidden'` while a project is open so the
  center editor can hold multiple buffers. The previous value is restored on
  close.
- The netrw browser opens files explicitly in the center editor through a
  project mapping; selecting a directory stays inside the browser.
- The outline uses coc's `outline.splitCommand = edit` while a project is
  active. It is opened inside the reserved right-hand window instead of
  creating a new column. The original value is restored on close.
- While a project is active, the plugin disables coc's
  `outline.checkBufferSwitch` and refreshes the outline only when the center
  editor's buffer changes. Moving focus to netrw, the terminal, or opencode
  keeps the outline showing the current source file instead of switching to
  "Document symbol provider not found".
- Press `,O` (leader + `O`) to toggle focus between the center editor and the
  outline. The command form is `:ProjectFocusOutline`. Pressing `Enter` on an
  outline item jumps to the symbol in the editor; `Ctrl-W p` returns to the
  previous window.
- If the language server is not ready when the project opens, the outline
  window starts with an "Outline unavailable" placeholder. Press `F2` or run
  `:ProjectOutline` after the file's LSP is ready; coc then populates the
  outline and follows the active buffer.
- The outline is project-aware; opening and closing it does not replace the
  center editor buffer.

## Configuration

```vim
" Layout (left width is a ratio of the total columns).
let g:project_management_left_width    = 0.28
let g:project_management_right_width   = 34
let g:project_management_bottom_height = 14
let g:project_management_winminwidth   = 20
let g:project_management_winminheight  = 5

" opencode
let g:project_management_opencode_cmd  = 'opencode'
let g:project_management_opencode_args = []

" Bottom shell. Empty means use &shell.
let g:project_management_shell = ''

" Set to 0 for headless tests or terminals without +terminal.
let g:project_management_enable_terminals = 1

" Set to 0 to use a placeholder instead of netrw (useful in tests).
let g:project_management_enable_netrw = 1
```

## File browser notes

The project uses the built-in netrw rather than coc-explorer:

- zero additional dependencies;
- `g:netrw_browse_split = 4` matches the "open in the center editor" model;
- the file browser can be placed in the right column without another coc tree
  view competing with the outline.

## Testing

The repository includes a headless smoke test:

```powershell
.\test\run.ps1
```

The test disables terminals and netrw via `test/vimrc`, then verifies open,
close, no-tab behavior, project buffer cleanup, non-project buffer retention,
PWD restoration and `:ProjectClose!`.

## Limitations

- The outline depends on a working coc language server. Before the server is
  ready, use `F2` / `:ProjectOutline`.
- `:ProjectClose!` is destructive by design.
- The plugin sets `outline.splitCommand` globally while a project is active
  and restores it on close.
