// The payment reference (BT-83), resolved alike wherever it appears.

/// The remittance information of a bank transfer: a structured `reference`
/// (EPC-QR line 10) or a free `text` (line 11), at most one of them.
///
/// -> dictionary
#let resolve-remittance(
  ctx,
  /// The `reference` of `bank-details`; `auto` falls back to the invoice.
  /// -> auto | none | str | content
  reference: auto,
  /// The `text` of `bank-details`.
  /// -> none | str | content
  text: none,
) = {
  if text != none { return (reference: none, text: text) }
  if reference != auto { return (reference: reference, text: none) }

  let payment-reference = ctx.at("payment-reference", default: none)
  if payment-reference != none {
    return (reference: none, text: payment-reference)
  }
  (reference: ctx.at("invoice-nr", default: none), text: none)
}

/// The payment reference as one value, from the `bank` signal if given.
///
/// -> none | str | content
#let resolve-payment-reference(ctx, bank: none) = {
  let remittance = if bank != none { bank } else { resolve-remittance(ctx) }
  let text = remittance.at("text", default: none)
  if text != none { text } else { remittance.at("reference", default: none) }
}

/// The `bank-details` signal: `bank` of the root context, else in `global`.
///
/// -> none | dictionary
#let bank-signal(ctx) = ctx.at(
  "bank",
  default: ctx.at("global", default: (:)).at("bank", default: none),
)
