# Earendil — Oh My Posh Prompt

This folder ships **a prompt, not a config file**. Copy the block at the bottom into any
AI coding agent, and it will recolor your oh-my-posh prompt to match the
[`pi/`](../pi) and [`ghostty/`](../ghostty) paper & ink themes.

A prompt is used instead of a JSON file on purpose: oh-my-posh configs are
version-sensitive, everyone's prompt layout is already customized, and the colors have a
hard numeric constraint that is easy to get wrong by hand. Describing the goal and the
acceptance test works across versions and layouts.

## Why this cannot be fixed from the terminal

oh-my-posh writes **24-bit truecolor** escapes (`38;2;R;G;B`). It never consults the
terminal's ANSI palette, so editing a Ghostty / kitty / WezTerm color scheme has no
effect on the prompt at all — the prompt carries its own literal colors.

That makes a dark-background prompt theme actively unreadable on paper. Upstream's
`robbyrussell.omp.json` is a One Dark palette, which on cream lands almost entirely
below the legibility floor:

| Element | Upstream | On `#e8e5de` | Paper & ink (light) | Result |
|---------|----------|--------------|---------------------|--------|
| `➜` prompt | `#98C379` | 1.60:1 | `#9a6e1e` amber | 3.61:1 |
| Path | `#56B6C2` | 1.88:1 | `#241c11` ink | 13.36:1 |
| `git:(` `)` label | `#5FAAE8` | 1.99:1 | `#6b6558` grey ink | 4.60:1 |
| Branch name | `#D0666F` | 2.87:1 | `#7e5a1b` deep gold | 4.96:1 |
| `✗` on error | `#BF616A` | 3.25:1 | `#9a3b22` vermilion | 5.52:1 |

## Both variants are required, not one

A light-only palette is not a finished job. Swap the terminal to a dark background and the
same prompt collapses:

| Element | Light value | On `#1b1710` | Paper & ink (dark) | Result |
|---------|-------------|--------------|--------------------|--------|
| Path | `#241c11` | **1.06:1** — invisible | `#e8e5de` paper | 14.19:1 |
| Branch name | `#7e5a1b` | 2.86:1 | `#efc272` | 10.73:1 |
| `git:(` `)` label | `#6b6558` | 3.08:1 | `#8e8779` | 5.01:1 |
| `➜` prompt | `#9a6e1e` | 3.56:1 | `#e1ab4f` | 8.62:1 |
| `✗` on error | `#9a3b22` | 1.60:1 | `#d9744f` | 5.58:1 |

Note the direction of the arrows: brightness *raises* contrast on a dark background and
*lowers* it on a light one. The dark variant's value is therefore not a lighter tint of the
light variant's — for the dim slots it is the same value, and for the accent it is a
different one chosen to clear 4.5:1 on its own background.

Ask for both, and ask for a switch, because the terminal, the editor theme and the prompt
all have to move together. Flipping only one leaves the other layers painting dark ink on
a dark background.

The same trap applies to any tool that hardcodes its own colors — `eza`, `lsd`, `bat`,
`delta`, syntax highlighters. Either point them at the ANSI palette (`LS_COLORS` with
indices rather than RGB, so the terminal theme governs them), or give them a paper & ink
palette of their own.

## The prompt

```text
Recolor my oh-my-posh prompt theme, for both light and dark terminal backgrounds.

Context you need to know:
- oh-my-posh emits 24-bit truecolor (38;2;R;G;B) and never consults the terminal's
  ANSI palette. Changing the terminal color scheme cannot fix the prompt; the colors
  have to be right in the theme itself.
- Most upstream oh-my-posh themes are designed for dark backgrounds. On a light
  background their colors land at roughly 1.5-3.3:1 contrast and look washed out.
- A theme tuned for only one background is not finished. Brightness raises contrast on
  a dark background and lowers it on a light one, so a palette that reads well on cream
  can drop to near 1:1 contrast on charcoal, and vice versa.

My setup:
- Backgrounds: cream #e8e5de (light) and warm charcoal #1b1710 (dark).
  If you can detect the real values, prefer those; otherwise use these and say so.
- Find my active oh-my-posh config: read the --config argument from ~/.zshrc, or fall
  back to $POSH_THEME.

Task:
1. Back the config file up first, so I can revert.
2. Read it, then preserve everything: blocks, segment order, types, style, properties,
   the structure of each template, version, final_space. Change colors only. Do not
   rewrite or "improve" my prompt layout.
3. Produce TWO variants, one per background. Apply this paper & ink palette:

     element                     light bg        dark bg
     prompt symbol               #9a6e1e         #e1ab4f
     path                        #241c11         #e8e5de
     git labels  git:(  and )    #6b6558         #8e8779
     branch name                 #7e5a1b         #efc272
     error symbol                #9a3b22         #d9744f

   Some templates carry inline color tags (e.g. <#5FAAE8>). Update those too, or the
   old palette will survive in the output.
4. Hard constraints, checked against the matching background for each variant:
   - every foreground must reach at least 3:1 contrast, and 4.5:1 for the path and the
     branch name, since those are the elements I actually read
   - keep explicit hex colors; do not switch to ANSI palette indices
5. Verify numerically before you finish, for BOTH variants. Do not eyeball it:

     oh-my-posh print primary --config <variant> --shell zsh

   Extract every 38;2;R;G;B triple from that output, compute the WCAG contrast ratio of
   each against that variant's background, and print two tables. Fix anything that
   misses its target and re-render to confirm.
6. Give me a way to switch between the two that cannot drift: one command that swaps the
   prompt config along with my terminal theme and my editor/agent theme, or if those live
   in separate files, a short script that changes all of them together and reports what
   it changed.
7. Show me the diff, and tell me how to revert.

Finish by reporting the file paths you changed and both contrast tables.
```

## Checking the result yourself

Render a variant without touching your shell, and confirm the colors on the wire:

```bash
oh-my-posh print primary --config ~/.poshthemes/earendil-dark.omp.json --shell zsh
```

Open a new terminal (or `source ~/.zshrc`) to see it live. Changing a theme file does not
repaint an already-drawn prompt, and changing a theme setting does not repaint an
already-running full-screen application.
