/// [ppi: 12]

// Totals never start a page alone (prototype tests/widow.typ,
// scripts/checks-presets.sh and checks-presets-business.sh): technical, compact
// and boxed on their default layout (soft: its totals card is separate by
// design), 14..22 items, with and without a closing group subtotal. The sweep
// is split over five tests to keep each document small; see
// tests/theme/widow.typ. Compile-only: the low ppi keeps tytanic's export of
// these many pages small.
#import "/tests/theme/widow.typ": widow-sweep

#widow-sweep(("technical", "compact", "boxed").map(p => (p, "auto")))
