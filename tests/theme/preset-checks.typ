// The preset validation fixture (prototype tests/preset-checks.typ): one preset
// on one layout with a seed colour, WCAG AA contrast checks (core pairs + the
// preset's checks.pairs) and an optional image logo with alt text.
#import "/tests/theme/body.typ": *

/// The theme: `seed` (hex or none), `image-logo`, `tint` (hex or none), `layout`.
#let checked-theme(
  look,
  layout: auto,
  seed: none,
  image-logo: false,
  tint: none,
) = {
  let th = preset-of(look).with(
    theme.custom.checks(min-contrast: 4.5),
    theme.custom.logo(image: if image-logo {
      image("/tests/theme/gallery/vossberg.svg", alt: "Atelier Nord GmbH")
    } else { logo-img }),
    if seed != none { theme.custom.colors(primary: rgb(seed)) },
    // negative check: a dark tint must fail the preset's own pairs
    if tint != none { theme.custom.colors(tint: rgb(tint)) },
  )
  if layout == auto { th } else { th.with(layout: layout-of(layout)) }
}

/// The invoice arguments (without the body).
#let checked-args(look, zugferd: false, validation: "draft", ..theme-args) = (
  theme: checked-theme(look, ..theme-args),
  locale: test-locale,
  validation: validation,
  ..party,
  zugferd: if zugferd { "basic" },
)
