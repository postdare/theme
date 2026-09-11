#!/usr/bin/env bash
# Postdare Themes — one-line installer
#
#   curl -fsSL https://raw.githubusercontent.com/postdare/theme/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --only pi --mode dark
#
#   ./install.sh --dry-run          preview every change
#   ./install.sh --uninstall        remove what this installed
#
# Everything it writes is backed up first, and every config edit is key-based
# replacement rather than append, so re-running is safe.
#
# Bash 3.2 compatible on purpose: that is what macOS ships, and `${var,,}`,
# `declare -A` and `readarray` would break silently there.
set -uo pipefail

REPO="postdare/theme"
REF="${THEME_REF:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$REF"

APP_NAME="Postdare Themes"
GHOSTTY_APP="/Applications/Ghostty.app"
MIN_CONTRAST="3"

# ── output helpers ────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_R=$'\033[0m'; C_D=$'\033[2m'; C_B=$'\033[1m'
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_HL=$'\033[36m'
else
  C_R=''; C_D=''; C_B=''; C_OK=''; C_WARN=''; C_ERR=''; C_HL=''
fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==>%s %s\n' "$C_B$C_HL" "$C_R" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_OK" "$C_R" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_R" "$*"; }
err()  { printf '  %s✗%s %s\n' "$C_ERR" "$C_R" "$*" >&2; }
die()  { err "$*"; exit 1; }
dim()  { printf '  %s%s%s\n' "$C_D" "$*" "$C_R"; }

# The interactive selector reads raw bytes from the terminal, not stdin: under
# `curl | bash` stdin is the script itself, so a plain read would return EOF and the
# menu could never appear.
TTY=/dev/tty
have_tty() { [ -r "$TTY" ] && [ -w "$TTY" ]; }

backup() { # backup <file>
  [ -f "$1" ] || return 0
  local b="$1.bak-postdare"
  cp "$1" "$b"
  dim "backup: $(tilde "$b")"
}
tilde() { printf '%s' "${1/#$HOME/~}"; }

# Replace a whole-line `key = value`, or append it when absent. Never duplicates.
set_key() { # set_key <file> <key> <value>
  python3 - "$1" "$2" "$3" <<'PY'
import re, sys, os
path, key, value = sys.argv[1:4]
text = open(path).read() if os.path.exists(path) else ''
pat = re.compile(rf'^{re.escape(key)}\s*=.*$', re.M)
line = f'{key} = {value}'
out = pat.sub(line, text, count=1) if pat.search(text) else (text.rstrip('\n') + f'\n{line}\n' if text else line + '\n')
open(path, 'w').write(out)
PY
}

# ── argument parsing ──────────────────────────────────────────────────
APPS=""
MODE=""
DIR="${THEME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/postdare-theme}"
DRY=0
ASSUME_YES=0
UNINSTALL=0
DO_UPDATE=0
SET_ZSH=1
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# Ghostty does NOT support inline comments - anything after `#` is swallowed into the
# value (`window-theme: invalid value "light  # note"`). So the install cannot mark its
# own lines. Instead it records exactly what it touched here, and --uninstall replays
# that record. Kept out of the theme directory so it never shows up as an untracked
# file in the checkout.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/postdare-theme"
MANIFEST="$STATE_DIR/installed"

usage() {
  cat <<EOF
$APP_NAME — installer

Usage:
  curl -fsSL $RAW/install.sh | bash
  curl -fsSL $RAW/install.sh | bash -s -- --only pi --mode dark

Options:
  --only <apps>     skip the menu: pi,ghostty,oh-my-posh,zsh
  --apps <apps>     same as --only
  --mode <m>        which variant is active: light | dark   (default: light)
                    both variants are always installed — `theme dark` switches later
  --dir <path>      where to keep the theme files     (default: $DIR)
  --update          pull the latest version in --dir and exit
  --no-zshrc        install the oh-my-posh config but do not touch .zshrc
  --dry-run         show what would change, write nothing
  --uninstall       remove symlinks, theme keys and the .zshrc line
  -y, --yes         no questions; take the defaults
  -h, --help        this text

Every file it edits is copied to <file>.bak-postdare first.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --only|--apps)   APPS="${2:-}"; shift 2 || die "$1 needs a value";;
    --mode)          MODE="${2:-}"; shift 2 || die "--mode needs a value";;
    --dir|--theme-dir) DIR="${2:-}"; shift 2 || die "--dir needs a value";;
    --zshrc)         ZSHRC="${2:-}"; shift 2 || die "--zshrc needs a value";;
    --no-zshrc)      SET_ZSH=0; shift;;
    --update)        DO_UPDATE=1; shift;;
    --dry-run)       DRY=1; shift;;
    --uninstall)     UNINSTALL=1; shift;;
    -y|--yes)        ASSUME_YES=1; shift;;
    -h|--help)       usage; exit 0;;
    *)               err "unknown option: $1"; usage; exit 1;;
  esac
