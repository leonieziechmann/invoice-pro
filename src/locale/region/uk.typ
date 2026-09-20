#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format

/// United Kingdom regional configuration (GB / UK).
#let uk(lang) = {
  // --- Regional Settings ---
  let numeric-format = (
    decimal-sign: ".",
    thousand-separators: ",",
    padding: false,
    accuracy: 4,
  )

  let currency-meta = (
    code: "GBP",
    symbol: "£",
    decimals: 2,
    decimals-fine: 4,
  )

  // --- Helper Functions ---
  let infer-tax-uk(rate) = {
    if rate == 20% {
      tax.vat(20%) // Standard rate
    } else if rate == 5% {
      tax.vat(5%) // Reduced rate (e.g., domestic fuel/energy, children's car seats)
    } else if rate == 0% {
      panic(
        lang.errors.ambiguous-tax
          + "\nAmbiguous 0% tax rate in region 'gb'. Please explicitly use one of the constructors:\n"
          + "`tax.zero()` -> Zero-rated supplies (e.g., most food, books, children's clothing)\n"
          + "`tax.exempt()` -> VAT exempt supplies (e.g., financial, postal, medical services)\n"
          + "`tax.outside-scope()` -> Outside scope of UK VAT / small business threshold\n"
          + "`tax.reverse-charge()` -> B2B Reverse Charge",
      )
    } else {
      panic(
        lang.errors.invalid-tax
          + repr(rate)
          + ". Expected 20%, 5%, or a specific tax constructor.",
      )
    }
  }

  // --- Regional Data ---
  return (
    meta: (
      region: "gb",
    ),

    currency: currency-meta,

    normalize: (
      infer-tax: infer-tax-uk,
    ),

    format: (
      // Override the base percent formatter to use a dot for decimals instead of a comma
      percent: x => {
        let p = float(x) * 100
        str(calc.round(p, digits: 1)) + "%"
      },

      date: x => if type(x) == array {
        x.first().display("[day]/[month]/[year]")
        " "
        sym.dash.em
        " "
        x.last().display("[day]/[month]/[year]")
      } else if type(x) == datetime {
        x.display("[day]/[month]/[year]")
      },
    )
      + m-format.make-formatters(
        numeric-format,
        currency-meta,
        currency-location: start,
      ),

    tax: (
      default-vat: tax.vat(20%),
      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Not registered for VAT under the UK statutory threshold.",
      ),
    ),
  )
}
