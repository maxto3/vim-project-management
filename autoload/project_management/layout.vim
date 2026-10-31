vim9script

import autoload 'project_management/opencode.vim'
import autoload 'project_management/terminal.vim'
import autoload 'project_management/files.vim'
import autoload 'project_management/outline.vim'

def Clamp(n: number, lo: number, hi: number): number
  if n < lo
    return lo
  endif
  if n > hi
    return hi
  endif
  return n
enddef

def Max2(a: number, b: number): number
  return a > b ? a : b
enddef

def OutlinePlaceholder(): void
  enew
  setlocal buftype=nofile bufhidden=wipe nobuflisted
  setline(1, ['Outline', 'Press F2 or :ProjectOutline'])
  setlocal nonumber norelativenumber signcolumn=no nowrap
enddef

export def Build(root: string, cfg: dict<any>): dict<any>
  var total_cols = &columns
  var total_lines = &lines

  var right_w = Clamp(float2nr(cfg.right_width), 15, Max2(15, total_cols / 3))
  var left_w = Clamp(float2nr(total_cols * cfg.left_ratio), cfg.min_width, Max2(cfg.min_width, total_cols / 2))
  if left_w + right_w + 40 + 4 > total_cols
    left_w = Max2(15, total_cols / 5)
    right_w = Max2(15, total_cols / 4)
  endif
  var bottom_h = Clamp(float2nr(cfg.bottom_height), cfg.min_height, Max2(cfg.min_height, total_lines / 2))

  var enable_terms = get(g:, 'project_management_enable_terminals', true)
  var result: dict<any> = {
    editor: win_getid(),
    files: 0,
    outline: 0,
    opencode: 0,
    terminal: 0,
    opencode_buf: -1,
    terminal_buf: -1,
  }

  # 1. Bottom terminal at root level, so it spans the full window width.
  execute 'belowright split'
  result.terminal = win_getid()
  if enable_terms
    try
      result.terminal_buf = terminal.Start(root)
    catch
      result.terminal_buf = -1
    endtry
  endif
  if result.terminal_buf == -1
    setlocal buftype=nofile bufhidden=wipe nobuflisted
    setline(1, ['terminal unavailable'])
  endif
  execute 'resize ' .. bottom_h
  setlocal winfixheight

  # 2. Left opencode column in the top row.
  win_gotoid(result.editor)
  execute 'aboveleft vnew'
  result.opencode = win_getid()
  if enable_terms
    try
      result.opencode_buf = opencode.Start(root)
    catch
      result.opencode_buf = -1
    endtry
  endif
  if result.opencode_buf == -1
    setlocal buftype=nofile bufhidden=wipe nobuflisted
    setline(1, ['opencode unavailable', '', 'Install with:', '  npm i -g opencode-ai'])
  endif
  execute 'vertical resize ' .. left_w
  setlocal winfixwidth

  # 3. Right column in the top row: files on top, outline at the bottom.
  win_gotoid(result.editor)
  execute 'belowright vnew'
  var files_win = win_getid()
  execute 'vertical resize ' .. right_w
  setlocal winfixwidth

  execute 'belowright split'
  var outline_win = win_getid()
  setlocal winfixwidth
  OutlinePlaceholder()

  # 4. Ask coc to open the outline in the placeholder window. This uses the
  #    "edit" split command so no additional window is created.
  var opened = 0
  try
    opened = outline.ShowInWindow(result.editor, outline_win)
  catch
    opened = 0
  endtry
  if opened == 0
    win_gotoid(outline_win)
    OutlinePlaceholder()
  endif
  result.outline = outline_win

  var right_total = winheight(files_win) + winheight(outline_win) + 1
  var outline_h = Clamp(right_total / 2, cfg.min_height, Max2(cfg.min_height, right_total - cfg.min_height - 1))
  win_gotoid(outline_win)
  execute 'resize ' .. outline_h

  # 5. File browser on top of the right column.
  win_gotoid(result.editor)
  win_gotoid(files_win)
  if get(g:, 'project_management_enable_netrw', true)
    files.Open(root)
  else
    setlocal buftype=nofile bufhidden=wipe nobuflisted
    setline(1, ['Files'])
  endif
  result.files = files_win

  # 6. Focus the editor.
  win_gotoid(result.editor)
  return result
enddef
