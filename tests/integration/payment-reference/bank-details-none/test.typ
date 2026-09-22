// Payment reference, level 1: `reference: none` on `bank-details` explicitly
// omits the reference. Nothing is printed or encoded in the EPC-QR code, and
// BT-83 is left out of the XML instead of falling back to the invoice.

#import "/tests/integration/payment-reference/harness.typ": *

#show: zugferd-invoice.with(payment-reference: "Kd. 4711 / RE-2026-001")

#standard-items

#bank-details(..bank, reference: none)

#expect-payment-reference(none)
