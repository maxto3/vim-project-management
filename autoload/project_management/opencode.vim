vim9script

export def Start(root: string, args: list<string> = []): number
  var exe = get(g:, 'project_management_opencode_cmd', 'opencode')
  if type(exe) != v:t_string
    exe = 'opencode'
  endif
  if !executable(exe)
    return -1
  endif

  var cmd: list<string>
  if has('win32') && exe !~? '\.exe$'
    cmd = ['cmd', '/c', exe]
  else
    cmd = [exe]
  endif
  cmd += args

  # The project opencode panel follows the Vim colorscheme through the global
  # CLI config: _vimrc generates ~/.config/opencode/themes/gvim.json from the
  # active highlight groups and points cli.json at it.  Passing the theme via
  # OPENCODE_CLI_CONFIG_CONTENT does not work here: with an inline config the
  # TUI cannot resolve custom theme files and silently falls back to a built-in.
  var buf = term_start(cmd, {
    cwd: root,
    curwin: true,
    term_name: 'opencode',
  })
  setbufvar(buf, '&buflisted', 0)
  setbufvar(buf, '&bufhidden', 'hide')
  setlocal nonumber norelativenumber signcolumn=no
  setlocal winfixwidth
  # Esc is passed to opencode by default so its dialogs and prompts work.
  # Set g:project_management_opencode_esc = 'normal' to make Esc enter
  # Terminal-Normal instead.
  if get(g:, 'project_management_opencode_esc', 'app') ==# 'normal'
    tnoremap <buffer><silent> <Esc> <C-\><C-N>
  endif
  return buf
enddef

export def Stop(bufnr: number): void
  if bufnr <= 0 || !bufexists(bufnr)
    return
  endif
  Terminate(bufnr)
  execute 'silent! bwipeout! ' .. bufnr
enddef

def Terminate(bufnr: number): void
  var job = term_getjob(bufnr)
  if type(job) == v:t_job
    try
      job_stop(job, 'kill')
    catch
    endtry
  endif
enddef
