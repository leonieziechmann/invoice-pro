#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format
#import "../../utils/coercion.typ"

#let de(lang) = {
  // --- Helper Functions ---
  let numeric-format = (
    decimal-sign: ",",
    thousand-separators: ".",
    padding: false,
    accuracy: 4,
  )
  let currency-format = (currency: "€", location: end)

  let infer-tax-de(rate) = {
    if rate == 19% { return tax.vat(19%) } else if rate == 7% {
      return tax.lower-rate(7%)
    } else if rate == 0% {
      panic(
        lang.errors.ambiguous-tax
          + " You must explicitly define the 0% category for legal compliance. "
          + "Please use one of the explicit constructors instead of a raw 0%:\n"
          + "`tax.reverse-charge()` -> B2B Reverse Charge (§13b UStG)\n"
          + "`tax.intra-community()` -> EU B2B Delivery (§4 Nr. 1b UStG)\n"
          + "`tax.export()` -> Non-EU Export (§4 Nr. 1a UStG)\n"
          + "`tax.exempt()` -> VAT Exemptions (§4 UStG)\n"
          + "`tax.outside-scope()` -> Small Business/Kleinunternehmer (§19 UStG) or out of scope.",
      )
    } else {
      panic(
        lang.errors.invalid-tax
          + repr(rate)
          + ". Expected 19%, 7%, or a specific tax constructor.",
      )
    }
  }

  // --- Regional Data ---
  return (
    meta: (
      region: "de",
    ),

    normalize: (
      money: x => calc.round(coercion.to-decimal(x), digits: 2),
      money-fine: x => calc.round(coercion.to-decimal(x), digits: 4),
      infer-tax: infer-tax-de,
    ),

    format: (
      number: m-format.number.with(..numeric-format),
      currency: m-format.currency.with(
        ..currency-format,
        number-format: numeric-format + (accuracy: 2, padding: true),
      ),
      currency-fine: x => {
        let accuracy = if (
          calc.round(x, digits: 2) == calc.round(x, digits: 4)
        ) { 2 } else { 4 }
        m-format.currency(
          x,
          ..currency-format,
          number-format: numeric-format + (accuracy: accuracy, padding: true),
        )
      },
    ),

    tax: (
      default-vat: tax.vat(19%),
      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
      ),
    ),
  )
}

