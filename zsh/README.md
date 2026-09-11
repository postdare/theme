# Earendil — 纸墨暖色 Oh My Zsh Theme

A paper & ink theme for Oh My Zsh, matching the [`pi/`](../pi), [`ghostty/`](../ghostty) and
[`oh-my-posh/`](../oh-my-posh) themes in this repository.

```
➜  theme git:(main) ✗
```

Same shape as the oh-my-posh prompt, so a remote host and a local machine look alike.

## Colors

Every colour is an **ANSI palette index**, never an absolute value, so one file is correct
on both a light and a dark terminal. The two terminal palettes in [`ghostty/`](../ghostty)
give each slot the same meaning, which is what makes that work.

| Element | Slot | On cream `#e8e5de` | On charcoal `#1b1710` |
|---------|------|--------------------|-----------------------|
| `➜` prompt, success | 11 amber | 5.92:1 | 8.62:1 |
| `➜` prompt, failure | 1 vermilion | 4.70:1 | 4.77:1 |
| `git:(` `)` label | 8 dim grey | 2.92:1 | 3.23:1 |
| Branch name | 3 deep gold | 3.94:1 | 7.85:1 |
| Path | terminal default | 13.36:1 | 14.19:1 |
| `✗` dirty marker | 1 vermilion | 4.70:1 | 4.77:1 |

Slot 8 is deliberately dim — it is a label, not content.

## Installation

```bash
ln -sf "$(pwd)/zsh/earendil.zsh-theme" "$ZSH_CUSTOM/themes/earendil.zsh-theme"
```

Then set the theme in `~/.zshrc`:

```zsh
ZSH_THEME="earendil"
```

Open a new shell. `echo $ZSH_THEME` confirms what loaded.

## Two portability traps this theme works around

**`%F{n}` is broken for n = 8..15 on some zsh builds.** Measured on macOS and Linux, both
running zsh 5.9:

| | macOS | Linux |
|---|-------|-------|
| `%F{8}` | `\e[90m` ok | `\e[38m` — not a valid SGR |
| `%F{9}` | `\e[91m` ok | `\e[39m` — the *default* foreground, so no colour at all |
| `%F{11}` | `\e[93m` ok | `\e[311m` — not a valid SGR |
| `%F{15}` | `\e[97m` ok | `\e[315m` — not a valid SGR |

Everything from 8 up silently loses its colour on the Linux build. The theme therefore writes
`\e[38;5;Nm` out explicitly, which is the standard 256-colour form and behaves identically
everywhere.

**Absolute colours do not survive a background change.** The previous theme here,
[`fire-earth`](./fire-earth.zsh-theme), used values such as `%F{208}` and `%F{179}`. Those
bypass the palette, which is fine on a dark terminal and unreadable on cream — measured
against `#e8e5de`, the arrow `#ff8700` is 1.91:1 and the path `#d7af5f` is 1.64:1, while the
same two values reach 7.41:1 and 8.66:1 on charcoal. Indexed slots are resolved by the
terminal, so this theme adapts on its own.

## Notes

- oh-my-zsh computes the git segment asynchronously in recent versions
  (`_OMZ_ASYNC_OUTPUT[_omz_git_prompt_info]`). It will be empty if you render the prompt by
  hand with `zsh -i -c`; that is not a fault, it appears normally in a real shell.
- The theme defines four globals prefixed `_earendil_` to hold the escape sequences. They are
  namespaced to avoid colliding with anything in your shell.
