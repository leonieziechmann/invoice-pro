#import "../../data/tax.typ"

/// The base region serves as the 'Master Schema' for all regional configurations.
/// Every regional file (e.g., DE.typ, US.typ) should mirror this structure.
#let base-region = (
  meta: (
    /// The official ISO code or identifier of the region (e.g., "DE", "US").
    /// -> str
    region: "base",
  ),

  normalize: (
    /// Rounds a numerical value to the standard decimal precision of the region's currency.
    /// Used for final totals and line item sums.
    /// -> (int | float | decimal) => (int | float | decimal)
    money: x => calc.round(x, digits: 2),

    /// Rounds a value to the precision required for unit prices or internal calculations.
    /// Useful for high-precision items (e.g., fuel prices or bulk commodities).
    /// -> (int | float | decimal) => (int | float | decimal)
    money-fine: x => calc.round(x, digits: 4),

    /// A function that interprets a raw tax value (usually a percentage or ratio)
    /// and maps it to a structured regional tax object.
    /// -> (ratio | float | decimal | int) => tax
    infer-tax: x => panic("Can't infer tax for region:`base`!"),
  ),

  format: (
    /// Converts a ratio (0.19) or number into a localized percentage string ("19%").
    /// -> (ratio | float | decimal | int) => str
    percent: x => {
      let p = float(x) * 100
      str(calc.round(p, digits: 1)).replace(".", ",") + "%"
    },

    /// Formats a number with regional separators (thousands, decimals).
    /// -> (int | float | decimal) => str
    number: x => str(x),

    /// Formats a value as a currency string with the regional symbol and placement.
    /// -> (int | float | decimal) => str
    currency: x => str(x) + "€",

    /// High-precision currency formatting. Used when unit prices require more
    /// decimals than the standard 'money' rounding allows.
    /// -> (int | float | decimal) => str
    currency-fine: x => str(x) + "€",

    /// Formats a single date or a range (start, end) into a human-readable string.
    /// Handles both `datetime` objects and arrays of two `datetime` objects.
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

    /// Formats a time object into a localized string (e.g., 24h or AM/PM).
    /// -> datetime => str
    time: x => x.display("[hour repr:24]:[minute padding:zero]"),
  ),

  tax: (
    /// The standard VAT/Sales Tax rate applied when no specific rate is provided.
    /// -> tax
    default-vat: tax.vat(21%),

    /// The legal tax object/exemption text used for small businesses or
    /// "Kleinunternehmer" schemes where VAT is not collected.
    /// -> tax
    small-enterprise-special-scheme: tax.outside-scope(),
  ),
)
