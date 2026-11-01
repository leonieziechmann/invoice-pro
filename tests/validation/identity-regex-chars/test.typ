// The identity check finds an invoice number made of the characters that have a
// meaning in a regular expression: the show rule that tags the number escapes
// them (`_regex-special` in src/theming/frame.typ). Unescaped, the parentheses
// would form a group, the braces a repetition and `|` an alternation, the
// number would no longer match itself, and strict would stop with "the invoice
// number ... does not appear in the first-page content".
#import "/tests/theme/identity.typ": identity-invoice, plain

#identity-invoice(
  plain,
  validation: "strict",
  invoice-nr: "R-1.(2)+[3]{4}|5*?^$#&~\\6",
  date: datetime(year: 2026, month: 10, day: 16),
)
