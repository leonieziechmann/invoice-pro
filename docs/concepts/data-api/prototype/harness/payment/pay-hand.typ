// The payment matrix without data, written with the 0.6.0 components.
#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *
#import "pay-common.typ": *
#show: invoice.with(..args)
#line-items[#item("Leistung", price: "100.00", tax: 19%)]
#if pay == "transfer" {
  payment-terms(days: 14)
  bank-details(..bank)
} else if pay == "direct-debit" {
  payment-terms(days: 14)
  direct-debit(
    mandate: "M-1",
    creditor-id: "DE98ZZZ09999999999",
    debtor-iban: "DE02120300000000202051",
  )
} else if pay == "card" {
  payment-terms(days: 14)
  card-payment(last4: "4242", kind: "credit")
} else if pay == "paid-cash" {
  paid(method: "cash", date: d)
} else if pay == "paid-transfer" {
  paid(method: "transfer", date: d)
  bank-details(..bank)
}
