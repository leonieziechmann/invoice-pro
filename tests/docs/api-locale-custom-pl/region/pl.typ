// region/pl.typ
#import "/src/lib.typ": locale, tax

// The region builder function
#let region-pl = lang => (
  meta: (
    region: "pl",
  ),
  format: (
    // Format currency to append 'zł' and use comma decimals
    currency: val => {
      let rounded = calc.round(val, digits: 2)
      str(rounded).replace(".", ",") + " zł"
    },
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
