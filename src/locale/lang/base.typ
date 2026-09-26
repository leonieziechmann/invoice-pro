#let resolve-plural(v, n) = {
  if type(v) != dictionary { return v }
  if v.len() == 0 { return none }
  let num = if type(n) == decimal or type(n) == int or type(n) == float {
    float(n)
  } else if type(n) == str {
    float(n)
  } else {
    1.0
  }
  let fallback = v.pairs().first(default: (none, none)).last()
  if num == 1 {
    v.at("singular", default: fallback)
  } else {
    v.at("plural", default: fallback)
  }
}

/// The schema of all languages and their English fallback.
#let base-language = (
  meta: (
    /// ISO 639-1 code, sets `text.lang`; "base" resolves to "en".
    lang: "base",
    /// Picks the singular or plural form for a count.
    /// -> (any, int | float | decimal | str) => any
    resolve-plural: resolve-plural,
  ),

  /// The default titles of `invoice(document-type: ..)`.
  document: (
    invoice: "Invoice",
    credit-note: "Credit Note",
    corrected: "Corrected Invoice",
    prepayment: "Prepayment Invoice",
    /// Must say "Self-billing" (VAT Directive, Art. 226 No. 10a).
    self-billed: "Self-Billing Invoice",
  ),

  address: (
    recipient: "Bill To",
    sender: "From",
  ),

  reference: (
    tax-number: "Tax ID",
    invoice-number: "Invoice Number",
    vat-id: "VAT ID",
    invoice-date: "Invoice Date",
    service-time: "Period of Service",
    customer-number: "Customer No.",
    buyer-reference: "Buyer Reference",
    recipient-vat-id: "Buyer VAT ID",
    recipient-tax-number: "Buyer Tax ID",
    order-number: "Order No.",
    order-date: "Order Date",
    project: "Project",
    contract-number: "Contract No.",
    quote-number: "Quote No.",
    delivery-note-number: "Delivery Note No.",
    delivery-address: "Delivery Address",
    preceding-invoice-number: "Preceding Invoice No.",
    preceding-invoice-date: "Preceding Invoice Date",
    due-date: "Due Date",
    payment-reference: "Payment Reference",
    contact-person: "Contact Person",
    contact-phone: "Phone",
    contact-email: "Email",
    /// Who receives the payment instead of the sender (BG-10).
    payee: "Payee",
  ),

  line-items: (
    position: "Item",
    description: "Description",
    quantity: "Qty",
    unit-price: "Unit Price",
    price: "Price",
    total: "Total",
    vat: "Tax",
    net: "net",
    gross: "gross",
    discount: "Discount",
    surcharge: "Surcharge",
    subtotal: "Subtotal",
    prepayment: "Prepayment",
    /// Joins the last two item names of an automatic bundle description.
    conjunction: "and",
    origin: "Country of origin",
  ),

  summary: (
    sum: "Subtotal",
    vat-tax: "Tax",
    total: "Total",
    including: "incl.",
    excluding: "excl.",
    prepayment: "Prepayment",
    amount-due: "Amount Due",
  ),

  /// Notes below the line items on what all items share.
  global-info: (
    /// -> (content|str, content|str, content|str) => content
    tax-statement: (
      tax-text,
      rate,
      vat-tax,
    ) => [All items are #tax-text #rate #vat-tax.],
    unit: "Unit for all items:",
    quantity: "Quantity for all items:",
    date: "Service date for all items:",
  ),

  /// Why no VAT is charged, for items of the categories AE, K, G and O
  /// without `grounds`: printed below the line items and written as BT-120.
  tax-exemption: (
    reverse-charge: "Reverse charge",
    intra-community: "Tax-exempt intra-community supply",
    export: "Tax-exempt export",
    outside-scope: "Not subject to VAT",
  ),

  units: (
    piece: "piece",
    "set": "set",
    pair: "pair",
    "lump-sum": "lump sum",
    hour: "hour",
    day: "day",
    month: "month",
    year: "year",
    kilogram: "kilogram",
    gram: "gram",
    tonne: "tonne",
    metre: "metre",
    "square-metre": "square metre",
    millimetre: "millimetre",
    centimetre: "centimetre",
    kilometre: "kilometre",
    litre: "litre",
    "cubic-metre": "cubic metre",
  ),

  bank-details: (
    account-holder: "Account Holder",
    bank: "Bank",
    iban: "IBAN",
    bic: "BIC",
    reference: "Reference",
  ),

  /// Texts of `direct-debit`, `card-payment` and `paid`.
  payment-means: (
    method: "Payment method",
    transfer: "Bank transfer",
    direct-debit: "Direct debit",
    sepa-direct-debit: "SEPA direct debit",
    card: "Card payment",
    credit-card: "Credit card",
    debit-card: "Debit card",
    cash: "Cash",
    cheque: "Cheque",
    online: "Online payment",
    mandate: "Mandate reference",
    creditor-id: "Creditor identifier",
    debtor-iban: "Your IBAN",
    card-number: "Card number",
    card-holder: "Cardholder",
    /// The sentence of `paid`: the amount and the date, if given.
    /// -> (content|str, none|content|str) => content
    paid: (
      sum,
      date,
    ) => if date
      == none [The total amount of *#sum* has been paid.] else [The total amount of *#sum* was paid on #date.],
    /// `paid` after prepayments: `sum` is the remaining amount.
    /// -> (content|str, none|content|str) => content
    paid-due: (
      sum,
      date,
    ) => if date
      == none [The amount due of *#sum* has been paid.] else [The amount due of *#sum* was paid on #date.],
    /// `paid` on a credit note or a self-billed invoice, whose sender pays.
    /// -> (content|str, none|content|str) => content
    paid-credit: (
      sum,
      date,
    ) => if date
      == none [We have paid the amount of *#sum* to you.] else [We paid the amount of *#sum* to you on #date.],
  ),

  payment: (
    /// The payment sentence: the amount and the deadline.
    /// -> (content|str, content|str) => content
    text: (
      sum,
      deadline,
    ) => [Please transfer the total amount of *#sum* #deadline to the account listed below.],

    /// `text` after prepayments: `sum` is the remaining amount due.
    /// -> (content|str, content|str) => content
    text-due: (
      sum,
      deadline,
    ) => [Please transfer the amount due of *#sum* #deadline to the account listed below.],

    /// -> (content|str, content|str) => content
    text-direct-debit: (
      sum,
      deadline,
    ) => [The total amount of *#sum* will be collected from your account by direct debit #deadline.],

    /// -> (content|str, content|str) => content
    text-direct-debit-due: (
      sum,
      deadline,
    ) => [The amount due of *#sum* will be collected from your account by direct debit #deadline.],

    /// -> (content|str, content|str) => content
    text-card: (
      sum,
      deadline,
    ) => [The total amount of *#sum* will be charged to your card #deadline.],

    /// -> (content|str, content|str) => content
    text-card-due: (
      sum,
      deadline,
    ) => [The amount due of *#sum* will be charged to your card #deadline.],

    /// The note of a cash discount (`payment-goal(discount: ..)`): the
    /// deadline from `deadline-days`, and `basis`, the amount, if given.
    /// -> (str, str, none|content|str) => content
    cash-discount: (
      percent,
      deadline,
      basis,
    ) => [For payment #deadline, a cash discount of #percent#if basis != none [ on #basis] is granted.],

    /// -> (content|str) => str
    deadline-date: date => ("no later than", date).join(" "),

    /// -> (int) => str
    deadline-days: days => (
      "within",
      str(days),
      "days",
    ).join(" "),

    /// -> str
    deadline-soon: "upon receipt",

    /// `text` of a credit note or a self-billed invoice, whose sender pays.
    /// -> (content|str, content|str) => content
    text-credit: (
      sum,
      deadline,
    ) => [We will transfer the amount of *#sum* #deadline to the account listed below.],

    /// `deadline-soon` in `text-credit`.
    /// -> str
    deadline-soon-credit: "promptly",
  ),

  signature: (
    closing: "Sincerely,",
  ),

  legal: (
    // The small business note: used with every region, so it cites no law.
    vat-exemption: "No VAT is charged due to small business exemption.",
  ),

  errors: (
    name-missing: "Name is missing!",
    address-missing: "Address is missing!",
    city-missing: "City is missing!",
    ambiguous-tax: "Ambiguous 0% tax rate detected.",
    invalid-tax: "Invalid tax rate detected: ",
  ),
)
