#let to-string(it) = {
  if it == none { return "" }
  if type(it) == str { return it }
  if type(it) != content { return str(it) }
  if it.has("text") { return it.text }
  if it.has("children") {
    return it.children.map(to-string).join()
  }
  if it.has("body") { return to-string(it.body) }
  if it == [ ] { return " " }
  return ""
}

/// Formats a number as currency with proper decimal places and locale-specific separators.
///
/// -> str
#let format-currency(
  /// The number to format.
  /// -> float | int
  number,
  /// The locale for formatting ("de" uses comma as decimal separator, "en" uses period).
  /// -> str
  locale: "de",
) = {
  let precision = 2
  assert(precision > 0)
  let s = str(calc.round(number, digits: precision))
  let after_dot = s.find(regex("\..*"))
  if after_dot == none {
    s = s + "."
    after_dot = "."
  }
  for i in range(precision - after_dot.len() + 1) {
    s = s + "0"
  }
  // Apply locale-specific decimal separator
  if locale == "de" {
    s.replace(".", ",")
  } else {
    s
  }
}

#let extract-city-name(zip-city-string) = {
  let pattern = regex("^\\s*\\d*")
  to-string(zip-city-string).trim(pattern)
}
