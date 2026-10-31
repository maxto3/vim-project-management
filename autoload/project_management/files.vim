vim9script

export def SaveConfig(): dict<any>
  return {
    browse_split: get(g:, 'netrw_browse_split', 0),
    banner: get(g:, 'netrw_banner', 1),
    liststyle: get(g:, 'netrw_liststyle', 0),
    winsize: get(g:, 'netrw_winsize', 0),
  }
enddef

export def ApplyConfig(): void
  g:netrw_browse_split = 4
  g:netrw_banner = 0
  g:netrw_liststyle = 3
enddef

export def RestoreConfig(saved: dict<any>): void
  g:netrw_browse_split = get(saved, 'browse_split', 0)
  g:netrw_banner = get(saved, 'banner', 1)
  g:netrw_liststyle = get(saved, 'liststyle', 0)
  g:netrw_winsize = get(saved, 'winsize', 0)
enddef

export def Open(root: string): void
  if exists(':Explore') != 2
    runtime! plugin/netrwPlugin.vim
  endif
  execute 'Explore ' .. fnameescape(root)
  setlocal nobuflisted
  setlocal bufhidden=hide
  setlocal nonumber norelativenumber signcolumn=no
  setlocal nowrap
enddef
