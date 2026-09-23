#import "../loom-wrapper.typ": loom, managed-motif
#import "../zugferd/zugferd.typ": process-zugferd
#import "../zugferd/report.typ": format-report, render-zugferd-report

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
        ensure("name", "#sender.name")
        ensure("address", "#sender.address")
        ensure("city", "#sender.city")
        ensure("name-inline", "#sender.name-inline")
        ensure("address-inline", "#sender.address-inline")
        ensure("city-inline", "#sender.city-inline")
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
        ensure("name", "#recipient.name")
        ensure("address", "#recipient.address")
        ensure("city", "#recipient.city")
        ensure("name-inline", "#recipient.name-inline")
        ensure("address-inline", "#recipient.address-inline")
        ensure("city-inline", "#recipient.city-inline")
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
      ensure("invoice-nr", "#invoice-nr")

      nest("locale", {
        ensure("lang", none)
        nest("meta", {
          ensure("region", "de")
        })
        nest("format", {
          ensure("date", (..) => panic("locale::format::date is not provided"))
        })
      })

      ensure("theme", "document", (.., body) => body)
      ensure("zugferd", none)
      ensure("zugferd-errors", "panic")

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

      let all-payment-goals = loom.query.collect-signals(
        children,
        kind: "payment-goal",
      )
      assert(
        all-payment-goals.len() <= 1,
        message: "There can only be one `payment-goal` element in the document!",
      )
      let payment-goal-signal = all-payment-goals.first(default: none)

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
        payment-goal: payment-goal-signal,
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
      // Without a language code, keep the surrounding `text.lang`.
      let lang-args = if ctx.locale.lang != none { (lang: ctx.locale.lang) }
      set text(region: region-code, ..lang-args)

      let eval-ctx = (
        ctx
          + (
            items: view.item-data.items,
            payment-goal: view.payment-goal,
            bank: view.bank,
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
            payment-goal: view.payment-goal,
            bank: view.bank,
            global: (
              total: view.total,
              formated-total: view.formated-total,
              bank: view.bank,
            ),
          )
      )

      let body = body
      if ctx.zugferd != none {
        let result = process-zugferd(
          ctx,
          view.item-data,
          payment-goal: view.payment-goal,
          bank: view.bank,
        )
        let errors = result.diagnostics.filter(d => d.level == "error")
        if errors.len() > 0 and ctx.zugferd-errors == "panic" {
          assert(false, message: format-report(result))
        }

        pdf.attach(
          "/factur-x.xml",
          result.xml,
          // MINIMUM and BASIC WL do not replace the visual invoice, so their
          // XML is attached as data rather than as an alternative of it.
          relationship: if result.profile.id in ("minimum", "basic-wl") {
            "data"
          } else { "alternative" },
          mime-type: "text/xml",
          description: "ZUGFeRD / Factur-X invoice data",
        )

        if ctx.zugferd-errors == "report" and result.diagnostics.len() > 0 {
          let render-report = ctx.theme.at(
            "zugferd-report",
            default: render-zugferd-report,
          )
          // A theme hides the report with `zugferd-report: none`; whatever
          // the hook returns is shown as content.
          if render-report != none {
            assert(
              type(render-report) == function,
              message: "theme::zugferd-report must be `none` or a function `(ctx, result) => content`, got "
                + repr(render-report),
            )
            body = [#render-report(ctx, result)] + body
          }
        }
      }

      (ctx.theme.document)(ctx, body)
    },
    body,
  )
}