done

case "$MODE" in ""|light|dark) ;; *) die "--mode must be light or dark";; esac
for a in $(printf '%s' "$APPS" | tr ',' ' '); do
  case "$a" in pi|ghostty|oh-my-posh|zsh) ;; *) die "unknown app: $a (want pi, ghostty, oh-my-posh or zsh)";; esac
done

# ── locate or fetch the theme files ───────────────────────────────────
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo '')"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/pi/earendil-light.json" ]; then
  SRC="$SELF_DIR"          # running from a checkout
else
  SRC=""
fi

fetch_into() { # fetch_into <dir>
  local dst="$1" tmp
  tmp="$(mktemp -d)"
  if command -v git >/dev/null 2>&1; then
    if git clone --quiet --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$tmp/t" 2>/dev/null; then
      mkdir -p "$dst"; cp -R "$tmp/t/." "$dst/"; rm -rf "$tmp"; return 0
    fi
    dim "git clone failed, falling back to tarball"
  fi
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" -o "$tmp/t.tgz" 2>/dev/null || {
    rm -rf "$tmp"; return 1; }
  mkdir -p "$tmp/x" && tar -xzf "$tmp/t.tgz" -C "$tmp/x" --strip-components=1 2>/dev/null || {
    rm -rf "$tmp"; return 1; }
  mkdir -p "$dst"; cp -R "$tmp/x/." "$dst/"; rm -rf "$tmp"
}

step "Theme files"
if [ -n "$SRC" ]; then
  ok "using the checkout at $(tilde "$SRC")"
else
  if [ -d "$DIR/.git" ]; then
    SRC="$DIR"
    # Reusing silently would keep a stale clone whose theme files may predate what is
    # being installed. Pulling is cheap and non-fatal, so a re-run always gets the
    # current themes without anyone thinking about it.
    if [ "$DRY" != 1 ]; then
      if git -C "$DIR" pull --ff-only --quiet 2>/dev/null; then
        ok "updated $(tilde "$DIR")"
        [ "$DO_UPDATE" = 1 ] && exit 0
      else
        dim "reusing $(tilde "$DIR") (could not reach the remote)"
      fi
    fi
    [ "$DO_UPDATE" = 1 ] && exit 0
  else
    if [ "$DRY" = 1 ]; then
      dim "would fetch $REPO@$REF into $(tilde "$DIR")"
      SRC="$DIR"
    else
      mkdir -p "$DIR" || die "cannot create $DIR"
      fetch_into "$DIR" || die "could not download $REPO@$REF"
      SRC="$DIR"
      ok "installed to $(tilde "$DIR")"
      dim "a copy now lives here and your configs will point at it — if you already"
      dim "have a checkout, run ./install.sh from inside it instead"
    fi
  fi
fi
[ "$DO_UPDATE" = 1 ] && exit 0

# ── detect what is present ────────────────────────────────────────────
detect() { # detect <app> -> 0 present
  case "$1" in
    pi)         command -v pi >/dev/null 2>&1 || [ -d "$HOME/.pi" ];;
    ghostty)    [ -d "$GHOSTTY_APP" ] || command -v ghostty >/dev/null 2>&1;;
    oh-my-posh) command -v oh-my-posh >/dev/null 2>&1;;
    zsh)        [ -d "$HOME/.oh-my-zsh" ];;
  esac
}

