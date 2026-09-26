// SEPA creditor identifier helpers (EPC262-08, BT-90).

#import "iban.typ": mod97, normalize-iban

// A function: compiled only on use, as direct debits are rare.
#let _creditor-id-format() = regex(
  "^[A-Z]{2}[0-9]{2}[A-Z0-9]{3}[A-Z0-9]{1,28}$",
)

/// A creditor identifier in electronic format (see `normalize-iban`).
///
/// -> str
#let normalize-creditor-id(creditor-id) = normalize-iban(creditor-id)

/// Whether a creditor identifier in electronic format has a valid structure
/// and check digits (MOD 97-10, without the business code).
///
/// -> bool
#let creditor-id-valid(creditor-id) = {
  if type(creditor-id) != str { return false }
  if creditor-id.match(_creditor-id-format()) == none { return false }
  mod97(creditor-id.slice(7) + creditor-id.slice(0, 4)) == 1
}
