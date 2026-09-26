// The document type of an invoice (`invoice(document-type: ..)`, BT-3): what
// it means for the title and for who pays whom.

/// The named document types and their UNTDID 1001 code (BT-3).
#let named-types = (
  invoice: "380",
  credit-note: "381",
  corrected: "384",
  prepayment: "386",
  self-billed: "389",
)

// The UNTDID 1001 codes that EN 16931 (BR-CL-01) and every Factur-X profile
// accept for BT-3, by the kind of document.
#let _kinds = (
  "71": "invoice",
  "80": "invoice",
  "81": "credit-note",
  "82": "invoice",
  "83": "credit-note",
  "84": "invoice",
  "102": "invoice",
  "130": "invoice",
  "202": "invoice",
  "203": "invoice",
  "204": "invoice",
  "211": "invoice",
  "218": "invoice",
  "219": "invoice",
  "261": "self-billed-credit-note",
  "262": "credit-note",
  "295": "invoice",
  "296": "credit-note",
  "308": "credit-note",
  "325": "invoice",
  "326": "invoice",
  "331": "invoice",
  "380": "invoice",
  "381": "credit-note",
  "382": "invoice",
  "383": "invoice",
  "384": "corrected",
  "385": "invoice",
  "386": "prepayment",
  "387": "invoice",
  "388": "invoice",
  "389": "self-billed",
  "390": "invoice",
  "393": "invoice",
  "394": "invoice",
  "395": "invoice",
  "396": "credit-note",
  "420": "credit-note",
  "456": "invoice",
  "457": "invoice",
  "458": "credit-note",
  "527": "self-billed",
  "532": "credit-note",
  "553": "invoice",
  "575": "invoice",
  "623": "invoice",
  "633": "invoice",
  "751": "invoice",
  "780": "invoice",
  "817": "invoice",
  "870": "invoice",
  "875": "invoice",
  "876": "invoice",
  "877": "invoice",
  "935": "invoice",
)

/// Whether a text is a UNTDID 1001 code the e-invoice accepts (BT-3).
///
/// -> bool
#let known-code(code) = type(code) == str and code in _kinds

/// Resolves the `document-type` of an invoice: `auto` (an invoice), a named
/// type or a UNTDID 1001 code, also as integer; panics for any other value.
/// `title` is the key of the default title in `strings.document`.
///
/// -> dictionary
#let resolve-document-type(value) = {
  let code = if value == auto { "380" } else if type(value) == int {
    str(value)
  } else if type(value) == str {
    named-types.at(value, default: value.trim())
  } else { none }
  if code == none or code not in _kinds {
    panic(
      "invoice::document-type must be one of "
        + named-types.keys().map(key => "\"" + key + "\"").join(", ")
        + " or a UNTDID 1001 code of an invoice or credit note (e.g. \"326\" for a partial invoice), got "
        + repr(value)
        + ".",
    )
  }
  let kind = _kinds.at(code)
  let name = none
  for (key, named) in named-types {
    if named == code { name = key }
  }
  let credit = kind in ("credit-note", "self-billed-credit-note")
  let self-billed = kind in ("self-billed", "self-billed-credit-note")
  (
    input: value,
    name: name,
    code: code,
    title: if kind == "self-billed-credit-note" { "credit-note" } else {
      kind
    },
    credit: credit,
    self-billed: self-billed,
    sender-pays: credit != self-billed,
    prepayment: kind == "prepayment",
  )
}

/// Whether the sender of the document pays its recipient (a credit note, a
/// self-billed invoice); `document` is the resolved `document-type` or `none`.
///
/// -> bool
#let sender-pays(document) = (
  type(document) == dictionary and document.at("sender-pays", default: false)
)

/// The default title of a document in the language of `strings`, or that of
/// an invoice if the language has none for its type.
///
/// -> str | content
#let document-title(document, strings) = {
  let titles = strings.at("document", default: (:))
  let key = if type(document) == dictionary { document.title } else {
    "invoice"
  }
  titles.at(key, default: titles.at("invoice", default: "Invoice"))
}
