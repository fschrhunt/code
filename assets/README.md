<h1 align="center">
  <img src="lockup/lockup.black-on-acid.svg" alt="Workframe" width="420">
</h1>

Brand assets for Workframe, grouped by what they are. Everything is generated
by [`build.sh`](build.sh) from a single set of path data — edit that script,
not the files it writes.

```bash
assets/build.sh
```

`build.sh` clears and rewrites `logo/`, `wordmark/` and `lockup/` on every run,
so don't hand-edit anything inside them. PNG exports need `rsvg-convert`
(`brew install librsvg`); the script skips them cleanly when it is missing.

```text
assets/
├── logo.svg     ← the icon. Start here.
├── logo.png     the same, rasterised at 1024
├── logo/        the brace mark on its own
├── wordmark/    WORKFRAME set on its own
├── lockup/      mark over wordmark — the full signature
└── colors/      colors.json, colors.css
```

**`logo.svg`** is the one to reach for: a 1024×1024 ink mark on an acid tile,
and the same artwork as `logo/logo.black-on-acid.svg`. It doubles as the
favicon — the mark runs to 81% of the tile, which keeps its strokes above 1px
all the way down to 16px, so no pre-rendered favicon sizes are needed. Point
`<link rel="icon">` straight at it.

(`logo.svg` the file and `logo/` the folder are separate things — the folder
holds the bare mark with no tile behind it.)

## Colors

| Token | Hex | Use |
| --- | --- | --- |
| Acid | `#F0FB29` | Primary. Backgrounds, and the mark on dark surfaces. |
| Ink | `#202020` | Primary. The mark on acid, and dark backgrounds. |
| White | `#FFFFFF` | The mark over photography or non-brand dark surfaces. |

Machine-readable in [`colors/colors.json`](colors/colors.json) and
[`colors/colors.css`](colors/colors.css). Both also carry the terminal palette
that `lib/palette.sh` uses for CLI output — change one, change the other.

## Which shape

**`logo/`** — the brace pair alone. Use it when the name is already present, or
where the lockup would be illegible: app icons, favicons, avatars, anything
below ~120px wide.

**`wordmark/`** — WORKFRAME with no mark. For headers and footers where a mark
would be redundant.

**`lockup/`** — the full signature, and the default choice for READMEs, docs
and anywhere the brand needs to introduce itself.

## Which file

Each folder holds transparent SVGs, boxed SVGs with the brand's rounded
container baked in, and PNG exports side by side.

| Folder | Transparent | Boxed | PNG |
| --- | --- | --- | --- |
| `logo/` | `logo.{acid,black,white}.svg` — 72×54 | `logo.{black-on-acid,acid-on-black,white-on-black}.svg` — 1024×1024 | `logo.black-on-acid.{1024,512,256}.png`, plus 512px of each other variant |
| `wordmark/` | `wordmark.{acid,black,white}.svg` — 568×58 | — | — |
| `lockup/` | `lockup.{acid,black,white}.svg` — 568×157 | `lockup.{black-on-acid,acid-on-black,white-on-black}.svg` — 713×218 | `lockup.{black,white,acid}@2x.png`, `lockup.black-on-acid@2x.png` |

Defaults: **`logo.svg`** for icons and favicons,
**`lockup/lockup.black-on-acid.svg`** for everything else. The latter is the
master artwork every other file is derived from.

## Icon geometry

Every tile — `logo.svg` and the three `logo/` boxed variants — shares one
construction, defined on a 1024 box:

| | |
| --- | --- |
| Corner radius | 160 (15.6% of the box) |
| Mark width | 829.333 (81%), at `(97, 201)` |

The mark running nearly edge to edge is load-bearing, not just a look: its
strokes are ~1/9 of its width, so at 81% they stay above 1px all the way down
to a 16px favicon. Scale the numbers proportionally for any other box size.

## Using them

Clear space around any shape is one brace-width — `logo/logo.acid.svg` is 72
units wide, so 72 units on all sides. Acid on white fails contrast at text
sizes: keep acid as a background, or pair it with ink.

Don't recolor outside the three brand colors, redraw the mark, stretch
non-uniformly, or add effects. If you need a new variant, add it to `build.sh`
so it stays in sync with the master geometry.
