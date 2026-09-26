// BIC helpers (ISO 9362).

#import "text.typ": plain-text

#let _bic-format = regex("^[A-Z0-9]{8}([A-Z0-9]{3})?$")

/// A BIC in electronic format (BT-86): its plain text without whitespace, in
/// upper case. `none` becomes `""`.
///
/// -> str
#let normalize-bic(bic) = upper(
  plain-text(bic).split().join(default: ""),
)

/// Whether a BIC in electronic format has 8 or 11 letters and digits.
///
/// -> bool
#let bic-valid(bic) = type(bic) == str and bic.match(_bic-format) != none
