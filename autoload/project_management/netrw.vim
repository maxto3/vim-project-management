vim9script

# Per-extension highlighting for the project file browser.  netrw itself only
# distinguishes directories, symlinks and executables, so the project browser
# adds matchadd() rules on top of the netrw syntax.
#
# Colours are generated instead of borrowed from highlight groups: linking to
# groups such as Comment/Constant collapses 55 extensions onto 9 colours and
# some of them (Function, Special) are identical to the Normal text colour.
#
# The hue comes from the extension itself, so a given extension always keeps
# its colour:
#   * curated extensions are ordered by how common they are and spread with the
#     golden angle (137.508 degrees), which keeps neighbours far apart;
#   * everything else gets a stable hash hue.
# Saturation and lightness follow the current Normal background, so the palette
# stays readable when the colorscheme changes.

# Ordered by how often the extension shows up in a project tree.
const CURATED: list<string> = [
  'md', 'py', 'js', 'json', 'ts', 'yaml', 'yml', 'toml', 'c', 'h',
  'cpp', 'hpp', 'java', 'go', 'rs', 'sh', 'ps1', 'vim', 'html', 'css',
  'scss', 'sql', 'lua', 'php', 'xml', 'ini', 'conf', 'env', 'txt', 'rst',
  'tsx', 'jsx', 'cs', 'kt', 'swift', 'rb', 'pl', 'r', 'jl', 'dart',
  'scala', 'clj', 'ex', 'exs', 'erl', 'hs', 'ml', 'nim', 'zig', 'cmake',
  'mk', 'bat', 'cmd', 'psm1', 'psd1', 'gradle', 'kts', 'properties', 'lock', 'log',
  'png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'pdf', 'zip', 'gz', 'tar',
  '7z', 'rar', 'csv', 'db', 'sqlite', 'woff', 'ttf', 'otf',
]

# Files without a usable extension, or where the name is more meaningful.
const NAMES: list<string> = [
  '.gitignore', '.gitattributes', '.gitmodules', '.editorconfig', '.env',
  '.npmrc', '.prettierrc', '.eslintrc', '.babelrc', '.dockerignore',
  '.mailmap', '.vimrc', 'LICENSE', 'README', 'Makefile', 'Dockerfile',
  'CMakeLists.txt', 'gradlew', 'mvnw', 'Procfile', 'Vagrantfile',
  'Jenkinsfile', 'Cargo.toml', 'Cargo.lock', 'go.mod', 'go.sum',
]

const GOLDEN_ANGLE = 137.508

def HexToRgb(hex: string): list<number>
  if len(hex) < 7 || hex[0] != '#'
    return [208, 208, 208]
  endif
  return [
    str2nr(hex[1 : 2], 16),
    str2nr(hex[3 : 4], 16),
    str2nr(hex[5 : 6], 16),
  ]
enddef

def HslToRgb(hue: float, sat: float, light: float): string
  var c = (1.0 - abs(2.0 * light - 1.0)) * sat
  var hp = hue / 60.0
  var x = c * (1.0 - abs(fmod(hp, 2.0) - 1.0))
  var r = 0.0
  var g = 0.0
  var b = 0.0
  if hp < 1.0
    r = c
    g = x
  elseif hp < 2.0
    r = x
    g = c
  elseif hp < 3.0
    g = c
    b = x
  elseif hp < 4.0
    g = x
    b = c
  elseif hp < 5.0
    r = x
    b = c
  else
    r = c
    b = x
  endif
  var m = light - c / 2.0
  return printf('#%02x%02x%02x',
    float2nr(round((r + m) * 255.0)),
    float2nr(round((g + m) * 255.0)),
    float2nr(round((b + m) * 255.0)))
enddef

def RgbToCterm(rgb: list<number>): number
  var r = rgb[0]
  var g = rgb[1]
  var b = rgb[2]
  if r == g && g == b
    if r < 8
      return 16
    endif
    if r > 248
      return 231
    endif
    return 232 + float2nr(round((r - 8) / 247.0 * 24.0))
  endif
  var ri = float2nr(round(r / 255.0 * 5.0))
  var gi = float2nr(round(g / 255.0 * 5.0))
  var bi = float2nr(round(b / 255.0 * 5.0))
  return 16 + 36 * ri + 6 * gi + bi
enddef

def HashHue(key: string): number
  var h = 7
  for i in range(strlen(key))
    h = (h * 31 + char2nr(strpart(key, i, 1))) % 360
  endfor
  return h
enddef

def HueFor(key: string, curated: list<string>): float
  var idx = index(curated, key)
  if idx >= 0
    return fmod(idx * GOLDEN_ANGLE, 360.0)
  endif
  return str2float(string(HashHue(key)))
enddef

def Style(): dict<any>
  var bg = synIDattr(synIDtrans(hlID('Normal')), 'bg#', 'gui')
  if bg == '' || bg == 'NONE'
    bg = &background ==# 'light' ? '#ffffff' : '#000000'
  endif
  var rgb = HexToRgb(bg)
  var lum = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
  var dark = lum < 128
  return {
    sat: dark ? 0.55 : 0.60,
    tiers: dark ? [0.70, 0.78, 0.85] : [0.32, 0.40, 0.46],
  }
enddef

