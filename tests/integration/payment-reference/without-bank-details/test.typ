// Payment reference without `bank-details`: BT-83, the reference signs and
// `info.payment-reference` still follow the invoice's `payment-reference`.
// Uses a non-German buyer, since XRechnung requires payment instructions.

#import "/tests/integration/payment-reference/harness.typ": *

#show: zugferd-invoice.with(
  recipient: (
    name: "Kunde GmbH",
    address: "Kärntner Straße 1",
    city: (name: "Wien", post-code: "1010"),
    country: country.at,
    vat-id: "ATU12345678",
    buyer-reference: "AT-4711",
  ),
  payment-reference: "Kd. 4711 / RE-2026-001",
)

#standard-items

#expect-payment-reference("Kd. 4711 / RE-2026-001", bank-details: false)
