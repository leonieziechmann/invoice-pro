#import "/src/lib.typ": locale, tax

// The region builder function
#let region-pl = lang => (
  meta: (
    region: "pl",
  ),
  // The currency: the amounts are printed with its symbol (e.g. "1.230,00 zł")
  // and rounded to its decimals, and the e-invoice states its code.
  currency: (
    code: "PLN",
    symbol: "zł",
  ),
  format: (
    // Customize date formatting: a date, a range, or none (no date)
    date: val => if type(val) == datetime {
      val.display("[day].[month].[year]")
    } else if type(val) == array {
      // Handle date ranges safely
      (
        val.first().display("[day].[month].[year]")
          + " - "
          + val.last().display("[day].[month].[year]")
      )
    },
  ),
  tax: (
    // Set standard Polish VAT
    default-vat: tax.vat(23%),
  ),
)
