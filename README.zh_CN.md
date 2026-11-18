# project-management

Vim 9 / GVim 的 VS Code 风格项目工作区，使用 Vim9 script 编写。

```
+------------+-------------------------------+------------------+
|            |                               | 文件浏览器       |
|  opencode  |          编辑器               | (netrw, 上)      |
|  (左侧)    |                               |------------------|
|            |                               | outline (下)     |
+------------+-------------------------------+------------------+
|                    终端（项目根目录）                          |
+-----------------------------------------------------------------+
```

## 功能

- `:ProjectOpen [path]` 在当前 tab 打开项目，不创建 Vim tab。
- 中间窗口是唯一的编辑窗口。文件浏览器选择的文件在这里打开，所有打开的
  文件以 buffer 形式保留。
- 左栏运行 `opencode`，工作目录为项目根目录。
- 底部窗口运行配置的 shell，工作目录为项目根目录。
- 右栏包含 netrw 文件浏览器和 coc outline；选择 outline 符号会跳转到中间
  编辑器的对应位置。
- `:ProjectClose` 停止项目终端、清理项目文件 buffer、保留非项目 buffer、
  恢复 gvim 启动目录，并只保留一个空的 `[No Name]` 窗口。
- `:ProjectClose!` 强制清空所有 buffer、窗口和 tab。

## 要求

- Vim 9.0+，带 `+terminal` 和 Vim9 script 支持（已在 Vim 9.2 / Windows
  GVim 验证）。
- `coc.nvim`，用于 outline 和 LSP。
- 内置 netrw。
- `opencode` 在 `PATH` 中。安装见 <https://opencode.ai>。
- **仅支持 Vim**，Vim9 script 不兼容 Neovim。

所有插件源码均为 Vim9 script，必须使用 UTF-8 无 BOM、LF 换行。CRLF 会在
`enddef` 后触发 `E1173`。

## 安装

通过 vim-plug 安装：

```vim
Plug 'https://github.com/maxto3/vim-project-management.git'
```

然后执行：

```vim
:PlugInstall
```

vim-plug 会克隆到：

```text
C:\Users\<you>\.vim\plugged\project-management
```

并从该目录加载插件。

修改并提交源码仓库后，用下面的命令更新安装副本：

```vim
:PlugUpdate project-management
```

### 备份

安装副本位于 `~/.vim/plugged`，`gvim_backup.py` 会随 `~/.vim` 一起归档；源码
仓库应继续用 Git 管理。

## 命令

| 命令 | 说明 |
| --- | --- |
| `:ProjectOpen [path]` | 打开项目；无参数时使用 `PWD`。 |
| `:ProjectClose` | 关闭项目，保留非项目 buffer。 |
| `:ProjectClose!` | 关闭项目并清空所有 buffer/窗口/tab。 |
| `:ProjectReload` | 重建项目布局，保留项目 buffer。 |
| `:ProjectStatus` | 显示根目录、PWD、窗口 ID 和终端 buffer。 |
| `:ProjectOutline` | 打开/聚焦 outline 窗口。 |
| `:ProjectToggleOutline` | 切换右侧栏 outline。 |

项目打开时 `F2` 自动调用 `:ProjectToggleOutline`；非项目状态下保持原有的
coc outline 切换行为。

## 按键映射

插件默认定义五个普通模式映射：

| 映射 | 命令 | 说明 |
| --- | --- | --- |
| `<Leader>wo` | `:ProjectOpen` | 打开当前目录为项目。 |
| `<Leader>wc` | `:ProjectClose` | 关闭项目，保留非项目 buffer。 |
| `<Leader>we` | `:ProjectFocus files` | 跳转到文件浏览器（netrw）窗口。 |
| `<Leader>wa` | `:ProjectFocus opencode` | 跳转到 opencode 窗口。 |
| `<Leader>wt` | `:ProjectFocus terminal` | 跳转到底部终端窗口。 |
| `<Leader>wl` | `:ProjectFocus outline` | 跳转到 outline 窗口（未打开时自动打开）。 |
| `<F11>` | `:ProjectFocusMode` | 切换专注模式：新开一个只保留编辑器窗口的 tab。 |

这三个跳转映射在终端窗口里同样有效，因此在 opencode 或底部 shell 中不用先退出终端模式。

在插件加载前设置 `g:project_management_default_mappings = 0` 可禁用默认映射，
改为自定义按键。`F2` 仍会感知项目状态；如需聚焦 outline，请自行映射
`:ProjectFocusOutline`。

## 事件