detect_note() {
  case "$1" in
    pi)         tilde "$HOME/.pi";;
    ghostty)    [ -d "$GHOSTTY_APP" ] && printf '%s' "$GHOSTTY_APP" || command -v ghostty;;
    oh-my-posh) command -v oh-my-posh 2>/dev/null;;
    zsh)        zsh_custom | sed "s|$HOME|~|";;
  esac
}

# oh-my-zsh's own default is $ZSH/custom; an explicit ZSH_CUSTOM in the environment wins.
zsh_custom() {
  if [ -n "${ZSH_CUSTOM:-}" ]; then printf '%s' "$ZSH_CUSTOM"
  else printf '%s' "$HOME/.oh-my-zsh/custom"; fi
}

# ── checkbox selector ─────────────────────────────────────────────────
# Arrows move, Space toggles, Enter confirms, a/n select all/none, q quits.
# Reads raw bytes from /dev/tty: under `curl | bash` stdin is the script itself, so
# any plain read hits EOF and a menu could never appear.
#
# POSTDARE_KEYS is a test seam - it replays a byte string instead of the terminal, so
# the selection logic can be exercised without a human (e.g. POSTDARE_KEYS=$'\033[B \r').
_KEYS="${POSTDARE_KEYS:-}"
_restore_tty() { [ -n "${_SAVED_TTY:-}" ] && stty "$_SAVED_TTY" <"$TTY" 2>/dev/null; return 0; }

_read_byte() { # sets _BYTE
  if [ -n "$_KEYS" ]; then _BYTE="${_KEYS:0:1}"; _KEYS="${_KEYS:1}"; return 0; fi
  IFS= read -rsn1 _BYTE <"$TTY" || return 1
}
_read_key() { # sets _KEY, folding 3-byte escape sequences
  _read_byte || return 1
  _KEY="$_BYTE"
  if [ "$_KEY" = $'\033' ]; then
    _read_byte && _KEY="$_KEY$_BYTE"
    _read_byte && _KEY="$_KEY$_BYTE"
  fi
  return 0
}

select_apps() { # select_apps <space separated candidates> -> echoed comma list
  local list="$1" a n=0 i=0
  local -a items sel
  for a in $list; do items[$n]="$a"; sel[$n]=1; n=$((n + 1)); done
  [ "$n" = 0 ] && return 1

  # POSTDARE_KEYS replays a byte string instead of the terminal. That is the only way to
  # exercise the selection logic from a script, and it also keeps the selector usable
  # with no tty attached.
  local testmode=0 out="$TTY"
  if [ -n "${POSTDARE_KEYS:-}" ]; then testmode=1; out=/dev/stderr; fi

  # No terminal, or -y: take everything, no questions.
  if [ "$ASSUME_YES" = 1 ] || { [ "$testmode" = 0 ] && ! have_tty; }; then
    printf '%s' "$(printf '%s' "$list" | tr ' ' ',')"
    return 0
  fi

  local cur=0 block=$((n + 2)) hint="↑/↓ move · Space toggle · Enter confirm · a all · n none"
  local first=1 chosen count
  if [ "$testmode" = 0 ]; then
    _SAVED_TTY="$(stty -g <"$TTY" 2>/dev/null)"
    [ -n "$_SAVED_TTY" ] && stty -icanon -echo min 1 time 0 <"$TTY" 2>/dev/null
    trap '_restore_tty' EXIT INT TERM
  fi

  draw() {
    local j mark
    if [ "$first" = 1 ]; then first=0; else printf '\033[%dA' "$block" >"$out"; fi
    printf '\033[K  %sWhich should be themed?%s\n' "$C_B" "$C_R" >"$out"
    for j in $(seq 0 $((n - 1))); do
      mark=' '; [ "${sel[$j]}" = 1 ] && mark='x'
      if [ "$j" = "$cur" ]; then
        printf '\033[K  %s\033[7m %s [%s] %-12s\033[0m %s\n' "$C_HL" "$j" "$mark" "${items[$j]}" "${C_D}$(detect_note "${items[$j]}")$C_R" >"$out"
      else
        printf '\033[K    %s [%s] %-12s %s%s%s\n' "$j" "$mark" "${items[$j]}" "$C_D" "$(detect_note "${items[$j]}")" "$C_R" >"$out"
      fi
    done
    printf '\033[K  %s%s%s\n' "$C_D" "$hint" "$C_R" >"$out"
  }

  while :; do
    draw
    _read_key || break
    case "$_KEY" in
      $'\033[A'|k) cur=$((cur == 0 ? n - 1 : cur - 1));;
      $'\033[B'|j) cur=$((cur == n - 1 ? 0 : cur + 1));;
      ' ')         if [ "${sel[$cur]}" = 1 ]; then sel[$cur]=0; else sel[$cur]=1; fi;;
      a|A)         for i in $(seq 0 $((n - 1))); do sel[$i]=1; done;;
      n|N)         for i in $(seq 0 $((n - 1))); do sel[$i]=0; done;;
      q|Q|$'\003') [ "$testmode" = 0 ] && { _restore_tty; trap - EXIT INT TERM; }
                   printf '\n' >&2; die "cancelled";;
      ''|$'\r'|$'\n') break;;
    esac
  done
  if [ "$testmode" = 0 ]; then _restore_tty; trap - EXIT INT TERM; fi

  chosen=""; count=0
  for i in $(seq 0 $((n - 1))); do
    if [ "${sel[$i]}" = 1 ]; then chosen="${chosen:+$chosen,}${items[$i]}"; count=$((count + 1)); fi
  done
  # Everything below goes to stderr: stdout is this function's return channel, and a
  # stray line of diagnostics there would end up inside $APPS.
  printf '\n' >&2
  if [ "$count" = 0 ]; then printf '  %snothing selected — nothing to do%s\n' "$C_D" "$C_R" >&2; return 1; fi
  printf '  %s✓%s selected: %s\n' "$C_OK" "$C_R" "$chosen" >&2
  printf '%s' "$chosen"
}

