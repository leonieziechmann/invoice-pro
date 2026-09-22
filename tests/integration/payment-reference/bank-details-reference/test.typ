// Payment reference, level 1: the `reference` argument of `bank-details`
// wins over the invoice's `payment-reference` and `invoice-nr`. It is sent
// as structured reference (EPC-QR line 10).

#import "/tests/integration/payment-reference/harness.typ": *

#show: zugferd-invoice.with(payment-reference: "Kd. 4711 / RE-2026-001")

#standard-items

#bank-details(..bank, reference: "RF18539007547034")

#expect-payment-reference("RF18539007547034", epc-field: "reference")
