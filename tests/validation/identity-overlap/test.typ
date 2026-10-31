// The identity check when one value starts the other: the invoice number 1 is
// the first character of the date 16.10.2026. Both are found and strict passes
// (with a show rule per value, the number's rule took the "1" of the date, and
// the date was reported missing).
#import "/tests/theme/identity.typ": identity-invoice, plain

#identity-invoice(
  plain,
  validation: "strict",
  invoice-nr: "1",
  date: datetime(year: 2026, month: 10, day: 16),
)
