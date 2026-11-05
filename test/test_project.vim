vim9script

import autoload 'project_management.vim'

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

project_management.Open(p1)
Check(project_management.project.active, 'project active after open')
Check(N(project_management.project.root) ==# N(p1), 'project root resolves to requested directory')
Check(tabpagenr('$') == 1, 'ProjectOpen does not create a tab')
Check(winnr('$') == 5, 'layout has five windows')
Check(N(getcwd()) ==# N(p1), 'PWD is the project root')

win_gotoid(project_management.project.editor_win)
execute 'edit ' .. fnameescape(p1 .. '/alpha.txt')
Check(N(bufname('%')) ==# N(p1 .. '/alpha.txt'), 'editor opens project file')

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
