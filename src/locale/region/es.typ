#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format
#import "../../utils/coercion.typ"

/// Spanish regional configuration (ES).
#let es(lang) = {
  let numeric-format = (
    decimal-sign: ",",
    thousand-separators: ".",
    padding: false,
    accuracy: 4,
  )
  let currency-format = (currency: "€", location: end)

  return (
    meta: (
      region: "es",
    ),

    normalize: (
      money: x => calc.round(x, digits: 2),
      money-fine: x => calc.round(x, digits: 4),

      infer-tax: x => {
        let val = float(x)
        if val == 21% {
          tax.vat(21%) // Standard IVA rate
        } else if val == 10% {
          tax.lower-rate(10%) // Reduced rate (e.g., passenger transport, some foods, water)
        } else if val == 4% {
          tax.lower-rate(4%) // Super-reduced rate (e.g., basic foods, books, medicines)
        } else if val == 0% {
          panic(
            "Ambiguous 0% tax rate in region 'es'. Please explicitly use tax.zero(), tax.exempt(), tax.export(), or tax.outside-scope() from tax.typ instead of passing 0%.",
          )
        } else {
          panic(
            "Invalid or unknown tax rate for region 'es': "
              + repr(x)
              + ". Valid rates are 21%, 10%, and 4%. If you need a custom rate, pass a full tax object.",
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
      default-vat: tax.vat(21%),

      // Exemption for small enterprises
      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Exento de IVA según el régimen especial de franquicia para pequeñas empresas.",
      ),
    ),
  )
}
