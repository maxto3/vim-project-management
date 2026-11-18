vim9script

# AI-assisted commit messages for the project workspace.
#
# Flow: :ProjectCommit collects the staged diff, asks `opencode run` for an
# English, itemised message, and opens it in a new tab.  In that buffer
# <Leader>gk commits the staged changes, <Leader>gq discards the message.
# When the model is unavailable (no executable, timeout, non-zero exit, empty
# output) a deterministic local template is used instead, so a commit is always
# possible.

var state: dict<any> = {}

def Config(): dict<any>
  return {
    model: get(g:, 'project_management_commit_model', 'opencode-go/deepseek-v4.1-flash'),
    ai: get(g:, 'project_management_commit_ai', 1),
    max_diff: get(g:, 'project_management_commit_max_diff', 400),
    timeout: get(g:, 'project_management_commit_timeout', 60),
  }
enddef

def Git(root: string, args: list<string>): list<string>
  return systemlist(['git', '-C', root] + args)
enddef

export def StagedFiles(root: string): list<string>
  return filter(Git(root, ['diff', '--cached', '--name-only']), 'v:val != ""')
enddef

def StagedStat(root: string): list<string>
  return Git(root, ['diff', '--cached', '--stat'])
enddef

def StagedDiff(root: string, max: number): string
  var lines = Git(root, ['diff', '--cached', '--unified=1'])
  if len(lines) > max
    lines = lines[: max - 1] + ['... (truncated)']
  endif
  return join(lines, "\n")
enddef

def Numstat(root: string): dict<any>
  var files = 0
  var added = 0
  var removed = 0
  for line in Git(root, ['diff', '--cached', '--numstat'])
    var parts = split(line, "\t")
    if len(parts) < 3
      continue
    endif
    files += 1
    if parts[0] =~# '^\d\+$'
      added += str2nr(parts[0])
    endif
    if parts[1] =~# '^\d\+$'
      removed += str2nr(parts[1])
    endif
  endfor
  return {files: files, added: added, removed: removed}
enddef

# Deterministic fallback: one bullet per top-level area.
export def LocalMessage(root: string): string
  var files = StagedFiles(root)
  if empty(files)
    return ''
  endif
  var summary = Numstat(root)
  var areas: dict<number> = {}
  for file in files
    var parts = split(substitute(file, '\\', '/', 'g'), '/')
    var area = len(parts) > 1 ? parts[0] .. '/' : parts[0]
    areas[area] = get(areas, area, 0) + 1
  endfor
  var subject = summary.files == 1
    ? 'Update ' .. fnamemodify(files[0], ':t')
    : 'Update ' .. summary.files .. ' files'
  var lines = [subject, '']
  for [area, count] in items(areas)
    add(lines, printf('- %s (%d file%s)', area, count, count == 1 ? '' : 's'))
  endfor
  return join(lines, "\n")
enddef

# Split a stream of concatenated JSON objects.  opencode run adds newlines only
# when stdout is a terminal, so the pipe delivers "}{" boundaries.
def SplitJson(text: string): list<string>
  var out: list<string> = []
  var depth = 0
  var in_str = false
  var esc = false
  var start = -1
  var i = 0
  while i < strlen(text)
    var ch = text[i]
    if in_str
      if esc
        esc = false
      elseif ch == '\'
        esc = true
      elseif ch == '"'
        in_str = false
      endif
    elseif ch == '"'
      in_str = true
    elseif ch == '{'
      if depth == 0
        start = i
      endif
      depth += 1
    elseif ch == '}'
      depth -= 1
      if depth == 0 && start >= 0
        add(out, strpart(text, start, i - start + 1))
        start = -1
      endif
    endif
    i += 1
  endwhile
  return out
enddef

