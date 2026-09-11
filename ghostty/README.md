# Earendil — Ghostty Palettes

Two terminal palettes matching the [`pi/`](../pi) themes: cream paper for light, warm
charcoal for dark.

| File | Background | Body text | Accent |
|------|-----------|-----------|--------|
| `earendil` | `#e8e5de` paper | `#241c11` ink | `#e1ab4f` amber |
| `earendil-dark` | `#1b1710` warm charcoal | `#e8e5de` paper | `#e1ab4f` amber |

## Installation

Reference the file directly:

```ini
theme = /path/to/theme/ghostty/earendil-dark
window-theme = dark
```

Or copy it into `~/.config/ghostty/themes/` and use the bare name:

```ini
theme = earendil-dark
```

Reload with `Cmd+Shift+,` or:

```bash
kill -USR2 $(pgrep -f 'MacOS/ghostty')
```

To preview one without touching your config, launch a throwaway instance — every config
key is available as a CLI flag:

```bash
open -na Ghostty.app --args --theme=/path/to/theme/ghostty/earendil-dark
```

`window-theme` controls the window chrome (title bar), not the terminal. Set it to
`light` or `dark` to match, otherwise the chrome follows the OS appearance and can end up
mismatched with the terminal.

## Do not rely on `theme = light:X,dark:Y`

Ghostty supports the paired syntax, and it validates, but the resolution is unreliable
here — verified on macOS in Dark mode, where Ghostty picked the **light** theme:

```ini
theme = light:.../ghostty/earendil,dark:.../ghostty/earendil-dark
window-theme = auto
```

```
$ defaults read -g AppleInterfaceStyle
Dark

$ ghostty +show-config | grep background
background = #e8e5de      # ← the light one
```

`window-theme = auto` also collapses to `system` rather than tracking the theme. Switch
explicitly with the single-theme form above instead.

## Design notes

The two palettes are **not** the same 16 colors with a different background. On dark
backgrounds a brighter color is a *more* readable one; on light backgrounds it is a
*less* readable one. So the bright ANSI slots are lighter than the normal ones in
`earendil-dark`, and darker than them in `earendil`.

Both palettes keep every hue inside the warm range. There is no blue and no green — the
ANSI blue and cyan slots are low-saturation warm greys, so `ls`, `git` and 16-color `vim`
stay distinguishable without importing a color the design does not use.

All 16 slots were checked against their own background: normal slots at 4.5:1 or better,
the two dim slots (0 and 8) at 2:1 and 3:1 respectively.
