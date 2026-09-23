#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../utils/text.typ": plain-text

// Characters XML 1.0 does not allow in a document, not even escaped.
#let _invalid-chars = regex(
  "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x{FFFE}\\x{FFFF}]",
)

// Characters `xml-escape` has to change: the markup characters and the
// characters of `_invalid-chars`. Most values contain none of them.
#let _needs-escape = regex(
  "[&<>\"'\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x{FFFE}\\x{FFFF}]",
)

// Escape a value for safe embedding in XML text/attribute content.
#let xml-escape(s) = {
  let value = if type(s) == str { s } else { plain-text(s) }
  // One scan instead of six replacements for the common case.
  if not value.contains(_needs-escape) { return value }
  value
    .replace(_invalid-chars, "")
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

// Format a decimal rate (0.19) as a ZUGFeRD percentage string ("19.00").
#let fmt-rate(rate) = fmt-number(to-ratio(rate) * 100)

// Format a datetime as YYYYMMDD for the ZUGFeRD date format code 102.
#let fmt-date(date) = if type(date) == datetime and date.year() != none {
  date.display("[year][month][day]")
} else { none }

// Serializes the element `tag` with the value `body`, see `dict-to-xml`.
//
// This runs once per element of the document, so it avoids everything that
// costs per call: Typst memoizes every closure call and hashes its arguments,
// which made the former `.pairs().map(..).filter(..)` chains, and the wrapper
// dictionary built for each child, re-hash a subtree several times per level.
// Plain `for` loops and one call per element keep the serializer linear in
// the size of the document. The recursion follows the nesting of the elements
// (about ten levels), so it stays far below Typst's call depth limit, and it
// needs no `while` loop, which Typst stops after 10 000 iterations.
#let _element(tag, body) = {
  if body == none { return "" }
  if type(body) == array {
    let out = ""
    for item in body { out += _element(tag, item) }
    return out
  }
  if type(body) == dictionary {
    let attrs = ""
    let children = ""
    for (key, value) in body {
      if key.starts-with("@") {
        if value != none {
          attrs += " " + key.slice(1) + "=\"" + xml-escape(value) + "\""
        }
      } else if key == "" {
        // The text of an element with attributes.
        if type(value) == dictionary {
          for (k, v) in value { children += _element(k, v) }
        } else if value != none {
          children += xml-escape(value)
        }
      } else {
        children += _element(key, value)
      }
    }
    // An identifier or code without its value would be invalid.
    if "" in body and children.trim() == "" { return "" }
    return if children == "" {
      "<" + tag + attrs + " />"
    } else {
      "<" + tag + attrs + ">" + children + "</" + tag + ">"
    }
  }
  let value = xml-escape(body)
  if value.trim() == "" { return "" }
  "<" + tag + ">" + value + "</" + tag + ">"
}

// Serialize a Typst dictionary/value to XML format.
//
// Keys starting with `@` become attributes and the key `""` holds the text of
// an element with attributes. `none` values and elements without text are left
// out, so optional data can be passed through unchecked; dictionaries without
// any children are kept as empty elements (e.g. an empty
// `ram:ApplicableHeaderTradeDelivery`, which the schema requires). An array
// repeats its element once per item.
#let dict-to-xml(data) = {
  if data == none { return "" }
  if type(data) != dictionary { return xml-escape(data) }
  let out = ""
  for (tag, body) in data { out += _element(tag, body) }
  out
}
