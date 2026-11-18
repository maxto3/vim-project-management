vim9script

import autoload 'project_management/layout.vim'
import autoload 'project_management/files.vim'
import autoload 'project_management/outline.vim'
import autoload 'project_management/opencode.vim'
import autoload 'project_management/terminal.vim'
import autoload 'project_management/commit.vim' as commitmsg
import autoload 'project_management/netrw.vim' as netrwcolors

export var project: dict<any> = {
  active: false,
  root: '',
  editor_win: 0,
  files_win: 0,
  outline_win: 0,
  opencode_win: 0,
  terminal_win: 0,
  opencode_buf: -1,
  terminal_buf: -1,
  startup_cwd: '',
  saved_hidden: false,
  saved_files: {},
  saved_outline_split: 'botright 30vs',
  saved_outline_check: true,
  outline_buf: -1,
  focus_tab: 0,
  focus_win: 0,
  main_tab: 0,
  main_win: 0,
}

var outline_busy = false


export def Init(): void
  if project.startup_cwd == ''
    project.startup_cwd = getcwd()
  endif
enddef

def Config(): dict<any>
  return {
    left_ratio: get(g:, 'project_management_left_width', 0.28),
    right_width: get(g:, 'project_management_right_width', 34),
    bottom_height: get(g:, 'project_management_bottom_height', 14),
    min_width: get(g:, 'project_management_winminwidth', 20),
    min_height: get(g:, 'project_management_winminheight', 5),
  }
enddef


def Error(msg: string): void
  echohl ErrorMsg
  echomsg 'project-management: ' .. msg
  echohl None
enddef

def ResolveRoot(path: string): string
  var p = path
  if p == ''
    p = getcwd()
  endif
  p = expand(p)
  p = fnamemodify(p, ':p')
  p = substitute(p, '[/\\]\+$', '', '')
  if p == ''
    p = getcwd()
  endif
  if !isdirectory(p)
    Error('not a directory: ' .. p)
    return ''
  endif
  return p
enddef

def IsUnder(path: string, root: string): bool
  var p = resolve(fnamemodify(path, ':p'))
  var r = resolve(fnamemodify(root, ':p'))
  p = substitute(p, '\\', '/', 'g')
  r = substitute(r, '\\', '/', 'g')
  if r !~# '/$'
    r ..= '/'
  endif
  if has('win32')
    return stridx(tolower(p), tolower(r)) == 0
  endif
  return stridx(p, r) == 0
enddef

def IsProjectBuffer(bufnr: number): bool
  if bufnr <= 0 || !bufexists(bufnr)
    return false
  endif
  var name = bufname(bufnr)
  if name == ''
    return false
  endif
  if getbufvar(bufnr, '&buftype') != ''
    return false
  endif
  return IsUnder(fnamemodify(name, ':p'), project.root)
enddef

def ProjectBuffers(): list<number>
  var out: list<number> = []
  for info in getbufinfo()
    if IsProjectBuffer(info.bufnr)
      add(out, info.bufnr)
    endif
  endfor
  return out
enddef

def InitialFile(root: string): void
  var patterns = ['*.py', '*.ps1', '*.sh', '*.java', '*.kt', '*.js', '*.ts', '*.go', '*.rs', '*.c', '*.cpp', '*.cs', '*.lua', '*.vim']
  for pat in patterns
    var found = glob(root .. '/' .. pat, 0, 1)
    if !empty(found)
      execute 'edit ' .. fnameescape(found[0])
      return
    endif
  endfor
  for pat in patterns
    var found = glob(root .. '/*/' .. pat, 0, 1)
    if !empty(found)
      execute 'edit ' .. fnameescape(found[0])
      return
    endif
  endfor
  for name in ['README.md', 'README', 'readme.md', 'Readme.md']
    var p = root .. '/' .. name
    if filereadable(p)
      execute 'edit ' .. fnameescape(p)
      return
    endif
  endfor
  for name in readdir(root)
    var p = root .. '/' .. name
    if !isdirectory(p) && filereadable(p)
      execute 'edit ' .. fnameescape(p)
      return
    endif
  endfor
  enew
enddef

def ApplyResult(res: dict<any>): void
  project.editor_win = res.editor
  project.files_win = res.files
  project.outline_win = res.outline
  project.opencode_win = res.opencode
  project.terminal_win = res.terminal
  project.opencode_buf = res.opencode_buf
  project.terminal_buf = res.terminal_buf
  project.outline_buf = winbufnr(res.editor)
