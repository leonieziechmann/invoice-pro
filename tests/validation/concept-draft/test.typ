// The validation snippet of the concept (§7.3; prototype tests/doc/validation.typ)
// and "off means off" (prototype scripts/checks-core.sh, run-all.sh): with
// ZUGFeRD and missing data, draft marks the gaps, lists them on a report page and
// withholds factur-x.xml; validation none renders clean (no issue, no report) and
// attaches the XML as built, also for the four problems of the draft fixture.
#import "/tests/theme/doc-prelude.typ": doc-body, doc-party
#import "/tests/theme/draft.typ": draft-invoice
#import "/tests/theme/harness.typ": (
  case, case-marker, close-cases, issues-of, span-of,
)
#import "/src/lib.typ": *

#let incomplete = (
  locale: locale.de-de,
  ..doc-party,
  invoice-nr: none, // missing: ‹fehlt: Rechnungsnummer›
  recipient: (name: "Muster AG"), // no address
  zugferd: "basic", // withheld while data is missing
)
#case("draft", ..incomplete, validation: "draft", doc-body())
#case("none", ..incomplete, validation: none, doc-body())
#draft-invoice(validation: none, marker: case-marker("fixture/none"))
#close-cases()
#context {
  assert.eq(
    issues-of("draft").map(x => x.id),
    ("invoice-number", "recipient-address"),
  )
  assert.eq(issues-of("none"), ())
  let attached(key) = {
    let s = span-of(key)
    query(pdf.attach)
      .filter(a => {
        let p = a.location().page()
        p >= s.first and p < s.first + s.pages
      })
      .map(a => a.path)
  }
  assert.eq(attached("draft"), (), message: "draft must withhold the XML")
  assert.eq(attached("none"), ("/factur-x.xml",), message: "none attaches it")
  assert.eq(issues-of("fixture/none"), ())
  assert.eq(attached("fixture/none"), ("/factur-x.xml",))
  assert(
    query(<ip-report>).len() == 1,
    message: "only the draft invoice has a report",
  )
}
