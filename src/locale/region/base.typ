/// The schema of all regions, and the fallback of their missing keys.
#let base-region = {
  import "../../data/tax.typ"
  import "../../utils/format.typ"

  let numeric-format = (
    decimal-sign: ",",
    thousand-separators: ".",
    padding: false,
    accuracy: 4,
  )

  let currency-meta = (
    /// ISO 4217 code, the invoice currency (BT-5).
    code: "EUR",
    symbol: "€",
    decimals: 2,
    /// Decimals of unit prices (BT-146); EN 16931 sets no limit, 4 is common.
    decimals-fine: 4,
  )

  (
    meta: (
      /// ISO 3166-1 alpha-2 code, lower case; the default country of addresses.
      /// -> str
      region: "base",
    ),

    currency: currency-meta,

    normalize: (
      /// Rounds totals.
      /// -> (int | float | decimal) => (int | float | decimal)
      money: x => calc.round(x, digits: currency-meta.decimals),

      /// Rounds unit prices.
      /// -> (int | float | decimal) => (int | float | decimal)
      money-fine: x => calc.round(x, digits: currency-meta.decimals-fine),

      /// Maps a raw rate (e.g. `19%`) to the tax object of the region.
      /// -> (ratio | float | decimal | int) => tax
      infer-tax: x => panic("Can't infer tax for region:`base`!"),
    ),

    format: (
      /// -> (ratio | float | decimal | int) => str
      percent: x => {
        let p = float(x) * 100
        str(calc.round(p, digits: 1)).replace(".", ",") + "%"
      },

      /// -> (datetime | (datetime, datetime)) => str
      date: x => if type(x) == array {
        x.first().display("[day].[month].[year]")
        " "
        sym.dash.em
        " "
        x.last().display("[day].[month].[year]")
      } else if type(x) == datetime {
        x.display("[day].[month].[year]")
      },

      /// -> datetime => str
      time: x => x.display("[hour repr:24]:[minute padding:zero]"),

      // Adds `number`, `currency` and `currency-fine`.
    )
      + format.make-formatters(numeric-format, currency-meta),
    tax: (
      /// The VAT of items without a tax.
      /// -> tax
      default-vat: tax.vat(21%),

      /// The tax with `tax-exempt-small-biz`; its `grounds` are the printed
      /// note and the exemption reason (BT-120). This fallback claims none.
      /// -> tax
      small-enterprise-special-scheme: tax.outside-scope(),
    ),
  )
}
