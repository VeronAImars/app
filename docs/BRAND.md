# k3sm brand in the app

This page records how the app carries the k3sm brand that k3sm.io uses, so a
view, an icon or a release asset can be checked against one list. The site's
stylesheet is the reference: where the app differs from it, the difference is
listed under [Open differences](#open-differences) until the maintainers rule
on it.

## The mark

The mark is the butterfly. Its source of truth is `Resources/k3sm-mark.svg`,
the same paths the site serves as `favicon.svg` (the favicon only crops the
view box to a square).

| Part | Light | Dark | Used for |
|---|---|---|---|
| Upper wings (`k3sm-a`) | `#022ffb` | `#6f88fe` | the bright half of the two-tone mark |
| Lower wings (`k3sm-b`) | `#011389` | `#2d48fe` | the deep half |

The app draws the mark in three forms:

- **Two-tone**, from the SVG: the app icon (`hack/make-icon.sh` renders
  `Resources/AppIcon.icns`).
- **One silhouette**, from `Butterfly.swift`: the wordmark glyph and the tour.
  The path is the SVG's outline normalised to the favicon's square view box.
- **Template**, from `StatusImage.swift`: the menu bar status item, flat black
  that the menu bar tints, with the degraded triangle and the LAN dot as
  badges.

Rules:

- Change the mark in the SVG first, then regenerate the icon and update
  `Butterfly.swift` from it. Never edit one copy alone.
- Never recolour the two-tone mark outside the four values above, and never add
  outlines, gradients or shadows to the mark itself. The single-colour forms
  (template, silhouette) take their colour from the surface they sit on.
- The name is written `k3sm`, lowercase, everywhere, including the start of
  a sentence.

## Colour

The site defines its colours as roles (`--accent`, `--ink`, `--muted`, ...).
The app's `Palette` names colours by role too, so a view never spells a hex
value. The site's roles, for reference:

| Role | Site light | Site dark |
|---|---|---|
| brand bright / deep | `#022ffb` / `#011389` | same |
| accent (links, focus, selection) | `#1633e0` | `#7d97ff` |
| background / surface | `#f7f7f8` / `#ffffff` | `#0a0b0d` / `#101216` |
| ink / muted | `#0b0c0e` / `#6b7177` | `#f3f4f6` / `#9aa1a9` |
| line / line strong | `#e4e6ea` / `#b9bec6` | `#23262c` / `#454a53` |
| good / warn | `#216e45` / `#875810` | `#4cc287` / `#e0a33e` |

The site's text colours meet WCAG AA (4.5:1) against the surface they sit on,
in both appearances. The app's do not yet; see items 3 and 4 below.

## Type

System faces only, on the site and in the app: San Francisco for text
(`system-ui`, `.system`) and SF Mono for code, names and figures
(`ui-monospace`, `.monospaced`). Figures that update in place use tabular
numbers.

## Open differences

Each item is a place where the app and the site disagree today. Each one
needs a maintainer ruling, not a silent fix.

1. **Accent.** The app uses brand bright `#022ffb` as its accent. The site
   uses `#1633e0` for its accent and keeps `#022ffb` for the mark.
2. **Neutrals.** The app's greys are blue-tinted (`#f6f7fb`, `#e3e5ee`,
   `#565c73`, `#8a8fa3`). The site's are near-neutral (`#f7f7f8`, `#e4e6ea`,
   `#6b7177`).
3. **Contrast.** The app's label colour `ink3` `#8a8fa3` measures 3.21:1 on
   white, under AA for 11 pt text. The site's `--muted` `#6b7177` measures
   4.94:1.
4. **Status colours.** The app's ok `#17914f` (4.04:1 on white) and warn
   `#b86a00` (4.12:1) are lighter than the site's good `#216e45` (6.21:1)
   and warn `#875810` (6.12:1). The site has no "bad" role. The app's bad is
   `#c9302c`.
5. **Dark appearance.** The site follows the system appearance and has a full
   dark palette. The console forces light (`ConsoleView`), and the app's
   palette has no dark values. The mark's dark wing colours are in the SVG
   but not in `Palette`.
6. **The navy panel.** The console's Mac panel is `#070d3d` with meters in
   `#5f7bff`, `#b9c5ff` and `#3a4380`. It is the console's own surface, and
   the site has none like it. Either the site adopts it (a hero or a docs
   callout), or this page names it as app-only.
7. **The app icon on macOS 26.** `make-icon.sh` ships the mark alone on a
   transparent canvas, by the maintainers' choice. macOS 26 places an icon
   without its own shape inside a grey rounded square in the Dock and
   Finder, so users see a grey tile the brand does not define. A layered
   icon built with Icon Composer (the two wing tones as layers, with light,
   dark and tinted variants) would let the system render the mark without
   the tile.
8. **Motion (proposed).** Nothing in the app moves the mark today. If it
   does, it flutters by folding its wings (a horizontal scale toward its
   centre line) and never spins or bounces. It moves only on an event or a
   long interval, never in a constant loop, and holds still when the system's
   Reduce Motion setting is on.

Contrast figures are WCAG 2 relative-luminance ratios computed from the hex
values above.
