// IBAN helpers (ISO 13616).

#import "text.typ": plain-text

#let _iban-format = regex("^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$")

/// An IBAN in electronic format (BT-84): its plain text without whitespace,
/// in upper case. `none` becomes `""`.
///
/// -> str
#let normalize-iban(iban) = upper(
  plain-text(iban).split().join(default: ""),
)

/// The ISO 7064 MOD 97-10 remainder of digits and letters A to Z (10 to 35).
///
/// -> int
#let mod97(text) = {
  let remainder = 0
  for char in text.clusters() {
    // Code points: "0"-"9" are 48-57, "A"-"Z" are 65-90.
    let code = str.to-unicode(char)
    remainder = if code <= 57 {
      calc.rem(remainder * 10 + code - 48, 97)
    } else {
      calc.rem(remainder * 100 + code - 55, 97)
    }
  }
  remainder
}

/// Whether an IBAN in electronic format has a valid structure and check digits.
///
/// -> bool
#let iban-valid(iban) = {
  if type(iban) != str { return false }
  if iban.match(_iban-format) == none {
    return false
  }
  mod97(iban.slice(4) + iban.slice(0, 4)) == 1
}

/// The paper format of an IBAN (ISO 13616): groups of four characters.
///
/// -> str
#let format-iban(iban) = (
  iban.clusters().chunks(4).map(chunk => chunk.join()).join(" ", default: "")
)
