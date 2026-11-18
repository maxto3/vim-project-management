vim9script

if exists('g:loaded_project_management')
  finish
endif
g:loaded_project_management = 1

import autoload 'project_management.vim'

command! -nargs=? -complete=dir ProjectOpen project_management.Open(<q-args>)
command! -bang ProjectClose project_management.Close(<bang>0)
command! ProjectReload project_management.Reload()
command! ProjectStatus project_management.Status()
command! ProjectOutline project_management.Outline()
command! ProjectToggleOutline project_management.ToggleOutline()
command! ProjectNetrwEnter project_management.NetrwEnter()
command! ProjectFocusOutline project_management.FocusOutline()
command! -nargs=1 ProjectFocus project_management.Focus(<q-args>)
command! ProjectFocusMode project_management.ToggleFocusMode()
command! ProjectCommit project_management.Commit()
command! ProjectCommitAccept project_management.CommitAccept()
command! ProjectCommitAbort project_management.CommitAbort()

# Default workspace mappings. Set g:project_management_default_mappings = 0
# before the plugin loads to define your own keys instead.
if get(g:, 'project_management_default_mappings', 1)
  nnoremap <silent> <Leader>wo <Cmd>ProjectOpen<CR>
  nnoremap <silent> <Leader>wc <Cmd>ProjectClose<CR>
  nnoremap <silent> <Leader>we <Cmd>ProjectFocus files<CR>
  nnoremap <silent> <Leader>wa <Cmd>ProjectFocus opencode<CR>
  nnoremap <silent> <Leader>wt <Cmd>ProjectFocus terminal<CR>
  nnoremap <silent> <Leader>wl <Cmd>ProjectFocus outline<CR>
  # The same keys work from inside the project terminals (Terminal-Job mode),
  # so the panels can be switched without leaving the terminal first.
  tnoremap <silent> <Leader>we <Cmd>ProjectFocus files<CR>
  tnoremap <silent> <Leader>wa <Cmd>ProjectFocus opencode<CR>
  tnoremap <silent> <Leader>wt <Cmd>ProjectFocus terminal<CR>
  tnoremap <silent> <Leader>wl <Cmd>ProjectFocus outline<CR>
  # F11: focus mode - a single tab with only the editor buffer.
  nnoremap <silent> <F11> <Cmd>ProjectFocusMode<CR>
  tnoremap <silent> <F11> <Cmd>ProjectFocusMode<CR>
  # Commit message generation for the staged changes.
  nnoremap <silent> <Leader>gc <Cmd>ProjectCommit<CR>
  tnoremap <silent> <Leader>gc <Cmd>ProjectCommit<CR>
endif

def OnNetrw()
  project_management.NetrwSetup()
enddef

def OnEditorBufEnter()
  project_management.OnEditorBufEnter()
enddef

def OnColorScheme()
  project_management.RefreshNetrwColors()
enddef

# Called from win_execute() so the refresh runs in the browser window.
def g:ProjectNetrwRecolor()
  project_management.NetrwSetup()
enddef

augroup project_management_netrw
  autocmd!
  autocmd FileType netrw call OnNetrw()
  autocmd ColorScheme * call OnColorScheme()
augroup END

augroup project_management_editor
  autocmd!
  autocmd BufEnter * call OnEditorBufEnter()
augroup END

project_management.Init()
