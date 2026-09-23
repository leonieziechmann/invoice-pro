// Reporting the e-invoice diagnostics: the message of the compiler error, the
// `zugferd-errors: "report"` mode, which hands them to the theme instead of
// failing, and the `"ignore"` mode, which embeds the XML anyway.

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/zugferd/report.typ": format-report, render-zugferd-report
#import "/src/zugferd/validate.typ": error, warning

#let result = (
  profile: resolve-profile("en16931", "DE", "DE"),
  diagnostics: (
    error(
      "BR-DE-15",
      "recipient.buyer-reference",
      "XRechnung requires the buyer reference (BT-10), e.g. the Leitweg-ID.",
      hint: "Set `buyer-reference` (or `leitweg-id`) on the recipient.",
    ),
    error("BR-02", "invoice-nr", "The invoice number (BT-1) is missing."),
    warning(
      "BR-DE-27",
      "sender.contact.phone",
      "The seller contact phone number (BT-42) should contain at least three digits.",
    ),
  ),
)

// --- 1. The compiler error lists every error, then the warnings ---
#{
  let expected = (
    "The e-invoice (ZUGFeRD / Factur-X, profile XRechnung 3.0) is not valid: 2 errors, 1 warning.",
    "  1. [BR-DE-15] recipient.buyer-reference: XRechnung requires the buyer reference (BT-10), e.g. the Leitweg-ID.",
    "     Hint: Set `buyer-reference` (or `leitweg-id`) on the recipient.",
    "  2. [BR-02] invoice-nr: The invoice number (BT-1) is missing.",
    "Warnings:",
    "  - [BR-DE-27] sender.contact.phone: The seller contact phone number (BT-42) should contain at least three digits.",
    "XRechnung is used because seller and buyer are located in Germany (`zugferd: \"en16931\"`).",
    "Set `zugferd-errors: \"report\"` on the invoice to list these problems in the document instead.",
  )
  assert.eq(format-report(result).split("\n"), expected)

  // The default theme renders the diagnostics as content
  assert.eq(type(render-zugferd-report((:), result)), content)
}

// --- 2. "report" hands all diagnostics to the theme instead of failing ---
#let incomplete = (
  theme: themes.blank.with(
    zugferd-report: (ctx, result) => {
      let rules = result.diagnostics.map(d => d.rule)
      assert.eq(rules, ("BR-02", "BR-CO-25"))
      assert.eq(result.profile.id, "en16931")
      [#metadata(rules)<reported-rules>]
    },
  ),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: "80339 München",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Buyer SAS",
    address: "Rue 1",
    city: (name: "Paris", post-code: "75001"),
    country: country.fr,
    vat-id: "FR99123456789",
  ),
  date: datetime(year: 2026, month: 9, day: 1),
)

#invoice(..incomplete, zugferd-errors: "report")[
  #line-items[#item([Consulting], price: 100)]
]

// --- 3. "ignore" embeds the XML without reporting anything ---
#invoice(..incomplete, zugferd-errors: "ignore")[
  #line-items[#item([Consulting], price: 100)]
]

#context {
  assert.eq(
    query(<reported-rules>).map(it => it.value),
    (("BR-02", "BR-CO-25"),),
  )
  let attachments = query(pdf.attach).filter(it => it.path == "/factur-x.xml")
  assert.eq(attachments.len(), 2)
}
