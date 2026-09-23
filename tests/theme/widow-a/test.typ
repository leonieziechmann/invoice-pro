/// [ppi: 12]

// Totals never start a page alone (prototype tests/widow.typ,
// scripts/checks-presets.sh and checks-presets-business.sh): classic, plain and
// corporate on their default layout, 14..22 items, with and without a closing
// group subtotal. The sweep is split over five tests to keep each document
// small; see tests/theme/widow.typ. Compile-only: the low ppi keeps tytanic's
// export of these many pages small.
#import "/tests/theme/widow.typ": widow-sweep

#widow-sweep(("classic", "plain", "corporate").map(p => (p, "auto")))
