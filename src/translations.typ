/// Translation dictionaries for supported languages.
///
/// Each language contains translations for all user-facing strings in the invoice.

#let translations = (
  de: (
    id: "de",
    country: "DE",
    // Document
    invoice: "Rechnung",
    // Address labels
    recipient: "Empfänger",
    sender: "Absender",
    // Reference signs
    tax-number: "Steuernummer",
    invoice-number: "Rechnungsnummer",
    // Table headers
    position: "Pos",
    description: "Beschreibung",
    quantity: "Menge",
    unit-price: "Einzelpreis",
    total-price: "Gesamt",
    price: "Preis",
    vat-label: "MwSt.",
    net: "netto",
    gross: "brutto",
    // Table footer
    sum: "Summe",
    vat-tax: "Mehrwertsteuer",
    total: "Gesamt",
    including: "inkl.",
    // VAT exemption notice (Kleinunternehmerregelung)
    vat-exemption-notice: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
    // Bank details
    account-holder: "Kontoinhaber:in",
    bank: "Kreditinstitut",
    iban-label: "IBAN",
    bic-label: "BIC",
    // Payment
    payment-text: (
      sum,
      currency,
      deadline,
    ) => [Bitte überweisen Sie den Gesamtbetrag von *#sum #currency* #deadline ohne Abzug auf das unten genannte Konto.],
    deadline-by-date: date => "bis spätestens " + date,
    deadline-within-days: days => "innerhalb von " + str(days) + " Tagen",
    deadline-soon: "zeitnah",
    // Signature
    closing: "Mit freundlichen Grüßen",
    // Validation errors
    name-missing: "Name fehlt!",
    address-missing: "Adresse fehlt!",
    city-missing: "Stadt fehlt!",
  ),
  en: (
    id: "en",
    country: "GB",
    // Document
    invoice: "Invoice",
    // Address labels
    recipient: "Recipient",
    sender: "Sender",
    // Reference signs
    tax-number: "Tax Number",
    invoice-number: "Invoice Number",
    // Table headers
    position: "Pos",
    description: "Description",
    quantity: "Qty",
    unit-price: "Unit Price",
    total-price: "Total",
    price: "Price",
    vat-label: "VAT",
    net: "net",
    gross: "gross",
    // Table footer
    sum: "Subtotal",
    vat-tax: "VAT",
    total: "Total",
    including: "incl.",
    // VAT exemption notice (small business regulation)
    vat-exemption-notice: "VAT is not charged in accordance with § 19 UStG (German VAT Act).",
    // Bank details
    account-holder: "Account Holder",
    bank: "Bank",
    iban-label: "IBAN",
    bic-label: "BIC",
    // Payment
    payment-text: (
      sum,
      currency,
      deadline,
    ) => [Please transfer the total amount of *#sum #currency* #deadline to the account below.],
    deadline-by-date: date => "by " + date,
    deadline-within-days: days => "within " + str(days) + " days",
    deadline-soon: "without undue delay",
    // Signature
    closing: "Kind regards",
    // Validation errors
    name-missing: "Name Missing!",
    address-missing: "Address Missing!",
    city-missing: "City Missing!",
  ),
)

/// Gets the translation dictionary for a given language.
///
/// -> dictionary
#let get-translations(
  /// The language code (e.g., "de", "en").
  /// -> str
  lang,
) = {
  if type(lang) == dictionary {
    // Allow passing a custom translation dictionary
    lang
  } else if lang in translations {
    translations.at(lang)
  } else {
    panic("Unsupported language: " + lang + ". Supported languages: " + translations.keys().join(", "))
  }
}

/// Merges custom translations with the base translations for a language.
///
/// -> dictionary
#let merge-translations(
  /// The base language code.
  /// -> str
  lang,
  /// Custom translations to override.
  /// -> dictionary
  overrides,
) = {
  let base = get-translations(lang)
  for key in overrides.keys() {
    base.insert(key, overrides.at(key))
  }
  base
}
