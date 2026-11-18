vim9script

import autoload 'project_management.vim'
import autoload 'project_management/netrw.vim' as netrwcolors
import autoload 'project_management/commit.vim' as commitmsg

var failures: list<string> = []

def Check(cond: bool, msg: string): void
  if !cond
    add(failures, msg)
  endif
enddef

def N(path: string): string
  var p = fnamemodify(path, ':p')
  p = substitute(p, '\\', '/', 'g')
  p = substitute(p, '/\+$', '', '')
  return has('win32') ? tolower(p) : p
enddef

def BufferNames(): list<string>
  var out: list<string> = []
  for b in getbufinfo()
    add(out, N(b.name))
  endfor
  return out
enddef

var base = tempname()
mkdir(base)
var p1 = base .. '/proj one'
mkdir(p1)
writefile(['# one'], p1 .. '/README.md')
writefile(['alpha'], p1 .. '/alpha.txt')
var p2 = base .. '/proj-two'
mkdir(p2)
writefile(['# two'], p2 .. '/README.md')
var nonproj = base .. '/outside.txt'
writefile(['outside'], nonproj)

var start = getcwd()

execute 'edit ' .. fnameescape(nonproj)

Check(!empty(maparg('\wo', 'n')), 'default <Leader>wo mapping is defined')
Check(!empty(maparg('\wc', 'n')), 'default <Leader>wc mapping is defined')
Check(!empty(maparg('\we', 'n')), 'default <Leader>we mapping is defined')
Check(!empty(maparg('\wa', 'n')), 'default <Leader>wa mapping is defined')
Check(!empty(maparg('\wt', 'n')), 'default <Leader>wt mapping is defined')
Check(!empty(maparg('\wl', 'n')), 'default <Leader>wl mapping is defined')
Check(!empty(maparg('<F11>', 'n')), 'F11 focus-mode mapping is defined')
Check(!empty(maparg('<F11>', 't')), 'F11 terminal focus-mode mapping is defined')
Check(!empty(maparg('\we', 't')), 'default <Leader>we terminal mapping is defined')
Check(!empty(maparg('\wa', 't')), 'default <Leader>wa terminal mapping is defined')
Check(!empty(maparg('\wt', 't')), 'default <Leader>wt terminal mapping is defined')
Check(!empty(maparg('\wl', 't')), 'default <Leader>wl terminal mapping is defined')

var extcolors = netrwcolors.ExtColorMap()
Check(len(extcolors) >= 40, 'extension colour map covers the curated extensions')
var palette: dict<bool> = {}
for [_, color] in items(extcolors)
  palette[color] = true
