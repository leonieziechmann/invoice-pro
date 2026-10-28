// lib.typ
#import "/src/lib.typ": locale

// 1. Import your definitions
#import "lang/pl.typ": pl
#import "region/pl.typ": region-pl

// 2. Build and export the highly-optimized locale
#let pl-pl = locale.build-locale(pl, region-pl)