# ── pick apps ─────────────────────────────────────────────────────────
if [ -z "$APPS" ] && [ "$UNINSTALL" != 1 ]; then
  step "Detected"
  avail=""
  for a in pi ghostty oh-my-posh zsh; do
    if detect "$a"; then ok "$a"; avail="${avail:+$avail }$a"; else dim "$a — not installed"; fi
  done
  [ -z "$avail" ] && die "none of pi, ghostty, oh-my-posh found; pass --only to force"

  say ""
  # select_apps runs in a subshell, so its own `exit` cannot stop this script - check the
  # status here, or a cancelled menu would fall through to "no apps applied" and exit 0.
  picks="$(select_apps "$avail")" || { say ""; exit 1; }
  APPS="$picks"
  [ -z "$APPS" ] && { say ""; exit 1; }
fi

# Both variants are always installed; --mode only decides which one is active.
[ -z "$MODE" ] && MODE=light
case "$MODE" in light) VARIANT=earendil-light;; dark) VARIANT=earendil-dark;; esac
OTHER=earendil-light; [ "$VARIANT" = earendil-light ] && OTHER=earendil-dark

has_app() { case ",$APPS," in *",$1,"*) return 0;; *) return 1;; esac; }

if [ "$DRY" = 1 ]; then
  step "Dry run — nothing will be written"
fi

# ─────────────────────────────────────────────────────────────────────
# pi
# ─────────────────────────────────────────────────────────────────────
install_pi() {
  step "pi"
  local themes="$HOME/.pi/agent/themes" settings="$HOME/.pi/agent/settings.json"
  for f in earendil-light earendil-dark; do
    local target="$themes/$f.json" src="$SRC/pi/$f.json"
    [ -f "$src" ] || { err "missing $src"; return 1; }
    if [ "$DRY" = 1 ]; then dim "would link $(tilde "$target") -> $(tilde "$src")"; continue; fi
    mkdir -p "$themes"
    rm -f "$target"
    ln -s "$src" "$target"
    ok "linked $(tilde "$target")"
  done
  if [ "$DRY" = 1 ]; then dim "would set theme=$VARIANT in $(tilde "$settings")"; return 0; fi
  mkdir -p "$(dirname "$settings")"
  backup "$settings"
  python3 - "$settings" "$VARIANT" <<'PY'
import json, os, sys
path, variant = sys.argv[1:3]
d = {}
if os.path.exists(path):
    try: d = json.load(open(path))
    except Exception: d = {}
d['theme'] = variant
open(path, 'w').write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
PY
  ok "theme = $VARIANT in $(tilde "$settings")"
  dim "restart pi, or run /settings, to apply it in a running session"
}