# Parse the JSONL stream printed by `opencode run --format json`.
# 2.2.x emits {"type":"text","part":{"text":...}}; 2.3.x wraps the same part in
# message.part.updated events, so collect text parts by id and keep the last
# value of each.
export def ParseJsonl(chunks: list<string>): string
  var order: list<string> = []
  var parts: dict<string> = {}
  var plain = ''
  for clean in SplitJson(join(chunks, ''))
    var obj: any = null
    try
      obj = json_decode(clean)
    catch
      continue
    endtry
    if type(obj) != v:t_dict
      continue
    endif
    var part = get(obj, 'part', {})
    if type(part) != v:t_dict || get(part, 'type', '') !=# 'text'
      if get(obj, 'type', '') ==# 'text'
        plain ..= get(obj, 'text', '')
      endif
      continue
    endif
    var id = get(part, 'id', '')
    if id == ''
      plain ..= get(part, 'text', '')
      continue
    endif
    if !has_key(parts, id)
      add(order, id)
    endif
    parts[id] = get(part, 'text', '')
  endfor
  var text = plain
  for id in order
    text ..= parts[id]
  endfor
  return CleanMessage(text)
enddef

def CleanMessage(text: string): string
  var msg = substitute(text, '\r', '', 'g')
  msg = substitute(msg, '^```[a-zA-Z]*\n', '', '')
  msg = substitute(msg, '\n```\s*$', '', '')
  var lines = split(msg, "\n")
  while !empty(lines) && lines[0] =~# '^\s*$'
    remove(lines, 0)
  endwhile
  while !empty(lines) && lines[-1] =~# '^\s*$'
    remove(lines, -1)
  endwhile
  return join(lines, "\n")
enddef

def Debug(lines: list<string>): void
  if !get(g:, 'project_management_commit_debug', 0)
    return
  endif
  writefile(lines, expand('~/.vim/tmp/commit-debug.txt'), 'a')
enddef

def TempDir(): string
  var dir = expand('~/.vim/tmp')
  if !isdirectory(dir)
    mkdir(dir, 'p')
  endif
  return dir
enddef

def WriteContext(root: string, file: string): void
  var cfg = Config()
  var lines = [
    'Write a professional English commit message for the git changes below.',
    'Rules:',
    '- subject line <= 50 characters, imperative mood, no trailing period',
    '- blank line, then 2-5 concise bullet points starting with "- "',
    '- group related changes and describe user-visible behaviour',
    '- output only the message: no code fences, no explanations',
    '- do not run commands or inspect the repository',
    '',
    'STAGED FILES:',
    join(StagedFiles(root), "\n"),
    '',
    'STAT:',
    join(StagedStat(root), "\n"),
    '',
    'DIFF:',
    StagedDiff(root, cfg.max_diff),
  ]
  writefile(lines, file)
enddef

# npm installs opencode as a .cmd shim, which CreateProcess cannot start.
# Prefer the real executable next to the shim.
def ResolveOpencode(): string
  var direct = exepath('opencode.exe')
  if direct != ''
    return direct
  endif
  var shim = exepath('opencode')
  if shim == ''
    return ''
  endif
  if shim =~? '\.exe$'
    return shim
  endif
  var candidate = fnamemodify(shim, ':h') .. '/node_modules/@opencode/cli/bin/opencode.exe'
  if filereadable(candidate)
    return candidate
  endif
  return shim
enddef

def BuildCommand(cfg: dict<any>, context: string): list<string>
  var exe = ResolveOpencode()
  if exe == ''
    return []
  endif
  var args = ['run', '--format', 'json', '-m', cfg.model,
    '--file', context,
    'Write the commit message from the attached file. Do not run commands or read other files. Output only the message.']
  if has('win32') && exe =~? '\.\(cmd\|bat\)$'
    return ['cmd', '/c', exe] + args
  endif
  return [exe] + args
enddef

def WriteMessage(text: string): void
  if get(state, 'ctx', '') != '' && filereadable(state.ctx)
    delete(state.ctx)
  endif
  writefile(split(text, "\n"), state.msg)
  OpenMessage()
enddef

