#!/usr/bin/env bash
# Postdare Themes — one-line installer
#
#   curl -fsSL https://raw.githubusercontent.com/postdare/theme/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --only pi --mode dark
#
#   ./install.sh --dry-run          preview every change
#   ./install.sh --uninstall        remove what this installed
#
# No interpreter beyond awk: a fresh Mac has no usable python3 (/usr/bin/python3 is a
# stub that pops the Xcode CLT dialog), and a one-line theme installer has no business
# making you install Xcode first.
#
# Bash 3.2 compatible on purpose: that is what macOS ships, and `${var,,}`,
# `declare -A` and `readarray` would break silently there.
set -uo pipefail

# If this script is piped (curl | bash), stdin IS the script. Copy it to a temp file and
# re-exec from there so subprocesses cannot accidentally consume it.
#
# The test is "can I find myself on disk", not "is stdin a pipe". Under `curl | bash`
# BASH_SOURCE is unset and $0 is "bash", so there is no file; when the script runs as a
# file, BASH_SOURCE points at it. Testing the pipe instead hangs forever on
# `ssh host 'bash install.sh'`, cron and CI — stdin is a pipe there too, so the script
# would sit in `cat` waiting for an EOF that never comes.
if [ ! -t 0 ] && [ ! -f "${BASH_SOURCE[0]:-$0}" ]; then
  _tmp=$(mktemp /tmp/postdare-install.XXXXXX) || exit 1
  cat > "$_tmp"
  chmod +x "$_tmp"
  # stdin goes to /dev/null: the original pipe held the script, and any subprocess that
  # reads stdin would consume it. Prompts read /dev/tty directly, so the menu still works.
  # Run via `bash -c source` rather than `bash file`; the latter makes bash try to claim a
  # controlling terminal in headless sessions and print a spurious /dev/tty warning.
  bash -c 'source "$0" "$@"' "$_tmp" "$@" < /dev/null
  exit $?
fi

# If we are the temp copy from above, clean ourselves up on exit.
if [[ "$0" == /tmp/postdare-install.* ]]; then
  trap 'rm -f "$0"' EXIT
fi

REPO="postdare/theme"
REF="${THEME_REF:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$REF"

APP_NAME="Postdare Themes"
GHOSTTY_APP="/Applications/Ghostty.app"
MIN_CONTRAST="3"
# Ghostty keys this run is responsible for. minimum-contrast joins the list only when we
# are the ones who added it, so --uninstall never strips a value the user chose.
GHOSTTY_KEYS="theme window-theme"

# ── output ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_R=$'\033[0m'; C_D=$'\033[2m'; C_B=$'\033[1m'
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_HL=$'\033[36m'
else
  C_R=''; C_D=''; C_B=''; C_OK=''; C_WARN=''; C_ERR=''; C_HL=''
