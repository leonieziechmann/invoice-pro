/// [ppi: 40]

// P2 on pre-printed paper (prototype tests/p2-stationery.typ, output=print): the
// stationery areas (letterhead, footer) stay empty, the folding marks stay.
#import "/tests/theme/stationery.typ": stationery-invoice

#stationery-invoice("print")