enddef

def SetupNetrw(): void
  if project.files_win > 0 && win_id2win(project.files_win) > 0
    win_gotoid(project.files_win)
    NetrwSetup()
    if project.editor_win > 0 && win_id2win(project.editor_win) > 0
      win_gotoid(project.editor_win)
    endif
  endif
enddef

def StopTerminals(): void
  terminal.Stop(project.terminal_buf)
  opencode.Stop(project.opencode_buf)
  project.terminal_buf = -1
  project.opencode_buf = -1
enddef

def CloseSideWindows(): void
  var wins = [project.terminal_win, project.opencode_win, project.outline_win, project.files_win]
  for w in wins
    if w > 0 && win_id2win(w) > 0
      win_gotoid(w)
      silent! close!
    endif
  endfor
  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    win_gotoid(project.editor_win)
  endif
  silent! only
enddef

def CleanupSpecialBuffers(): void
  for info in getbufinfo()
    if info.bufnr == bufnr('%')
      continue
    endif
    var ft = getbufvar(info.bufnr, '&filetype')
    var name = info.name
    if ft == 'netrw' || ft == 'coctree' || name =~# 'NetrwTreeListing' || name =~# 'CocTree'
      execute 'silent! bwipeout! ' .. info.bufnr
    endif
  endfor
enddef

def RestoreEnvironment(): void
  files.RestoreConfig(project.saved_files)
  outline.SetSplit(project.saved_outline_split)
  outline.SetCheckBufferSwitch(project.saved_outline_check)
  if !project.saved_hidden
    set nohidden
  endif
enddef

def ResetState(): void
  outline_busy = false
  g:project_management_active = false
  project.active = false
  project.root = ''
  project.editor_win = 0
  project.files_win = 0
  project.outline_win = 0
  project.opencode_win = 0
  project.terminal_win = 0
  project.opencode_buf = -1
  project.terminal_buf = -1
  project.saved_files = {}
  project.saved_outline_split = 'botright 30vs'
  project.saved_outline_check = true
  project.outline_buf = -1
  project.focus_tab = 0
  project.focus_win = 0
  project.main_tab = 0
  project.main_win = 0
enddef

export def Open(path: string): void
  Init()
  var root = ResolveRoot(path)
  if root == ''
    return
  endif

  if project.active
    if !Close(false)
      return
    endif
  endif

  project.saved_hidden = &hidden
  project.saved_files = files.SaveConfig()
  project.saved_outline_split = outline.SaveConfig()
  project.saved_outline_check = outline.SaveCheckBufferSwitch()

  set hidden
  files.ApplyConfig()
  outline.SetSplit('edit')
  outline.SetCheckBufferSwitch(false)

  silent! only
  if &buftype != ''
    enew
  endif

  project.root = root
  project.active = true
  g:project_management_active = true
  project.editor_win = win_getid()

  execute 'cd ' .. fnameescape(root)
  InitialFile(root)

  try
    var res = layout.Build(root, Config())
    ApplyResult(res)
    SetupNetrw()
  catch
    Error('layout failed: ' .. v:exception)
    Close(false)
    return
  endtry

  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    win_gotoid(project.editor_win)
  endif
  echomsg 'Project opened: ' .. root
  silent doautocmd <nomodeline> User ProjectOpened
enddef

export def Close(force: bool): bool
  if !project.active
    echomsg 'No project is open'
    return false
  endif

  if FocusModeTab() > 0
    LeaveFocusMode()
  endif

  if !force
    var modified: list<number> = []
    for b in ProjectBuffers()
      if getbufvar(b, '&modified')
        add(modified, b)
      endif
    endfor
    if !empty(modified)
      var choice = confirm('Discard changes in ' .. len(modified) .. ' project buffer(s)?', "&Yes\n&No", 2)
      if choice != 1
        return false
      endif
    endif
  endif

  StopTerminals()

  if exists('g:did_coc_loaded')
    try
      outline.Close()
    catch
    endtry
  endif

  if force
    silent! tabonly
  endif

  CloseSideWindows()

  if force
    enew
    for info in getbufinfo()
      if info.bufnr != bufnr('%')
        execute 'silent! bwipeout! ' .. info.bufnr
      endif
    endfor
    CleanupSpecialBuffers()
  else
    enew
    for b in ProjectBuffers()
      execute 'silent! bwipeout! ' .. b
    endfor
    CleanupSpecialBuffers()
  endif

  enew

  if isdirectory(project.startup_cwd)
    execute 'cd ' .. fnameescape(project.startup_cwd)
  endif

  RestoreEnvironment()
  ResetState()
  silent doautocmd <nomodeline> User ProjectClosed
  echomsg 'Project closed. PWD: ' .. getcwd()
  return true
