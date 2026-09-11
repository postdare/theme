# Earendil — pi Themes

Two warm "paper & ink" themes for [pi](https://github.com/earendil-works/pi), derived from the
palette of Earendil's own RFC-style letter design.

- **Earendil Light** — cream paper, warm ink, amber accent.
- **Earendil Dark** — the same two inks inverted onto warm charcoal.

## Preview & Colors

| Role | Light | Dark |
|------|-------|------|
| Paper (background) | `#e8e5de` | `#1b1710` |
| Ink (body text) | `#241c11` | `#e8e5de` |
| Amber (accent) | `#9a6e1e` | `#e1ab4f` |
| Muted / dim | `#686259` / `#7a7364` | `#8e8779` / `#6e685c` |
| Olive (success, `diff +`) | `#63632e` | `#a3a85f` |
| Vermilion (error, `diff −`) | `#9a3b22` | `#c86a4a` |
| Selection | `#e7d9b8` | `#382e1b` |

## Installation

Link the theme files into pi's global theme directory:

```bash
ln -sf "$(pwd)/pi/earendil-light.json" ~/.pi/agent/themes/earendil-light.json
ln -sf "$(pwd)/pi/earendil-dark.json"  ~/.pi/agent/themes/earendil-dark.json
```

Then pick one via `/settings`, or set it in `~/.pi/agent/settings.json`:

```json
{ "theme": "earendil-light" }
```

To follow the terminal's light/dark appearance automatically, use the paired form:

```json
{ "theme": "earendil-light/earendil-dark" }
```

> **Caveat.** The paired form relies on pi detecting the terminal background
> (terminal color-scheme query → OSC 11 → `COLORFGBG` → fallback `"dark"`).
> Terminals that export no `COLORFGBG` and answer no query silently fall through
> to `dark`, which renders light text on a light background. Prefer an explicit
> single theme unless the detection is known to work.

Editing an active theme file hot-reloads it in the running session, so colors can
be tuned live.

## Design Notes

The palette is deliberately narrow: **every hue sits between 20° and 60°**, with the
single exception of the vermilion used for errors and removed lines (~12°). There is
no blue and no green. Everything is distinguished by lightness and by small hue
shifts inside the warm range.

Semantics follow two-ink printing rather than the usual green/red convention:

| Meaning | Ink |
|---------|-----|
| success, added lines | olive `#63632e` |
| error, removed lines | vermilion `#9a3b22` |

### Gotcha: `mdCodeBlockBorder` is text, not a rule

pi's markdown renderer colors the **fence lines — backticks and language label — with
`mdCodeBlockBorder`**:

```js
case "code": {
  lines.push(this.theme.codeBlockBorder("```" + (token.lang || ""))); // ```ini
  lines.push(this.theme.codeBlock(codeLine));                          // body
  lines.push(this.theme.codeBlockBorder("```"));                       // closing fence
}
```

Treating it as a decorative separator (a near-background tint) makes the fences and the
language label invisible. It needs body-text contrast — at least **4.5:1**.
The same applies to `mdHr` and `mdQuoteBorder`, which are drawn as repeated glyphs.

### Contrast budget

Because a terminal theme paints only foregrounds — the background comes from the
terminal — every token was audited against **its actual background**, not just against
the page. Tool boxes (`toolPendingBg`, `toolSuccessBg`, `toolErrorBg`) are lighter than
the page in light mode and lighter than the page in dark mode too, so diff colors must
be checked against `toolPendingBg` specifically.

Minimums used: 4.5:1 for text, 3.0:1 for de-emphasized text, 2.0:1 for rules and
borders, 1.8:1 for the editor border. Both themes pass for all 47 audited tokens.

## Related

- [`ghostty/earendil`](../ghostty/earendil) — the matching Ghostty terminal palette.
