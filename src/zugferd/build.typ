#import "xml.typ": dict-to-xml, fmt-amount, fmt-date, fmt-rate, xml-escape
#import "../utils/coercion.typ": to-string

#let profile-urn(profile) = {
  if profile == "minimum" { "urn:factur-x.eu:1p0:minimum" } else if (
    profile == "basic-wl"
  ) { "urn:factur-x.eu:1p0:basicwl" } else if profile == "basic" {
    "urn:factur-x.eu:1p0:basic"
  } else { "urn:cen.eu:en16931:2017" }
}

// Map common invoice-pro unit strings to UN/ECE recommendation 20 unit codes.
#let map-unit-code(unit) = {
  if type(unit) == dictionary and "code" in unit {
    return unit.code
  }
  let u = if type(unit) == str { unit } else if unit == none { "" } else {
    to-string(unit)
  }
  if u in ("HUR", "DAY", "MON", "ANN", "KGM", "GRM", "MTR", "LTR", "C62") {
    u
  } else if u in ("hrs", "hr", "h", "Std.", "Stunden") { "HUR" } else if (
    u in ("day", "days", "Tag", "Tage")
  ) { "DAY" } else if u in ("month", "months", "Monat", "Monate") {
    "MON"
  } else if u in ("year", "years", "Jahr", "Jahre") { "ANN" } else if (
    u in ("kg",)
  ) { "KGM" } else if u in ("g", "gram") { "GRM" } else if u in ("m", "meter") {
    "MTR"
  } else if u in ("l", "liter") { "LTR" } else { "C62" }
}

// Emits the exchanged document context dictionary
#let build-document-context(profile) = (
  "ram:GuidelineSpecifiedDocumentContextParameter": (
    "ram:ID": profile-urn(profile),
  ),
)

// Emits the exchanged document details
#let build-exchanged-document(invoice-nr, invoice-date) = (
  "ram:ID": if invoice-nr != none { invoice-nr } else { "" },
  "ram:TypeCode": "380",
  "ram:IssueDateTime": (
    "udt:DateTimeString": (
      "@format": "102",
      "": fmt-date(invoice-date),
    ),
  ),
)

// Emits the seller trade party details
#let build-seller-trade-party(
  name,
  address,
  city,
  postcode,
  country,
  tax-nr,
  vat-id,
  include-addresses,
) = {
  let tax-registrations = {
    if vat-id != none and vat-id != "" {
      (
        (
          "ram:ID": (
            "@schemeID": "VA",
            "": vat-id,
          ),
        ),
      )
    }
    if tax-nr != none and tax-nr != "" {
      (
        (
          "ram:ID": (
            "@schemeID": "FC",
            "": tax-nr,
          ),
        ),
      )
    }
  }

  ("ram:Name": name)
  if include-addresses and address != none and address != () {
    (
      "ram:PostalTradeAddress": {
        if postcode != none and postcode != "" {
          ("ram:PostcodeCode": postcode)
        }
        if type(address) == array {
          if address.len() > 0 { ("ram:LineOne": address.at(0)) }
          if address.len() > 1 { ("ram:LineTwo": address.at(1)) }
          if address.len() > 2 {
            ("ram:LineThree": address.slice(2).join(", "))
          }
        } else {
          ("ram:LineOne": address)
        }
        ("ram:CityName": city)
        ("ram:CountryID": country)
      },
    )
  }
  if tax-registrations.len() > 0 {
    (
      "ram:SpecifiedTaxRegistration": tax-registrations,
    )
  }
}

// Emits the buyer trade party details
//
// Note: unlike the seller, EN16931 only defines a VAT identifier (BT-48,
// schemeID "VA") for the buyer — there is no buyer equivalent of the
// seller's national tax number (BT-32, schemeID "FC"), so `tax-nr` is
// intentionally not used here.
#let build-buyer-trade-party(
  name,
  address,
  city,
  postcode,
  country,
  vat-id,
  include-addresses,
) = {
  ("ram:Name": name)
  if include-addresses and address != none and address != () {
    (
      "ram:PostalTradeAddress": {
        if postcode != none and postcode != "" {
          ("ram:PostcodeCode": postcode)
        }
        if type(address) == array {
          if address.len() > 0 { ("ram:LineOne": address.at(0)) }
          if address.len() > 1 { ("ram:LineTwo": address.at(1)) }
          if address.len() > 2 {
            ("ram:LineThree": address.slice(2).join(", "))
          }
        } else {
          ("ram:LineOne": address)
        }
        ("ram:CityName": city)
        ("ram:CountryID": country)
      },
    )
  }
  if vat-id != none and vat-id != "" {
    (
      "ram:SpecifiedTaxRegistration": (
        "ram:ID": (
          "@schemeID": "VA",
          "": vat-id,
        ),
      ),
    )
  }
}