| 事件 | 触发时机 |
| --- | --- |
| `User ProjectOpened` | 布局构建完成、项目状态已激活之后。 |
| `User ProjectClosed` | `:ProjectClose` 重置项目状态之后。 |

配套插件可以监听这些事件同步自身状态，例如恢复打开项目前的工作目录。

## 布局与行为

- `:ProjectOpen` 先把当前 tab 收敛为一个窗口，再用显式的
  `aboveleft`/`belowright` 分割构建布局。已有 buffer 会保留。
- 项目打开期间临时启用 `'hidden'`，让中间编辑器可以同时持有多个 buffer。
  关闭时恢复原值。
- netrw 通过项目映射显式在中间编辑器打开文件；选择目录则留在文件浏览器内。
- outline 在项目期间使用 coc 的 `outline.splitCommand = edit`，在右侧预留
  窗口中打开，不新开列。关闭项目时恢复原值。
- 项目期间会关闭 coc 的 `outline.checkBufferSwitch`，只在中编辑器的 buffer
  变化时刷新 outline。光标移到 netrw、终端或 opencode 时，outline 继续显示
  当前源代码结构，不会变成 “Document symbol provider not found”。
- 按 `,O`（leader + `O`）在中间编辑器和 outline 之间切换焦点。命令形式为
  `:ProjectFocusOutline`。在 outline 条目上按回车会跳转到编辑器对应符号；
  `Ctrl-W p` 返回上一个窗口。
- 如果项目打开时 LSP 尚未就绪，outline 窗口显示占位。等该文件的 LSP 就绪后
  按 `F2` 或执行 `:ProjectOutline`，coc 会填充 outline 并跟随当前 buffer。
- outline 的打开/关闭不会替换中间编辑器的文件。

## 配置

```vim
" 布局（左侧宽度为总列数比例）
let g:project_management_left_width    = 0.28
let g:project_management_right_width   = 34
let g:project_management_bottom_height = 14
let g:project_management_winminwidth   = 20
let g:project_management_winminheight  = 5

" opencode
let g:project_management_opencode_cmd  = 'opencode'
let g:project_management_opencode_args = []

" 底部 shell；空字符串表示使用 &shell
let g:project_management_shell = ''

" 无终端环境/测试时设为 0
let g:project_management_enable_terminals = 1

" 测试时可设为 0，用占位窗口替代 netrw
let g:project_management_enable_netrw = 1

" 设为 0 可禁用默认的 <Leader>wo / <Leader>wc 映射
let g:project_management_default_mappings = 1

" 覆盖文件浏览器自动生成的扩展名颜色；键为不带点的扩展名，值为 highlight group
let g:project_management_netrw_ext_groups = {}

" 终端 Esc 策略：'app' 把 Esc 透传给程序，'normal' 进入 Terminal-Normal
let g:project_management_opencode_esc = 'app'
let g:project_management_terminal_esc = 'normal'
```

`g:project_management_powershell_esc`（在 `_vimrc` 中读取）控制
coc-powershell 终端的同样行为。

## 为什么选择 netrw

- 零额外依赖；
- `g:netrw_browse_split = 4` 正好对应“在中间编辑器打开”；
- 可以直接放在右栏，不需要再引入一个 coc 树视图与 outline 竞争窗口位置；
- 项目模式下按扩展名排序（目录优先），每个文件名按扩展名着色（整个文件名，
  含扩展名，统一使用一种颜色）：色相由扩展名
  本身决定（金色角分布），饱和度/亮度跟随当前 `Normal` 背景，因此颜色互不
  重复且会随 `:colorscheme` 自适应；点文件和 `LICENSE`、`Makefile`、
  `Dockerfile` 等按名字单独配色；仍可用
  `g:project_management_netrw_ext_groups` 把某个扩展名固定到指定高亮组。

终端按键：

- 默认把 `Esc` 交给 opencode；用 `Ctrl-\ Ctrl-N` 或 `Ctrl-W N` 进入
  Terminal-Normal；
- `Ctrl-W w/h/j/k/l` 仍然执行 Vim 窗口切换；
- `Ctrl-W .` 向终端作业发送字面 `Ctrl-W`。

## 测试

仓库包含无头冒烟测试：

```powershell
.\test\run.ps1
```

测试通过 `test/vimrc` 关闭终端和 netrw，验证打开/关闭、无 tab、项目 buffer
清理、非项目 buffer 保留、PWD 恢复和 `:ProjectClose!`。

## 限制

- outline 依赖 coc 语言服务器；服务器未就绪时请按 `F2` 或
  `:ProjectOutline`。
- `:ProjectClose!` 按设计是破坏性的。
- 项目期间会全局设置 `outline.splitCommand`，关闭时恢复。
