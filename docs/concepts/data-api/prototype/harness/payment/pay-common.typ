// The invoice around the payment block of the payment matrix (no data).
#let pay = sys.inputs.at("pay", default: "transfer")
#let args = (
  zugferd: "en16931",
  sender: (
    name: "Entsorgung Süd GmbH",
    address: "Industriestraße 7",
    city: "80339 München",
    country: "DE",
    vat-id: "DE123456789",
    contact: (
      name: "Buchhaltung",
      phone: "+49 89 1234567",
      email: "r@e.example",
    ),
  ),
  recipient: (
    name: "Bayerische Beispiel AG",
    address: "Marienplatz 8",
    city: "80331 München",
    country: "DE",
    vat-id: "DE987654321",
    buyer-reference: "04011000-1234512345-06",
  ),
  invoice-nr: "P-1",
  date: datetime(year: 2026, month: 11, day: 2),
)
#let d = datetime(year: 2026, month: 11, day: 2)
#let bank = (
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
