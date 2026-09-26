// The payment means of an invoice (BG-16), as `bank-details`, `direct-debit`,
// `card-payment` and `paid` state them.

/// The methods of `paid` and the kind of payment means of each.
#let method-kinds = (
  cash: "other",
  cheque: "other",
  online: "other",
  transfer: "transfer",
  card: "card",
  direct-debit: "direct-debit",
)

// The UNTDID 4461 codes with details in EN 16931 (BG-17, BG-18, BG-19).
#let _code-kinds = (
  "30": "transfer",
  "58": "transfer",
  "48": "card",
  "54": "card",
  "55": "card",
  "49": "direct-debit",
  "59": "direct-debit",
)

/// The kind of payment means of a code (BT-81), see `method-kinds`.
///
/// -> str
#let code-kind(code) = _code-kinds.at(code, default: "other")

/// The kind of payment means of a method of `paid`; `none` for `auto`.
///
/// -> none | str
#let method-kind(method) = {
  if method == auto { return none }
  if type(method) == dictionary { return code-kind(method.code) }
  method-kinds.at(method)
}

/// The code (BT-81) of a credit transfer, SEPA in euro.
///
/// -> str
#let transfer-code(currency) = if currency == "EUR" { "58" } else { "30" }

/// The code (BT-81) of a direct debit, SEPA in euro.
///
/// -> str
#let direct-debit-code(currency) = if currency == "EUR" { "59" } else {
  "49"
}

/// The code (BT-81) of a payment card (`auto`: of any kind).
///
/// -> str
#let card-code(kind) = if kind == "credit" { "54" } else if kind == "debit" {
  "55"
} else { "48" }

#let _method-codes = (cash: "10", cheque: "20", card: "48", online: "68")

/// The code (BT-81) of a method of `paid` in a currency.
///
/// -> str
#let method-code(method, currency) = {
  if type(method) == dictionary { return method.code }
  if method == "transfer" { return transfer-code(currency) }
  if method == "direct-debit" { return direct-debit-code(currency) }
  _method-codes.at(method)
}

/// Whether problems are shown in the document (`zugferd-errors: "report"`).
///
/// -> bool
#let report-problems(ctx) = (
  ctx.at("zugferd", default: none) != none
    and ctx.at("zugferd-errors", default: "panic") == "report"
)

/// Combines the signals of the payment means components and the `kinds` they
/// state, in the order that decides the payment sentence.
///
/// -> dictionary
#let resolve(transfers, direct-debit, card, paid) = {
  let stated = (
    direct-debit: direct-debit != none,
    card: card != none,
    transfer: transfers.len() > 0,
    other: false,
  )
  let paid-kind = if paid != none { paid.at("kind", default: none) }
  if paid-kind != none { stated.insert(paid-kind, true) }
  let kinds = ()
  for (kind, present) in stated {
    if present { kinds.push(kind) }
  }
  (
    transfers: transfers,
    direct-debit: direct-debit,
    card: card,
    paid: paid,
    kinds: kinds,
  )
}

/// The payment means of `resolve` (from the second layout pass on) or `none`.
///
/// -> none | dictionary
#let of-context(ctx) = (
  ctx.at("global", default: (:)).at("payment-means", default: none)
)

/// Whether the bank details show their EPC-QR code by default: only for a
/// credit transfer, so that the buyer does not pay twice.
///
/// -> bool
#let transfer-requested(means) = {
  if means == none { return true }
  (
    means.paid == none and means.direct-debit == none and means.card == none
  )
}

/// The payment strings with the sentences of the invoice's payment means.
///
/// -> dictionary
#let goal-strings(payment, means, discount-notes: ()) = {
  let kind = if means == none { none } else {
    means.kinds.first(default: none)
  }
  let text = payment.text
  let text-due = payment.text-due
  if kind == "direct-debit" {
    text = payment.at("text-direct-debit", default: text)
    text-due = payment.at("text-direct-debit-due", default: text-due)
  } else if kind == "card" {
    text = payment.at("text-card", default: text)
    text-due = payment.at("text-card-due", default: text-due)
  }
  if discount-notes.len() > 0 {
    let notes = discount-notes.join(" ")
    let sentence = text
    let sentence-due = text-due
    text = (sum, deadline) => [#sentence(sum, deadline) #notes]
    text-due = (sum, deadline) => [#sentence-due(sum, deadline) #notes]
  }
  payment + (text: text, text-due: text-due)
}
