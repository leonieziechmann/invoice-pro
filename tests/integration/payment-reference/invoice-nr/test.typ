// Payment reference, level 3: without any explicit payment reference, the
// `invoice-nr` is used. It is sent as structured reference (EPC-QR line 10).

#import "/tests/integration/payment-reference/harness.typ": *

#show: zugferd-invoice

#standard-items

#bank-details(..bank)

#expect-payment-reference("RE-2026-001", epc-field: "reference")
