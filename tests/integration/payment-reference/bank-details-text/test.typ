// Payment reference, level 1: the `text` argument of `bank-details` wins
// over the invoice's `payment-reference` and `invoice-nr`. It is sent as
// unstructured remittance text (EPC-QR line 11) and must survive XML escaping.

#import "/tests/integration/payment-reference/harness.typ": *

#show: zugferd-invoice.with(payment-reference: "Kd. 4711 / RE-2026-001")

#standard-items

#bank-details(..bank, text: "Mitgliedsbeitrag 2026 & Spende")

#expect-payment-reference("Mitgliedsbeitrag 2026 & Spende", epc-field: "text")
