// Payment means besides `bank-details`: direct debit, card, paid (BG-16).

#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../utils/text.typ": plain-text
#import "../utils/iban.typ": format-iban, iban-valid, normalize-iban
#import "../utils/creditor-id.typ": creditor-id-valid, normalize-creditor-id
#import "../logic/payment-means.typ": (
  card-code, direct-debit-code, method-kind, method-kinds, of-context,
  report-problems, transfer-code,
)
#import "../logic/document-type.typ": sender-pays
#import "../logic/currency.typ": currency-code

#let _scope(ctx) = loom.mutator.batch(ctx, {
  import loom.mutator: *

  nest("theme", {
    ensure("payment-means", (..) => panic(
      "theme::payment-means is not provided",
    ))
  })

  nest("global", {
    nest("total", {
      ensure("gross", 0)
      ensure("prepaid", 0)
    })
  })
})

#let _draw(ctx, _, view, ..) = (ctx.theme.payment-means)(ctx, view)

#let _is-missing(value) = value in (none, "", [])

#let _require-buyer-pays(ctx, name) = {
  if sender-pays(ctx.at("document-type", default: none)) {
    panic(
      name
        + ": a credit note or a self-billed invoice is paid by its sender, so the amount cannot be collected from the recipient. Use `bank-details` with the recipient's account or `paid`.",
    )
  }
}

/// Collects the amount by SEPA direct debit (BT-81 = 59, BG-19).
///
/// -> content
#let direct-debit(
  /// The reference of the SEPA mandate (BT-89). Required.
  /// -> str | content
  mandate: none,

  /// Your SEPA creditor identifier (BT-90). Required.
  /// -> str | content
  creditor-id: none,

  /// The IBAN of the debited account (BT-91).
  /// -> none | str | content
  debtor-iban: none,
) = {
  types.require(mandate, "direct-debit::mandate", none, str, content)
  types.require(creditor-id, "direct-debit::creditor-id", none, str, content)
  types.require(debtor-iban, "direct-debit::debtor-iban", none, str, content)
  assert(
    not _is-missing(mandate),
    message: "direct-debit: the mandate reference is missing. Set `mandate` to the reference of the SEPA direct debit mandate the buyer signed.",
  )
  assert(
    not _is-missing(creditor-id),
    message: "direct-debit: the creditor identifier is missing. Set `creditor-id` to your SEPA creditor identifier, e.g. \"DE98ZZZ09999999999\".",
  )

  managed-motif(
    "direct-debit",
    scope: _scope,
    measure: (ctx, _) => {
      // Inside the line items, it would be printed but not stated.
      let _ = loom.guards.assert-not-inside(ctx, "line-items")
      _require-buyer-pays(ctx, "direct-debit")
      let strings = ctx.locale.strings.payment-means
      // SEPA (euro) creditor identifiers have check digits.
      let sepa = currency-code(ctx.locale) == "EUR"
      let creditor = normalize-creditor-id(creditor-id)
      let creditor-valid = not sepa or creditor-id-valid(creditor)
      let iban = if not _is-missing(debtor-iban) {
        normalize-iban(debtor-iban)
      }
      let valid-iban = iban == none or iban-valid(iban)

      let report = report-problems(ctx)
      if not report and not creditor-valid {
        panic(
          "direct-debit: the creditor identifier \""
            + creditor
            + "\" is not a valid SEPA creditor identifier (wrong check digits or format). Check it for typos.",
        )
      }
      if not report and not valid-iban {
        panic(
          "direct-debit: the IBAN \""
            + format-iban(iban)
            + "\" of `debtor-iban` is not valid (wrong check digits or format). Check it for typos.",
        )
      }

      let details = (
        (
          label: strings.method,
          value: if sepa { strings.sepa-direct-debit } else {
            strings.direct-debit
          },
        ),
        (label: strings.mandate, value: mandate),
        (label: strings.creditor-id, value: creditor, valid: creditor-valid),
      )
      if iban != none {
        details.push((
          label: strings.debtor-iban,
          value: format-iban(iban),
          valid: valid-iban,
        ))
      }

      let public = (
        mandate: mandate,
        creditor-id: creditor,
        debtor-iban: iban,
      )
      (public, (kind: "direct-debit", text: none, details: details))
    },
    draw: _draw,
    none,
  )
}

