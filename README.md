# Postdare Themes

A collection of personal themes for terminal and editor.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/postdare/theme/main/install.sh | bash
```

It detects which of `pi`, `ghostty`, `oh-my-posh` and `zsh` (oh-my-zsh) you actually have,
then shows a checkbox list — `↑`/`↓` to move, `Space` to toggle, `Enter` to confirm, `a`/`n` for all or
none. It prints one line per app and nothing else. **Both variants are always installed**; `--mode` only decides which one is active, and
`theme light` / `theme dark` switches afterwards. The theme files stay in this repository and
are referenced from it, so keep the checkout around.

```bash
# non-interactive: install only specific apps (useful in CI or dotfiles)
curl -fsSL https://raw.githubusercontent.com/postdare/theme/main/install.sh | bash -s -- --only pi --mode dark

./install.sh --dry-run        # show every change, write nothing
./install.sh --uninstall      # remove what it installed
./install.sh --help
```

Worth knowing before you run it:

- **Interactive even when piped.** Under `curl | bash`, stdin is the script itself, so the
  installer copies itself to `/tmp` and re-attaches `/dev/tty` for prompts. The checkbox
  selector reads raw keystrokes from the real terminal and restores it on every exit path.
- **Nothing is overwritten silently.** Every file it edits is copied to `<file>.bak-postdare`
  the first time it touches it — that copy always holds the pre-install original, so
  re-running never clobbers it. Config edits replace a key rather than append, and
  re-running changes nothing.
- **Uninstall is recorded, not guessed.** Ghostty does not support inline comments — anything
  after `#` is swallowed into the value — so the installer cannot mark its own lines. It keeps
  a record in `~/.local/state/postdare-theme/installed` instead, and falls back to matching the
  theme path if that file is gone. For zsh it also records the theme name it replaced, so
  `--uninstall` puts *your* theme back rather than leaving a dangling `ZSH_THEME`.
- **No dependencies beyond `awk`.** Every config edit is an awk pass into a temp file that
  is then renamed, so an interrupted edit leaves the original intact. Notably *not* python3:
  on a Mac without Xcode CLT, `/usr/bin/python3` is a stub that pops the install dialog, and
  a one-line theme installer has no business making you install Xcode first.
- **Bash 3.2 compatible**, which is what macOS ships. `${var,,}`, `declare -A` and `readarray`
  would break there.

## Contents

- [`zsh/`](./zsh) — **Earendil** (纸墨暖色), a paper & ink Oh My Zsh theme. Palette-indexed, so it adapts to light and dark.
- [`oh-my-posh/`](./oh-my-posh) — **Earendil** (纸墨暖色), a paper & ink oh-my-posh prompt (light/dark).
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

All three layers are covered on a fresh clone, since the oh-my-posh configs ship in
[`oh-my-posh/`](./oh-my-posh). If that directory is missing the switcher warns and still
moves the other two layers.

The one thing no palette can fix is a tool that hardcodes its own colors. See the
`minimum-contrast` guard in [`ghostty/README.md`](./ghostty/README.md).