fi
say()  { printf '%s\n' "$*"; }
# One aligned line per app — the whole report is this plus a footer.
row()  { printf '  %-12s %s%s%s\n' "$1" "$C_D" "$2" "$C_R"; }
hint() { printf '  %s%s%s\n' "$C_D" "$*" "$C_R"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_R" "$*" >&2; }
err()  { printf '  %s✗%s %s\n' "$C_ERR" "$C_R" "$*" >&2; }
die()  { err "$*"; exit 1; }

# The selector reads raw bytes from the terminal, not stdin: under `curl | bash` stdin is
# the script itself, so a plain read hits EOF and the menu could never appear.
TTY=/dev/tty
# In headless ssh sessions /dev/tty exists and is even -r/-w but opening it fails. Redirect
# fd 0 from it and ask bash whether that fd is a tty.
#
# The 2>/dev/null must come FIRST: redirections apply left to right, so with it trailing
# the failed open is still reported on the original stderr and every headless run — ssh,
# cron, CI, Docker — prints `/dev/tty: No such device or address`.
have_tty() { [ -t 0 ] 2>/dev/null <"$TTY"; }

# ── file editing (awk only) ───────────────────────────────────────────
# Every edit writes a temp file and renames it, so a failure part-way through leaves the
# original intact rather than a half-written config.

backup() { # backup <file>
  [ -f "$1" ] || return 0
  local b="$1.bak-postdare"
  # First backup wins: it is the only copy of the file as it was before this installer
  # ever touched it. A re-run, or a second section editing the same .zshrc within one
  # run, must not overwrite it with our own output.
  [ -e "$b" ] && return 0
  cp "$1" "$b"
}

# Replace a whole-line `key = value`, or append it when absent. Never duplicates.
set_key() { # set_key <file> <key> <value>
  local f="$1" k="$2" v="$3" tmp="$1.postdare.$$"
  [ -f "$f" ] || : > "$f"
  awk -v k="$k" -v v="$v" '
    BEGIN { hit = 0 }
    !hit && $0 ~ "^[ \t]*" k "[ \t]*=" { print k " = " v; hit = 1; next }
    { print }
    END { if (!hit) print k " = " v }
  ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f"
}

# Drop whole `key = ...` lines. Used by --uninstall.
drop_keys() { # drop_keys <file> <key…>
  local f="$1"; shift
  local tmp="$f.postdare.$$"
  awk -v keys="$*" '
    BEGIN { n = split(keys, a, " ") }
    { for (i = 1; i <= n; i++) if ($0 ~ "^[ \t]*" a[i] "[ \t]*=") next
      print }
  ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f"
}

# pi's settings.json only ever needs one top-level string key set. Substituting an
# existing `"key": "..."` covers every case but a first install, where the key goes in
# right after the opening brace. Anything more exotic fails loudly instead of guessing —
# a mangled settings.json is far worse than a message.
set_json_string() { # set_json_string <file> <key> <value>
  local f="$1" k="$2" v="$3" tmp="$1.postdare.$$"
  if [ ! -s "$f" ]; then
    printf '{\n  "%s": "%s"\n}\n' "$k" "$v" > "$f"
    return $?
  fi
  awk -v k="$k" -v v="$v" '
    BEGIN { hit = 0 }
    !hit && $0 ~ "\"" k "\"[ \t]*:" {
      sub("\"" k "\"[ \t]*:[ \t]*\"[^\"]*\"", "\"" k "\": \"" v "\"")
      hit = 1
    }
    { buf[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        print buf[i]
        if (!hit && i == 1 && buf[i] ~ /^[ \t]*\{[ \t]*$/) {
          print "  \"" k "\": \"" v "\","
          hit = 1
        }
      }
      if (!hit) exit 1
    }
  ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f"
}

# Replace the first line matching <regex>, or append <line> under a marker comment.
set_line() { # set_line <file> <regex> <line> <comment>
  local f="$1" re="$2" line="$3" note="$4" tmp="$1.postdare.$$"
  [ -f "$f" ] || : > "$f"
  awk -v re="$re" -v line="$line" -v note="$note" '
    BEGIN { hit = 0 }
    !hit && $0 ~ re { print line; hit = 1; next }
    { print }
    END { if (!hit) { print ""; print note; print line } }
  ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f"
}

# Drop lines matching <regex>, plus our marker comment, plus any trailing blank lines.
drop_line() { # drop_line <file> <regex> <comment>
  local f="$1" re="$2" note="$3" tmp="$1.postdare.$$"
  awk -v re="$re" -v note="$note" '
    $0 ~ re { next }
    note != "" && $0 == note { next }
    { buf[++n] = $0 }
    END {
      while (n > 0 && buf[n] ~ /^[ \t]*$/) n--
      for (i = 1; i <= n; i++) print buf[i]
    }
  ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f"
}

# Collapse $HOME to ~. Deliberately NOT `${1/#$HOME/~}`: bash 5 tilde-expands the
# replacement straight back into $HOME so nothing collapses, while escaping it as `\~`
# leaves a literal backslash on bash 3.2. Prefix matching behaves the same everywhere.
tilde() { # tilde <path>
  case "$1" in
    "$HOME")   printf '~';;
    "$HOME"/*) printf '~%s' "${1#"$HOME"}";;
    *)         printf '%s' "$1";;
  esac
}

# In --dry-run the theme files may not be on disk yet — under `curl | bash` nothing is
# fetched — so a missing source there is expected, not an error.
have_src() { # have_src <path>
  [ -f "$1" ] && return 0
  [ "$DRY" = 1 ] && return 0
  err "missing $1"
  return 1
}

# ── arguments ─────────────────────────────────────────────────────────
APPS=""
MODE=""
DIR="${THEME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/postdare-theme}"
DRY=0
ASSUME_YES=0
UNINSTALL=0
DO_UPDATE=0
SET_ZSH=1
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# Ghostty does NOT support inline comments — anything after `#` is swallowed into the
# value (`window-theme: invalid value "light  # note"`). So the install cannot mark its
# own lines. It records exactly what it touched here instead, and --uninstall replays
# that record. Kept out of the theme directory so it never shows up as untracked.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/postdare-theme"
MANIFEST="$STATE_DIR/installed"

usage() {
  cat <<EOF
$APP_NAME — installer

  curl -fsSL $RAW/install.sh | bash
  curl -fsSL $RAW/install.sh | bash -s -- --only pi --mode dark

  --only <apps>   skip the menu: pi,ghostty,oh-my-posh,zsh
  --mode <m>      which variant is active: light | dark   (default: light)
                  both are always installed — \`theme dark\` switches later
  --dir <path>    where to keep the theme files  (default: $DIR)
  --update        pull the latest theme files and exit
  --no-zshrc      install the oh-my-posh config but do not touch .zshrc
  --dry-run       show what would change, write nothing
  --uninstall     undo it
  -y, --yes       no questions; take everything detected
  -h, --help      this text

Each file it edits is copied to <file>.bak-postdare the first time.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --only|--apps)   APPS="${2:-}"; shift 2 || die "--only needs a value";;
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

# `--only "pi, zsh"` is a natural thing to type. Left alone, the space rides along into
# $APPS and has_app's `,pi, zsh,` match fails for every app but the first — the installer
# would then apply nothing at all while still reporting success.
APPS="$(printf '%s' "$APPS" | tr -d '[:space:]')"
for a in $(printf '%s' "$APPS" | tr ',' ' '); do
  case "$a" in pi|ghostty|oh-my-posh|zsh) ;; *) die "unknown app: $a (want pi, ghostty, oh-my-posh or zsh)";; esac
done

command -v awk >/dev/null 2>&1 || die "awk is required"

# ── locate or fetch the theme files ───────────────────────────────────
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo '')"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/pi/earendil-light.json" ]; then
  SRC="$SELF_DIR"          # running from a checkout
else
  SRC=""
fi

fetch_into() { # fetch_into <dir>
  local dst="$1" tmp
  tmp="$(mktemp -d)" || return 1
  if command -v git >/dev/null 2>&1 &&
     git clone --quiet --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$tmp/t" 2>/dev/null; then
    mkdir -p "$dst" && cp -R "$tmp/t/." "$dst/"; local rc=$?; rm -rf "$tmp"; return $rc
  fi
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" -o "$tmp/t.tgz" 2>/dev/null &&
    mkdir -p "$tmp/x" && tar -xzf "$tmp/t.tgz" -C "$tmp/x" --strip-components=1 2>/dev/null &&
    mkdir -p "$dst" && cp -R "$tmp/x/." "$dst/"
  local rc=$?; rm -rf "$tmp"; return $rc
}

say ""
say "  ${C_B}$APP_NAME${C_R}"

if [ -n "$SRC" ]; then
  # --update from inside a checkout used to fall through to the exit below and report
  # success without fetching anything.
  if [ "$DO_UPDATE" = 1 ]; then
    if [ "$DRY" = 1 ]; then hint "would pull $(tilde "$SRC")"
    elif [ -d "$SRC/.git" ] && git -C "$SRC" pull --ff-only --quiet < /dev/null 2>/dev/null; then
      row "updated" "$(tilde "$SRC")"
    else
      warn "could not fast-forward $(tilde "$SRC") — pull it by hand"
    fi
  fi
else
  if [ -d "$DIR/.git" ]; then
    SRC="$DIR"
    # Reusing silently keeps a stale clone whose theme files may predate what is being
    # installed. Pulling is cheap and non-fatal. < /dev/null keeps git off our stdin.
    if [ "$DRY" != 1 ]; then
      git -C "$DIR" pull --ff-only --quiet < /dev/null 2>/dev/null &&
        [ "$DO_UPDATE" = 1 ] && row "updated" "$(tilde "$DIR")"
    fi
  elif [ "$DRY" = 1 ]; then
    hint "would fetch $REPO@$REF into $(tilde "$DIR")"
    SRC="$DIR"
  else
    mkdir -p "$DIR" || die "cannot create $DIR"
    fetch_into "$DIR" || die "could not download $REPO@$REF"
    SRC="$DIR"
  fi
fi
[ "$DO_UPDATE" = 1 ] && { say ""; exit 0; }

# ── detect ────────────────────────────────────────────────────────────
detect() { # detect <app> -> 0 present
  case "$1" in
    pi)         command -v pi >/dev/null 2>&1 || [ -d "$HOME/.pi" ];;
    ghostty)    [ -d "$GHOSTTY_APP" ] || command -v ghostty >/dev/null 2>&1;;
    oh-my-posh) command -v oh-my-posh >/dev/null 2>&1;;
    zsh)        [ -d "$HOME/.oh-my-zsh" ];;
    *)          return 1;;
  esac
}

detect_note() {
  case "$1" in
    pi)         tilde "$HOME/.pi";;
    ghostty)    [ -d "$GHOSTTY_APP" ] && printf '%s' "$GHOSTTY_APP" || command -v ghostty;;
    oh-my-posh) command -v oh-my-posh 2>/dev/null;;
    zsh)        tilde "$(zsh_custom)";;
  esac
}

# oh-my-zsh's own default is $ZSH/custom; an explicit ZSH_CUSTOM in the environment wins.
zsh_custom() {
  if [ -n "${ZSH_CUSTOM:-}" ]; then printf '%s' "$ZSH_CUSTOM"
  else printf '%s' "$HOME/.oh-my-zsh/custom"; fi
}

# ── selector: space toggles, enter confirms ───────────────────────────
# Reads raw bytes from /dev/tty: under `curl | bash` stdin is the script itself, so any
# plain read hits EOF and a menu could never appear.
#
# POSTDARE_KEYS is a test seam — it replays a byte string instead of the terminal, so the
# selection logic can be exercised without a human (e.g. POSTDARE_KEYS=$'\033[B \r').
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

  local testmode=0 out="$TTY"
  if [ -n "${POSTDARE_KEYS:-}" ]; then testmode=1; out=/dev/stderr; fi

  # No terminal, or -y: take everything, no questions.
  if [ "$ASSUME_YES" = 1 ] || { [ "$testmode" = 0 ] && ! have_tty; }; then
    printf '%s' "$(printf '%s' "$list" | tr ' ' ',')"
    return 0
  fi

  local cur=0 block=$((n + 2)) first=1 chosen count
  if [ "$testmode" = 0 ]; then
    _SAVED_TTY="$(stty -g <"$TTY" 2>/dev/null)"
    [ -n "$_SAVED_TTY" ] && stty -icanon -echo min 1 time 0 <"$TTY" 2>/dev/null
    trap '_restore_tty' EXIT INT TERM
  fi

  printf '\n' >"$out"
  draw() {
    local j mark
    if [ "$first" = 1 ]; then first=0; else printf '\033[%dA' "$block" >"$out"; fi
    for j in $(seq 0 $((n - 1))); do
      mark=' '; [ "${sel[$j]}" = 1 ] && mark='x'
      if [ "$j" = "$cur" ]; then
        printf '\033[K  %s❯%s [%s] %-12s %s%s%s\n' \
          "$C_HL" "$C_R" "$mark" "${items[$j]}" "$C_D" "$(detect_note "${items[$j]}")" "$C_R" >"$out"
      else
        printf '\033[K    [%s] %-12s %s%s%s\n' \
          "$mark" "${items[$j]}" "$C_D" "$(detect_note "${items[$j]}")" "$C_R" >"$out"
      fi
    done
    printf '\033[K\n' >"$out"
    printf '\033[K  %sspace toggle · enter confirm · a all · n none%s\n' "$C_D" "$C_R" >"$out"
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
                   printf '\n' >&2; exit 1;;
      ''|$'\r'|$'\n') break;;
    esac
  done
  if [ "$testmode" = 0 ]; then _restore_tty; trap - EXIT INT TERM; fi

  chosen=""; count=0
  for i in $(seq 0 $((n - 1))); do
    if [ "${sel[$i]}" = 1 ]; then chosen="${chosen:+$chosen,}${items[$i]}"; count=$((count + 1)); fi
  done
  # Everything but the result goes to stderr: stdout is this function's return channel,
  # and a stray line of diagnostics there would end up inside $APPS.
  [ "$count" = 0 ] && return 1
  printf '%s' "$chosen"
}

if [ -z "$APPS" ] && [ "$UNINSTALL" != 1 ]; then
  avail=""
  for a in pi ghostty oh-my-posh zsh; do
    detect "$a" && avail="${avail:+$avail }$a"
  done
  [ -z "$avail" ] && die "none of pi, ghostty, oh-my-posh, zsh found — pass --only to force"

  # select_apps runs in a subshell, so its own `exit` cannot stop this script — check the
  # status here, or a cancelled menu would fall through and exit 0.
  picks="$(select_apps "$avail")" || { say ""; exit 1; }
  APPS="$picks"
  [ -z "$APPS" ] && { say ""; exit 1; }
fi

# Both variants are always installed; --mode only decides which one is active.
[ -z "$MODE" ] && MODE=light
case "$MODE" in light) VARIANT=earendil-light;; dark) VARIANT=earendil-dark;; esac

has_app() { case ",$APPS," in *",$1,"*) return 0;; *) return 1;; esac; }

say ""
[ "$DRY" = 1 ] && hint "dry run — nothing will be written"

# ── pi ────────────────────────────────────────────────────────────────
install_pi() {
  local themes="$HOME/.pi/agent/themes" settings="$HOME/.pi/agent/settings.json" f
  for f in earendil-light earendil-dark; do
    have_src "$SRC/pi/$f.json" || return 1
    [ "$DRY" = 1 ] && continue
    mkdir -p "$themes"
    rm -f "$themes/$f.json"
    ln -s "$SRC/pi/$f.json" "$themes/$f.json" || { err "pi: cannot link $(tilde "$themes/$f.json")"; return 1; }
  done
  if [ "$DRY" = 1 ]; then row pi "$VARIANT"; return 0; fi
  mkdir -p "$(dirname "$settings")"
  backup "$settings"
  set_json_string "$settings" theme "$VARIANT" || {
    err "pi: could not set theme in $(tilde "$settings") — set \"theme\": \"$VARIANT\" by hand"; return 1; }
  row pi "$VARIANT"
}

# ── ghostty ───────────────────────────────────────────────────────────
install_ghostty() {
  local cfg="$HOME/.config/ghostty/config" note="$VARIANT"
  local gtheme="$SRC/ghostty/earendil"
  [ "$MODE" = dark ] && gtheme="$SRC/ghostty/earendil-dark"
  have_src "$gtheme" || return 1
  if [ "$DRY" = 1 ]; then row ghostty "$VARIANT"; return 0; fi

  mkdir -p "$(dirname "$cfg")"
  backup "$cfg"
  set_key "$cfg" theme "$gtheme"      || { err "ghostty: could not write $(tilde "$cfg")"; return 1; }
  set_key "$cfg" window-theme "$MODE" || { err "ghostty: could not write $(tilde "$cfg")"; return 1; }
  # minimum-contrast is what rescues tools that hardcode their own colors. Only ours to
  # set — and later to remove — when the user had no opinion.
  if ! grep -q '^[[:space:]]*minimum-contrast[[:space:]]*=' "$cfg"; then
    set_key "$cfg" minimum-contrast "$MIN_CONTRAST" || { err "ghostty: could not write $(tilde "$cfg")"; return 1; }
    GHOSTTY_KEYS="$GHOSTTY_KEYS minimum-contrast"
  fi

  local pid
  pid=$(ps -Ao pid,command 2>/dev/null | grep -F 'MacOS/ghostty' | grep -v grep | awk '{print $1}' | head -1)
  if [ -n "$pid" ] && kill -USR2 "$pid" 2>/dev/null; then note="$note  reloaded"
  else note="$note  open a new window"; fi
  row ghostty "$note"
}

# ── oh-my-posh ────────────────────────────────────────────────────────
install_omp() {
  local dir="$HOME/.poshthemes" rel="~/.poshthemes/earendil.omp.json" v
  have_src "$SRC/oh-my-posh/$VARIANT.omp.json" || return 1
  if [ "$DRY" = 1 ]; then row oh-my-posh "$VARIANT"; return 0; fi

  mkdir -p "$dir"
  # Both variants land on disk so the prompt can be switched by hand as well as by
  # `theme dark`; the fixed filename is what .zshrc references.
  for v in earendil-light earendil-dark; do
    [ -f "$SRC/oh-my-posh/$v.omp.json" ] && cp "$SRC/oh-my-posh/$v.omp.json" "$dir/$v.omp.json"
  done
  cp "$SRC/oh-my-posh/$VARIANT.omp.json" "$dir/earendil.omp.json" || { err "oh-my-posh: cannot write $(tilde "$dir")"; return 1; }

  if [ "$SET_ZSH" = 0 ]; then
    row oh-my-posh "$VARIANT  add: eval \"\$(oh-my-posh init zsh --config $rel)\""
    return 0
  fi
  [ -f "$ZSHRC" ] || { row oh-my-posh "$VARIANT  no $(tilde "$ZSHRC")"; return 0; }
  backup "$ZSHRC"
  set_line "$ZSHRC" 'oh-my-posh[ \t]+init[ \t]+zsh' \
    "eval \"\$(oh-my-posh init zsh --config $rel)\"" \
    '# oh-my-posh prompt (Postdare Themes)' \
    || { err "oh-my-posh: could not write $(tilde "$ZSHRC")"; return 1; }
  row oh-my-posh "$VARIANT"
}

# ── zsh (oh-my-zsh) ───────────────────────────────────────────────────
ZSH_THEME_PREV=""
install_zsh() {
  local src="$SRC/zsh/earendil.zsh-theme" dir link
  dir="$(zsh_custom)/themes"; link="$dir/earendil.zsh-theme"
  have_src "$src" || return 1

  # Remembered so --uninstall can put the user's own theme back.
  if [ -f "$ZSHRC" ]; then
    ZSH_THEME_PREV="$(grep -m1 -E '^[[:space:]]*ZSH_THEME=' "$ZSHRC" 2>/dev/null |
      cut -d= -f2- | tr -d '"'"'"' \t')"
  fi
  if [ "$DRY" = 1 ]; then row zsh "earendil"; return 0; fi

  mkdir -p "$dir"
  rm -f "$link"
  ln -s "$src" "$link" || { err "zsh: cannot link $(tilde "$link")"; return 1; }

  [ -f "$ZSHRC" ] || { row zsh "earendil  set ZSH_THEME=\"earendil\" yourself"; return 0; }
  backup "$ZSHRC"
  set_line "$ZSHRC" '^[ \t]*ZSH_THEME=' 'ZSH_THEME="earendil"' '# Postdare Themes' \
    || { err "zsh: could not write $(tilde "$ZSHRC")"; return 1; }
  if [ -n "$ZSH_THEME_PREV" ] && [ "$ZSH_THEME_PREV" != earendil ]; then
    row zsh "earendil  was $ZSH_THEME_PREV"
  else
    row zsh "earendil"
  fi
}

# ── uninstall ─────────────────────────────────────────────────────────
uninstall() {
  local themes="$HOME/.pi/agent/themes" cfg="$HOME/.config/ghostty/config"
  local rdir="$DIR" rcfg="" rkeys="" rzshrc="$ZSHRC" rbin="$HOME/.local/bin/theme"
  local rzsh_custom="" rzsh_prev="" k v f n=0

  # Prefer the record written by the install. Parsed rather than sourced, so a damaged
  # manifest cannot execute anything.
  if [ -f "$MANIFEST" ]; then
    while IFS='=' read -r k v; do
      case "$k" in
        DIR)            rdir="$v";;
        GHOSTTY_CFG)    rcfg="$v";;
        GHOSTTY_KEYS)   rkeys="$v";;
        ZSHRC)          rzshrc="$v";;
        ZSH_THEME_PREV) rzsh_prev="$v";;
        ZSH_CUSTOM)     rzsh_custom="$v";;
        BIN_LINK)       rbin="$v";;
      esac
    done < "$MANIFEST"
  fi
  [ -n "$rcfg" ] && cfg="$rcfg"
  [ -n "$rzshrc" ] && ZSHRC="$rzshrc"

  # pi — only the symlinks we made. settings.json is left alone: the theme name there is
  # the user's preference, not ours.
  local pi_hit=0
  for f in earendil-light earendil-dark; do
    if [ -L "$themes/$f.json" ]; then
      pi_hit=1; [ "$DRY" = 1 ] || rm -f "$themes/$f.json"
    fi
  done
  [ "$pi_hit" = 1 ] && { row pi "themes unlinked"; n=$((n + 1)); }

  # Ghostty — drop exactly the keys recorded; without a record, infer from the value
  # itself rather than an assumed install directory (which differs for a checkout).
  if [ -f "$cfg" ]; then
    if [ -z "$rkeys" ] && grep -qE '^[[:space:]]*theme[[:space:]]*=.*/ghostty/earendil(-dark)?[[:space:]]*$' "$cfg" 2>/dev/null; then
      rkeys="theme window-theme"
    fi
    if [ -n "$rkeys" ]; then
      if [ "$DRY" != 1 ]; then
        backup "$cfg"
        drop_keys "$cfg" $rkeys || { err "could not write $(tilde "$cfg")"; return 1; }
      fi
      row ghostty "dropped $rkeys"; n=$((n + 1))
    fi
  fi

  # oh-my-posh — the `earendil*.omp.json` names are ours, so removing them is unambiguous
  local omp_hit=0
  for f in "$HOME/.poshthemes"/earendil*.omp.json; do
    [ -f "$f" ] || continue
    omp_hit=1; [ "$DRY" = 1 ] || rm -f "$f"
  done
  # The .zshrc line is not gated on the record: leaving it behind after removing the file
  # it points at would make every new shell print an error.
  if [ -f "$ZSHRC" ] && grep -q 'poshthemes/earendil\.omp\.json' "$ZSHRC"; then
    omp_hit=1
    if [ "$DRY" != 1 ]; then
      backup "$ZSHRC"
      drop_line "$ZSHRC" 'oh-my-posh[ \t]+init[ \t]+zsh.*poshthemes/earendil\.omp\.json' \
        '# oh-my-posh prompt (Postdare Themes)' || { err "could not write $(tilde "$ZSHRC")"; return 1; }
    fi
  fi
  [ "$omp_hit" = 1 ] && { row oh-my-posh "removed"; n=$((n + 1)); }

  # zsh — drop the theme link and put the previous theme name back. The install may have
  # run with a different ZSH_CUSTOM than this uninstall sees.
  local zlink="${rzsh_custom:-$(zsh_custom)}/themes/earendil.zsh-theme" zsh_hit="" back
  if [ -L "$zlink" ] || [ -f "$zlink" ]; then
    zsh_hit="unlinked"; [ "$DRY" = 1 ] || rm -f "$zlink"
  fi
  if [ -f "$ZSHRC" ] && grep -q '^ZSH_THEME="earendil"' "$ZSHRC"; then
    back="${rzsh_prev:-robbyrussell}"
    [ "$back" = earendil ] && back=robbyrussell
    zsh_hit="ZSH_THEME restored to $back"
    if [ "$DRY" != 1 ]; then
      backup "$ZSHRC"
      set_line "$ZSHRC" '^[ \t]*ZSH_THEME=' "ZSH_THEME=\"$back\"" '# Postdare Themes' \
        || { err "could not write $(tilde "$ZSHRC")"; return 1; }
    fi
  fi
  [ -n "$zsh_hit" ] && { row zsh "$zsh_hit"; n=$((n + 1)); }

  if [ -L "$rbin" ]; then
    [ "$DRY" = 1 ] || rm -f "$rbin"
    row theme "unlinked"; n=$((n + 1))
  fi

  [ "$DRY" = 1 ] || rm -f "$MANIFEST"
  [ "$n" = 0 ] && hint "nothing of ours found"
  say ""
  hint "theme files left at $(tilde "$rdir") · backups are *.bak-postdare"
}

# ── run ───────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = 1 ]; then uninstall; say ""; exit 0; fi

has_app pi         && install_pi
has_app ghostty    && install_ghostty
has_app oh-my-posh && install_omp
has_app zsh        && install_zsh

# The switcher is the whole point of this repo: three layers, one command.
if [ "$DRY" = 1 ]; then
  row theme "~/.local/bin/theme"
elif [ -f "$SRC/bin/theme" ]; then
  mkdir -p "$HOME/.local/bin"
  if ln -sfn "$SRC/bin/theme" "$HOME/.local/bin/theme" 2>/dev/null; then
    row theme "~/.local/bin/theme"
    # Linking a command nobody can run only shows up later, as `theme: command not found`.
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) warn "~/.local/bin is not on \$PATH — add it, or call ~/.local/bin/theme directly";;
    esac
  fi