/// States that the amount is paid with a card (BT-81 = 48, 54, 55, BG-18).
///
/// -> content
#let card-payment(
  /// The last 4 (at most 6) digits of the card number (BT-87, BR-51). Required.
  /// -> str | content
  last4: none,

  /// The name of the card holder (BT-88).
  /// -> none | str | content
  holder: none,

  /// The kind of card: `"credit"` (BT-81 = 54), `"debit"` (55) or `auto` (48).
  /// -> auto | "credit" | "debit"
  kind: auto,
) = {
  types.require(last4, "card-payment::last4", none, str, content)
  types.require(holder, "card-payment::holder", none, str, content)
  types.require(kind, "card-payment::kind", auto, "credit", "debit")
  let digits = plain-text(last4).replace(" ", "")
  let only-digits = true
  for char in digits.clusters() {
    if char not in "0123456789" { only-digits = false }
  }
  assert(
    only-digits and digits.len() >= 4 and digits.len() <= 6,
    message: "card-payment: `last4` must be the last 4 digits of the card number (at most 6), e.g. \"1234\", got "
      + repr(last4)
      + ". An invoice must never show the full card number.",
  )

  managed-motif(
    "card-payment",
    scope: _scope,
    measure: (ctx, _) => {
      let _ = loom.guards.assert-not-inside(ctx, "line-items")
      _require-buyer-pays(ctx, "card-payment")
      let strings = ctx.locale.strings.payment-means
      let details = (
        (
          label: strings.method,
          value: if kind == "credit" { strings.credit-card } else if (
            kind == "debit"
          ) { strings.debit-card } else { strings.card },
        ),
        (label: strings.card-number, value: "**** " + digits),
      )
      if not _is-missing(holder) {
        details.push((label: strings.card-holder, value: holder))
      }
      let public = (
        last4: digits,
        holder: if not _is-missing(holder) { holder },
        kind: kind,
      )
      (public, (kind: "card", text: none, details: details))
    },
    draw: _draw,
    none,
  )
}

// The methods of `paid` and their keys in the language strings.
#let _method-names = (
  cash: "cash",
  cheque: "cheque",
  online: "online",
  transfer: "transfer",
  card: "card",
)

/// States that the invoice is paid already (BT-113, BT-115 = 0).
///
/// -> content
#let paid(
  /// How it was paid: `"cash"`, `"card"`, `"transfer"`, `"direct-debit"`,
  /// `"cheque"`, `"online"`, or `(code: .., name: ..)` (BT-81).
  /// -> auto | str | dictionary
  method: auto,

  /// The date of the payment.
  /// -> none | datetime | str | content
  date: none,
) = {
  types.require(
    method,
    "paid::method",
    auto,
    ..method-kinds.keys(),
    (code: str, name: types.text-like),
  )
  types.require(date, "paid::date", none, datetime, str, content)
  types.require-day(date, "paid::date")

  managed-motif(
    "paid",
    scope: _scope,
    measure: (ctx, _) => {
      let _ = loom.guards.assert-not-inside(ctx, "line-items")
      let strings = ctx.locale.strings
      let names = strings.payment-means
      let format = ctx.locale.format
      let total = ctx.global.total
      let currency = currency-code(ctx.locale)
      let has-prepayments = total.prepaid > 0
      let amount = total.at("due", default: total.gross)
      let sentence = if sender-pays(ctx.at("document-type", default: none)) {
        names.paid-credit
      } else if has-prepayments { names.paid-due } else { names.paid }
      let text = sentence(
        (format.currency)(amount),
        if type(date) == datetime { (format.date)(date) } else { date },
      )

      // A code of its own must be the component's: one per invoice (BT-81).
      let kind = method-kind(method)
      let means = of-context(ctx)
      if type(method) == dictionary and means != none {
        let (component, stated, hint) = if (
          kind == "card" and means.card != none
        ) {
          (
            "card-payment",
            card-code(means.card.at("kind", default: auto)),
            "Set the kind of the card on `card-payment` (`kind: \"credit\"` for 54, `kind: \"debit\"` for 55, `auto` for 48) and use a `method` of that code, or leave out `method`.",
          )
        } else if kind == "direct-debit" and means.direct-debit != none {
          (
            "direct-debit",
            direct-debit-code(currency),
            "A direct debit is stated as 59 (SEPA direct debit) in euro and as 49 otherwise: use `method: \"direct-debit\"`, or leave out `method`.",
          )
        } else if kind == "transfer" and means.transfers.len() > 0 {
          (
            "bank-details",
            transfer-code(currency),
            "A credit transfer is stated as 58 (SEPA credit transfer) in euro and as 30 otherwise: use `method: \"transfer\"`, or leave out `method`.",
          )
        } else { (none, none, none) }
        if stated != none and stated != method.code {
          panic(
            "paid: `method` names the payment means code \""
              + method.code
              + "\", but the `"
              + component
              + "` of the invoice states the code \""
              + stated
              + "\". An invoice states one payment means code (BT-81). "
              + hint,
          )
        }
      }

      // The method, unless the details of the direct debit or card print it.
      let detailed = (
        means != none
          and type(method) != dictionary
          and (
            (kind == "direct-debit" and means.direct-debit != none)
              or (kind == "card" and means.card != none)
          )
      )
      let method-name = if detailed or method == auto { none } else if (
        type(method) == dictionary
      ) { method.name } else if method == "direct-debit" {
        if currency == "EUR" { names.sepa-direct-debit } else {
          names.direct-debit
        }
      } else { names.at(_method-names.at(method)) }

      // The sentence and the method are the payment terms (BT-20).
      let lines = (text,)
      let details = ()
      if method-name != none {
        details.push((label: names.method, value: method-name))
        lines.push([#names.method: #method-name])
      }
      details.push((
        label: strings.summary.amount-due,
        value: (format.currency)(0),
      ))

      let public = (method: method, kind: kind, date: date, terms: lines)
      (public, (kind: "paid", text: text, details: details))
    },
    draw: _draw,
    none,
  )
}
