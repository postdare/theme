# Earendil — Oh My Posh Theme

A paper & ink prompt for [oh-my-posh](https://ohmyposh.dev), matching the
[`pi/`](../pi) and [`ghostty/`](../ghostty) themes.

```
➜  theme git:(main) ✗
```

Two variants are shipped, one per background:

| File | For | Body color |
|------|-----|-----------|
| `earendil-light.omp.json` | cream paper `#e8e5de` | `#241c11` ink |
| `earendil-dark.omp.json` | warm charcoal `#1b1710` | `#e8e5de` paper |

Segment layout is kept from upstream's `robbyrussell.omp.json`; only the colors differ.

## Colors

| Element | Light | On `#e8e5de` | Dark | On `#1b1710` |
|---------|-------|--------------|------|--------------|
| `➜` prompt | `#9a6e1e` amber | 3.61:1 | `#e1ab4f` amber | 8.62:1 |
| Path | `#241c11` ink | 13.36:1 | `#e8e5de` paper | 14.19:1 |
| `git:(` `)` label | `#6b6558` grey ink | 4.60:1 | `#8e8779` | 5.01:1 |
| Branch name | `#7e5a1b` deep gold | 4.96:1 | `#efc272` | 10.73:1 |
| `✗` on error | `#9a3b22` vermilion | 5.52:1 | `#d9744f` | 5.58:1 |

## Installation

```bash
mkdir -p ~/.poshthemes
cp oh-my-posh/earendil-dark.omp.json ~/.poshthemes/earendil.omp.json   # pick one
```

Then in `~/.zshrc`:

```zsh
eval "$(oh-my-posh init zsh --config ~/.poshthemes/earendil.omp.json)"
```

[`bin/theme`](../bin/theme) does this for you and keeps the prompt in step with the
terminal and the agent theme — that is the point of it, since the three layers each store
their own colors and switching one alone leaves the others invisible.

Render it without touching your shell to check the result:

```bash
oh-my-posh print primary --config ~/.poshthemes/earendil.omp.json --shell zsh
```

## Why the terminal theme cannot fix this

oh-my-posh writes **24-bit truecolor** escapes (`38;2;R;G;B`). It never consults the
terminal's ANSI palette, so editing a Ghostty / kitty / WezTerm color scheme has no effect
on the prompt at all — the prompt carries its own literal colors.

That makes a dark-background prompt theme actively unreadable on paper. Upstream's
`robbyrussell.omp.json` is a One Dark palette, which on cream lands almost entirely below
the legibility floor:

| Element | Upstream | On `#e8e5de` |
|---------|----------|--------------|
| `➜` prompt | `#98C379` | 1.60:1 |
| Path | `#56B6C2` | 1.88:1 |
| `git:(` `)` label | `#5FAAE8` | 1.99:1 |
| Branch name | `#D0666F` | 2.87:1 |
| `✗` on error | `#BF616A` | 3.25:1 |

## Both variants are required

A light-only palette is not a finished job. Swap the terminal to a dark background and the
same prompt collapses:

| Element | Light value | On `#1b1710` |
|---------|-------------|--------------|
| Path | `#241c11` | **1.06:1** — invisible |
| Branch name | `#7e5a1b` | 2.86:1 |
| `git:(` `)` label | `#6b6558` | 3.08:1 |
| `➜` prompt | `#9a6e1e` | 3.56:1 |

Note the direction: brightness *raises* contrast on a dark background and *lowers* it on a
light one. The dark variant is therefore not a lighter tint of the light variant — it is a
separate set of values chosen to clear 4.5:1 on its own background.

## Adapting it to your own layout

The shipped configs use this repository's layout. To keep your own prompt instead, copy
your existing config and replace only the colors using the table above — including any
inline color tags such as `<#5FAAE8>` inside a template, or the old palette will survive in
the output. Then verify numerically rather than by eye: render with
`oh-my-posh print primary` and compute the WCAG contrast of every emitted color against
your background.

The same trap applies to any tool that hardcodes its own colors — `eza`, `lsd`, `bat`,
`delta`, syntax highlighters. Either point them at the ANSI palette (`LS_COLORS` with
indices rather than RGB, so the terminal theme governs them), or give them a paper & ink
palette of their own. For colors that cannot be reconfigured at all — and there are some,
like yazi's non-directory icons, which are literal `#ffffff` — see the `minimum-contrast`
guard in [`ghostty/README.md`](../ghostty/README.md).
