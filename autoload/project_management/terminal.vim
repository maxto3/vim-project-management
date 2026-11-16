vim9script

export def Start(root: string): number
  var shell = get(g:, 'project_management_shell', '')
  if type(shell) != v:t_string || shell == ''
    shell = &shell
  endif

  var buf = term_start(shell, {
    cwd: root,
    curwin: true,
    term_name: 'project-terminal',
  })
  setbufvar(buf, '&buflisted', 0)
  setbufvar(buf, '&bufhidden', 'hide')
  setlocal nonumber norelativenumber signcolumn=no
  setlocal winfixheight
  # Keep Esc for Terminal-Normal by default; set
  # g:project_management_terminal_esc = 'app' to pass it to the shell job.
  if get(g:, 'project_management_terminal_esc', 'normal') ==# 'normal'
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
