#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test

#show: invoice.with(
  theme: themes.DIN-5008(),
  locale: locale.de-de,
  sender: (
    name: "Sender GmbH",
    address: "Musterstr. 1",
    city: "12345 Berlin",
    tax-nr: "11/222/33333",
    vat-id: "DE123456789",
    contact: (
      name: "Erika Muster",
      phone: "+49 30 123456",
      email: "erika@sender.de",
    ),
  ),
  recipient: (
    name: "Customer AG",
    address: "Kundenstr. 2",
    city: "80331 München",
    vat-id: "DE987654321",
    customer-nr: "KD-9988",
    buyer-reference: "04011000-12345-67",
  ),
  invoice-nr: "INV-2026-0099",
  date: datetime(year: 2026, month: 8, day: 15),
  order-nr: "PO-4455",
  order-date: datetime(year: 2026, month: 8, day: 1),
  project: "Website Redesign",
  contract-nr: "CTR-2026-01",
  quote-nr: "QUO-8877",
  delivery-note-nr: "DEL-1122",
  preceding-invoice-nr: "INV-2026-0050",
  references: (
    references.invoice-nr(),
    references.customer-nr(),
    references.buyer-reference(),
    references.recipient-vat-id(),
    references.order-nr(),
    references.order-date(),
    references.project(),
    references.contract-nr(),
    references.quote-nr(),
    references.delivery-note-nr(),
    references.preceding-invoice-nr(),
    references.due-date(),
    references.contact-person(),
    references.contact-phone(),
    references.contact-email(),
  ),
)

#line-items[
  #item(
    [Consulting],
    price: 100.00,
    quantity: 1,
    date: (
      datetime(year: 2026, month: 8, day: 10),
      datetime(year: 2026, month: 8, day: 12),
    ),
  )
]

#payment-goal(days: 14)
