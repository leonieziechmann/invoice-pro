// Overrides for `locale.<lang>-<region>.with(..)`. Each returns an array of
// one patch: in a code block, arrays join, dictionaries would overwrite.

/// Drops the `auto` arguments: only the given fields are patched.
#let _clean-auto(d) = {
  let res = (:)
  for (k, v) in d {
    if v != auto { res.insert(k, v) }
  }
  return res
}


// --- Language (strings.*) ---

/// The titles of the document types (`str`), the defaults of
/// `invoice(document-type: ..)`.
/// -> array
#let document(
  invoice: auto,
  credit-note: auto,
  corrected: auto,
  prepayment: auto,
  self-billed: auto,
) = (
  {
    let payload = _clean-auto((
      invoice: invoice,
      credit-note: credit-note,
      corrected: corrected,
      prepayment: prepayment,
      self-billed: self-billed,
    ))
    (strings: (document: payload))
  },
)

/// The labels of the addresses (`str`).
/// -> array
#let address(recipient: auto, sender: auto) = (
  {
    let payload = _clean-auto((recipient: recipient, sender: sender))
    (strings: (address: payload))
  },
)

/// The labels of the references and contact details (`str`); `payee` labels
/// who receives the payment instead of the sender.
/// -> array
#let reference(
  tax-number: auto,
  invoice-number: auto,
  vat-id: auto,
  invoice-date: auto,
  service-time: auto,
  customer-number: auto,
  buyer-reference: auto,
  recipient-vat-id: auto,
  recipient-tax-number: auto,
  order-number: auto,
  order-date: auto,
  project: auto,
  contract-number: auto,
  quote-number: auto,
  delivery-note-number: auto,
  delivery-address: auto,
  preceding-invoice-number: auto,
  preceding-invoice-date: auto,
  due-date: auto,
  payment-reference: auto,
  contact-person: auto,
  contact-phone: auto,
  contact-email: auto,
  payee: auto,
) = (
  {
    let payload = _clean-auto((
      tax-number: tax-number,
      invoice-number: invoice-number,
      vat-id: vat-id,
      invoice-date: invoice-date,
      service-time: service-time,
      customer-number: customer-number,
      buyer-reference: buyer-reference,
      recipient-vat-id: recipient-vat-id,
      recipient-tax-number: recipient-tax-number,
      order-number: order-number,
      order-date: order-date,
      project: project,
      contract-number: contract-number,
      quote-number: quote-number,
      delivery-note-number: delivery-note-number,
      delivery-address: delivery-address,
      preceding-invoice-number: preceding-invoice-number,
      preceding-invoice-date: preceding-invoice-date,
      due-date: due-date,
      payment-reference: payment-reference,
      contact-person: contact-person,
      contact-phone: contact-phone,
      contact-email: contact-email,
      payee: payee,
    ))
    (strings: (reference: payload))
  },
)

/// The headers and labels of the line-items table (`str`); `conjunction`
/// joins the last two item names of an automatic bundle description.
/// -> array
#let line-items(
  position: auto,
  description: auto,
  quantity: auto,
  unit-price: auto,
  price: auto,
  total: auto,
  vat: auto,
  net: auto,
  gross: auto,
  discount: auto,
  surcharge: auto,
  subtotal: auto,
  conjunction: auto,
  origin: auto,
) = (
  {
    let payload = _clean-auto((
      position: position,
      description: description,
      quantity: quantity,
      unit-price: unit-price,
      price: price,
      total: total,
      vat: vat,
      net: net,
      gross: gross,
      discount: discount,
      surcharge: surcharge,
      subtotal: subtotal,
      conjunction: conjunction,
      origin: origin,
    ))

    (strings: (line-items: payload))
  },
)

/// The labels of the totals below the table (`str`).
/// -> array
#let summary(
  sum: auto,
  vat-tax: auto,
  total: auto,
  including: auto,
  excluding: auto,
) = (
  {
    let payload = _clean-auto((
      sum: sum,
      vat-tax: vat-tax,
      total: total,
      including: including,
      excluding: excluding,
    ))
    (strings: (summary: payload))
  },
)

/// The notes below the table on what all items share (`str`), and:
/// - tax-statement (auto, fn): (tax-text, rate, vat-tax) => content
#let global-info(
  tax-statement: auto,
  unit: auto,
  quantity: auto,
  date: auto,
) = (
  {
    let payload = _clean-auto((
      tax-statement: tax-statement,
      unit: unit,
      quantity: quantity,
      date: date,
    ))
    (strings: (global-info: payload))
  },
)

/// The labels of the bank details (`str`).
/// -> array
#let bank-details(
  account-holder: auto,
  bank: auto,
  iban: auto,
  bic: auto,
  reference: auto,
) = (
  {
    let payload = _clean-auto((
      account-holder: account-holder,
      bank: bank,
      iban: iban,
      bic: bic,
      reference: reference,
    ))
    (strings: (bank-details: payload))
  },
)

