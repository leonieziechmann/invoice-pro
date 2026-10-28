/// [ppi: 40]

// P2 with a digital letterhead (prototype tests/p2-stationery.typ, output=pdf):
// the first-page art behind page 1, the rest-page art behind page 2, no marks,
// no continuation header (the rest-page art carries its own).
#import "/tests/theme/stationery.typ": stationery-invoice

#stationery-invoice("pdf")
