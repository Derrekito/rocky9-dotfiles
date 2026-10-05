" Pandoc LaTeX templates (*.latex): TeX syntax, minus the inline math zones,
" since in a template `$` delimits pandoc variables, not math. The pandoc
" template highlighting itself is in after/ftplugin/pandoc-latex.lua.
if exists("b:current_syntax")
  finish
endif

runtime! syntax/tex.vim
unlet! b:current_syntax

for s:zone in ["texMathZoneX", "texMathZoneY"]
  if hlexists(s:zone)
    execute "syntax clear" s:zone
  endif
endfor
unlet s:zone

let b:current_syntax = "pandoc-latex"
