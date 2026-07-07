#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  zugferd: "en16931",
  sender: (
    name: ("My Company Ltd", "Billing Dept"),
    address: ("123 Street Rd", "Suite 100"),
    city: "12345 City",
    tax-nr: "12/345/6789",
    vat-id: "DE987654321",
  ),
  recipient: (
    name: "Client Corp",
    address: "10 Downing St",
    city: (
      name: "London",
      post-code: "SW1A 2AA",
    ),
    country: country.uk,
    tax-nr: "987/654/32109",
    vat-id: "GB123456789",
  ),
)

#data-test(test: (ctx, data) => {
  // 1. Verify Sender (Seller) Data
  assert.eq(
    ctx.sender.name,
    [My Company Ltd \ Billing Dept],
    message: "Sender name vertical",
  )
  assert.eq(
    ctx.sender.name-inline,
    "My Company Ltd, Billing Dept",
    message: "Sender name inline",
  )
  assert.eq(
    ctx.sender.address,
    [123 Street Rd \ Suite 100],
    message: "Sender address vertical",
  )
  assert.eq(
    ctx.sender.address-inline,
    "123 Street Rd, Suite 100",
    message: "Sender address inline",
  )
  assert.eq(ctx.sender.city, "12345 City", message: "Sender city")
  assert.eq(ctx.sender.post-code, "12345", message: "Sender postcode")
  assert.eq(ctx.sender.city-name, "City", message: "Sender city-name")
  assert.eq(ctx.sender.tax-nr, "12/345/6789", message: "Sender tax-nr")
  assert.eq(ctx.sender.vat-id, "DE987654321", message: "Sender vat-id")

  // 2. Verify Recipient (Buyer) Data
  assert.eq(ctx.recipient.name, "Client Corp", message: "Recipient name")
  assert.eq(
    ctx.recipient.address,
    "10 Downing St",
    message: "Recipient address",
  )
  assert.eq(ctx.recipient.city-name, "London", message: "Recipient city name")
  assert.eq(ctx.recipient.post-code, "SW1A 2AA", message: "Recipient postcode")
  assert.eq(ctx.recipient.country.code, "GB", message: "Recipient country code")
  assert.eq(
    ctx.recipient.country.name,
    "United Kingdom",
    message: "Recipient country name",
  )
  assert.eq(ctx.recipient.vat-id, "GB123456789", message: "Recipient vat-id")
  assert.eq(ctx.recipient.tax-nr, "987/654/32109", message: "Recipient tax-nr")

  // Recipient city vertical should include London \ SW1A 2AA \ United Kingdom (international destination)
  assert.eq(
    ctx.recipient.city,
    [London \ SW1A 2AA \ United Kingdom],
    message: "Recipient city vertical",
  )
  assert.eq(
    ctx.recipient.city-inline,
    "London, SW1A 2AA, United Kingdom",
    message: "Recipient city inline",
  )
})[
  #line-items[
    #item(
      [Service],
      price: 100.00,
      quantity: 1,
    )
  ]
]
