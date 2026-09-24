#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../utils/text.typ": invalid-xml-chars, invalid-xml-class, plain-text

/// The characters `xml-escape` has to change, as the body of a character
/// class of a regex: the markup characters and the characters XML 1.0 does
/// not allow (`invalid-xml-class` of utils/text.typ), built from the same
/// class so that the two cannot drift apart.
#let escaped-class = "&<>\"'" + invalid-xml-class

// Most values contain none of them.
#let _needs-escape = regex("[" + escaped-class + "]")

// Escape a value for safe embedding in XML text/attribute content.
#let xml-escape(s) = {
  let value = if type(s) == str { s } else { plain-text(s) }
  // One scan instead of six replacements for the common case.
  if not value.contains(_needs-escape) { return value }
  value
    .replace(invalid-xml-chars, "")
    .replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
    .replace("\"", "&quot;")
    .replace("'", "&apos;")
}

/// Formats a number for the XML: `.` as decimal separator, an ASCII minus sign,
/// no thousands separators, rounded to `max-digits` and padded to `min-digits`
/// decimals.
///
/// -> str
#let fmt-number(value, min-digits: 2, max-digits: 2) = {
  let number = if value == none or value == auto { decimal("0") } else {
    to-decimal(value)
  }
  let rounded = calc.round(number, digits: max-digits)
  let (whole, fraction, ..) = str(calc.abs(rounded)).split(".") + ("",)
  fraction = fraction.trim("0", at: end, repeat: true)
  if fraction.len() < min-digits {
    fraction += "0" * (min-digits - fraction.len())
  }
  let result = if fraction == "" { whole } else { whole + "." + fraction }
  if rounded < decimal("0") { "-" + result } else { result }
}

// Format a monetary amount (exactly 2 decimals, as required by BR-DEC-*).
#let fmt-amount(d) = fmt-number(d)

// Format a unit price, which may carry more decimals than an amount (BT-146).
#let fmt-price(d) = fmt-number(d, max-digits: 6)

// Format a quantity (BT-129, BT-149) without losing its decimals.
#let fmt-quantity(d) = fmt-number(d, max-digits: 6)

/// The decimals of a VAT rate in percent the XML states (BT-96, BT-103,
/// BT-119, BT-152). EN 16931 does not limit them; 4 state every real rate
/// exactly, e.g. 9.975%.
#let rate-digits = 4

// Format a decimal rate (0.19) as a ZUGFeRD percentage string: "19.00",
// "5.50", "9.975".
#let fmt-rate(rate) = fmt-number(
  to-ratio(rate) * 100,
  max-digits: rate-digits,
)

// Format a datetime as YYYYMMDD for the ZUGFeRD date format code 102.
#let fmt-date(date) = if type(date) == datetime and date.year() != none {
  date.display("[year][month][day]")
} else { none }


/// Serializes the builder's element tree `data` (see build.typ) into the
/// CrossIndustryInvoice XML and checks every element against the guard
/// tables of `profile` in the same pass: the write guard (G1, G2; see
/// guard/write.typ).
///
/// Keys starting with `@` become attributes and the key `""` holds the text
/// of an element with attributes. `none` values and elements without text
/// are left out, so optional data can be passed through unchecked;
/// dictionaries without any children are kept as empty elements (e.g. an
/// empty `ram:ApplicableHeaderTradeDelivery`, which the schema requires). An
/// array repeats its element once per item.
///
/// Returns `(xml: str, findings: array)`: the XML, without the XML
/// declaration, and every problem the guard found, as findings `(kind, rule,
/// path, ..details)` (see guard/report.typ). The XML does not depend on the
/// findings.
///
/// -> dictionary
#let dict-to-xml(data, profile) = {
  // Imported here, as guard/write.typ imports this module; zugferd.typ loads
  // it with the other modules of the e-invoice.
  import "guard/write.typ": write
  write(data, profile)
}
