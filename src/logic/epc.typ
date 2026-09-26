// The EPC-QR code (GiroCode, EPC069-12) of the bank details: its fields and
// the reasons it cannot be generated. The theme draws it with `sepay`.

#import "../utils/bic.typ": bic-valid
#import "../utils/iban.typ": format-iban, iban-valid
#import "../utils/text.typ": plain-text

#let _too-long(what, value, limit) = (
  what
    + " \""
    + value
    + "\" is too long for the EPC-QR code (at most "
    + str(limit)
    + " bytes, non-ASCII characters count twice or more)"
)

/// Why the plain text fields of `qr-code` give no EPC-QR code, as
/// `(short: .., message: ..)`; length limits count UTF-8 bytes, as in `sepay`.
///
/// -> array
#let problems(
  /// -> str
  beneficiary,
  /// -> str
  iban,
  /// -> none | str
  bic,
  /// -> none | str
  reference,
  /// -> none | str
  text,
) = {
  let found = ()
  if iban == "" {
    found.push((short: "IBAN missing", message: "the IBAN is missing"))
  } else if not iban-valid(iban) {
    found.push((
      short: "invalid IBAN",
      message: "the IBAN \"" + format-iban(iban) + "\" is not valid",
    ))
  }
  if beneficiary == "" or beneficiary.starts-with("#sender.") {
    found.push((
      short: "account holder missing",
      message: "the account holder name is missing (set `name` on `bank-details`)",
    ))
  } else if beneficiary.len() > 70 {
    found.push((
      short: "account holder too long",
      message: _too-long("the account holder name", beneficiary, 70)
        + "; set the account name as registered at the bank with `name` on `bank-details`",
    ))
  }
  if bic != none and not bic-valid(bic) {
    found.push((
      short: "invalid BIC",
      message: "the BIC \""
        + bic
        + "\" is not valid (8 or 11 letters and digits)",
    ))
  }
  if reference != none and reference.len() > 35 {
    found.push((
      short: "reference too long",
      message: _too-long("the payment reference", reference, 35)
        + "; use `text` on `bank-details` for a longer, unstructured reference",
    ))
  }
  if text != none and text.len() > 140 {
    found.push((
      short: "reference text too long",
      message: _too-long("the payment reference text", text, 140),
    ))
  }
  found
}

/// The EPC-QR code of a bank transfer: `(payload: .., problems: ..)`, the
/// fields for `epc-qr-code` of `sepay`, or `none` and the `problems`.
///
/// -> dictionary
#let qr-code(
  /// The account holder (beneficiary), as printed.
  /// -> str | content
  holder,
  /// The IBAN in electronic format.
  /// -> str
  iban,
  /// The BIC in electronic format, `""` or `none`.
  /// -> none | str
  bic: none,
  /// The structured payment reference (EPC-QR line 10).
  /// -> none | str | content
  reference: none,
  /// The unstructured remittance text (EPC-QR line 11), used over `reference`.
  /// -> none | str | content
  text: none,
  /// The amount to pay; outside 0.01 to 999 999 999.99, the payer enters it.
  /// -> none | decimal | float | int
  amount: none,
) = {
  let beneficiary = plain-text(holder)
  let reference = if text == none and reference != none {
    plain-text(reference)
  }
  let text = if text != none { plain-text(text) }
  if reference == "" { reference = none }
  if text == "" { text = none }
  if bic == "" { bic = none }

  let found = problems(beneficiary, iban, bic, reference, text)
  if found.len() > 0 { return (payload: none, problems: found) }

  let amount = if amount != none { float(amount) }
  (
    payload: (
      beneficiary: beneficiary,
      iban: iban,
      bic: bic,
      amount: if (
        amount != none and amount >= 0.01 and amount <= 999999999.99
      ) { amount },
      reference: reference,
      text: text,
    ),
    problems: (),
  )
}
