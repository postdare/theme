# Fire & Earth (火土/暖阳) Theme for Oh My Zsh
# Colors: 256-color palette
# 208/214: Warm Orange/Amber (火/暖橙)
# 178/179/137: Khaki / Warm Earth / Sand (土/卡其/土黄)
# 196/203: Fiery Red (赤红)
# 221/222: Warm Gold (金黄)

PROMPT="%(?:%F{208}➜ :%F{196}➜ ) %F{179}%c%f"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{137}git:(%F{203}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{137}) %F{214}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{137})"
