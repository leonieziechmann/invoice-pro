#import "../loom-wrapper.typ": loom, managed-motif
#import "../zugferd/build.typ": (
  build-zugferd-xml, e-invoice-issues, effective-profile,
)
#import "../validation/issue.typ": blocking-classes, enforce, issue
#import "../validation/data.typ": check-data
#import "../theming/frame.typ": render-frame

/// The internal root container that wraps the invoice body.
/// It initializes the global context and provides the base document structure to the theme.
///
/// -> content
#let root(
  /// The content to be rendered within the document structure.
  /// -> content
  body,
) = {
  managed-motif(
    "root",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      nest("sender", {
        // missing values stay `none`: validation reports them, nothing prints a placeholder
        ensure("name", none)
        ensure("address", none)
        ensure("city", none)
        ensure("name-inline", none)
        ensure("address-inline", none)
        ensure("city-inline", none)
        ensure("country", "#sender.country")
        ensure("city-name", "#sender.city-name")
        ensure("post-code", "#sender.post-code")
        ensure("state", none)
        ensure("tax-nr", none)
        ensure("vat-id", none)
        ensure("address-lines", ())

        ensure("extra", ())
        update("extra", x => if type(x) == dictionary { x.pairs() } else { x })
      })

      nest("recipient", {
        // missing values stay `none`: validation reports them, nothing prints a placeholder
        ensure("name", none)
        ensure("address", none)
        ensure("city", none)
        ensure("name-inline", none)
        ensure("address-inline", none)
        ensure("city-inline", none)
        ensure("country", "#recipient.country")
        ensure("city-name", "#recipient.city-name")
        ensure("post-code", "#recipient.post-code")
        ensure("state", none)
        ensure("tax-nr", none)
        ensure("vat-id", none)
        ensure("address-lines", ())

        ensure("extra", ())
        update("extra", x => if type(x) == dictionary { x.pairs() } else { x })
      })

      ensure("invoice-date", datetime.today())
      ensure("subject", "#subject")
      ensure("references", ())
      ensure("invoice-nr", none)
      ensure("validation", (level: none, issues: ()))

      nest("locale", {
        // FIX (lang bug): take the language from the locale strings.
        let lang = ctx
          .locale
          .at("strings", default: (:))
          .at("meta", default: (:))
          .at("lang", default: "en")
        ensure("lang", if lang.len() in (2, 3) { lang } else { "en" })
        nest("meta", {
          ensure("region", "de")
        })
        nest("format", {
          ensure("date", (..) => panic("locale::format::date is not provided"))
        })
      })

      ensure("zugferd", none)

      // Internally Calculated
      nest("global", {
        nest("total", {
          ensure("net", decimal(0))
          ensure("gross", decimal(0))
          ensure("due", decimal(0))
          ensure("prepaid", decimal(0))
        })

        nest("formated-total", {
          ensure("net", "0")
          ensure("gross", "0")
          ensure("due", "0")
          ensure("prepaid", "0")
        })
      })
    }),
    measure: (ctx, children) => {
      let all-line-itmes = loom.query.collect-signals(
        children,
        kind: "line-items",
      )
      assert(
        all-line-itmes.len() <= 1,
        message: "There can only be one `line-items` element in the document!",
      )
      let line-items = all-line-itmes.first(default: (:))

      let bank-signal = loom
        .query
        .collect-signals(
          children,
          kind: "bank-details",
        )
        .first(default: none)

      let all-payment-terms = loom.query.collect-signals(
        children,
        kind: "payment-terms",
      )
      assert(
        all-payment-terms.len() <= 1,
        message: "There can only be one `payment-terms` element in the document!",
      )
      let payment-terms-signal = all-payment-terms.first(default: none)

      let item-data = loom.mutator.batch(
        line-items.at("item-data", default: (:)),
        {
          import loom.mutator: *
          ensure("items", ())
          ensure("taxes", (:))
          ensure("net-total", decimal("0"))
          ensure("gross-total", decimal("0"))
          ensure("unmodified-net-total", decimal("0"))
          ensure("due-total", decimal("0"))
          ensure("prepaid-total", decimal("0"))
          ensure("prepayments", ())
          ensure("discounts", ())
          ensure("surcharges", ())
        },
      )

      let public = (
        total: line-items.at("total", default: (:)),
        formated-total: line-items.at("formated-total", default: (:)),
        bank: bank-signal,
      )

      let view = (
        item-data: item-data,
        payment-terms: payment-terms-signal,
        bank: bank-signal,
        total: line-items.at("total", default: (:)),
        formated-total: line-items.at("formated-total", default: (:)),
      )

      return (public, view)
    },
    draw: (ctx, public, view, body) => {
      let region = ctx.locale.meta.at("region", default: none)
      let region-code = if type(region) == str and region.len() == 2 {
        region
      } else { none }
      set text(lang: ctx.locale.lang, region: region-code)

      let eval-ctx = (
        ctx
          + (
            items: view.item-data.items,
            payment-terms: view.payment-terms,
          )
      )

      import "../public/references.typ" as public-references
      let all-builder-fns = (
        public-references.tax-nr,
        public-references.vat-id,
        public-references.invoice-nr,
        public-references.invoice-date,
        public-references.service-time,
        public-references.customer-nr,
        public-references.buyer-reference,
        public-references.recipient-vat-id,
        public-references.recipient-tax-nr,
        public-references.order-nr,
        public-references.order-date,
        public-references.project,
        public-references.contract-nr,
        public-references.quote-nr,
        public-references.delivery-note-nr,
        public-references.delivery-address,
        public-references.preceding-invoice-nr,
        public-references.due-date,
        public-references.payment-reference,
        public-references.contact-person,
        public-references.contact-phone,
        public-references.contact-email,
      )
      let all-preset-fns = (
        public-references.preset-b2b,
        public-references.preset-b2g,
        public-references.preset-project,
        public-references.preset-din-5008,
      )

      let eval-single-fn(fn) = {
        if fn in all-preset-fns {
          let inner-list = fn()
          inner-list.map(f => eval-single-fn(f))
        } else if fn in all-builder-fns {
          let closure = fn()
          closure(eval-ctx)
        } else {
          fn(eval-ctx)
        }
      }

      let process-raw-refs(raw) = {
        let items = ()
        if type(raw) == function {
          if raw in all-preset-fns {
            items = raw()
          } else {
            items = (raw,)
          }
        } else if type(raw) == array {
          items = raw
        } else if type(raw) == dictionary {
          items = raw.pairs()
        }

        let is-valid-val(v) = {
          v != none and v != "" and v != []
        }

        let flat-refs = ()
        for item in items {
          if type(item) == function {
            let res = eval-single-fn(item)
            if (
              type(res) == array
                and res.len() > 0
                and type(res.first()) == array
                and res.first().len() == 2
            ) {
              for pair in res {
                if pair.len() == 2 and is-valid-val(pair.at(1)) {
                  flat-refs.push(pair)
                }
              }
            } else if type(res) == array and res.len() == 2 {
              if is-valid-val(res.at(1)) {
                flat-refs.push(res)
              }
            }
          } else if (
            type(item) == array
              and item.len() == 2
              and (type(item.first()) == str or type(item.first()) == content)
          ) {
            let (k, v) = item
            if type(v) == function {
              let val = eval-single-fn(v)
              let val-extracted = if type(val) == array and val.len() == 2 {
                val.last()
              } else {
                val
              }
              if is-valid-val(val-extracted) {
                flat-refs.push((k, val-extracted))
              }
            } else {
              if is-valid-val(v) {
                flat-refs.push((k, v))
              }
            }
          } else if type(item) == array {
            for sub-item in process-raw-refs(item) {
              flat-refs.push(sub-item)
            }
          }
        }
        flat-refs
      }

      let normalized-references = process-raw-refs(ctx.references)

      let ctx = (
        ctx
          + (
            references: normalized-references,
            items: view.item-data.items,
            item-data: view.item-data,
            payment-terms: view.payment-terms,
            bank: view.bank,
            global: (
              total: view.total,
              formated-total: view.formated-total,
              bank: view.bank,
            ),
          )
      )

      // Validation: the measured checks join the up-front ones; the level decides.
      let level = ctx.validation.level
      let issues = if level == none { () } else {
        (
          ctx.validation.issues
            + check-data(
              "invoice",
              "measure",
              (
                items: view.item-data.items,
                taxes: view.item-data.taxes.values(),
                recipient: ctx.recipient,
              ),
              region: lower(str(ctx.locale.meta.at("region", default: "de"))),
            )
            + e-invoice-issues(ctx, view.item-data)
            + if view.bank != none
              and not view.bank.at("iban-valid", default: true) {
              // a wrong IBAN makes the invoice unpayable: data class (blocks the XML in
              // draft), no QR code; the renderers print it as given
              (
                issue(
                  "iban",
                  "data",
                  "bank-details::iban `"
                    + view.bank.iban
                    + "` is not a valid IBAN (ISO 13616 check digits)",
                  ref: "EN 16931 BT-84",
                  fix: "bank-details(iban: \"DE89 3704 0044 0532 0130 00\")",
                  key: "iban",
                  args: (iban: view.bank.iban),
                ),
              )
            } else { () }
        )
      }
      let issues = enforce(issues, level)
      // Draft: a machine-readable invoice with missing data is never attached
      // (a receiving system would book it automatically); the badge and the
      // report say that it was withheld. Under `none` no check runs, so the XML
      // is attached whatever it contains ("off means off", documented on invoice()).
      let withheld = (
        ctx.zugferd != none and issues.any(x => x.class in blocking-classes)
      )
      let ctx = (
        ctx
          + (
            validation: ctx.validation
              + (
                issues: issues,
                e-invoice-withheld: withheld,
                e-invoice-profile: if ctx.zugferd != none {
                  effective-profile(ctx)
                },
              ),
          )
      )

      if ctx.zugferd != none and not withheld {
        pdf.attach(
          "/factur-x.xml",
          build-zugferd-xml(
            ctx,
            view.item-data,
            view.payment-terms,
          ),
          relationship: "alternative",
          mime-type: "text/xml",
          description: "ZUGFeRD / Factur-X invoice data",
        )
      }

      // Compliance output lives in core, before and outside any theme code.
      let keywords = ("Invoice",)
      if ctx.zugferd != none and not withheld {
        keywords += ("ZUGFeRD", "Factur-X")
      }
      if issues.len() > 0 { keywords += ("Draft",) }
      let author = ctx.sender.at("name-inline", default: none)
      set document(
        title: ctx.subject,
        author: if type(author) == str { author } else { () },
        date: ctx.invoice-date,
        description: ctx.subject,
        keywords: keywords,
      )
      render-frame(ctx, body)
    },
    body,
  )
}
