# Earendil — Oh My Posh Theme

A paper & ink prompt for [oh-my-posh](https://ohmyposh.dev), matching the
[`pi/`](../pi) and [`ghostty/`](../ghostty) themes.

```
➜  theme git:(main) ✗
```

Layout and segments are kept from upstream's `robbyrussell.omp.json`; only the
colors change.

## Colors

| Element | Color | Contrast on `#e8e5de` |
|---------|-------|-----------------------|
| `➜` prompt | amber `#9a6e1e` | 3.61:1 |
| Path | ink `#241c11` | 13.36:1 |
| `git:(` `)` label | grey ink `#6b6558` | 4.60:1 |
| Branch name | deep gold `#7e5a1b` | 4.96:1 |
| `✗` on error | vermilion `#9a3b22` | 5.52:1 |

## Installation

```bash
ln -sf "$(pwd)/oh-my-posh/earendil.omp.json" ~/.poshthemes/earendil.omp.json
```

Then in `~/.zshrc`:

```zsh
eval "$(oh-my-posh init zsh --config ~/.poshthemes/earendil.omp.json)"
```

Render it without touching your shell to check the result:

```bash
oh-my-posh print primary --config ~/.poshthemes/earendil.omp.json --shell zsh
```

## Why a separate theme was needed

oh-my-posh writes **24-bit truecolor** escapes. It never consults the terminal's
ANSI palette, so changing a Ghostty/kitty/WezTerm color scheme has no effect on the
prompt at all — the prompt carries its own literal colors.

That makes an upstream prompt theme designed for a dark terminal actively unreadable
on a light background. `robbyrussell.omp.json` is a One Dark palette, which on cream
paper lands almost entirely below the legibility floor:

| Element | Upstream | On `#e8e5de` |
|---------|----------|--------------|
| `➜` | `#98C379` | 1.60:1 |
| Path | `#56B6C2` | 1.88:1 |
| `git:(` `)` | `#5FAAE8` | 1.99:1 |
| Branch | `#D0666F` | 2.87:1 |
| `✗` | `#BF616A` | 3.25:1 |

The same applies to any tool that hardcodes its own colors — `eza`, `lsd`, `bat`,
`delta`, `zsh-syntax-highlighting` themes, and so on. Either point them at the ANSI
palette (`LS_COLORS` with indices rather than RGB) so the terminal theme governs them,
or give them a paper & ink palette of their own.
