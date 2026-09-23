/// [ppi: 12]

// Look x layout matrix, part 1 (prototype tests/matrix.typ): classic, plain,
// corporate, elegant and prestige on every layout and on their own (auto).
#import "/tests/theme/body.typ": layouts
#import "/tests/theme/matrix.typ": matrix

#matrix(
  ("classic", "plain", "corporate", "elegant", "prestige")
    .map(p => ("auto", ..layouts).map(l => (p, l)))
    .join(),
)
