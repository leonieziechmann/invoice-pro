/// [ppi: 12]

// Look x layout matrix, part 2 (prototype tests/matrix.typ): bold, technical,
// soft, compact and boxed on every layout and on their own (auto), and the docs
// recipe `minimal` on every layout.
#import "/tests/theme/body.typ": layouts
#import "/tests/theme/matrix.typ": matrix

#matrix(
  ("bold", "technical", "soft", "compact", "boxed")
    .map(p => ("auto", ..layouts).map(l => (p, l)))
    .join()
    + layouts.map(l => ("minimal", l)),
)
