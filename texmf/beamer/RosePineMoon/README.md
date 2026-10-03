# RosePineMoon Beamer theme (parts)

The color, font, inner and outer parts of the RosePineMoon Beamer theme from
slideforge. One change: the outer theme declares the `[chrome]` switch itself
when the main theme hasn't, since its footline uses it and the main theme
isn't installed here. They need only TikZ, which Rocky 9's TeX Live has.
The full theme (`beamerthemeRosePineMoon.sty`) also loads minted, fvextra and
tcolorbox's minted library, which Rocky 9 doesn't package, so it isn't here.

`install.sh` links each file into `~/texmf/tex/latex/beamer/RosePineMoon/`
(kpathsea doesn't search inside a symlinked directory).
`:MarkdownExport slides` finds them there and loads them one by one
(`-V colortheme=... -V fonttheme=... -V innertheme=... -V outertheme=...`).
