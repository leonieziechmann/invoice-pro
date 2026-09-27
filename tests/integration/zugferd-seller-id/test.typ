// Seller identifier (BT-29) without a tax registration (BT-32), see
// https://github.com/leonieziechmann/invoice-pro/issues/42
//
// A UK sole trader who is not VAT registered and has no tax number is
// identified by `id` alone, which satisfies BR-CO-26 without asserting a false
// tax identifier. Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.en-de,
  zugferd: "en16931",
  tax: tax.outside-scope(grounds: "Not registered for VAT."),
  sender: (
    name: "Jane Doe",
    address: "1 Example Street",
    city: "Sometown AB1 2CD",
    country: country.uk,
    id: "70025",
    contact: (
      name: "Jane Doe",
      phone: "+44 7000 000000",
      email: "jane@example.com",
    ),
  ),
  recipient: (
    name: "Example Client GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    email: "contact@example.de",
  ),
  invoice-nr: "2026-00001",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Design work], price: 400, quantity: 2, unit: unit.day)
]
#payment-goal(days: 14)