// Emits a single supply chain line item
#let build-line-item(
  pos,
  name,
  item-id,
  price,
  quantity,
  unit,
  tax-category,
  tax-rate,
  total,
) = {
  let unit-code = map-unit-code(unit)

  let item-ids = (:)
  if type(item-id) == dictionary {
    if "standard" in item-id and item-id.standard != none {
      item-ids.insert("ram:GlobalID", (
        "@schemeID": "0160",
        "": item-id.standard,
      ))
    }
    if "seller" in item-id and item-id.seller != none {
      item-ids.insert("ram:SellerAssignedID", item-id.seller)
    }
  }

  (
    "ram:AssociatedDocumentLineDocument": (
      "ram:LineID": str(pos),
    ),
    "ram:SpecifiedTradeProduct": (
      "ram:Name": name,
    )
      + item-ids,
    "ram:SpecifiedLineTradeAgreement": (
      "ram:NetPriceProductTradePrice": (
        "ram:ChargeAmount": fmt-amount(price),
      ),
    ),
    "ram:SpecifiedLineTradeDelivery": (
      "ram:BilledQuantity": (
        "@unitCode": unit-code,
        "": fmt-amount(quantity),
      ),
    ),
    "ram:SpecifiedLineTradeSettlement": (
      "ram:ApplicableTradeTax": (
        "ram:TypeCode": "VAT",
        "ram:CategoryCode": tax-category,
        "ram:RateApplicablePercent": fmt-rate(tax-rate),
      ),
      "ram:SpecifiedTradeSettlementLineMonetarySummation": (
        "ram:LineTotalAmount": fmt-amount(total),
      ),
    ),
  )
}

// Emits the payment means block
#let build-payment-means(bank-iban, bank-bic) = {
  if bank-iban == none or bank-iban == "" {
    return none
  }

  let bic = if bank-bic != none and bank-bic != "" {
    (
      "ram:PayeeSpecifiedCreditorFinancialInstitution": (
        "ram:BICID": bank-bic,
      ),
    )
  } else { (:) }

  (
    (
      "ram:TypeCode": "58",
      "ram:PayeePartyCreditorFinancialAccount": (
        "ram:IBANID": bank-iban,
      ),
    )
      + bic
  )
}

// Emits the tax breakdown block
#let build-applicable-trade-tax(tax-list) = {
  tax-list.map(tax => {
    let entry = (
      "ram:CalculatedAmount": fmt-amount(tax.absolute),
      "ram:TypeCode": "VAT",
    )
    if tax.at("grounds", default: none) != none {
      entry.insert("ram:ExemptionReason", tax.grounds)
    }
    entry.insert("ram:BasisAmount", fmt-amount(tax.basis))
    entry.insert("ram:CategoryCode", tax.category)
    entry.insert("ram:RateApplicablePercent", fmt-rate(tax.rate))
    entry
  })
}

// Emits the header monetary summation block
#let build-monetary-summation(net-total, gross-total, total-tax, currency) = (
  "ram:LineTotalAmount": fmt-amount(net-total),
  "ram:TaxBasisTotalAmount": fmt-amount(net-total),
  "ram:TaxTotalAmount": (
    "@currencyID": currency,
    "": fmt-amount(total-tax),
  ),
  "ram:GrandTotalAmount": fmt-amount(gross-total),
  "ram:DuePayableAmount": fmt-amount(gross-total),
)

// Emits the SpecifiedTradePaymentTerms block from a `payment-goal` signal
// (see `components/payment-goal.typ`), if any data is available.
#let build-payment-terms(payment-goal, invoice-date) = {
  if payment-goal == none {
    return none
  }

  let due-date = if type(payment-goal.date) == datetime {
    payment-goal.date
  } else if payment-goal.days != none {
    invoice-date + duration(days: payment-goal.days)
  } else { none }

  if due-date != none {
    return (
      "ram:DueDateDateTime": (
        "udt:DateTimeString": (
          "@format": "102",
          "": fmt-date(due-date),
        ),
      ),
    )
  }

  if payment-goal.date != none {
    let description = to-string(payment-goal.date)
    if description != "" {
      return ("ram:Description": description)
    }
  }

  none
}

