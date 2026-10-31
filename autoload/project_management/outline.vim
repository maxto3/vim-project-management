vim9script

export def SaveConfig(): string
  if exists('g:coc_user_config')
    return get(g:coc_user_config, 'outline.splitCommand', 'botright 30vs')
  endif
  return 'botright 30vs'
enddef

export def SetSplit(cmd: string): void
  if !exists('g:did_coc_loaded')
    return
  endif
  try
    g:coc_user_config['outline.splitCommand'] = cmd
    coc#config('outline.splitCommand', cmd)
  catch
  endtry
enddef

export def SaveCheckBufferSwitch(): bool
  if exists('g:coc_user_config')
    return get(g:coc_user_config, 'outline.checkBufferSwitch', true)
  endif
  return true
enddef

export def SetCheckBufferSwitch(value: bool): void
  if !exists('g:did_coc_loaded')
    return
  endif
  try
    g:coc_user_config['outline.checkBufferSwitch'] = value
    coc#config('outline.checkBufferSwitch', value)
  catch
  endtry
enddef

# Open the coc outline inside the given target window without creating a new
# split. The target window is temporarily pointed at the editor buffer so coc
# can resolve the document symbols, then coc replaces it with the tree buffer.
# The project sets outline.splitCommand to "edit" while it is active so coc
# opens in the current window instead of a new right-hand column.
export def ShowInWindow(editor_win: number, target_win: number): number
  if !exists('g:did_coc_loaded')
    return 0
  endif
  if target_win <= 0 || win_id2win(target_win) == 0
    return 0
  endif
  if editor_win <= 0 || win_id2win(editor_win) == 0
    return 0
  endif

  var existing = coc#window#find('cocViewId', 'OUTLINE')
  if existing > 0 && existing != target_win && win_id2win(existing) > 0
    try
      win_execute(existing, 'close!', 'silent!')
    catch
    endtry
  endif

  if target_win <= 0 || win_id2win(target_win) == 0
    return 0
  endif
  win_gotoid(target_win)
  if win_getid() != target_win
    return 0
  endif
  execute 'silent buffer ' .. winbufnr(editor_win)

  try
    call('CocAction', ['showOutline', 1])
  catch
    return 0
  endtry

  var winid = coc#window#find('cocViewId', 'OUTLINE')
  if winid > 0 && winid != target_win
    try
      win_execute(winid, 'close!', 'silent!')
    catch
    endtry
    return 0
  endif
  return winid > 0 ? winid : 0
enddef

export def Close(): void
  if !exists('g:did_coc_loaded')
    return
  endif
  try
    var winid = coc#window#find('cocViewId', 'OUTLINE')
    if winid > 0
      win_execute(winid, 'close!', 'silent!')
    endif
  catch
  endtry
enddef
