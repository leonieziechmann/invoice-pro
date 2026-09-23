// IBAN helpers (ISO 13616) shared by the bank details, the EPC-QR code and
// the e-invoice.

#import "text.typ": plain-text

// The patterns are compiled once: compiling a regex costs far more than
// matching it, and `iban-valid` tests every character of an IBAN.
#let _whitespace = regex("\\s")
#let _iban-format = regex("^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$")
#let _digit = regex("^[0-9]$")

/// The electronic format of an IBAN: its plain text without whitespace, in
/// upper case. The printed IBAN, the EPC-QR code and the e-invoice (BT-84)
/// all derive from it. `none` becomes `""`.
///
/// -> str
#let normalize-iban(iban) = upper(plain-text(iban).replace(_whitespace, ""))

/// Whether an IBAN in electronic format (see `normalize-iban`) has the
/// structure of an IBAN (country code, check digits, up to 30 alphanumeric
/// characters) and correct check digits (ISO 7064 MOD 97-10).
///
/// -> bool
#let iban-valid(iban) = {
  if type(iban) != str { return false }
  if iban.match(_iban-format) == none {
    return false
  }
  let remainder = 0
  for char in (iban.slice(4) + iban.slice(0, 4)).clusters() {
    if char.match(_digit) != none {
      remainder = calc.rem(remainder * 10 + int(char), 97)
    } else {
      remainder = calc.rem(remainder * 100 + str.to-unicode(char) - 55, 97)
    }
  }
  remainder == 1
}

/// Formats an IBAN in electronic format for print: groups of four
/// characters separated by spaces (ISO 13616 paper format).
///
/// -> str
#let format-iban(iban) = (
  iban.clusters().chunks(4).map(chunk => chunk.join()).join(" ", default: "")
)
