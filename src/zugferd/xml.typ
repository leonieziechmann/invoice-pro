#import "../utils/coercion.typ": to-string

// Escape a value for safe embedding in XML text/attribute content.
#let xml-escape(s) = {
  let text = if s == none { "" } else if type(s) == str { s } else { to-string(s) }
  if text == none { text = "" }
  text
    .replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
    .replace("\"", "&quot;")
    .replace("'", "&apos;")
}

// Format a decimal/float as a ZUGFeRD amount string (dot separator, 2 decimal places).
#let fmt-amount(d) = {
  let f = calc.round(float(d), digits: 2)
  let s = str(f)
  if "." not in s {
    s += ".00"
  } else {
    let parts = s.split(".")
    let frac = parts.at(1)
    if frac.len() == 0 { s += "00" }
    else if frac.len() == 1 { s += "0" }
  }
  s
}

// Format a decimal rate (0.19) as a ZUGFeRD percentage string ("19.00").
#let fmt-rate(rate) = {
  let pct = calc.round(float(rate) * 100, digits: 2)
  let s = str(pct)
  if "." not in s {
    s += ".00"
  } else {
    let parts = s.split(".")
    let frac = parts.at(1)
    if frac.len() == 0 { s += "00" }
    else if frac.len() == 1 { s += "0" }
  }
  s
}

// Format a datetime as YYYYMMDD for the ZUGFeRD date format code 102.
#let fmt-date(dt) = {
  let y = str(dt.year())
  let m = str(dt.month())
  let d = str(dt.day())
  let mm = if m.len() == 1 { "0" + m } else { m }
  let dd = if d.len() == 1 { "0" + d } else { d }
  y + mm + dd
}
