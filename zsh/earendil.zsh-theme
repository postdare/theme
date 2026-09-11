# Earendil — paper & ink theme for Oh My Zsh
#
# Same palette as the pi, Ghostty and oh-my-posh themes in this repository.
#
# ## Why explicit 38;5;N escapes instead of %F{n}
#
# %F{n} for n = 8..15 is not portable. Measured on the two machines this theme is used
# on, both running zsh 5.9:
#
#               macOS                 Linux
#   %F{8}       \e[90m   ok            \e[38m      not a valid SGR
#   %F{9}       \e[91m   ok            \e[39m      = default foreground, i.e. no colour
#   %F{11}      \e[93m   ok            \e[311m     not a valid SGR
#   %F{15}      \e[97m   ok            \e[315m     not a valid SGR
#
# Everything from 8 up silently loses its colour on the Linux build, so the escape is
# written out directly. 38;5;N is the standard 256-colour form, and for N < 16 the
# terminal resolves it through its own palette — which is the whole point here.
#
# ## Why only palette indices (0-15)
#
# Palette slots carry the same meaning in ghostty/earendil and ghostty/earendil-dark —
# 11 is always the amber, 1 always the vermilion, 8 always the dim grey — so one file is
# correct on both backgrounds. Absolute values such as %F{208} bypass the palette and are
# guaranteed to be wrong on one of them: 208 on cream is a glaring orange.
#
#   slot 11 amber      prompt arrow (last command succeeded)
#   slot  1 vermilion  prompt arrow (failed) and the dirty marker
#   slot  3 deep gold  git branch name
#   slot  8 dim grey   the git:( ) label
#   (unset)            default foreground — ink on a light background, paper on a dark one
#
# Measured contrast for every colour used, against both backgrounds:
#
#   slot    cream #e8e5de   charcoal #1b1710
#   11      5.92:1          8.62:1
#    3      3.94:1          7.85:1
#    1      4.70:1          4.77:1
#    8      2.92:1          3.23:1   (deliberately dim: a label, not content)
#   default 13.36:1        14.19:1
#
# ## Layout
#
#   ➜  theme git:(main) ✗
#
# The same shape as this repository's oh-my-posh prompt, so a remote host and a local
# machine look alike. `%c` shows the trailing path component only.

typeset -g _earendil_amber=$'%{\e[38;5;11m%}'
typeset -g _earendil_verm=$'%{\e[38;5;1m%}'
typeset -g _earendil_gold=$'%{\e[38;5;3m%}'
typeset -g _earendil_grey=$'%{\e[38;5;8m%}'

PROMPT="%(?:${_earendil_amber}➜ :${_earendil_verm}➜ )%f %c"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="${_earendil_grey}git:(%f${_earendil_gold}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f${_earendil_grey})%f"
ZSH_THEME_GIT_PROMPT_DIRTY="${_earendil_verm} ✗%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""