enddef

export def Reload(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif

  if FocusModeTab() > 0
    LeaveFocusMode()
  endif

  var root = project.root
  StopTerminals()
  if exists('g:did_coc_loaded')
    try
      outline.Close()
    catch
    endtry
  endif
  CloseSideWindows()
  CleanupSpecialBuffers()

  try
    var res = layout.Build(root, Config())
    ApplyResult(res)
    SetupNetrw()
  catch
    Error('layout failed: ' .. v:exception)
    return
  endtry

  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    win_gotoid(project.editor_win)
  endif
  echomsg 'Project layout rebuilt: ' .. root
enddef

export def Outline(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif
  if !exists('g:did_coc_loaded')
    Error('coc.nvim is not available')
    return
  endif
  var winid = coc#window#find('cocViewId', 'OUTLINE')
  if winid > 0
    project.outline_buf = winbufnr(project.editor_win)
    win_gotoid(winid)
    return
  endif
  if project.outline_win <= 0 || win_id2win(project.outline_win) == 0
    Error('outline window is missing; run :ProjectReload')
    return
  endif
  var opened = 0
  try
    opened = outline.ShowInWindow(project.editor_win, project.outline_win)
  catch
    Error('outline call failed: ' .. v:exception)
    opened = 0
  endtry
  if opened == 0
    Error('outline is unavailable (coc.nvim not ready or no LSP)')
    win_gotoid(project.outline_win)
    enew
    setlocal buftype=nofile bufhidden=wipe nobuflisted
    setline(1, ['Outline', 'Press F2 after the LSP is ready'])
  else
    project.outline_buf = winbufnr(project.editor_win)
  endif
  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    win_gotoid(project.editor_win)
  endif
enddef

export def FocusOutline(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif
  if !exists('g:did_coc_loaded')
    # Without coc.nvim the right column still holds a placeholder outline.
    var placeholder = project.outline_win
    if placeholder <= 0 || win_id2win(placeholder) == 0
      Error('outline window is missing; run :ProjectReload')
      return
    endif
    if win_getid() == placeholder
      if project.editor_win > 0 && win_id2win(project.editor_win) > 0
        win_gotoid(project.editor_win)
      endif
      return
    endif
    win_gotoid(placeholder)
    return
  endif
  var winid = coc#window#find('cocViewId', 'OUTLINE')
  if winid > 0 && win_getid() == winid
    if project.editor_win > 0 && win_id2win(project.editor_win) > 0
      win_gotoid(project.editor_win)
    endif
    return
  endif
  Outline()
  winid = coc#window#find('cocViewId', 'OUTLINE')
  if winid > 0
    win_gotoid(winid)
  endif
enddef

def MakeOutlinePlaceholder(files_win: number): number
  if files_win <= 0 || win_id2win(files_win) == 0
    return 0
  endif
  win_gotoid(files_win)
  execute 'belowright split'
  var w = win_getid()
  enew
  setlocal buftype=nofile bufhidden=wipe nobuflisted
  setline(1, ['Outline', ''])
  setlocal nonumber norelativenumber signcolumn=no nowrap
  setlocal winfixwidth
  var total = winheight(files_win) + winheight(w) + 1
  var h = total / 2
  if h < 5
    h = 5
  endif
  execute 'resize ' .. h
  return w
enddef

export def OnEditorBufEnter(): void
  if !project.active || outline_busy
    return
  endif
  if !exists('g:did_coc_loaded')
    return
  endif
  if project.editor_win <= 0 || win_getid() != project.editor_win
    return
  endif
  if &buftype != ''
    return
  endif
  var name = bufname('%')
  if name == '' || !IsUnder(fnamemodify(name, ':p'), project.root)
    return
  endif
  if coc#window#find('cocViewId', 'OUTLINE') <= 0
    return
  endif
  var b = bufnr('%')
  if project.outline_buf == b
    return
  endif
  outline_busy = true
  try
    call('CocAction', ['showOutline', 1])
    project.outline_buf = b
  catch
  endtry
  outline_busy = false
enddef

export def NetrwSetup(): void
  if !project.active
    return
  endif
  if project.files_win <= 0 || win_getid() != project.files_win
    return
  endif
  nnoremap <buffer><silent> <CR> :ProjectNetrwEnter<CR>
  nnoremap <buffer><silent> <2-LeftMouse> :ProjectNetrwEnter<CR>
  netrwcolors.ApplyColors()
enddef

export def NetrwEnter(): void
  if !project.active
    return
  endif
  if project.files_win <= 0 || win_id2win(project.files_win) == 0
    return
  endif
  if project.editor_win <= 0 || win_id2win(project.editor_win) == 0
    return
  endif
  if win_getid() != project.files_win
    return
  endif

  # Resolve the entry under the cursor with netrw's own helpers. Files are
  # opened explicitly in the center editor; directories stay in the browser.
  # This avoids relying on netrw's "previous window" and never moves windows.
  var word = netrw#Call('NetrwGetWord')
  if type(word) != v:t_string || word == ''
    return
  endif
  var tree = netrw#Call('NetrwTreePath', get(w:, 'netrw_treetop', get(b:, 'netrw_curdir', project.root)))
  if type(tree) != v:t_string || tree == ''
    tree = get(b:, 'netrw_curdir', project.root)
  endif

  var line = getline('.')
  var path = ''
  var isdir_entry = line =~# '/\s*$'
  if word == '../' || line ==# '../'
    path = fnamemodify(get(b:, 'netrw_curdir', project.root), ':h')
  elseif isdir_entry
    path = tree
  else
    path = tree
    if path !~# '[/\\]$'
      path ..= '/'
    endif
    path ..= word
  endif
  path = substitute(path, '[/\\]\+', '/', 'g')
  path = fnamemodify(path, ':p')
  path = substitute(path, '[/\\]$', '', '')

  if isdirectory(path)
    var oldbase = fnamemodify(get(b:, 'netrw_curdir', project.root), ':t')
    var dirtext = line
    win_gotoid(project.files_win)
    call netrw#LocalBrowseCheck(path)
    if project.files_win > 0 && win_id2win(project.files_win) > 0
      win_gotoid(project.files_win)
      NetrwSetup()

      # Keep the cursor near the directory the user just entered.  In tree
      # mode netrw expands the entry in place; keep the cursor on that line.
      # For non-tree listings or when the line is gone, use the first entry
      # after "../" instead of leaving the cursor at the top.
      var target = ''
      if word == '../' || line ==# '../'
        target = '^[│ ]*' .. escape(oldbase, '\.*$^~[]') .. '/$'
      elseif isdir_entry && dirtext != ''
        target = '^' .. escape(dirtext, '\.*$^~[]') .. '$'
      endif
      if target != ''
        cursor(1, 1)
        search(target, 'cw')
      endif
      if line('.') == 1 && line('$') > 1
        cursor(2, 1)
      endif
    endif
    return
  endif

  if filereadable(path)
    win_gotoid(project.editor_win)
    execute 'edit ' .. fnameescape(path)
  endif
enddef

export def ToggleOutline(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif

  outline_busy = true

  if exists('g:did_coc_loaded') && coc#window#find('cocViewId', 'OUTLINE') > 0
    try
      outline.Close()
    catch
    endtry
    project.outline_buf = -1
    project.outline_win = MakeOutlinePlaceholder(project.files_win)
    if project.editor_win > 0 && win_id2win(project.editor_win) > 0
      win_gotoid(project.editor_win)
    endif
    outline_busy = false
    return
  endif

  if project.outline_win <= 0 || win_id2win(project.outline_win) == 0
    project.outline_win = MakeOutlinePlaceholder(project.files_win)
    if project.outline_win == 0
      outline_busy = false
      Error('file browser window is missing; run :ProjectReload')
      return
    endif
  endif

  Outline()
  outline_busy = false
enddef

export def Focus(kind: string): void
  if !project.active
    echomsg 'No project is open'
    return
  endif
  if kind ==# 'outline'
    # Same behaviour as <Leader>O: focus, opening the outline when needed,
    # and toggle back to the editor when it already has the focus.
    FocusOutline()
    return
  endif
  var target = 0
  var label = ''
  if kind ==# 'files' || kind ==# 'explorer' || kind ==# 'netrw'
    target = project.files_win
    label = 'file browser'
  elseif kind ==# 'opencode'
    target = project.opencode_win
    label = 'opencode'
  elseif kind ==# 'terminal'
    target = project.terminal_win
    label = 'terminal'
  else
    Error('unknown focus target: ' .. kind .. ' (files, opencode, terminal, outline)')
    return
  endif
  if target <= 0 || win_id2win(target) == 0
    Error(label .. ' window is missing; run :ProjectReload')
    return
  endif
  win_gotoid(target)
enddef

# ---- focus mode ---------------------------------------------------------
# A separate tab that shows only the project editor buffer.  The original
# layout stays untouched in its own tab.

def FocusModeTab(): number
  if project.focus_tab <= 0 || project.focus_win <= 0
    return 0
  endif
  var info = win_id2tabwin(project.focus_win)
  if empty(info) || info[0] <= 0 || info[0] != project.focus_tab
    # The tab was closed behind our back.
    project.focus_tab = 0
    project.focus_win = 0
    return 0
  endif
  return project.focus_tab
enddef

export def FocusModeActive(): bool
  return FocusModeTab() > 0 && tabpagenr() == project.focus_tab
enddef

def EnterFocusMode(): void
  project.main_tab = tabpagenr()
  project.main_win = win_getid()
  var buf = -1
  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    buf = winbufnr(project.editor_win)
  else
    buf = bufnr('%')
  endif
  execute 'tabnew'
  project.focus_tab = tabpagenr()
  project.focus_win = win_getid()
  if buf > 0 && bufexists(buf)
    execute 'buffer ' .. buf
  endif
  silent! only
  if project.focus_tab > 0
    echomsg 'Focus mode: ' .. expand('%:t')
  endif
enddef

def LeaveFocusMode(): void
  var focus_tab = FocusModeTab()
  if focus_tab <= 0
    return
  endif
  # Keep whatever the user opened while in focus mode.
  var buf = tabpagenr() == focus_tab ? bufnr('%') : -1
  var main_tab = project.main_tab
  if main_tab <= 0 || main_tab > tabpagenr('$') || main_tab == focus_tab
    main_tab = focus_tab == 1 ? 2 : 1
  endif
  if main_tab <= tabpagenr('$')
    execute 'tabnext ' .. main_tab
  endif
  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    win_gotoid(project.editor_win)
    if buf > 0 && bufexists(buf)
      execute 'buffer ' .. buf
    endif
  endif
  if focus_tab <= tabpagenr('$')
    execute 'tabclose ' .. focus_tab
  endif
  project.focus_tab = 0
  project.focus_win = 0
  project.main_tab = 0
  project.main_win = 0
  if exists('g:did_coc_loaded')
    OnEditorBufEnter()
  endif
enddef

# F11: enter a one-window tab with the current project file, or leave it.
export def ToggleFocusMode(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif
  var focus_tab = FocusModeTab()
  if focus_tab > 0 && tabpagenr() == focus_tab
    LeaveFocusMode()
  elseif focus_tab > 0
    execute 'tabnext ' .. focus_tab
  else
    EnterFocusMode()
  endif
enddef

# Recompute the file-browser colours, e.g. after :colorscheme.
export def RefreshNetrwColors(): void
  for info in getwininfo()
    if getbufvar(info.bufnr, '&filetype') == 'netrw'
      win_execute(info.winid, 'call ProjectNetrwRecolor()')
    endif
  endfor
enddef

# Commit helpers: :ProjectCommit builds a message for the staged changes.
export def Commit(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif
  commitmsg.Start(project.root)
enddef

export def CommitAccept(): void
  commitmsg.Accept()
enddef

export def CommitAbort(): void
  commitmsg.Abort()
enddef

export def Status(): void
  if !project.active
    echomsg 'No project is open'
    return
  endif
  var parts: list<string> = [
    'root=' .. project.root,
    'pwd=' .. getcwd(),
    'editor=' .. project.editor_win,
    'files=' .. project.files_win,
    'outline=' .. project.outline_win,
    'opencode=' .. project.opencode_win .. '(buf ' .. project.opencode_buf .. ')',
    'terminal=' .. project.terminal_win .. '(buf ' .. project.terminal_buf .. ')',
    'focus=' .. FocusModeTab(),
    'hidden=' .. string(&hidden),
  ]
  echomsg join(parts, ' | ')
enddef