def OpenMessage(): void
  execute 'tabnew ' .. fnameescape(state.msg)
  setlocal filetype=gitcommit
  b:project_commit_msg = state.msg
  b:project_commit_root = state.root
  nnoremap <buffer><silent> <Leader>gk <Cmd>ProjectCommitAccept<CR>
  nnoremap <buffer><silent> <Leader>gq <Cmd>ProjectCommitAbort<CR>
  execute 'autocmd BufWipeout <buffer> silent! call delete(' .. string(state.msg) .. ')'
  echomsg 'Review the message: <Leader>gk commits, <Leader>gq aborts'
enddef

def StopJob(): void
  if !has_key(state, 'job') || type(state.job) != v:t_job
    return
  endif
  if job_status(state.job) ==# 'run'
    state.timed_out = true
    job_stop(state.job, 'kill')
  endif
enddef

def OnExit(code: number): void
  if get(state, 'done', false)
    return
  endif
  state.done = true
  if get(state, 'timer', 0) > 0
    timer_stop(state.timer)
    state.timer = 0
  endif
  Debug(['exit=' .. code, 'raw=' .. join(get(state, 'out', []), '')])
  var text = ParseJsonl(get(state, 'out', []))
  if text == ''
    text = LocalMessage(state.root)
  endif
  if text == ''
    echomsg 'project-management: cannot build a commit message (git exit ' .. code .. ')'
    return
  endif
  WriteMessage(text)
enddef

export def Start(root: string): void
  if root == '' || !isdirectory(root)
    echomsg 'project-management: no project root'
    return
  endif
  if empty(StagedFiles(root))
    echomsg 'project-management: nothing staged; run "git add" first'
    return
  endif

  var cfg = Config()
  var stamp = strftime('%Y%m%d-%H%M%S')
  var dir = TempDir()
  state = {
    root: root,
    ctx: dir .. '/commit-ctx-' .. stamp .. '.txt',
    msg: dir .. '/commit-msg-' .. stamp .. '.txt',
    job: v:null,
    timer: 0,
    out: [],
    done: false,
    timed_out: false,
  }

  if !cfg.ai
    WriteMessage(LocalMessage(root))
    return
  endif

  var cmd = BuildCommand(cfg, state.ctx)
  if empty(cmd)
    WriteMessage(LocalMessage(root))
    return
  endif

  WriteContext(root, state.ctx)
  echomsg 'project-management: generating commit message…'
  state.job = job_start(cmd, {
    cwd: root,
    in_io: 'null',
    out_cb: (ch, msg) => add(state.out, msg),
    err_cb: (ch, msg) => add(state.out, msg),
    exit_cb: (j, code) => OnExit(code),
  })
  Debug(['cmd=' .. string(cmd)])
  if job_status(state.job) ==# 'fail'
    state.job = v:null
    WriteMessage(LocalMessage(root))
    return
  endif
  state.timer = timer_start(cfg.timeout * 1000, (_) => StopJob())
enddef

# Commit the staged changes using the message in the current buffer.
export def Accept(): void
  var file = get(b:, 'project_commit_msg', '')
  var root = get(b:, 'project_commit_root', '')
  if file == '' || root == '' || !filereadable(file)
    echomsg 'project-management: not a commit message buffer'
    return
  endif
  silent write
  var out = systemlist(['git', '-C', root, 'commit', '-F', file])
  if v:shell_error != 0
    echomsg 'project-management: commit failed: ' .. join(out, ' ')
    return
  endif
  var summary = systemlist(['git', '-C', root, 'log', '-1', '--oneline'])
  b:project_commit_msg = ''
  execute 'tabclose'
  if filereadable(file)
    delete(file)
  endif
  echomsg 'project-management: committed ' .. get(summary, 0, '')
enddef

# Discard the generated message.
export def Abort(): void
  var file = get(b:, 'project_commit_msg', '')
  b:project_commit_msg = ''
  if tabpagenr('$') > 1
    execute 'tabclose'
  endif
  if file != '' && filereadable(file)
    delete(file)
  endif
  echomsg 'project-management: commit aborted'
enddef
