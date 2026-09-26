// Plain text of content.

/// The characters XML 1.0 forbids even escaped, as a character class body.
///
/// -> str
#let invalid-xml-class = "\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x{FFFE}\\x{FFFF}"

/// A pattern of the characters of `invalid-xml-class`.
///
/// -> regex
#let invalid-xml-chars = regex("[" + invalid-xml-class + "]")
/// Printable ASCII words with single spaces: texts `plain-text` returns as is.
///
/// -> regex
#let plain-ascii = regex("^[!-~]+(?: [!-~]+)*$")
// Hyphens, and the minus sign (U+2212) Typst sets for "-" before a digit.
#let _hyphens = regex("[\\x{2010}\\x{2011}\\x{2212}]")
// Parts of a fraction or root with these need parentheses (no regex: slow).
#let _compound = (
  " ",
  "+",
  "*",
  "/",
  "=",
  "<",
  ">",
  "-",
  "\u{2212}",
  "\u{00B1}",
  "\u{00B7}",
  "\u{00D7}",
  "\u{00F7}",
  "\u{22C5}",
)
#let _space = [ ].func()
#let _sequence = [*a* b].func()

#let _superscripts = (
  "0": "⁰",
  "1": "¹",
  "2": "²",
  "3": "³",
  "4": "⁴",
  "5": "⁵",
  "6": "⁶",
  "7": "⁷",
  "8": "⁸",
  "9": "⁹",
  "+": "⁺",
  "-": "⁻",
  "−": "⁻",
  "=": "⁼",
  "(": "⁽",
  ")": "⁾",
  // Primes (`f'`) are attached as superscripts already.
  "′": "′",
)
#let _subscripts = (
  "0": "₀",
  "1": "₁",
  "2": "₂",
  "3": "₃",
  "4": "₄",
  "5": "₅",
  "6": "₆",
  "7": "₇",
  "8": "₈",
  "9": "₉",
  "+": "₊",
  "-": "₋",
  "−": "₋",
  "=": "₌",
  "(": "₍",
  ")": "₎",
)

// A math script as Unicode scripts ("²") or after `sign` ("^n").
#let _script(text, characters, sign) = {
  if text == "" { return "" }
  let clusters = text.clusters()
  let result = ""
  for cluster in clusters {
    let script = characters.at(cluster, default: none)
    if script == none {
      return sign + if clusters.len() == 1 { text } else { "(" + text + ")" }
    }
    result += script
  }
  result
}

#let _grouped(text) = {
  for character in _compound {
    if text.contains(character) { return "(" + text + ")" }
  }
  text
}

#let _collect-text(it, newline) = {
  if it == none or it == auto { return "" }
  let kind = type(it)
  if kind == str { return it }
  if kind in (int, float, decimal) { return str(it) }
  if kind == datetime { return it.display() }
  if kind == symbol { return str(it) }
  if kind == array {
    let parts = ()
    for value in it { parts.push(_collect-text(value, newline)) }
    return parts.join(" ", default: "")
  }
  if kind != content { return "" }

  let func = it.func()
  // Math operators (`sin`) carry their text as content.
  if it.has("text") {
    return if type(it.text) == str { it.text } else {
      _collect-text(it.text, newline)
    }
  }
  if func == smartquote {
    return if it.at("double", default: true) { "\"" } else { "'" }
  }
  if func in (linebreak, parbreak) { return newline }
  if func in (_space, h, v) { return " " }
  if func == footnote { return "" }

  if func == math.frac {
    return (
      _grouped(_collect-text(it.num, newline))
        + "/"
        + _grouped(_collect-text(it.denom, newline))
    )
  }
  if func == math.root {
    let index = _collect-text(it.at("index", default: none), newline)
    let sign = if index in ("", "2") { "√" } else if index == "3" {
      "∛"
    } else if index == "4" { "∜" } else {
      _script(index, _superscripts, "") + "√"
    }
    return sign + _grouped(_collect-text(it.radicand, newline))
  }
  if func == math.attach {
    let part(name) = _collect-text(it.at(name, default: none), newline)
    return (
      _script(part("tl"), _superscripts, "^")
        + _script(part("bl"), _subscripts, "_")
        + part("base")
        + _script(part("b") + part("br"), _subscripts, "_")
        + _script(part("t") + part("tr"), _superscripts, "^")
    )
  }
  if func == math.primes { return "′" * it.count }

  if it.has("children") {
    let parts = ()
    for child in it.children { parts.push(_collect-text(child, newline)) }
    return parts.join(default: "")
  }
  if it.has("body") { return _collect-text(it.body, newline) }
  if it.has("child") { return _collect-text(it.child, newline) }

  let parts = ()
  for value in it.fields().values() {
    if type(value) == content { parts.push(_collect-text(value, newline)) }
  }
  parts.join(default: "")
}

/// The plain text of a value as it reads on the page, XML-safe and with
/// whitespace collapsed; `keep-newlines: true` keeps line breaks as `"\n"`.
///
/// -> str
#let plain-text(it, keep-newlines: false) = {
  // Fast path: a string, a text, or a sequence of texts and spaces.
  let collected = none
  if type(it) == str { collected = it } else if type(it) == content {
    let func = it.func()
    if func == text { collected = it.text } else if func == _sequence {
      collected = ""
      for child in it.children {
        let kind = child.func()
        if kind == text { collected += child.text } else if kind == _space {
          collected += " "
        } else {
          collected = none
          break
        }
      }
    }
  }
  if collected != none and plain-ascii in collected { return collected }
  if collected == none {
    collected = _collect-text(it, if keep-newlines { "\n" } else { " " })
  }
  let result = collected.replace(invalid-xml-chars, "").replace(_hyphens, "-")
  // Collapses and trims whitespace; a `\s` pattern is slow to compile.
  if not keep-newlines { return result.split().join(" ", default: "") }
  let lines = ()
  for line in result.replace("\r\n", "\n").replace("\r", "\n").split("\n") {
    lines.push(line.split().join(" ", default: ""))
  }
  lines.join("\n").trim("\n")
}