# ─────────────────────────────────────────────────────────────────────
# ghostty
# ─────────────────────────────────────────────────────────────────────
install_ghostty() {
  step "Ghostty"
  local cfg="$HOME/.config/ghostty/config"
  local gtheme="$SRC/ghostty/earendil"
  [ "$MODE" = dark ] && gtheme="$SRC/ghostty/earendil-dark"
  [ -f "$gtheme" ] || { err "missing $gtheme"; return 1; }

  if [ "$DRY" = 1 ]; then
    dim "would set theme = $gtheme in $(tilde "$cfg")"
    dim "would set window-theme = $MODE"
    dim "would set minimum-contrast = $MIN_CONTRAST if unset"
    return 0
  fi
  mkdir -p "$(dirname "$cfg")"
  [ -f "$cfg" ] || : > "$cfg"
  backup "$cfg"
  set_key "$cfg" theme "$gtheme"
  set_key "$cfg" window-theme "$MODE"
  ok "theme = $(tilde "$gtheme")"
  ok "window-theme = $MODE"
  if grep -q '^minimum-contrast' "$cfg"; then
    dim "minimum-contrast already set, left alone"
  else
    set_key "$cfg" minimum-contrast "$MIN_CONTRAST"
    ok "minimum-contrast = $MIN_CONTRAST"
    dim "this is what rescues tools that hardcode their own colors"
  fi
  if command -v ghostty >/dev/null 2>&1 && ghostty +validate-config >/dev/null 2>&1; then
    ok "config validates"
  fi
  local pid
  pid=$(ps -Ao pid,command 2>/dev/null | grep -F 'MacOS/ghostty' | grep -v grep | awk '{print $1}' | head -1)
  if [ -n "$pid" ]; then
    kill -USR2 "$pid" 2>/dev/null && ok "reloaded (pid $pid)" || dim "press Cmd+Shift+, to reload"
  else
    dim "open a new Ghostty window to see it"
  fi
  dim "note: a light terminal wants window-theme = light, a dark one wants dark"
}

# ─────────────────────────────────────────────────────────────────────
# oh-my-posh
# ─────────────────────────────────────────────────────────────────────
install_omp() {
  step "oh-my-posh"
  local src="$SRC/oh-my-posh/$VARIANT.omp.json"
  local rel="~/.poshthemes/earendil.omp.json"
  local dst="$HOME/.poshthemes/earendil.omp.json"
  local dir="$HOME/.poshthemes"
  [ -f "$src" ] || { err "missing $src"; return 1; }

  if [ "$DRY" = 1 ]; then
    dim "would install earendil-light.omp.json and earendil-dark.omp.json to $(tilde "$dir")"
    dim "would activate $VARIANT as earendil.omp.json"
    [ "$SET_ZSH" = 1 ] && dim "would point .zshrc at $rel"
    return 0
  fi
  mkdir -p "$dir"
  # Both variants land on disk so the prompt can be switched by hand as well as by
  # `theme dark`; the fixed filename is what .zshrc references.
  for v in earendil-light earendil-dark; do
    if [ -f "$SRC/oh-my-posh/$v.omp.json" ]; then
      cp "$SRC/oh-my-posh/$v.omp.json" "$dir/$v.omp.json"
    fi
  done
  cp "$src" "$dst"
  ok "installed earendil-light.omp.json, earendil-dark.omp.json → $(tilde "$dir")"
  ok "active: $VARIANT"

  if [ "$SET_ZSH" = 0 ]; then
    dim "--no-zshrc: add this yourself:"
    dim "  eval \"\$(oh-my-posh init zsh --config $rel)\""
    return 0
  fi
  [ -f "$ZSHRC" ] || { dim "no $(tilde "$ZSHRC"), skipping"; return 0; }
  backup "$ZSHRC"
  python3 - "$ZSHRC" "$rel" <<'PY'
import re, sys
path, cfg = sys.argv[1:3]
text = open(path).read()
line = f'eval "$(oh-my-posh init zsh --config {cfg})"'
pat = re.compile(r'^.*oh-my-posh\s+init\s+zsh.*$', re.M)
if pat.search(text):
    text = pat.sub(line, text, count=1)     # replace, never stack a second prompt
else:
    text = text.rstrip('\n') + f'\n\n# oh-my-posh prompt (Postdare Themes)\n{line}\n'
open(path, 'w').write(text)
PY
  ok "pointed $(tilde "$ZSHRC") at the paper & ink prompt"
  dim "open a new terminal, or 'source $(tilde "$ZSHRC")'"
}

