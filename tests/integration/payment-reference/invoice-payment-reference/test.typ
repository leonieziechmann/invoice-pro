// Payment reference, level 2: without a `reference` or `text` argument on
// `bank-details`, the invoice's `payment-reference` (Verwendungszweck) wins
// over the `invoice-nr`. It is free text and therefore sent as unstructured
// remittance text (EPC-QR line 11).

#import "/tests/integration/payment-reference/harness.typ": *

#show: zugferd-invoice.with(payment-reference: "Kd. 4711 / RE-2026-001")

#standard-items

#bank-details(..bank)

#expect-payment-reference("Kd. 4711 / RE-2026-001", epc-field: "text")
