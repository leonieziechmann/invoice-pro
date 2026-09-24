// The strict mode of the write guard (`zugferd-strict: true`, which the CI
// uses): on top of the standard checks, the round trip of every line
// (roundtrip.typ) and an arithmetic of its own over the amounts the XML
// states (concept 4.4), which this module holds. It loads only for an
// invoice in the strict mode.
//
// The arithmetic checks the sums the official rules require of the written
// amounts, with their tolerances, computed from the parsed XML alone:
// BR-CO-10 to BR-CO-17 and the taxable amount of every VAT category
// (BR-S-08, BR-Z-08, BR-E-08, BR-AE-08, BR-IC-08, BR-G-08, BR-O-08,
// BR-AF-08, BR-AG-08; exact for S, O, L and M, within 1 for Z, E, AE, K and
// G), in the profiles whose validators have the rule. A finding names the
// official rule: the XML breaks it as written.

#let _zero = decimal("0")
#let _one = decimal("1")
#let _hundred = decimal("100")
#let _decimal = regex("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)$")

// The profiles with lines, where BR-CO-10 and the rules of the taxable
// amount per VAT category apply, and those with a VAT breakdown (BR-CO-11 to
// BR-CO-17).
#let _lines = ("basic", "en16931", "xrechnung")
#let _settlement = ("basic-wl", "basic", "en16931", "xrechnung")

// The rule of the taxable amount of each VAT category and whether it
// compares per rate (true) and exactly (false: within 1).
#let _basis-rules = (
  S: ("BR-S-08", true, true),
  Z: ("BR-Z-08", false, false),
  E: ("BR-E-08", false, false),
  AE: ("BR-AE-08", false, false),
  K: ("BR-IC-08", false, false),
  G: ("BR-G-08", false, false),
  O: ("BR-O-08", false, true),
  L: ("BR-AF-08", true, true),
  M: ("BR-AG-08", true, true),
)

// The first child element of `node` named `tag`, or `none`.
#let _child(node, tag) = {
  if node == none { return none }
  for child in node.children {
    if type(child) == dictionary and child.tag == tag { return child }
  }
  none
}

// The decimal a leaf states, or `none` (no element or no decimal).
#let _number(node) = {
  if node == none { return none }
  let text = ""
  for child in node.children {
    if type(child) == str { text += child }
  }
  if _decimal in text { decimal(text) } else { none }
}

// The text a leaf states, or `none`.
#let _code(node) = {
  if node == none { return none }
  let text = ""
  for child in node.children {
    if type(child) == str { text += child }
  }
  text
}

// A value rounded to cents as the Schematron does (round(x * 100) div 100,
// half up).
#let _cents(value) = calc.round(value, digits: 2)

// A finding of the arithmetic: the official `rule`, the element `path` it
// is about and the sentence that says what does not add up.
#let _broken(rule, path, text) = (
  kind: "arithmetic",
  rule: rule,
  path: path,
  text: text,
)

// The key of a VAT category and rate in the sums, e.g. "S 19" (per rate)
// or "E" (per category).
#let _key(category, rate, per-rate) = if per-rate and rate != none {
  category + " " + str(rate)
} else { category }

