#import "@preview/sepay:0.1.1": epc-qr-code
#import "../../utils/iban.typ": format-iban, iban-valid, normalize-iban
#import "../../utils/text.typ": plain-text

// Why the EPC-QR code (EPC069-12) cannot be generated from the bank details,
// as a list of `(short: .., message: ..)`. `sepay` counts the length limits in
// bytes (UTF-8), so umlauts and other non-ASCII characters count twice or
// more.
#let _epc-problems(beneficiary, iban, bic, reference, text) = {
  let too-long(what, value, limit) = (
    what
      + " \""
      + value
      + "\" is too long for the EPC-QR code (at most "
      + str(limit)
      + " bytes, non-ASCII characters count twice or more)"
  )
  let problems = ()
  if iban == "" {
    problems.push((short: "IBAN missing", message: "the IBAN is missing"))
  } else if not iban-valid(iban) {
    problems.push((
      short: "invalid IBAN",
      message: "the IBAN \"" + format-iban(iban) + "\" is not valid",
    ))
  }
  if beneficiary == "" or beneficiary.starts-with("#sender.") {
    problems.push((
      short: "account holder missing",
      message: "the account holder name is missing (set `name` on `bank-details`)",
    ))
  } else if beneficiary.len() > 70 {
    problems.push((
      short: "account holder too long",
      message: too-long("the account holder name", beneficiary, 70)
        + "; set the account name as registered at the bank with `name` on `bank-details`",
    ))
  }
  if bic != none and bic.match(regex("^[A-Z0-9]{8}([A-Z0-9]{3})?$")) == none {
    problems.push((
      short: "invalid BIC",
      message: "the BIC \""
        + bic
        + "\" is not valid (8 or 11 letters and digits)",
    ))
  }
  if reference != none and reference.len() > 35 {
    problems.push((
      short: "reference too long",
      message: too-long("the payment reference", reference, 35)
        + "; use `text` on `bank-details` for a longer, unstructured reference",
    ))
  }
  if text != none and text.len() > 140 {
    problems.push((
      short: "reference text too long",
      message: too-long("the payment reference text", text, 140),
    ))
  }
  problems
}

// The BIC without whitespace, in upper case, as the e-invoice (BT-86)
// carries it; `none` if there is none.
#let _normalize-bic(bic) = {
  let result = upper(plain-text(bic).replace(regex("\\s"), ""))
  if result == "" { none } else { result }
}

// The EPC-QR code (GiroCode) of the bank details. Payee, IBAN, BIC and
// payment reference are the plain texts the invoice prints and the e-invoice
// carries. Returns `(image: .., problems: ..)`, with `image: none` if there
// are problems.
#let _epc-qr-code(view, iban, bic, reference, text) = {
  let beneficiary = plain-text(view.sender.name)
  let reference = if reference != none { plain-text(reference) }
  let text = if text != none { plain-text(text) }
  if reference == "" { reference = none }
  if text == "" { text = none }

  let problems = _epc-problems(beneficiary, iban, bic, reference, text)
  if problems.len() > 0 { return (image: none, problems: problems) }

  // EPC069-12 allows 0.01 to 999 999 999.99 EUR; otherwise the payer enters
  // the amount.
  let amount = float(view.payment-amount)
  let image = epc-qr-code(
    beneficiary,
    iban,
    bic: bic,
    amount: if amount >= 0.01 and amount <= 999999999.99 { amount },
    reference: reference,
    text: text,
    width: view.qr-code.size,
    height: view.qr-code.size,
  )
  (image: image, problems: ())
}

// Stands in for an EPC-QR code that cannot be generated, with
// `zugferd-errors: "report"`.
#let _qr-placeholder(size, problems) = block(
  width: size,
  height: size,
  inset: 2pt,
  stroke: 1pt + rgb("#b91c1c"),
  clip: true,
  {
    set par(justify: false, leading: 0.3em)
    set text(size: 5pt, fill: rgb("#b91c1c"), hyphenate: false)
    align(center + horizon)[
      No EPC-QR code: #problems.map(problem => problem.short).join(", ")
    ]
  },
)

#let render-bank-details(ctx, view) = {
  let strings = ctx.locale.strings
  let bd-str = strings.bank-details
  let currency-code = ctx.locale.currency.code

  let remittance-text = view.at("text", default: none)
  let reference = view.at("reference", default: none)
  let report-problems = view.at("report-problems", default: false)

  let iban = normalize-iban(view.sender.iban)
  let valid-iban = view.sender.at("iban-valid", default: iban-valid(iban))
  let bic = _normalize-bic(view.sender.at("bic", default: none))

  // The EPC-QR code is only generated when it is shown (SEPA: EUR only).
  let qr-image = none
  if view.qr-code.display and currency-code == "EUR" {
    let qr = _epc-qr-code(
      view,
      iban,
      bic,
      if remittance-text == none { reference },
      remittance-text,
    )
    qr-image = qr.image
    if qr.problems.len() > 0 {
      if not report-problems {
        panic(
          "bank-details: the EPC-QR code cannot be generated: "
            + qr.problems.map(problem => problem.message).join("; ")
            + ". Hide it with `qr-code: (display: false)` on `bank-details` if it is not needed.",
        )
      }
      qr-image = _qr-placeholder(view.qr-code.size, qr.problems)
    }
  }

  block(
    width: 100% - view.qr-code.size,
    grid(
      columns: (auto, 1fr),
      align: top,
      gutter: 1em,
      stroke: none,
    )[
      #set par(leading: 0.4em)
      #set text(number-type: "lining")
      #bd-str.account-holder: #view.sender.name \
      #bd-str.bank: #view.sender.bank \
      #bd-str.iban: *#format-iban(iban)*#if not valid-iban {
        text(fill: rgb("#b91c1c"))[ (#if iban == "" [missing] else [invalid])]
      } \
      #if bic != none [#bd-str.bic: #bic \ ]
      #if (
        view.show-reference and remittance-text != none
      ) [#bd-str.reference: *#remittance-text*] else if (
        view.show-reference and reference != none
      ) [#bd-str.reference: *#reference*] \
      #h(6.5cm)
    ][
      #if view.qr-code.display {
        block(width: view.qr-code.size, qr-image)
      }
    ],
  )
}
