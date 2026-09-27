// The pages of the theme figures (docs/static/img/themes and the figures of
// the concept in docs/concepts/theming-api/figures): one invoice per
// compilation, chosen with `--input page=..`, rendered from the fixtures of
// the tests, so that the figures show what the tests check. The figures are
// built by scripts/theme-figures, which composes the pages with sheets.typ.
//
//   page=gallery    preset=<name>         the gallery invoice of a preset
//   page=matrix     look=<name> layout=<name|auto>
//                                         the shared 4-item body with a brand
//   page=proof      layout=<name>         the print proof of a window layout
//   page=draft                            a draft and its report page
//   page=stationery mode=print|pdf|einvoice
//   page=acme                             a third-party A5 sidebar layout
//   page=roll                             an 80 mm thermal-roll receipt
#import "/src/lib.typ": *
#import "/tests/theme/body.typ": body, layout-of, logo-img, party, preset-of
#import "/tests/theme/doc-prelude.typ": doc-body, doc-party
#import "/tests/test-locale.typ": test-locale
#import "/tests/theme/draft.typ": draft-invoice
#import "/tests/theme/stationery.typ": stationery-invoice
#import "/tests/theme/acme-theme.typ" as acme
#import "/tests/theme/gallery/bold.typ" as bold
#import "/tests/theme/gallery/boxed.typ" as boxed
#import "/tests/theme/gallery/classic.typ" as classic
#import "/tests/theme/gallery/compact.typ" as compact
#import "/tests/theme/gallery/corporate.typ" as corporate
#import "/tests/theme/gallery/elegant.typ" as elegant
#import "/tests/theme/gallery/plain.typ" as plain
#import "/tests/theme/gallery/prestige.typ" as prestige
#import "/tests/theme/gallery/soft.typ" as soft
#import "/tests/theme/gallery/technical.typ" as technical

#let page = sys.inputs.at("page", default: "matrix")
#let input(key, default) = sys.inputs.at(key, default: default)

#let galleries = (
  classic: classic.gallery,
  plain: plain.gallery,
  corporate: corporate.gallery,
  elegant: elegant.gallery,
  prestige: prestige.gallery,
  bold: bold.gallery,
  technical: technical.gallery,
  soft: soft.gallery,
  compact: compact.gallery,
  boxed: boxed.gallery,
)

// The brand of the matrix pages (tests/theme/matrix.typ).
#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)

// The receipt of the concept (§8.5): any format is data.
#let roll = (
  name: "roll-80",
  paper: (width: 80mm, height: auto),
  marks: none,
  margin: (x: 4mm, top: 6mm, bottom: 16mm),
  areas: (
    letterhead: (place: "before", parts: ("sender",), align: center),
    title: (place: "before", parts: ("title",)),
    address: (place: "before", parts: ("recipient",)),
    footer: (place: "footer", parts: ("registration",), text: (size: 6pt)),
  ),
)

#if page == "gallery" {
  galleries.at(input("preset", "classic"))()
} else if page == "matrix" {
  let look = input("look", "classic")
  let lay = input("layout", "auto")
  let preset = preset-of(look)
  invoice(
    theme: if lay == "auto" { preset.with(brand) } else {
      preset.with(brand, layout: layout-of(lay))
    },
    locale: test-locale,
    ..party,
    body(n: 4),
  )
} else if page == "proof" {
  invoice(
    theme: theme.classic.with(
      layout: layout-of(input("layout", "din-5008-a")),
      theme.custom.proof(true),
    ),
    locale: test-locale,
    ..party,
    body(n: 4),
  )
} else if page == "draft" {
  draft-invoice(look: "classic", lang: "de")
} else if page == "stationery" {
  stationery-invoice(input("mode", "pdf"))
} else if page == "acme" {
  invoice(
    theme: theme.classic.with(acme.patch, layout: acme.sidebar-a5),
    locale: locale.de-de,
    ..doc-party,
    doc-body(),
  )
} else if page == "roll" {
  invoice(
    theme: theme.plain.with(
      layout: roll,
      theme.custom.sizes(body: 8pt, fine: 6pt),
      theme.custom.title(show-place-date: true),
    ),
    locale: locale.de-de,
    ..doc-party,
    doc-body(n: 3),
  )
} else {
  panic("tools/figures/pages.typ: unknown page " + repr(page))
}
