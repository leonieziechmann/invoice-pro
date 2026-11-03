// The payment matrix without data: `payment(..)` with the arguments of one
// method, the twin of pay-hand.typ (the components written by hand).
#import "/repo/src/lib.typ": *
#import "pay-common.typ": *
#show: invoice.with(..args)
#line-items[#item("Leistung", price: "100.00", tax: 19%)]
#if pay == "transfer" {
  payment(terms: (days: 14), bank: bank)
} else if pay == "direct-debit" {
  payment(
    terms: (days: 14),
    bank: bank,
    creditor-id: "DE98ZZZ09999999999",
    direct-debit: (mandate: "M-1", debtor-iban: "DE02120300000000202051"),
  )
} else if pay == "card" {
  payment(terms: (days: 14), bank: bank, card: (last4: "4242", kind: "credit"))
} else if pay == "paid-cash" {
  payment(terms: (days: 14), bank: bank, paid: (method: "cash", date: d))
} else if pay == "paid-transfer" {
  payment(terms: (days: 14), bank: bank, paid: (method: "transfer", date: d))
}
