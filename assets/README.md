# Workframe assets

The mark is a single rectangular frame. The only brand colors are ink and
white.

```text
assets/
├── logo.svg        ink mark
├── logo-white.svg  white mark
└── build.sh         regenerates both mark variants
```

| Token | Hex |
| --- | --- |
| Ink | `#09090B` |
| White | `#FFFFFF` |

`logo.svg` is the canonical source provided by the design. `favicon.svg` is a
separate square icon with the former 16% corner radius. Run `assets/build.sh`
after changing the mark geometry; do not create alternate marks, wordmarks,
tiles, or color variants.
