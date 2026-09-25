; extends

; Tag common C++ standard-library stream objects / well-known globals as
; @variable.builtin so they get a distinct color (rose-pine -> love, pink)
; instead of the generic @variable text color. Matched by name, since the
; grammar has no "stdlib object" signal. Works with std:: prefix or after a
; `using namespace std;` (bare identifier).
((identifier) @variable.builtin
  (#any-of? @variable.builtin
    "cout" "cin" "cerr" "clog"
    "wcout" "wcin" "wcerr" "wclog"
    "endl" "ends" "flush"))
