vim9script

import autoload 'project_management/layout.vim'
import autoload 'project_management/files.vim'
import autoload 'project_management/outline.vim'
import autoload 'project_management/opencode.vim'
import autoload 'project_management/terminal.vim'

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

  set hidden
  files.ApplyConfig()
  outline.SetSplit('edit')

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
enddef

export def Close(force: bool): bool
  if !project.active
    echomsg 'No project is open'
    return false
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
  echomsg 'Project closed. PWD: ' .. getcwd()
  return true
enddef

export def Reload(): void
  if !project.active
    echomsg 'No project is open'
    return
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
  endif
  if project.editor_win > 0 && win_id2win(project.editor_win) > 0
    win_gotoid(project.editor_win)
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

export def NetrwSetup(): void
  if !project.active
    return
  endif
  if project.files_win <= 0 || win_getid() != project.files_win
    return
  endif
  nnoremap <buffer><silent> <CR> :ProjectNetrwEnter<CR>
  nnoremap <buffer><silent> <2-LeftMouse> :ProjectNetrwEnter<CR>
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

  # Make the editor the alternate window, then let netrw resolve the entry and
  # open it. This preserves tree/list navigation while forcing files to open in
  # the center editor instead of whichever window was previous.
  var word = netrw#Call('NetrwGetWord')
  if type(word) != v:t_string || word == ''
    return
  endif
  var target = netrw#Call('NetrwBrowseChgDir', 1, word, 1)
  if type(target) != v:t_string || target == ''
    return
  endif
  var isdir = isdirectory(target)

  win_gotoid(project.editor_win)
  win_gotoid(project.files_win)
  call netrw#LocalBrowseCheck(target)

  var files = project.files_win
  if files > 0 && win_id2win(files) > 0
    win_gotoid(files)
    NetrwSetup()
  endif
  if !isdir
    if project.editor_win > 0 && win_id2win(project.editor_win) > 0
      win_gotoid(project.editor_win)
    endif
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
    'hidden=' .. string(&hidden),
  ]
  echomsg join(parts, ' | ')
enddef
