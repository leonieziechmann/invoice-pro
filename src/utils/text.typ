// Plain text of values that may be content: for the e-invoice XML, the PDF
// metadata, the EPC-QR payload and anything else that needs a string.

// Characters XML 1.0 does not allow in a document, not even escaped.
#let _invalid-chars = regex(
  "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x{FFFE}\\x{FFFF}]",
)
#let _whitespace = regex("\\s+")
#let _space = [ ].func()

// Collects the visible text of a value, see `plain-text`.
#let _collect-text(it) = {
  if it == none or it == auto { return "" }
  let kind = type(it)
  if kind == str { return it }
  if kind in (int, float, decimal) { return str(it).replace("\u{2212}", "-") }
  if kind == datetime { return it.display() }
  if kind == symbol { return str(it) }
  if kind == array { return it.map(_collect-text).join(" ", default: "") }
  if kind != content { return "" }

  let func = it.func()
  // `text`, `raw` and symbols (e.g. the `--` shorthand) carry a text field.
  if it.has("text") and type(it.text) == str { return it.text }
  if func == smartquote {
    return if it.at("double", default: true) { "\"" } else { "'" }
  }
  if func in (_space, linebreak, parbreak, h, v) { return " " }
  if func == footnote { return "" }
  if it.has("children") {
    return it.children.map(_collect-text).join(default: "")
  }
  if it.has("body") { return _collect-text(it.body) }
  if it.has("child") { return _collect-text(it.child) }

  // Any other element (e.g. math): the text of its content fields in order.
  it
    .fields()
    .values()
    .filter(value => type(value) == content)
    .map(_collect-text)
    .join(default: "")
}

/// Extracts the plain text of a value as it reads on the page.
///
/// Works for strings, numbers and arbitrary content, including styled text,
/// emphasis, links, boxes, smart quotes and line breaks. Whitespace is
/// collapsed and characters XML cannot carry are removed, so the result can be
/// written into a single XML text node.
///
/// -> str
#let plain-text(it) = (
  _collect-text(it).replace(_invalid-chars, "").replace(_whitespace, " ").trim()
)
