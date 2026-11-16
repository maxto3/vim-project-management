vim9script

# Per-extension highlighting for the project file browser.  netrw itself only
# distinguishes directories, symlinks and executables, so the project browser
# adds matchadd() rules on top of the netrw syntax.

const DEFAULT_EXT_GROUPS: dict<string> = {
  py: 'Identifier',
  js: 'Statement', jsx: 'Statement', ts: 'Statement', tsx: 'Statement',
  json: 'Constant', jsonc: 'Constant',
  yaml: 'Constant', yml: 'Constant', toml: 'Constant',
  md: 'Comment', markdown: 'Comment', txt: 'Comment', rst: 'Comment',
  sh: 'Function', bash: 'Function', zsh: 'Function',
  ps1: 'Function', psm1: 'Function', psd1: 'Function',
  vim: 'Type',
  c: 'PreProc', h: 'PreProc', cpp: 'PreProc', cc: 'PreProc', hpp: 'PreProc',
  go: 'String',
  rs: 'Special',
  java: 'Label', cs: 'Label',
  html: 'Number', css: 'Number', scss: 'Number', less: 'Number',
  sql: 'Macro', lua: 'Operator', php: 'Exception',
  xml: 'Define', xsd: 'Define', xsl: 'Define',
  cmake: 'Delimiter', mk: 'Delimiter',
  ini: 'Constant', conf: 'Constant', env: 'Constant',
  png: 'Special', jpg: 'Special', jpeg: 'Special', gif: 'Special',
  svg: 'Special', ico: 'Special', pdf: 'Special',
  zip: 'Comment', gz: 'Comment', tar: 'Comment',
}

def Pattern(ext: string): string
  var escaped = escape(ext, '\.^$~[]*+?(){}|')
  return '\c^\%(\%([-+|│]\s*\)\+\s*\)\?\zs\%(\S\+ \)*\S\+\.'
    .. escaped
    .. '\ze\%([*@]\=\s*\)$'
enddef

export def ApplyColors(): void
  # Only the project file-browser window calls this, after NetrwSetup checks
  # that the project is active and this is the files window.
  var old = get(w:, 'project_netrw_match_ids', [])
  for id in old
    silent! matchdelete(id)
  endfor
  w:project_netrw_match_ids = []

  var configured: dict<string> = get(g:, 'project_management_netrw_ext_groups', {})
  var groups: dict<string> = copy(DEFAULT_EXT_GROUPS)
  extend(groups, configured)

  var ids: list<number> = []
  for [ext, group] in items(groups)
    var name = substitute(printf('%s', ext), '^\.', '', '')
    var target = printf('%s', group)
    if empty(name) || empty(target)
      continue
    endif
    var hl = 'ProjectNetrwExt' .. substitute(name, '[^A-Za-z0-9]', '', 'g')
    if empty(hl)
      continue
    endif
    execute 'highlight default link ' .. hl .. ' ' .. target
    try
      add(ids, matchadd(hl, Pattern(name), 10))
    catch
      # An invalid custom group or pattern must not break the browser.
    endtry
  endfor
  w:project_netrw_match_ids = ids
enddef

export def ClearColors(): void
  for id in get(w:, 'project_netrw_match_ids', [])
    silent! matchdelete(id)
  endfor
  w:project_netrw_match_ids = []
enddef