# ─────────────────────────────────────────────────────────────────────
# zsh (oh-my-zsh)
# ─────────────────────────────────────────────────────────────────────
ZSH_THEME_PREV=""
install_zsh() {
  step "zsh (oh-my-zsh)"
  local src="$SRC/zsh/earendil.zsh-theme"
  local dir; dir="$(zsh_custom)/themes"
  local link="$dir/earendil.zsh-theme"
  [ -f "$src" ] || { err "missing $src"; return 1; }

  # Remembered so --uninstall can put the user's own theme back.
  if [ -f "$ZSHRC" ]; then
    ZSH_THEME_PREV="$(grep -m1 -E '^[[:space:]]*ZSH_THEME=' "$ZSHRC" 2>/dev/null | cut -d= -f2- | tr -d '\"' | tr -d "'" | xargs)"
  fi

  if [ "$DRY" = 1 ]; then
    dim "would link $(tilde "$link") -> $(tilde "$src")"
    dim "would set ZSH_THEME=\"earendil\" in $(tilde "$ZSHRC")"
    [ -n "$ZSH_THEME_PREV" ] && dim "  (currently \"$ZSH_THEME_PREV\")"
    return 0
  fi

  mkdir -p "$dir"
  rm -f "$link"
  ln -s "$src" "$link"
  ok "linked $(tilde "$link")"

  [ -f "$ZSHRC" ] || { dim "no $(tilde "$ZSHRC") — set ZSH_THEME=\"earendil\" yourself"; return 0; }
  backup "$ZSHRC"
  python3 - "$ZSHRC" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
pat = re.compile(r'^[ \t]*ZSH_THEME=.*$', re.M)
if pat.search(text):
    text = pat.sub('ZSH_THEME="earendil"', text, count=1)
else:
    text = text.rstrip('\n') + '\n\n# Postdare Themes\nZSH_THEME="earendil"\n'
open(path, 'w').write(text)
PY
  ok "ZSH_THEME=\"earendil\" in $(tilde "$ZSHRC")"
  if [ -n "$ZSH_THEME_PREV" ] && [ "$ZSH_THEME_PREV" != earendil ]; then
    dim "was \"$ZSH_THEME_PREV\" — --uninstall puts it back"
  fi
  dim "open a new shell to see it"
}

