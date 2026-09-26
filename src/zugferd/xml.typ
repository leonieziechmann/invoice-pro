#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../utils/text.typ": invalid-xml-chars, invalid-xml-class, plain-text

/// The characters `xml-escape` changes, as the body of a regex class.
#let escaped-class = "&<>\"'" + invalid-xml-class

// Compiled on first use (memoized).
#let _needs-escape() = regex("[" + escaped-class + "]")

#let xml-escape(s) = {
  let value = if type(s) == str { s } else { plain-text(s) }
  if not value.contains(_needs-escape()) { return value }
  value
    .replace(invalid-xml-chars, "")
    .replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
    .replace("\"", "&quot;")
    .replace("'", "&apos;")
}

#let _zero = decimal("0")

/// A number as the XML writes it, with `min-digits` to `max-digits` decimals.
///
/// -> str
#let fmt-number(value, min-digits: 2, max-digits: 2) = {
  let number = if type(value) == decimal { value } else if (
    value == none or value == auto
  ) { _zero } else {
    to-decimal(value)
  }
  let rounded = calc.round(number, digits: max-digits)
  let (whole, fraction, ..) = str(calc.abs(rounded)).split(".") + ("",)
  fraction = fraction.trim("0", at: end, repeat: true)
  if fraction.len() < min-digits {
    fraction += "0" * (min-digits - fraction.len())
  }
  let result = if fraction == "" { whole } else { whole + "." + fraction }
  if rounded < _zero { "-" + result } else { result }
}

// An amount: 2 decimals (BR-DEC-*).
#let fmt-amount = fmt-number

// A unit price (BT-146, BT-148), never rounded: a decimal has 28 at most.
#let fmt-price = fmt-number.with(max-digits: 28)

// A quantity (BT-129, BT-149).
#let fmt-quantity = fmt-number.with(max-digits: 6)

/// The decimals of a VAT rate in percent (BT-96, BT-103, BT-119, BT-152):
/// 4 state every real rate exactly, e.g. 9.975%.
#let rate-digits = 4

// A rate (e.g. 0.19) as a percentage ("19.00").
#let fmt-rate(rate) = fmt-number(
  to-ratio(rate) * 100,
  max-digits: rate-digits,
)

#let fmt-date(date) = if type(date) == datetime and date.year() != none {
  date.display("[year][month][day]")
} else { none }

// A text written as it is: not blank, nothing to escape.
#let _plain = {
  let c = escaped-class
  regex("^[^" + c + "]*[^\\s" + c + "][^" + c + "]*$")
}

// The element `tag` with `body`; the loop writes plain leaves itself.
#let _element(tag, body) = {
  if body == none { return "" }
  if type(body) == array {
    let out = ""
    for item in body { out += _element(tag, item) }
    return out
  }
  if type(body) != dictionary {
    let text = if type(body) == str and _plain in body { body } else {
      xml-escape(body)
    }
    return if text.trim() == "" { "" } else {
      "<" + tag + ">" + text + "</" + tag + ">"
    }
  }
  let attrs = ""
  let out = ""
  for (key, value) in body {
    if value == none { continue }
    if type(value) == str and _plain in value {
      if key.starts-with("@") {
        attrs += " " + key.slice(1) + "=\"" + value + "\""
      } else if key == "" { out += value } else {
        out += "<" + key + ">" + value + "</" + key + ">"
      }
    } else if key.starts-with("@") {
      attrs += " " + key.slice(1) + "=\"" + xml-escape(value) + "\""
    } else if key == "" {
      if type(value) == dictionary {
        for (k, v) in value { out += _element(k, v) }
      } else { out += xml-escape(value) }
    } else { out += _element(key, value) }
  }
  // An identifier or code without its value would be invalid.
  if "" in body and out.trim() == "" { return "" }
  if out == "" { "<" + tag + attrs + " />" } else {
    "<" + tag + attrs + ">" + out + "</" + tag + ">"
  }
}

/// Serializes the element tree of build.typ into XML without declaration:
/// `@..` keys are attributes, `""` the text next to them, an array repeats
/// its element; `none` and blank texts are left out.
///
/// -> str
#let dict-to-xml(data) = {
  if type(data) != dictionary {
    return if data == none { "" } else { xml-escape(data) }
  }
  let out = ""
  for (tag, body) in data { out += _element(tag, body) }
  out
}
