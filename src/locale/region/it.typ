#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format
#import "../../utils/coercion.typ"

/// Italian regional configuration (IT).
#let it(lang) = {
  let numeric-format = (
    decimal-sign: ",",
    thousand-separators: ".",
    padding: false,
    accuracy: 4,
  )
  let currency-format = (currency: "€", location: end)

  return (
    meta: (
      region: "it",
    ),

    normalize: (
      money: x => calc.round(x, digits: 2),
      money-fine: x => calc.round(x, digits: 4),

      infer-tax: x => {
        let val = float(x)
        if val == 22% {
          tax.vat(22%) // Standard IVA rate
        } else if val == 10% {
          tax.lower-rate(10%) // Reduced rate (e.g., certain foods, hospitality)
        } else if val == 5% {
          tax.lower-rate(5%) // Super-reduced rate (e.g., certain health services, passenger transport)
        } else if val == 4% {
          tax.lower-rate(4%) // Super-reduced rate (e.g., basic groceries, books)
        } else if val == 0% {
          panic(
            "Ambiguous 0% tax rate in region 'it'. Please explicitly use tax.zero(), tax.exempt(), tax.export(), or tax.outside-scope() from tax.typ instead of passing 0%.",
          )
        } else {
          panic(
            "Invalid or unknown tax rate for region 'it': "
              + repr(x)
              + ". Valid rates are 22%, 10%, 5%, and 4%. If you need a custom rate, pass a full tax object.",
          )
        }
      },
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
      default-vat: tax.vat(22%),

      // Exemption for small enterprises (Regime Forfettario)
      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Operazione in franchigia da IVA ex art. 1, c. 54-89, L. 190/2014 (Regime forfettario).",
      ),
    ),
  )
}
