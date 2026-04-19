/// German language overrides.
/// This dictionary is merged over `lang/base.typ` by the locale factory.
#let de = (
  meta: (
    lang: "de",
  ),

  document: (
    invoice: "Rechnung",
  ),

  address: (
    recipient: "Empfänger",
    sender: "Absender",
  ),

  reference: (
    tax-number: "Steuernummer",
    invoice-number: "Rechnungsnummer",
  ),

  line-items: (
    position: "Pos",
    description: "Beschreibung",
    quantity: "Menge",
    unit-price: "Einzelpreis",
    price: "Preis",
    total: "Gesamt",
    vat: "MwSt.",
    net: "netto",
    gross: "brutto",
    discount: "Rabatt",
    surcharge: "Zuschlag",
    subtotal: "Zwischensumme",
  ),

  summary: (
    sum: "Summe",
    vat-tax: "Mehrwertsteuer",
    total: "Gesamt",
    including: "inkl.",
    excluding: "zzgl.",
  ),

  bank-details: (
    account-holder: "Kontoinhaber:in",
    bank: "Kreditinstitut",
    iban: "IBAN",
    bic: "BIC",
  ),

  payment: (
    text: (
      sum,
      currency,
      deadline,
    ) => [Bitte überweisen Sie den Gesamtbetrag von *#sum #currency* #deadline ohne Abzug auf das unten genannte Konto.],
    deadline-date: date => "bis spätestens " + str(date),
    deadline-days: days => "innerhalb von " + str(days) + " Tagen",
    deadline-soon: "zeitnah",
  ),

  signature: (
    closing: "Mit freundlichen Grüßen",
  ),

  legal: (
    vat-exemption: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
  ),

  errors: (
    name-missing: "Name fehlt!",
    address-missing: "Adresse fehlt!",
    city-missing: "Stadt fehlt!",
    ambiguous-tax: "Mehrdeutiger 0% Steuersatz erkannt.",
    invalid-tax: "Ungültiger Steuersatz erkannt: ",
  ),
)