def MakeColor(key: string, curated: list<string>): string
  var style = Style()
  var hue = HueFor(key, curated)
  var tiers: list<float> = style.tiers
  var tier = HashHue(key) % len(tiers)
  return HslToRgb(hue, style.sat, tiers[tier])
enddef

# Like MakeColor(), but rotates the hue until the colour is unused in this
# window, so two visible entries never share a colour.
def UniqueColor(key: string, curated: list<string>, used: dict<bool>): string
  var style = Style()
  var tiers: list<float> = style.tiers
  var tier = HashHue(key) % len(tiers)
  var base = HueFor(key, curated)
  var offset = 0.0
  while offset < 360.0
    var color = HslToRgb(fmod(base + offset, 360.0), style.sat, tiers[tier])
    if !has_key(used, color)
      used[color] = true
      return color
    endif
    offset += 13.0
  endwhile
  var color = HslToRgb(base, style.sat, tiers[tier])
  used[color] = true
  return color
enddef

# Colour for a file extension (without the dot).
export def ExtColor(ext: string): string
  return MakeColor(tolower(ext), CURATED)
enddef

# Colour for a well-known file name (dotfiles, LICENSE, Makefile, ...).
export def NameColor(name: string): string
  return MakeColor(name, NAMES)
enddef

# Extension -> colour map for the whole curated list; used by tests and docs.
export def ExtColorMap(): dict<string>
  var out: dict<string> = {}
  for ext in CURATED
    out[ext] = ExtColor(ext)
  endfor
  return out
enddef

def ApplyGroup(group: string, color: string): void
  var rgb = HexToRgb(color)
  execute printf('highlight %s guifg=%s ctermfg=%d', group, color, RgbToCterm(rgb))
enddef

# Match the whole file name, from the character after the netrw tree prefix to
# the end of the line, so the entire name (not just the extension) is coloured.
# The prefix is made of box-drawing characters, spaces, '+' and '-'.
const PREFIX = '\c^[│|`+ \t-]*\zs'

def Escape(key: string): string
  return escape(key, '\.^$~[]*+?(){}|')
enddef

# The name must end with ".ext"; the netrw marker for executables (*) or
# symlinks (@) may follow it.
def ExtPattern(ext: string): string
  return PREFIX .. '.\{-}\.' .. Escape(ext) .. '\ze[*@]\=\s*$'
enddef

# Same, but for a literal file name such as .gitignore or Makefile.
def NamePattern(name: string): string
  return PREFIX .. Escape(name) .. '\ze[*@]\=\s*$'
enddef

# Test hooks: return the text the highlight would cover.
export def MatchExtText(line: string, ext: string): string
  return matchstr(line, ExtPattern(ext))
enddef

export def MatchNameText(line: string, name: string): string
  return matchstr(line, NamePattern(name))
enddef

def CleanEntry(line: string): string
  var name = substitute(line, '^\s*[-+|│` ]*\s*', '', '')
  name = substitute(name, '[*@]\=\s*$', '', '')
  name = substitute(name, '\s\+$', '', '')
  return name
enddef

def Collect(overrides: dict<string>): dict<any>
  var exts: dict<bool> = {}
  var names: dict<bool> = {}
  for line in getline(1, '$')
    var name = CleanEntry(line)
    if name == '' || name == '../' || name =~# '/$'
      continue
    endif
    if index(NAMES, name) >= 0
      names[name] = true
      continue
    endif
    var ext = tolower(fnamemodify(name, ':e'))
    if ext != ''
      exts[ext] = true
    endif
  endfor
  # Configured groups always get a rule, even when no such file is visible.
  for ext in keys(overrides)
    exts[substitute(ext, '^\.', '', '')] = true
  endfor
  return {exts: exts, names: names}
enddef

export def ApplyColors(): void
  # Only the project file-browser window calls this, after NetrwSetup checks
  # that the project is active and this is the files window.
  var old = get(w:, 'project_netrw_match_ids', [])
  for id in old
    silent! matchdelete(id)
  endfor
  w:project_netrw_match_ids = []

  var overrides: dict<string> = get(g:, 'project_management_netrw_ext_groups', {})
  var found = Collect(overrides)
  var ids: list<number> = []
  var used: dict<bool> = {}

  for ext in sort(keys(found.exts))
    var group = 'ProjectNetrwExt' .. substitute(ext, '[^A-Za-z0-9]', '', 'g')
    if has_key(overrides, ext)
      # Backwards compatibility: an explicit highlight group wins.
      var target = synIDattr(synIDtrans(hlID(overrides[ext])), 'fg#', 'gui')
      if target != '' && target != 'NONE'
        ApplyGroup(group, target)
        used[target] = true
      else
        execute 'highlight clear ' .. group
        execute 'highlight default link ' .. group .. ' ' .. overrides[ext]
      endif
    else
      ApplyGroup(group, UniqueColor(ext, CURATED, used))
    endif
    try
      add(ids, matchadd(group, ExtPattern(ext), 10))
    catch
      # An invalid custom group or pattern must not break the browser.
    endtry
  endfor

  for name in sort(keys(found.names))
    var group = 'ProjectNetrwName' .. substitute(name, '[^A-Za-z0-9]', '', 'g')
    ApplyGroup(group, UniqueColor(name, NAMES, used))
    try
      add(ids, matchadd(group, NamePattern(name), 10))
    catch
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
