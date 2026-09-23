// `base-quantity` must be greater than 0.
//
// Bug: `base-quantity: 0` crashed with a division by zero, and a negative
// base quantity silently produced a nonsense credit line (and an e-invoice
// violating PEPPOL-EN16931-R121).
//
// Expected: a clear error at the item or bundle.

#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

#let test-invoice(body) = invoice(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Seller", address: "Street 1", city: "City"),
  recipient: (name: "Buyer", address: "Street 2", city: "City"),
  line-items(tax: tax.vat(19%), body),
)

// `body` is a function, as the item checks its arguments when it is called.
#let expect-error(component, value, body) = {
  let message = catch(() => test-invoice(body()))
  let expected = (
    component + "::base-quantity must be greater than 0, got " + value + "."
  )
  assert(
    message != none and message.contains(expected),
    message: "Expected `" + expected + "`, got " + repr(message),
  )
}

#expect-error("item", "0", () => [
  #item([Screws], price: 5, quantity: 200, base-quantity: 0)
])
#expect-error("item", "-100", () => [
  #item([Screws], price: 5, quantity: 200, base-quantity: -100)
])
#expect-error("bundle", "0", () => [
  #bundle([Package], base-quantity: 0)[
    #item([Screws], price: 5)
  ]
])
// A base quantity cascaded with `apply` is checked as well.
#expect-error("item", "0", () => [
  #apply(base-quantity: 0)[
    #item([Screws], price: 5, quantity: 200)
  ]
])

// A valid base quantity still works.
#test-invoice[
  #item([Screws], price: 5, quantity: 200, base-quantity: 100)
]
