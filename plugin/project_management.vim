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

def OnNetrw()
  project_management.NetrwSetup()
enddef

augroup project_management_netrw
  autocmd!
  autocmd FileType netrw call OnNetrw()
augroup END

project_management.Init()
