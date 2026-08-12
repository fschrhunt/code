# Workframe assets

The mark is a single rectangular frame. The only brand colors are ink and
white.

```text
assets/
├── logo.svg        ink mark
├── logo-white.svg  white mark
└── build.sh         regenerates both variants and favicon.svg
```

| Token | Hex |
| --- | --- |
| Ink | `#09090B` |
| White | `#FFFFFF` |

`logo.svg` is the canonical source provided by the design. Run
`assets/build.sh` after changing its geometry; do not create alternate marks,
wordmarks, tiles, or color variants.
