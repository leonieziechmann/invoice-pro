// The invoice currency as every part of the invoice reads it.

#import "../utils/text.typ": plain-text

// Invisible characters (e.g. a copied zero width space), compiled on use.
#let _invisible() = regex("\\p{Cf}")

/// The ISO 4217 code of the invoice currency (BT-5) from the locale, without
/// whitespace and invisible characters, in upper case; or `none`.
///
/// -> none | str
#let currency-code(locale) = {
  let code = plain-text(
    locale.at("currency", default: (:)).at("code", default: none),
  ).replace(" ", "")
  if code.len() != code.codepoints().len() {
    code = code.replace(_invisible(), "")
  }
  if code == "" { none } else { upper(code) }
}
