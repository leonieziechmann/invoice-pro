#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../utils/text.typ": plain-text

// Characters XML 1.0 does not allow in a document, not even escaped.
#let _invalid-chars = regex(
  "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x{FFFE}\\x{FFFF}]",
)

// Escape a value for safe embedding in XML text/attribute content.
#let xml-escape(s) = {
  let value = if type(s) == str { s.replace(_invalid-chars, "") } else {
    plain-text(s)
  }
  value
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

// Serialize a Typst dictionary/value to XML format.
//
// Keys starting with `@` become attributes and the key `""` holds the text of
// an element with attributes. `none` values and elements without text are left
// out, so optional data can be passed through unchecked; dictionaries without
// any children are kept as empty elements (e.g. an empty
// `ram:ApplicableHeaderTradeDelivery`, which the schema requires).
#let dict-to-xml(data) = {
  if data == none {
    return ""
  }
  if type(data) != dictionary {
    return xml-escape(data)
  }

  data
    .pairs()
    .map(((tag, body)) => {
      if body == none {
        return ""
      }

      if type(body) == array {
        return body.map(item => dict-to-xml(((tag): item))).join(default: "")
      }

      if type(body) == dictionary {
        let attrs = body
          .pairs()
          .filter(((k, v)) => k.starts-with("@") and v != none)
          .map(((k, v)) => " " + k.slice(1) + "=\"" + xml-escape(v) + "\"")
          .join(default: "")

        let children = body
          .pairs()
          .filter(((k, _)) => not k.starts-with("@"))
          .map(((k, v)) => {
            if k == "" {
              dict-to-xml(v)
            } else {
              dict-to-xml(((k): v))
            }
          })
          .join(default: "")

        // An identifier or code without its value would be invalid.
        if "" in body and children.trim() == "" {
          return ""
        }

        return if children == "" {
          "<" + tag + attrs + " />"
        } else {
          "<" + tag + attrs + ">" + children + "</" + tag + ">"
        }
      }

      let value = xml-escape(body)
      if value.trim() == "" {
        return ""
      }
      return "<" + tag + ">" + value + "</" + tag + ">"
    })
    .join(default: "")
}