/// Generates a ZUGFeRD 2.x / Factur-X 1.0 CrossIndustryInvoice XML document
/// from the fully-computed invoice context.
///
/// The XML is returned as `bytes` suitable for embedding via `pdf.attach()`.
///
/// -> bytes
#let build-zugferd-xml(ctx, item-data, payment-goal) = {
  let profile = ctx.zugferd
  let currency = ctx.locale.currency.code
  let country = ctx.sender.country.code

  let bank = ctx.global.at("bank", default: none)

  let items = item-data.items
  let taxes = item-data.taxes
  let net-total = item-data.net-total
  let gross-total = item-data.gross-total

  let include-line-items = profile in ("basic", "en16931")
  let include-addresses = profile != "minimum"

  let total-tax = taxes.values().map(t => t.absolute).sum(default: decimal("0"))
  let invoice-nr-str = if ctx.invoice-nr != none { ctx.invoice-nr } else { "" }

  let line-items = if include-line-items {
    items
      .enumerate()
      .map(((i, item)) => {
        build-line-item(
          i + 1,
          item.name,
          item.at("item-id", default: none),
          item.price,
          item.quantity,
          item.unit,
          item.tax.category,
          item.tax.rate,
          item.total,
        )
      })
  } else { () }

  let trade-settlement = (
    "ram:PaymentReference": invoice-nr-str,
    "ram:InvoiceCurrencyCode": currency,
  )

  let bank-iban = if bank != none { bank.iban } else { "" }
  let bank-bic = if bank != none { bank.bic } else { "" }
  let payment-means = build-payment-means(bank-iban, bank-bic)
  if payment-means != none {
    trade-settlement.insert(
      "ram:SpecifiedTradeSettlementPaymentMeans",
      payment-means,
    )
  }

  let applicable-taxes = build-applicable-trade-tax(taxes.values())
  if applicable-taxes != () {
    trade-settlement.insert("ram:ApplicableTradeTax", applicable-taxes)
  }

  let payment-terms = build-payment-terms(payment-goal, ctx.invoice-date)
  if payment-terms != none {
    trade-settlement.insert("ram:SpecifiedTradePaymentTerms", payment-terms)
  }

  trade-settlement.insert(
    "ram:SpecifiedTradeSettlementHeaderMonetarySummation",
    build-monetary-summation(net-total, gross-total, total-tax, currency),
  )

  let transaction = (:)
  if line-items != () {
    transaction.insert("ram:IncludedSupplyChainTradeLineItem", line-items)
  }
  transaction.insert("ram:ApplicableHeaderTradeAgreement", (
    "ram:SellerTradeParty": build-seller-trade-party(
      ctx.sender.name-inline,
      ctx.sender.address-lines,
      ctx.sender.city-name,
      ctx.sender.post-code,
      ctx.sender.country.code,
      ctx.sender.tax-nr,
      ctx.sender.vat-id,
      include-addresses,
    ),
    "ram:BuyerTradeParty": build-buyer-trade-party(
      ctx.recipient.name-inline,
      ctx.recipient.address-lines,
      ctx.recipient.city-name,
      ctx.recipient.post-code,
      ctx.recipient.country.code,
      ctx.recipient.vat-id,
      include-addresses,
    ),
  ))
  transaction.insert("ram:ApplicableHeaderTradeDelivery", (:))
  transaction.insert("ram:ApplicableHeaderTradeSettlement", trade-settlement)

  let data = (
    "rsm:CrossIndustryInvoice": (
      "@xmlns:rsm": "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
      "@xmlns:qdt": "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
      "@xmlns:ram": "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
      "@xmlns:udt": "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100",
      "@xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
      "rsm:ExchangedDocumentContext": build-document-context(profile),
      "rsm:ExchangedDocument": build-exchanged-document(
        ctx.invoice-nr,
        ctx.invoice-date,
      ),
      "rsm:SupplyChainTradeTransaction": transaction,
    ),
  )

  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + dict-to-xml(data)
  bytes(xml)
}