# ─────────────────────────────────────────────────────────────────────
# uninstall
# ─────────────────────────────────────────────────────────────────────
uninstall() {
  step "Uninstall"
  local settings="$HOME/.pi/agent/settings.json"
  local themes="$HOME/.pi/agent/themes"
  local cfg="$HOME/.config/ghostty/config"
  local rdir="$DIR" rcfg="" rkeys="" rposh="$HOME/.poshthemes/earendil.omp.json"
  local rzshrc="$ZSHRC" rzshrc_touched=0 rbin="$HOME/.local/bin/theme"

  # Prefer the record written by the install. Parsed rather than sourced, so a
  # damaged manifest cannot execute anything.
  if [ -f "$MANIFEST" ]; then
    local k v
    while IFS='=' read -r k v; do
      case "$k" in
        DIR)            rdir="$v";;
        GHOSTTY_CFG)    rcfg="$v";;
        GHOSTTY_KEYS)   rkeys="$v";;
        POSH_ACTIVE)    rposh="$v";;
        ZSHRC)          rzshrc="$v";;
        ZSHRC_TOUCHED)  rzshrc_touched="$v";;
        ZSH_THEME_PREV) rzsh_theme_prev="$v";;
        BIN_LINK)       rbin="$v";;
      esac
    done < "$MANIFEST"
    ok "using the install record ($(tilde "$MANIFEST"))"
  else
    dim "no install record; falling back to heuristics"
  fi
  [ -n "$rcfg" ] && cfg="$rcfg"
  [ -n "$rzshrc" ] && ZSHRC="$rzshrc"

  # pi — only symlinks that point into the theme directory
  for f in earendil-light earendil-dark; do
    local t="$themes/$f.json"
    if [ -L "$t" ]; then
      if [ "$DRY" = 1 ]; then dim "would remove $(tilde "$t")"
      else rm -f "$t"; ok "removed $(tilde "$t")"; fi
    fi
  done
  dim "left settings.json alone — the theme name there is your preference, not ours"

  # Ghostty — drop exactly the keys we recorded; without a record, infer from the value
  # itself rather than from an assumed install directory (that differs when the script
  # runs from a checkout). A theme pointing at a /ghostty/earendil* path is ours.
  if [ -f "$cfg" ]; then
    if [ -z "$rkeys" ] && grep -qE '^[[:space:]]*theme[[:space:]]*=.*/ghostty/earendil(-dark)?[[:space:]]*$' "$cfg" 2>/dev/null; then
      rkeys="theme window-theme"
    fi
    if [ -n "$rkeys" ]; then
      if [ "$DRY" = 1 ]; then dim "would drop '$rkeys' from $(tilde "$cfg")"
      else
        backup "$cfg"
        python3 - "$cfg" "$rkeys" <<'PY'
import re, sys
path, keys = sys.argv[1], sys.argv[2].split()
text = open(path).read()
for k in keys:
    text = re.sub(rf'^{re.escape(k)}\s*=.*$\n?', '', text, flags=re.M)
open(path, 'w').write(text)
PY
        ok "dropped '$rkeys' from $(tilde "$cfg")"
      fi
    else
      dim "nothing of ours found in $(tilde "$cfg")"
    fi
  fi

  # oh-my-posh — the `earendil*.omp.json` names are ours, so removing them is unambiguous
  local f found=0
  for f in "$HOME/.poshthemes"/earendil*.omp.json; do
    [ -f "$f" ] || continue
    found=1
    if [ "$DRY" = 1 ]; then dim "would remove $(tilde "$f")"
    else rm -f "$f"; ok "removed $(tilde "$f")"; fi
  done
  [ "$found" = 0 ] && dim "nothing of ours in ~/.poshthemes"

  # .zshrc — `~/.poshthemes/earendil.omp.json` is a filename only this repo uses, so
  # matching it is unambiguous. Not gated on the install record: leaving the line behind
  # after removing the file it points at would make every new shell print an error.
  if [ -f "$ZSHRC" ] && grep -q 'poshthemes/earendil\.omp\.json' "$ZSHRC"; then
    if [ "$DRY" = 1 ]; then dim "would drop the oh-my-posh line from $(tilde "$ZSHRC")"
    else
      backup "$ZSHRC"
      python3 - "$ZSHRC" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(r'^.*oh-my-posh\s+init\s+zsh.*poshthemes/earendil\.omp\.json.*$\n?', '', text, flags=re.M)
