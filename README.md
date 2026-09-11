# Postdare Themes

A collection of personal themes for terminal and editor.

## Contents

- [`zsh/`](./zsh) — **Fire & Earth** (火土暖色), a warm Oh My Zsh theme. Designed for a dark background.
- [`oh-my-posh/`](./oh-my-posh) — **Earendil** (纸墨暖色), a *prompt* that recolors your existing oh-my-posh theme. No config file is shipped.
- [`pi/`](./pi) — **Earendil** (纸墨暖色), light/dark themes for [pi](https://github.com/earendil-works/pi).
- [`ghostty/`](./ghostty) — **Earendil**, the matching Ghostty terminal palettes (light/dark).
- **Postdare for Zed** — moved to its own repository: [`postdare/zed-postdare`](https://github.com/postdare/zed-postdare).

## Zed Themes

The Zed themes now live in [`postdare/zed-postdare`](https://github.com/postdare/zed-postdare) and are published as a Zed extension.

Install them from inside Zed:

1. Press `Cmd+Shift+P` / `Ctrl+Shift+P` and run `zed: extensions`.
2. Search for **Postdare** and click **Install**.
3. Run `theme selector` and choose **Postdare Light** or **Postdare Dark**.

## Switcher

`bin/theme` flips every layer at once:

```bash
ln -sf "$(pwd)/bin/theme" ~/.local/bin/theme   # install
theme status                                   # show current state
theme light                                    # paper
theme dark                                     # charcoal
```

The three layers store their colors independently — the terminal palette in Ghostty, the
TUI theme in `~/.pi/agent/settings.json`, the prompt in an oh-my-posh config. Flipping only
one leaves the others painting ink on ink. Measured, not hypothetical:

| Changed | Unchanged | Result |
|---------|-----------|--------|
| terminal → dark | pi light | body text `#241c11` on `#1b1710` = **1.06:1**, TUI gone |
| terminal → light | prompt dark | path `#e8e5de` on `#e8e5de` = **1.00:1**, path gone |

Every write is backed up to `*.bak-theme` first. Paths are resolved from the script's own
location, so any clone works; override with `THEME_REPO`, `GHOSTTY_CONFIG`, `PI_SETTINGS`
or `POSH_DIR`.

The oh-my-posh half is optional: this repo ships a prompt rather than a config
([`oh-my-posh/README.md`](./oh-my-posh)), so if the generated variants are absent the
switcher warns and still moves the other two layers.