/// The texts of `direct-debit`, `card-payment` and `paid` (`str`), and:
/// - paid, paid-due, paid-credit (auto, fn): (sum, date) => content, `date`
///   may be `none`
/// -> array
#let payment-means(
  method: auto,
  transfer: auto,
  direct-debit: auto,
  sepa-direct-debit: auto,
  card: auto,
  credit-card: auto,
  debit-card: auto,
  cash: auto,
  cheque: auto,
  online: auto,
  mandate: auto,
  creditor-id: auto,
  debtor-iban: auto,
  card-number: auto,
  card-holder: auto,
  paid: auto,
  paid-due: auto,
  paid-credit: auto,
) = (
  {
    let payload = _clean-auto((
      method: method,
      transfer: transfer,
      direct-debit: direct-debit,
      sepa-direct-debit: sepa-direct-debit,
      card: card,
      credit-card: credit-card,
      debit-card: debit-card,
      cash: cash,
      cheque: cheque,
      online: online,
      mandate: mandate,
      creditor-id: creditor-id,
      debtor-iban: debtor-iban,
      card-number: card-number,
      card-holder: card-holder,
      paid: paid,
      paid-due: paid-due,
      paid-credit: paid-credit,
    ))
    (strings: (payment-means: payload))
  },
)

/// The sentences of the payment goal (`-due`: after prepayments, `-credit`:
/// on a credit note or a self-billed invoice).
/// - text, text-due, text-direct-debit, text-direct-debit-due, text-card,
///   text-card-due, text-credit (auto, fn): (sum, deadline) => content
/// - cash-discount (auto, fn): (percent, deadline, basis) => content
/// - deadline-date, deadline-days (auto, fn): (date) => str, (days) => str
/// - deadline-soon, deadline-soon-credit (auto, str): e.g. "upon receipt"
/// -> array
#let payment(
  text: auto,
  text-due: auto,
  text-direct-debit: auto,
  text-direct-debit-due: auto,
  text-card: auto,
  text-card-due: auto,
  cash-discount: auto,
  deadline-date: auto,
  deadline-days: auto,
  deadline-soon: auto,
  text-credit: auto,
  deadline-soon-credit: auto,
) = (
  {
    let payload = _clean-auto((
      text: text,
      text-due: text-due,
      text-direct-debit: text-direct-debit,
      text-direct-debit-due: text-direct-debit-due,
      text-card: text-card,
      text-card-due: text-card-due,
      cash-discount: cash-discount,
      deadline-date: deadline-date,
      deadline-days: deadline-days,
      deadline-soon: deadline-soon,
      text-credit: text-credit,
      deadline-soon-credit: deadline-soon-credit,
    ))
    (strings: (payment: payload))
  },
)

/// The closing above the signature (`str`).
/// -> array
#let signature(closing: auto) = (
  {
    let payload = _clean-auto((closing: closing))
    (strings: (signature: payload))
  },
)

/// The small business note (`str`).
/// -> array
#let legal(vat-exemption: auto) = (
  {
    let payload = _clean-auto((vat-exemption: vat-exemption))
    (strings: (legal: payload))
  },
)

/// The error messages (`str`).
#let errors(
  name-missing: auto,
  address-missing: auto,
  city-missing: auto,
  ambiguous-tax: auto,
  invalid-tax: auto,
) = (
  {
    let payload = _clean-auto((
      name-missing: name-missing,
      address-missing: address-missing,
      city-missing: city-missing,
      ambiguous-tax: ambiguous-tax,
      invalid-tax: invalid-tax,
    ))
    (strings: (errors: payload))
  },
)

// --- Region (region.*) ---

/// The rounding and the tax inference of the region.
/// - money (auto, fn): rounds totals
/// -> (number) => number
/// - money-fine (auto, fn): rounds unit prices
/// -> (number) => number
/// - infer-tax (auto, fn): maps a raw rate to a tax object
/// -> (number) => tax
/// -> array
#let normalize(
  money: auto,
  money-fine: auto,
  infer-tax: auto,
) = (
  {
    let payload = _clean-auto((
      money: money,
      money-fine: money-fine,
      infer-tax: infer-tax,
    ))
    (region: (normalize: payload))
  },
)

/// The formatting functions of the region.
/// - percent, number, currency, currency-fine (auto, fn): (number) => str
/// - date (auto, fn): (datetime | array) => str
/// - time (auto, fn): (datetime) => str
/// -> array
#let format(
  percent: auto,
  number: auto,
  currency: auto,
  currency-fine: auto,
  date: auto,
  time: auto,
) = (
  {
    let payload = _clean-auto((
      percent: percent,
      number: number,
      currency: currency,
      currency-fine: currency-fine,
      date: date,
      time: time,
    ))
    (region: (format: payload))
  },
)

/// The tax objects of the region: `default-vat` for items without a tax,
/// `small-enterprise-special-scheme` with `tax-exempt-small-biz`.
/// -> array
#let tax(
  default-vat: auto,
  small-enterprise-special-scheme: auto,
) = (
  {
    let payload = _clean-auto((
      default-vat: default-vat,
      small-enterprise-special-scheme: small-enterprise-special-scheme,
    ))
    (region: (tax: payload))
  },
)
