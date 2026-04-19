/// English language overrides.
/// This dictionary is merged over `lang/base.typ` by the locale factory.
#let en = (
  meta: (
    lang: "en",
  ),

  document: (
    invoice: "Invoice",
  ),

  address: (
    recipient: "Bill To",
    sender: "From",
  ),

  reference: (
    tax-number: "Tax ID",
    invoice-number: "Invoice Number",
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
  ),

  summary: (
    sum: "Subtotal",
    vat-tax: "Tax",
    total: "Total Due",
    including: "incl.",
    excluding: "excl.",
  ),

  bank-details: (
    account-holder: "Account Holder",
    bank: "Bank",
    iban: "IBAN",
    bic: "BIC",
  ),

  payment: (
    text: (
      sum,
      currency,
      deadline,
    ) => [Please transfer the total amount of *#sum #currency* #deadline to the account listed below.],
    deadline-date: date => "by " + str(date),
    deadline-days: days => "within " + str(days) + " days",
    deadline-soon: "upon receipt",
  ),

  signature: (
    closing: "Sincerely,",
  ),

  legal: (
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
