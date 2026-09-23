// Reporting the e-invoice diagnostics: the message of the compiler error, the
// `zugferd-errors: "report"` mode, which hands them to the theme instead of
// failing and attaches the XML of an invoice with errors as a draft, and the
// `"ignore"` mode, which attaches the XML anyway.

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile, switch-profile
#import "/src/zugferd/report.typ": format-report, render-zugferd-report
#import "/src/zugferd/validate.typ": error, warning

#let result = (
  profile: resolve-profile("xrechnung", "DE"),
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
    "Set `zugferd-errors: \"report\"` on the invoice to list these problems in the document instead.",
  )
  assert.eq(format-report(result).split("\n"), expected)

  // The default theme renders the diagnostics as content
  assert.eq(type(render-zugferd-report((:), result)), content)
}

// --- 1b. With `zugferd: auto`, the report says which profile was chosen ---
#{
  let chosen = switch-profile(resolve-profile(auto, "DE"), "en16931")
  chosen.skipped = ((id: "xrechnung", name: "XRechnung 3.0"),)
  let report = format-report((
    profile: chosen,
    diagnostics: (
      error("BR-02", "invoice-nr", "The invoice number (BT-1) is missing."),
    ),
  ))
  assert(
    report.starts-with(
      "The e-invoice (ZUGFeRD / Factur-X, profile EN 16931 (COMFORT)) is not valid: 1 error.",
    ),
  )
  assert(
    report.contains(
      "Profile chosen by `zugferd: auto`: EN 16931 (COMFORT). Not possible: XRechnung 3.0 (see the warnings).",
    ),
  )

  // Without a fallback, only the chosen profile is named
  let direct = format-report((
    profile: resolve-profile(auto, "FR"),
    diagnostics: (error("BR-02", "invoice-nr", "missing"),),
  ))
  assert(
    direct.contains(
      "Profile chosen by `zugferd: auto`: EN 16931 (COMFORT).\n",
    ),
  )
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

// --- 4. "report" without errors: a warning only (the IBAN) ---
#invoice(
  ..incomplete,
  theme: themes.blank.with(zugferd-report: (ctx, result) => [#metadata(
    result.diagnostics.map(d => (d.level, d.rule)),
  )<warned-rules>]),
  zugferd-errors: "report",
  invoice-nr: "RE-2026-001",
)[
  #line-items[#item([Consulting], price: 100)]
  #payment-goal(days: 14)
  #bank-details(iban: "DE00370400440532013000")
]

#context {
  assert.eq(
    query(<reported-rules>).map(it => it.value),
    (("BR-02", "BR-CO-25"),),
  )
  assert.eq(
    query(<warned-rules>).map(it => it.value),
    ((("warning", "BR-DE-19"),),),
  )

  // With errors, "report" attaches the XML only as a draft, under another
  // name than the e-invoice and as data. "ignore" and an invoice without
  // errors attach it as the e-invoice.
  let (draft, ignored, valid) = query(pdf.attach)
  assert.eq(
    (draft.path, draft.relationship, draft.mime-type),
    ("/invoice-draft.xml", "data", "text/xml"),
  )
  assert(draft.description.starts-with("Draft"), message: draft.description)
  for attachment in (ignored, valid) {
    assert.eq(
      (attachment.path, attachment.relationship, attachment.description),
      ("/factur-x.xml", "alternative", "ZUGFeRD / Factur-X invoice data"),
    )
  }
  // The draft is the same XML that "ignore" attaches
  assert.eq(draft.data, ignored.data)
}
