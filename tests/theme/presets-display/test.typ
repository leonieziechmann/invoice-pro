/// [ppi: 12]

// The bold and compact presets (prototype tests/presets-display.typ, gallery
// bold/compact, scripts/checks-presets-display.sh):
// - a 4-item invoice fits on ONE page on the preset's default layout and on DIN
//   5008 A; compact puts 30 rows, totals, bank details and closing on one page;
// - three pages: continuation header, page labels, repeated table header;
// - the payable label: the poster block and the totals bar name the same amount;
// - contrast 4.5:1 incl. the looks' checks.pairs under strict, four brand seeds;
//   the declared disc pair of bold is checked;
// - galleries: a long document word, other layouts and languages, an image logo
//   with alt text, ZUGFeRD attaches the XML;
// - strict stops on missing data (the draft markers: tests/validation/draft-*).
// The looks kit and the layout mapping: tests/theme/looks-kit.
#import "/tests/theme/body.typ": body, layout-of, logo-img, party, preset-of
#import "/tests/theme/display.typ": display-invoice
#import "/tests/theme/gallery/bold.typ": gallery as bold-gallery
#import "/tests/theme/gallery/compact.typ": gallery as compact-gallery
#import "/tests/theme/harness.typ": (
  case, case-marker, close-cases, in-case, span-of,
)
#import "/tests/test-locale.typ": test-locale
#import "/src/lib.typ": *

#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
// a 4-item invoice (tests/theme/body.typ) on the named layouts
#for (look, lay) in (
  ("bold", "a4-digital"),
  ("bold", "din-5008-a"),
  ("compact", "a4-dense"),
  ("compact", "din-5008-a"),
) {
  case(
    look + "/" + lay,
    theme: preset-of(look).with(brand, layout: layout-of(lay)),
    locale: test-locale,
    ..party,
    body(n: 4),
  )
}
// the display invoice: layout auto (German sender: bold -> a4-digital, compact
// -> a4-dense), dense rows, three pages, the payable label
#let shown = (
  ("bold/auto", "bold", (n: 4)),
  ("compact/auto", "compact", (n: 4)),
  ("compact/dense-30", "compact", (n: 30)),
  ("bold/3-pages", "bold", (n: 60)),
  ("compact/3-pages", "compact", (n: 110)),
  ("bold/deposit", "bold", (n: 4, deposit: true)),
)
#for (key, look, args) in shown {
  display-invoice(look, ..args, marker: case-marker(key))
}
// contrast 4.5:1 under strict over four brand seeds (the galleries with checks)
#let seeds = (none, "111111", "ffd400", "0f766e")
#for seed in seeds {
  let s = if seed == none { "default" } else { seed }
  bold-gallery(
    check: true,
    seed: seed,
    validation: "strict",
    marker: case-marker("bold/contrast/" + s),
  )
  compact-gallery(
    check: true,
    seed: seed,
    validation: "strict",
    marker: case-marker("compact/contrast/" + s),
  )
}
// galleries: long document words, other layouts and languages, e-invoice, logo
#bold-gallery(
  title: "Abschlagsrechnung",
  deposit: true,
  marker: case-marker("bold/long-title"),
)
#bold-gallery(
  title: "Abschlagsrechnung",
  layout: "sn-010130-right",
  marker: case-marker("bold/long-title/sn"),
)
#for lang in ("de", "fr") {
  bold-gallery(lang: lang, marker: case-marker("bold/gallery/" + lang))
}
#compact-gallery(
  lang: "en",
  layout: "us-letter-dense",
  marker: case-marker("compact/gallery/en"),
)
#bold-gallery(zugferd: true, marker: case-marker("bold/zugferd"))
#compact-gallery(
  zugferd: true,
  logo: "image",
  marker: case-marker("compact/zugferd"),
)
#close-cases()

#context {
  let pages(key) = span-of(key).pages
  for key in (
    "bold/a4-digital",
    "bold/din-5008-a",
    "compact/a4-dense",
    "compact/din-5008-a",
    "bold/auto",
    "compact/auto",
    "compact/dense-30",
  ) {
    assert(
      pages(key) == 1,
      message: key + ": " + str(pages(key)) + " pages, want 1",
    )
  }
  for key in ("bold/3-pages", "compact/3-pages") {
    assert(
      pages(key) == 3,
      message: key + ": " + str(pages(key)) + " pages, want 3",
    )
  }
  // the payable label: block and bar say "Fälliger Betrag" after a deposit,
  // "Gesamtbetrag" without one
  let labels(key) = in-case(key, <pd-label>)
  let dep = labels("bold/deposit")
  assert(
    dep.filter(l => l == "amount-due").len() >= 2,
    message: "bold payable label after a deposit: " + repr(dep),
  )
  let plain = labels("bold/auto")
  assert(
    "amount-due" not in plain and plain.filter(l => l == "total").len() >= 2,
    message: "bold payable label without deposit: " + repr(plain),
  )
  // ZUGFeRD: the complete invoices attach the XML
  let attached(key) = {
    let s = span-of(key)
    query(pdf.attach).filter(a => {
      let p = a.location().page()
      p >= s.first and p < s.first + s.pages
    })
  }
  for key in ("bold/zugferd", "compact/zugferd") {
    assert(
      attached(key).map(a => a.path) == ("/factur-x.xml",),
      message: key + ": the XML is not attached",
    )
  }
}

// the declared pair is checked: a seed whose disc fails is reported by name
#assert.eq(
  catch(() => invoice(
    theme: theme.bold.with(
      theme.custom.colors(primary: rgb("#777777"), on-primary: white),
      theme.custom.checks(min-contrast: 4.5),
    ),
    sender: (
      name: "A GmbH",
      address: "Weg 1",
      city: "20457 Hamburg",
      vat-id: "DE123456789",
    ),
    recipient: (name: "B AG", address: "Weg 2", city: "80331 München"),
    invoice-nr: "1",
    validation: "strict",
    [#line-items[#item([X], price: 10)]],
  )),
  "panicked with: "
    + repr(
      "invoice-pro found 2 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):\n  1. theme: colors::on-primary on colors::primary has contrast 4.48:1, below checks.min-contrast 4.5:1\n  2. theme: checks::pairs::bold-disc (#ffffff on #a0a0a0) has contrast 2.62:1, below checks.min-contrast 4.5:1",
    ),
)
// strict stops on missing data (no invoice number, no seller tax ID)
#let missing = "invoice-pro found 2 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):\n  1. invoice::invoice-nr is missing; every invoice needs a unique, sequential number (§ 14 Abs. 4 Nr. 4 UStG; EN 16931 BT-1)\n  2. invoice::sender has neither `vat-id` nor `tax-nr`; the supplier's VAT ID or tax number is required (§ 14 Abs. 4 Nr. 2 UStG; EN 16931 BT-31, BT-32)"
#for look in ("bold", "compact") {
  assert.eq(
    catch(() => display-invoice(look, broken: true, validation: "strict")),
    "panicked with: " + repr(missing),
    message: look,
  )
}