endfor
Check(len(palette) >= 40, 'extension colours are mostly distinct')
Check(extcolors['md'] !=# extcolors['py'], 'md and py use different colours')
Check(extcolors['md'] !=# extcolors['js'], 'md and js use different colours')
Check(extcolors['yaml'] !=# extcolors['json'], 'yaml and json use different colours')
Check(extcolors['c'] !=# extcolors['cpp'], 'c and cpp use different colours')
Check(netrwcolors.NameColor('.gitignore') !=# netrwcolors.NameColor('LICENSE'), 'dotfiles and LICENSE differ')

var jsonl = ['{"type":"step_start"}',
      \ '{"type":"text","part":{"id":"p1","type":"text","text":"Add commit helper\n\n- parse the stream"}}']
Check(commitmsg.ParseJsonl(jsonl) ==# "Add commit helper\n\n- parse the stream", 'commit: JSONL stream is parsed')
Check(commitmsg.ParseJsonl(['{"type":"text","part":{"id":"p","type":"text","text":"Build it"}}{"type":"text","part":{"id":"p","type":"text","text":"Build it"}}']) ==# 'Build it', 'commit: concatenated JSON objects are parsed once')
Check(commitmsg.ParseJsonl(['{"type":"text","part":{"id":"p2","type":"text","text":"```\nSubject\n```"}}']) ==# 'Subject', 'commit: code fences are stripped')

if executable('git')
  var crepo = base .. '/commit-repo'
  mkdir(crepo)
  system('git -C ' .. shellescape(crepo) .. ' init -q')
  writefile(['one'], crepo .. '/one.txt')
  system('git -C ' .. shellescape(crepo) .. ' add one.txt')
  Check(!empty(commitmsg.StagedFiles(crepo)), 'commit: staged files are detected')
  var local = commitmsg.LocalMessage(crepo)
  Check(local =~# '^Update', 'commit: local fallback builds a subject')
  Check(local =~# 'one.txt', 'commit: local fallback mentions the file')
endif

Check(netrwcolors.MatchExtText('│ main.py', 'py') ==# 'main.py', 'extension rule covers the whole file name')
Check(netrwcolors.MatchExtText('│ my notes.md', 'md') ==# 'my notes.md', 'names with spaces are fully coloured')
Check(netrwcolors.MatchExtText('│ netrw-demo/', 'md') ==# '', 'directories are not coloured')
Check(netrwcolors.MatchNameText('│ .gitignore', '.gitignore') ==# '.gitignore', 'dotfile rule covers the whole name')
Check(netrwcolors.MatchNameText('│ LICENSE*', 'LICENSE') ==# 'LICENSE', 'executable marker stays outside the match')

project_management.Open(p1)
Check(project_management.project.active, 'project active after open')
Check(N(project_management.project.root) ==# N(p1), 'project root resolves to requested directory')
Check(tabpagenr('$') == 1, 'ProjectOpen does not create a tab')
Check(winnr('$') == 5, 'layout has five windows')
Check(N(getcwd()) ==# N(p1), 'PWD is the project root')

win_gotoid(project_management.project.editor_win)
execute 'edit ' .. fnameescape(p1 .. '/alpha.txt')
Check(N(bufname('%')) ==# N(p1 .. '/alpha.txt'), 'editor opens project file')

project_management.Focus('files')
Check(win_getid() == project_management.project.files_win, 'Focus files moves to the file browser window')
project_management.Focus('opencode')
Check(win_getid() == project_management.project.opencode_win, 'Focus opencode moves to the opencode window')
project_management.Focus('terminal')
Check(win_getid() == project_management.project.terminal_win, 'Focus terminal moves to the terminal window')
project_management.Focus('outline')
Check(win_getid() == project_management.project.outline_win, 'Focus outline moves to the outline window')
project_management.Focus('outline')
Check(win_getid() == project_management.project.editor_win, 'Focus outline toggles back to the editor')
var before_unknown = win_getid()
project_management.Focus('nope')
Check(win_getid() == before_unknown, 'unknown focus target keeps the current window')

win_gotoid(project_management.project.editor_win)
project_management.ToggleFocusMode()
Check(tabpagenr('$') == 2, 'focus mode opens a second tab')
Check(winnr('$') == 1, 'focus mode shows a single window')
Check(project_management.FocusModeActive(), 'focus mode reports active')
Check(N(bufname('%')) ==# N(p1 .. '/alpha.txt'), 'focus mode keeps the editor buffer')
project_management.ToggleFocusMode()
Check(tabpagenr('$') == 1, 'focus mode closes its tab')
Check(winnr('$') == 5, 'focus mode restores the project layout')
Check(win_getid() == project_management.project.editor_win, 'focus mode returns to the editor window')
win_gotoid(project_management.project.editor_win)

var ok = project_management.Close(false)
Check(ok, 'ProjectClose returns true')
Check(winnr('$') == 1, 'ProjectClose leaves one window')
Check(tabpagenr('$') == 1, 'ProjectClose leaves one tab')
Check(bufname('%') == '', 'ProjectClose leaves an empty default buffer')
Check(N(getcwd()) ==# N(start), 'ProjectClose restores startup PWD')

var after_close = BufferNames()
Check(index(after_close, N(nonproj)) >= 0, 'non-project buffer is preserved')
Check(index(after_close, N(p1 .. '/alpha.txt')) < 0, 'project buffer is wiped')
Check(index(after_close, N(p1 .. '/README.md')) < 0, 'initial project buffer is wiped')

project_management.Open(p1)
project_management.Reload()
Check(winnr('$') == 5, 'ProjectReload rebuilds the layout')
project_management.Close(false)
Check(winnr('$') == 1, 'close after reload leaves one window')

execute 'cd ' .. fnameescape(p2)
project_management.Open('')
Check(N(project_management.project.root) ==# N(p2), 'ProjectOpen without arguments uses PWD')
project_management.Close(true)
Check(winnr('$') == 1, 'ProjectClose! leaves one window')
Check(tabpagenr('$') == 1, 'ProjectClose! leaves one tab')
Check(bufname('%') == '', 'ProjectClose! leaves an empty default buffer')
Check(N(getcwd()) ==# N(start), 'ProjectClose! restores startup PWD')
Check(len(BufferNames()) == 1, 'ProjectClose! wipes all buffers')

project_management.Open(p1)
project_management.Open(base .. '/missing')
Check(N(project_management.project.root) ==# N(p1), 'invalid path keeps the current project')
project_management.Close(true)

execute 'cd ' .. fnameescape(start)

var result = getenv('PM_TEST_RESULT')
if type(result) != v:t_string || result == ''
  result = base .. '/result.txt'
endif

if empty(failures)
  writefile(['PASS'], result)
  execute 'qall!'
else
  writefile(failures, result)
  cquit
endif
