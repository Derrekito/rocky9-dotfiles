-- VimTeX configuration for LaTeX editing, pinned to v2.15 (the last release
-- supporting Neovim 0.8). Works alongside texlab LSP for complete LaTeX support.
-- These globals are read when VimTeX starts up for a .tex buffer.
-- Set the LaTeX flavor
vim.g.tex_flavor = 'latex'

-- PDF viewer configuration
-- Options: 'zathura', 'evince', 'okular', 'skim' (macOS), 'sioyek'
vim.g.vimtex_view_method = 'zathura' -- Change to your preferred PDF viewer

-- Compiler settings
vim.g.vimtex_compiler_method = 'latexmk'
vim.g.vimtex_compiler_latexmk = {
  build_dir = '',
  callback = 1,
  continuous = 1,
  executable = 'latexmk',
  options = {
    '-pdf',
    '-verbose',
    '-file-line-error',
    '-synctex=1',
    '-interaction=nonstopmode',
  },
}

-- Quickfix window settings
vim.g.vimtex_quickfix_mode = 0 -- Don't open quickfix automatically

-- Disable overfull/underfull box warnings
vim.g.vimtex_quickfix_ignore_filters = {
  'Overfull',
  'Underfull',
}

-- Table of contents settings
vim.g.vimtex_toc_config = {
  name = 'TOC',
  layers = { 'content', 'todo', 'include' },
  split_width = 30,
  todo_sorted = 0,
  show_help = 1,
  show_numbers = 1,
}

-- Folding (disable if you don't like it)
vim.g.vimtex_fold_enabled = 0

-- Concealment (make LaTeX source prettier)
vim.g.vimtex_syntax_conceal = {
  accents = 1,
  ligatures = 1,
  cites = 1,
  fancy = 1,
  spacing = 1,
  greek = 1,
  math_bounds = 1,
  math_delimiters = 1,
  math_fracs = 1,
  math_super_sub = 1,
  math_symbols = 1,
  sections = 0,
  styles = 1,
}

-- Indent settings
vim.g.vimtex_indent_enabled = 1

-- Auto-save before compiling
vim.g.vimtex_compiler_latexmk_engines = {
  _ = '-pdf',
}

-- Disable some warnings
vim.g.vimtex_log_ignore = {
  'Underfull',
  'Overfull',
  'specifier changed to',
  'Token not allowed in a PDF string',
}