fi

# Record precisely what changed so --uninstall does not have to guess.
if [ "$DRY" != 1 ]; then
  mkdir -p "$STATE_DIR"
  # A re-run must not overwrite the recorded original theme with our own name, or
  # --uninstall can no longer put the user's theme back.
  _prev=$ZSH_THEME_PREV
  _gkeys=$GHOSTTY_KEYS
  if [ -f "$MANIFEST" ]; then
    _old="$(sed -n 's/^ZSH_THEME_PREV=//p' "$MANIFEST" | head -1)"
    [ -n "$_old" ] && [ "$_old" != earendil ] && _prev="$_old"
    # A re-run finds minimum-contrast already set and leaves it alone, so it would drop
    # out of the record — and --uninstall would then leave our own value behind forever.
    case "$(sed -n 's/^GHOSTTY_KEYS=//p' "$MANIFEST" | head -1)" in
      *minimum-contrast*) case "$_gkeys" in *minimum-contrast*) ;; *) _gkeys="$_gkeys minimum-contrast";; esac;;
    esac
  fi
  {
    printf 'DIR=%s\n' "$SRC"
    printf 'APPS=%s\n' "$APPS"
    printf 'MODE=%s\n' "$MODE"
    printf 'GHOSTTY_CFG=%s\n' "$HOME/.config/ghostty/config"
    has_app ghostty && printf 'GHOSTTY_KEYS=%s\n' "$_gkeys"
    printf 'ZSHRC=%s\n' "$ZSHRC"
    has_app zsh && printf 'ZSH_THEME_PREV=%s\n' "$_prev"
    has_app zsh && printf 'ZSH_CUSTOM=%s\n' "$(zsh_custom)"
    printf 'BIN_LINK=%s\n' "$HOME/.local/bin/theme"
  } > "$MANIFEST"
fi

say ""
hint "theme light · theme dark · theme status"
say ""
