// presets technical and soft: contrast (core pairs + the looks' checks.pairs) for
// the default seed and brand seeds from very dark to very light, strict level;
// kit helpers; the looks replace few parts and keep the built-in items table.
#import "/src/lib.typ": *
#import "/src/theming/looks/kit.typ"

#let seeds = (
  auto,
  rgb("#0f766e"),
  rgb("#111827"),
  rgb("#facc15"),
  rgb("#db2777"),
  rgb("#a3e635"),
  rgb("#1d4ed8"),
  rgb("#9c3d26"),
)
#let rows = ()
#for (name, preset) in (technical: theme.technical, soft: theme.soft) {
  for seed in seeds {
    // strict: any pair below 4.5:1 panics and names the pair
    let th = theme.resolve(preset.with(
      theme.custom.colors(primary: seed),
      theme.custom.checks(min-contrast: 4.5),
    ))
    let pairs = th.checks.pairs
    assert(
      pairs.len() >= 2,
      message: name + ": declares its own contrast pairs",
    )
    rows.push((
      name,
      if seed == auto { "default" } else { seed.to-hex() },
      pairs.keys().join(", "),
    ))
  }
}

// the looks' pairs are registered under their names
#let th = theme.resolve(theme.technical)
#assert(
  "technical-accent-labels" in th.checks.pairs
    and "technical-payable" in th.checks.pairs,
)
#let th = theme.resolve(theme.soft)
#assert(
  "soft-brand-on-tint" in th.checks.pairs
    and "soft-text-on-tint" in th.checks.pairs,
)

// replaced-part budget: the built-in items table stays (totals as its footer in
// technical; a wrap in soft), few replaced renderers
#let replaced(p) = theme.resolve(p).spec.replaced
#assert(
  "items-table" not in replaced(theme.technical),
  message: "technical keeps the built-in items table",
)
#assert(
  "items-table" not in replaced(theme.soft),
  message: "soft wraps (not replaces) the items table",
)
#assert(
  replaced(theme.technical).len() <= 4,
  message: "technical replaces " + repr(replaced(theme.technical)),
)
#assert(
  replaced(theme.soft).len() <= 6,
  message: "soft replaces " + repr(replaced(theme.soft)),
)

// kit.strip-word: the title stack never repeats the document word
#assert.eq(kit.strip-word("Invoice — Sprint 14", "Invoice"), "Sprint 14")
#assert.eq(kit.strip-word("invoice: March", "Invoice"), "March")
#assert.eq(kit.strip-word("Rechnung", "Rechnung"), none)
#assert.eq(
  kit.strip-word("Catering am 12.09.", "Rechnung"),
  "Catering am 12.09.",
)
#assert.eq(kit.strip-word([Invoice X], "Invoice"), [Invoice X]) // content stays as it is

#set page(width: auto, height: auto, margin: 1em)
#table(
  columns: 3,
  [preset],
  [seed],
  [own pairs (all >= 4.5 with the core pairs)],
  ..rows.flatten(),
)
PRESETS-GRID CHECKS PASSED
