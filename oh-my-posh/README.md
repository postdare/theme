# Earendil — Oh My Posh Prompt

This folder ships **a prompt, not a config file**. Copy the block at the bottom into any
AI coding agent, and it will recolor your existing oh-my-posh theme to match the
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

| Element | Upstream | On `#e8e5de` | Paper & ink | Result |
|---------|----------|--------------|-------------|--------|
| `➜` prompt | `#98C379` | 1.60:1 | `#9a6e1e` amber | 3.61:1 |
| Path | `#56B6C2` | 1.88:1 | `#241c11` ink | 13.36:1 |
| `git:(` `)` label | `#5FAAE8` | 1.99:1 | `#6b6558` grey ink | 4.60:1 |
| Branch name | `#D0666F` | 2.87:1 | `#7e5a1b` deep gold | 4.96:1 |
| `✗` on error | `#BF616A` | 3.25:1 | `#9a3b22` vermilion | 5.52:1 |

The same trap applies to any tool that hardcodes its own colors — `eza`, `lsd`, `bat`,
`delta`, syntax highlighters. Either point them at the ANSI palette (`LS_COLORS` with
indices rather than RGB, so the terminal theme governs them), or give them a paper & ink
palette of their own.

## The prompt

```text
Recolor my oh-my-posh prompt theme for a light terminal background.

Context you need to know:
- oh-my-posh emits 24-bit truecolor (38;2;R;G;B) and never consults the terminal's
  ANSI palette. Changing the terminal color scheme cannot fix the prompt; the colors
  have to be right in the theme itself.
- Most upstream oh-my-posh themes are designed for dark backgrounds. On a light
  background their colors land at roughly 1.5-3.3:1 contrast and look washed out.

My setup:
- My terminal background is #e8e5de (cream). If you can detect the real value, prefer
  that; otherwise use this one and tell me you assumed it.
- Find my active oh-my-posh config: read the --config argument from ~/.zshrc, or fall
  back to $POSH_THEME.

Task:
1. Back the config file up first, so I can revert.
2. Read it, then preserve everything: blocks, segment order, types, style, properties,
   the structure of each template, version, final_space. Change colors only. Do not
   rewrite or "improve" my prompt layout.
3. Apply this paper & ink palette:
     prompt symbol              #9a6e1e   amber
     path                       #241c11   ink
     git labels  git:(  and )   #6b6558   grey ink
     branch name                #7e5a1b   deep gold
     error symbol                #9a3b22   vermilion
   Some templates carry inline color tags (e.g. <#5FAAE8>). Update those too, or the
   old palette will survive in the output.
4. Hard constraints:
   - every foreground must reach at least 3:1 contrast against my background
   - keep explicit hex colors; do not switch to ANSI palette indices
5. Verify numerically before you finish, do not eyeball it:

     oh-my-posh print primary --config <config-path> --shell zsh

   Extract every 38;2;R;G;B triple from that output, compute the WCAG contrast ratio of
   each against my background, and print a table of color -> contrast ratio. Fix
   anything below 3:1 and re-render to confirm.
6. Then show me the diff of the changed file and tell me how to revert it.

Finish by reporting the config path you changed and the final contrast table.
```

## Checking the result yourself

Render the prompt without touching your shell, and confirm the colors on the wire:

```bash
oh-my-posh print primary --config ~/.poshthemes/earendil.omp.json --shell zsh
```

Open a new terminal (or `source ~/.zshrc`) to see it live. Changing a theme file does not
repaint an already-drawn prompt.
