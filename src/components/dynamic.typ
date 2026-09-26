#import "../loom-wrapper.typ": content-motif
#import "../utils/types.typ"
#import "../utils/helper.typ": first-given
#import "../logic/payment-reference.typ": bank-signal, resolve-payment-reference

#let _recipient(ctx, key) = (
  ctx.at("recipient", default: (:)).at(key, default: none)
)

#let _to-content(val) = {
  if val == none {
    none
  } else if type(val) == content {
    val
  } else {
    [#val]
  }
}

// Not a closure in `dynamic`: `info` creates one per value at import.
#let _draw(pos, default, format, ctx, body) = {
  if pos.len() == 0 {
    return _to-content(default)
  }

  // 1. A query closure `ctx => content`
  if type(pos.first()) == function {
    let fn = pos.first()
    let res = fn(ctx)
    if res == none { res = default }
    return _to-content(res)
  }

  // 2. Flatten and normalize path keys
  let keys = ()
  for p in pos {
    if type(p) == array {
      for sub in p { keys.push(str(sub)) }
    } else if type(p) == str and p.contains(".") {
      for sub in p.split(".") { keys.push(sub) }
    } else {
      keys.push(str(p))
    }
  }

  // 3. Top-level keys, with fallbacks
  let val = none
  if keys.len() == 1 {
    let key = keys.first()
    if key == "invoice-nr" {
      val = ctx.at("invoice-nr", default: none)
    } else if key == "invoice-date" or key == "date" {
      val = ctx.at("invoice-date", default: none)
    } else if key == "due-date" {
      val = ctx.at("due-date", default: none)
      if (
        val == none and "payment-goal" in ctx and ctx.payment-goal != none
      ) {
        if ctx.payment-goal.at("date", default: none) != none {
          val = ctx.payment-goal.date
        } else if (
          ctx.payment-goal.at("days", default: none) != none
            and type(ctx.at("invoice-date", default: none)) == datetime
        ) {
          val = ctx.invoice-date + duration(days: ctx.payment-goal.days)
        }
      }
    } else if key == "customer-nr" or key == "customer-id" {
      // Unset parameters of `invoice` are `none`: fall back explicitly.
      val = first-given(
        ctx.at("customer-nr", default: none),
        _recipient(ctx, "customer-nr"),
        _recipient(ctx, "id"),
        _recipient(ctx, "customer-id"),
      )
    } else if key == "order-nr" or key == "po-nr" {
      val = first-given(
        ctx.at("order-nr", default: none),
        _recipient(ctx, "order-nr"),
        ctx.at("po-nr", default: none),
        _recipient(ctx, "po-nr"),
      )
    } else if key == "order-date" {
      val = first-given(
        ctx.at("order-date", default: none),
        _recipient(ctx, "order-date"),
      )
    } else if key == "project" {
      val = first-given(
        ctx.at("project", default: none),
        _recipient(ctx, "project"),
      )
    } else if key == "contract-nr" {
      val = first-given(
        ctx.at("contract-nr", default: none),
        _recipient(ctx, "contract-nr"),
      )
    } else if key == "quote-nr" {
      val = first-given(
        ctx.at("quote-nr", default: none),
        _recipient(ctx, "quote-nr"),
      )
    } else if key == "delivery-note-nr" {
      val = first-given(
        ctx.at("delivery-note-nr", default: none),
        _recipient(ctx, "delivery-note-nr"),
      )
    } else if key == "preceding-invoice-nr" {
      val = first-given(
        ctx.at("preceding-invoice-nr", default: none),
        ctx.at("original-invoice-nr", default: none),
      )
    } else if key == "payment-reference" {
      val = resolve-payment-reference(ctx, bank: bank-signal(ctx))
    } else if key == "buyer-reference" or key == "leitweg-id" {
      val = first-given(
        ctx.at("buyer-reference", default: none),
        _recipient(ctx, "buyer-reference"),
        _recipient(ctx, "leitweg-id"),
      )
    } else if key == "subject" {
      val = ctx.at("subject", default: none)
    } else if key == "tax-nr" {
      val = ctx.sender.at("tax-nr", default: none)
    } else if key == "vat-id" {
      val = ctx.sender.at("vat-id", default: none)
    } else if key == "iban" {
      val = ctx
        .at(
          "bank",
          default: (:),
        )
        .at(
          "iban",
          default: ctx
            .sender
            .at("bank", default: (:))
            .at(
              "iban",
              default: none,
            ),
        )
    } else if key == "bic" {
      val = ctx
        .at(
          "bank",
          default: (:),
        )
        .at(
          "bic",
          default: ctx
            .sender
            .at("bank", default: (:))
            .at(
              "bic",
              default: none,
            ),
        )
    } else if key in ctx {
      val = ctx.at(key)
    }
  } else {
    // Standard path traversal
    val = ctx
    for k in keys {
      if type(val) == dictionary and k in val {
        val = val.at(k)
      } else {
        val = none
        break
      }
    }

    // Fallbacks for nested paths
    if val == none {
      if (
        keys == ("locale", "region", "code")
          or keys == ("locale", "region")
          or keys == ("region", "code")
      ) {
        val = ctx
          .locale
          .at(
            "meta",
            default: (:),
          )
          .at(
            "region",
            default: ctx
              .locale
              .at("region", default: (:))
              .at(
                "meta",
                default: (:),
              )
              .at("region", default: none),
          )
      } else if (
        keys == ("locale", "lang")
          or keys == ("locale", "language")
          or keys == ("lang",)
      ) {
        val = ctx.locale.at(
          "lang",
          default: ctx
            .locale
            .at("meta", default: (:))
            .at(
              "lang",
              default: none,
            ),
        )
      } else if keys == ("bank", "iban") {
        val = ctx
          .at(
            "bank",
            default: (:),
          )
          .at(
            "iban",
            default: ctx
              .sender
              .at("bank", default: (:))
              .at(
                "iban",
                default: none,
              ),
          )
      } else if keys == ("bank", "bic") {
        val = ctx
          .at(
            "bank",
            default: (:),
          )
          .at(
            "bic",
            default: ctx
              .sender
              .at("bank", default: (:))
              .at(
                "bic",
                default: none,
              ),
          )
      } else if keys == ("total", "gross") or keys == ("total", "net") {
        let field = keys.at(1)
        val = ctx
          .at(
            "global",
            default: (:),
          )
          .at(
            "formated-total",
            default: (:),
          )
          .at(field, default: none)
      }
    }
  }

  let res = if val == none { default } else { val }
  if res == none { return none }

  // 4. Custom formatting
  if format != auto {
    if type(format) == function {
      return _to-content(format(res))
    }
  }

  // 5. Default formatting based on type
  if type(res) == datetime {
    if (
      "locale" in ctx and "format" in ctx.locale and "date" in ctx.locale.format
    ) {
      _to-content((ctx.locale.format.date)(res))
    } else {
      _to-content(res.display())
    }
  } else if type(res) == array {
    _to-content(
      res.map(x => if type(x) == content { x } else { [#x] }).join(", "),
    )
  } else if type(res) == dictionary and "id" in res {
    // An identifier of the `id` module.
    _to-content(res.id)
  } else {
    _to-content(res)
  }
}

/// Displays a value of the context (`ctx`) at a path, e.g.
/// `#dynamic("sender", "name")`.
///
/// -> content
#let dynamic(
  /// The path in `ctx`, or a query function `ctx => content`.
  /// -> ..str | function
  ..path,

  /// Shown if the value is missing or `none`.
  /// -> any
  default: none,

  /// A formatter `val => content`; `auto` formats e.g. dates by the locale.
  /// -> auto | function
  format: auto,
) = {
  content-motif(
    draw: _draw.with(path.pos(), default, format),
    body: none,
  )
}