text = re.sub(r'^# oh-my-posh prompt \(Postdare Themes\)\n', '', text, flags=re.M)
open(path, 'w').write(text.rstrip('\n') + '\n')
PY
      ok "removed the oh-my-posh line from $(tilde "$ZSHRC")"
    fi
  fi

  # switcher symlink — match the recorded path, or any link pointing at the theme dir
  if [ -L "$rbin" ]; then
    if [ "$DRY" = 1 ]; then dim "would remove $(tilde "$rbin")"
    else rm -f "$rbin"; ok "removed $(tilde "$rbin")"; fi
  fi

  # zsh (oh-my-zsh) — drop the theme link and put the previous theme name back
  local zlink; zlink="$(zsh_custom)/themes/earendil.zsh-theme"
  if [ -L "$zlink" ] || [ -f "$zlink" ]; then
    if [ "$DRY" = 1 ]; then dim "would remove $(tilde "$zlink")"
    else rm -f "$zlink"; ok "removed $(tilde "$zlink")"; fi
  fi
  if [ -f "$ZSHRC" ] && grep -q '^ZSH_THEME="earendil"' "$ZSHRC"; then
    local back="${rzsh_theme_prev:-robbyrussell}"
    [ "$back" = earendil ] && back=robbyrussell
    if [ "$DRY" = 1 ]; then dim "would restore ZSH_THEME=\"$back\""
    else
      backup "$ZSHRC"
      python3 - "$ZSHRC" "$back" <<'PY'
import re, sys
path, back = sys.argv[1:3]
text = open(path).read()
text = re.sub(r'^[ \t]*ZSH_THEME=.*$', f'ZSH_THEME="{back}"', text, count=1, flags=re.M)
open(path, 'w').write(text)
PY
      ok "restored ZSH_THEME=\"$back\""
    fi
  fi

  if [ "$DRY" != 1 ]; then
    rm -f "$MANIFEST"
    dim "cleared the install record"
  fi

  say ""
  dim "the theme directory was left in place: $(tilde "$rdir")"
  dim "backups are named *.bak-postdare — nothing else was touched"
}

# ─────────────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = 1 ]; then uninstall; say ""; exit 0; fi

has_app pi         && install_pi
has_app ghostty    && install_ghostty
has_app oh-my-posh && install_omp
has_app zsh        && install_zsh

# The switcher is the whole point of this repo: three layers, one command.
if [ "$DRY" != 1 ] && [ -f "$SRC/bin/theme" ]; then
  step "Switcher"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$SRC/bin/theme" "$HOME/.local/bin/theme" 2>/dev/null && ok "linked ~/.local/bin/theme"
  dim "theme light | theme dark | theme status"
fi

step "Done"
say "  themes    $(tilde "$SRC")"
[ -n "$APPS" ] && say "  applied   $APPS"
say "  variants  earendil-light, earendil-dark  (both installed)"
say "  active    $MODE"

# Record precisely what we changed so --uninstall does not have to guess.
if [ "$DRY" != 1 ]; then
  mkdir -p "$STATE_DIR"
  # A re-run must not overwrite the recorded original theme with our own name, or
  # --uninstall can no longer put the user's theme back.
  _prev=$ZSH_THEME_PREV
  if [ -f "$MANIFEST" ]; then
    _old="$(sed -n 's/^ZSH_THEME_PREV=//p' "$MANIFEST" | head -1)"
    if [ -n "$_old" ] && [ "$_old" != earendil ]; then _prev="$_old"; fi
  fi
  {
    printf 'DIR=%s\n' "$SRC"
    printf 'APPS=%s\n' "$APPS"
    printf 'MODE=%s\n' "$MODE"
    printf 'GHOSTTY_CFG=%s\n' "$HOME/.config/ghostty/config"
    has_app ghostty && printf 'GHOSTTY_KEYS=theme window-theme\n'
    printf 'POSH_ACTIVE=%s\n' "$HOME/.poshthemes/earendil.omp.json"
    printf 'ZSHRC=%s\n' "$ZSHRC"
    has_app oh-my-posh && [ "$SET_ZSH" = 1 ] && printf 'ZSHRC_TOUCHED=1\n'
    has_app zsh && printf 'ZSH_THEME_PREV=%s\n' "$_prev"
    printf 'BIN_LINK=%s\n' "$HOME/.local/bin/theme"
  } > "$MANIFEST"
  dim "recorded what changed: $(tilde "$MANIFEST")"
fi

say ""
dim "switching later:  theme light   /   theme dark   /   theme status"
dim "rollback:         install.sh --uninstall   (and any *.bak-postdare file)"
dim "this repo must stay on disk — the themes are referenced from it"