/// The findings of the strict mode for the parsed XML `root` (its root
/// element) of the data model `model` (see the top of this file).
///
/// -> array
#let strict-findings(root, model) = {
  let found = ()
  let profile = model.profile.id
  let transaction = _child(root, "SupplyChainTradeTransaction")
  if transaction == none { return found }
  let settlement = _child(transaction, "ApplicableHeaderTradeSettlement")
  let summation = _child(
    settlement,
    "SpecifiedTradeSettlementHeaderMonetarySummation",
  )
  let prefix = ("rsm:CrossIndustryInvoice", "rsm:SupplyChainTradeTransaction")
  let summary = (
    prefix
      + (
        "ram:ApplicableHeaderTradeSettlement",
        "ram:SpecifiedTradeSettlementHeaderMonetarySummation",
      )
  )

  // --- The lines --------------------------------------------------------
  // The sums of the line net amounts, allowances and charges per VAT
  // category and rate (for BR-x-08), rounded as the rules round them.
  let sums = (:)
  let add(sums, key, kind, value) = {
    let entry = sums.at(key, default: (
      lines: _zero,
      charges: _zero,
      allowances: _zero,
    ))
    entry.insert(kind, entry.at(kind) + value)
    sums.insert(key, entry)
    sums
  }
  let line-total = _zero
  for element in transaction.children {
    if (
      type(element) != dictionary
        or element.tag != "IncludedSupplyChainTradeLineItem"
    ) {
      continue
    }
    let trade = _child(element, "SpecifiedLineTradeSettlement")
    let tax = _child(trade, "ApplicableTradeTax")
    let amount = _number(_child(
      _child(trade, "SpecifiedTradeSettlementLineMonetarySummation"),
      "LineTotalAmount",
    ))
    if amount == none { continue }
    line-total += amount
    let category = _code(_child(tax, "CategoryCode"))
    let rule = _basis-rules.at(
      if category == none { "" } else { category },
      default: none,
    )
    if rule != none {
      let rate = _number(_child(tax, "RateApplicablePercent"))
      sums = add(sums, _key(category, rate, rule.at(1)), "lines", amount)
    }
  }

  if profile not in _settlement or summation == none { return found }

  // --- The document level allowances and charges and the VAT breakdown ----
  let allowance-total = _zero
  let charge-total = _zero
  let allowances = false
  let charges = false
  let breakdowns = ()
  let tax-total = _zero
  for element in settlement.children {
    if type(element) != dictionary { continue }
    if element.tag == "SpecifiedTradeAllowanceCharge" {
      let charge = _code(_child(
        _child(element, "ChargeIndicator"),
        "Indicator",
      ))
      let amount = _number(_child(element, "ActualAmount"))
      if amount == none { continue }
      let is-charge = charge != none and charge.trim() == "true"
      if is-charge {
        charges = true
        charge-total += amount
      } else {
        allowances = true
        allowance-total += amount
      }
      let tax = _child(element, "CategoryTradeTax")
      let category = _code(_child(tax, "CategoryCode"))
      let rule = _basis-rules.at(
        if category == none { "" } else { category },
        default: none,
      )
      if rule != none {
        let rate = _number(_child(tax, "RateApplicablePercent"))
        sums = add(
          sums,
          _key(category, rate, rule.at(1)),
          if is-charge { "charges" } else { "allowances" },
          amount,
        )
      }
    } else if element.tag == "ApplicableTradeTax" {
      let amount = _number(_child(element, "CalculatedAmount"))
      if amount != none { tax-total += amount }
      breakdowns.push((
        amount: amount,
        basis: _number(_child(element, "BasisAmount")),
        category: _code(_child(element, "CategoryCode")),
        rate: _number(_child(element, "RateApplicablePercent")),
        vat: _code(_child(element, "TypeCode")) == "VAT",
      ))
    }
  }

  // --- The totals (BG-22) ---------------------------------------------------
  let total(tag) = _number(_child(summation, tag))
  let line = total("LineTotalAmount")
  let allowance = total("AllowanceTotalAmount")
  let charge = total("ChargeTotalAmount")
  let net = total("TaxBasisTotalAmount")
  let tax = total("TaxTotalAmount")
  let gross = total("GrandTotalAmount")
  let prepaid = total("TotalPrepaidAmount")
  let due = total("DuePayableAmount")
  let text(value) = if value == none { "(none)" } else { str(value) }

  if profile in _lines and line != none and line != _cents(line-total) {
    found.push(_broken(
      "BR-CO-10",
      summary + ("ram:LineTotalAmount",),
      "The sum of the line net amounts (BT-106) is "
        + text(line)
        + ", but the lines add up to "
        + str(_cents(line-total))
        + ".",
    ))
  }
  if (
    (allowances or allowance != none) and allowance != _cents(allowance-total)
  ) {
    found.push(_broken(
      "BR-CO-11",
      summary + ("ram:AllowanceTotalAmount",),
      "The sum of the allowances (BT-107) is "
        + text(allowance)
        + ", but the allowances add up to "
        + str(_cents(allowance-total))
        + ".",
    ))
  }
  if (charges or charge != none) and charge != _cents(charge-total) {
    found.push(_broken(
      "BR-CO-12",
      summary + ("ram:ChargeTotalAmount",),
      "The sum of the charges (BT-108) is "
        + text(charge)
        + ", but the charges add up to "
        + str(_cents(charge-total))
        + ".",
    ))
  }
  let basis = (
    if line == none { _zero } else { line }
      - if allowance == none { _zero } else { allowance }
      + if charge == none { _zero } else { charge }
  )
  if net != _cents(basis) {
    found.push(_broken(
      "BR-CO-13",
      summary + ("ram:TaxBasisTotalAmount",),
      "The total without VAT (BT-109) is "
        + text(net)
        + ", but the line net amounts minus the allowances plus the charges are "
        + str(_cents(basis))
        + ".",
    ))
  }
  if tax != _cents(tax-total) {
    found.push(_broken(
      "BR-CO-14",
      summary + ("ram:TaxTotalAmount",),
      "The VAT total (BT-110) is "
        + text(tax)
        + ", but the VAT amounts of the breakdown add up to "
        + str(_cents(tax-total))
        + ".",
    ))
  }
  if net != none and tax != none and gross != _cents(net + tax) {
    found.push(_broken(
      "BR-CO-15",
      summary + ("ram:GrandTotalAmount",),
      "The total with VAT (BT-112) is "
        + text(gross)
        + ", but the total without VAT plus the VAT total is "
        + str(_cents(net + tax))
        + ".",
    ))
  }
  if gross != none {
    let expected = gross - if prepaid == none { _zero } else { prepaid }
    if due != expected {
      found.push(_broken(
        "BR-CO-16",
        summary + ("ram:DuePayableAmount",),
        "The amount due (BT-115) is "
          + text(due)
          + ", but the total with VAT minus the paid amount is "
          + str(expected)
          + ".",
      ))
    }
  }

  // --- Every VAT breakdown (BG-23) -----------------------------------------
  let i = 0
  for breakdown in breakdowns {
    i += 1
    let here = (
      prefix
        + (
          "ram:ApplicableHeaderTradeSettlement",
          "ram:ApplicableTradeTax[" + str(i) + "]",
        )
    )
    let amount = breakdown.amount
    let rate = breakdown.rate
    let basis = breakdown.basis
    // BR-CO-17: the VAT amount is the taxable amount times the rate, within
    // 1; a rate of 0 (rounded) has a VAT amount of 0 (rounded).
    if breakdown.vat and amount != none {
      let ok = if rate == none or calc.round(rate) == _zero {
        calc.round(amount) == _zero
      } else if basis == none { false } else {
        let expected = _cents(calc.abs(basis) * rate / _hundred)
        (
          calc.abs(amount) - _one <= expected
            and calc.abs(amount) + _one >= expected
        )
      }
      if not ok {
        found.push(_broken(
          "BR-CO-17",
          here + ("ram:CalculatedAmount",),
          "The VAT amount (BT-117) "
            + text(amount)
            + " is not the taxable amount "
            + text(basis)
            + " times the rate "
            + text(rate)
            + " %, within 1.",
        ))
      }
    }
    // BR-x-08: the taxable amount is the sum of the lines, charges and
    // allowances of the category (and rate).
    let category = breakdown.category
    let rule = _basis-rules.at(
      if category == none { "" } else { category },
      default: none,
    )
    if rule == none or profile not in _lines or basis == none { continue }
    let (id, per-rate, exact) = rule
    let entry = sums.at(_key(category, rate, per-rate), default: (
      lines: _zero,
      charges: _zero,
      allowances: _zero,
    ))
    let sum = (
      _cents(entry.lines) + _cents(entry.charges) - _cents(entry.allowances)
    )
    let ok = if exact { basis == sum } else {
      basis - _one < sum and sum < basis + _one
    }
    if not ok {
      found.push(_broken(
        id,
        here + ("ram:BasisAmount",),
        "The taxable amount (BT-116) of the VAT category "
          + category
          + if per-rate { " at " + text(rate) + " %" } else { "" }
          + " is "
          + str(basis)
          + ", but its lines, charges and allowances add up to "
          + str(sum)
          + if exact { "." } else { ", beyond the tolerance of 1." },
      ))
    }
  }
  found
}
