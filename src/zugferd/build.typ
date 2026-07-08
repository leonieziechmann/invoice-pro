#import "xml.typ": dict-to-xml, fmt-amount, fmt-date, fmt-rate, xml-escape
#import "../utils/coercion.typ": to-string

#let profile-urn(profile) = {
  if profile == "minimum" { "urn:factur-x.eu:1p0:minimum" } else if (
    profile == "basic-wl"
  ) { "urn:factur-x.eu:1p0:basicwl" } else if profile == "basic" {
    "urn:factur-x.eu:1p0:basic"
  } else { "urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:en16931" }
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
  let address-dict = if include-addresses and address != none {
    let addr = (
      "ram:LineOne": address,
      "ram:CityName": city,
      "ram:CountryID": country,
    )
    if postcode != none and postcode != "" {
      addr.insert("ram:PostcodeCode", postcode)
    }
    (
      "ram:PostalTradeAddress": addr,
    )
  } else { (:) }

  let tax-registrations = ()
  if vat-id != none and vat-id != "" {
    tax-registrations.push((
      "ram:ID": (
        "@schemeID": "VA",
        "": vat-id,
      ),
    ))
  }
  if tax-nr != none and tax-nr != "" {
    tax-registrations.push((
      "ram:ID": (
        "@schemeID": "FC",
        "": tax-nr,
      ),
    ))
  }

  let tax-registration-dict = if tax-registrations.len() > 0 {
    (
      "ram:SpecifiedTaxRegistration": tax-registrations,
    )
  } else { (:) }

  (
    (
      "ram:Name": name,
    )
      + address-dict
      + tax-registration-dict
  )
}

// Emits the buyer trade party details
#let build-buyer-trade-party(
  name,
  address,
  city,
  postcode,
  country,
  tax-nr,
  vat-id,
  include-addresses,
) = {
  let address-dict = if include-addresses and address != none {
    let addr = (
      "ram:LineOne": address,
      "ram:CityName": city,
      "ram:CountryID": country,
    )
    if postcode != none and postcode != "" {
      addr.insert("ram:PostcodeCode", postcode)
    }
    (
      "ram:PostalTradeAddress": addr,
    )
  } else { (:) }

  let tax-registrations = ()
  if vat-id != none and vat-id != "" {
    tax-registrations.push((
      "ram:ID": (
        "@schemeID": "VA",
        "": vat-id,
      ),
    ))
  }
  if tax-nr != none and tax-nr != "" {
    tax-registrations.push((
      "ram:ID": (
        "@schemeID": "FC",
        "": tax-nr,
      ),
    ))
  }

  let tax-registration-dict = if tax-registrations.len() > 0 {
    (
      "ram:SpecifiedTaxRegistration": tax-registrations,
    )
  } else { (:) }

  (
    (
      "ram:Name": name,
    )
      + address-dict
      + tax-registration-dict
  )
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
    let exemption = if tax.at("grounds", default: none) != none {
      ("ram:ExemptionReason": tax.grounds)
    } else { (:) }

    (
      (
        "ram:CalculatedAmount": fmt-amount(tax.absolute),
        "ram:TypeCode": "VAT",
        "ram:BasisAmount": fmt-amount(tax.basis),
        "ram:CategoryCode": tax.category,
        "ram:RateApplicablePercent": fmt-rate(tax.rate),
      )
        + exemption
    )
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

/// Generates a ZUGFeRD 2.x / Factur-X 1.0 CrossIndustryInvoice XML document
/// from the fully-computed invoice context.
///
/// The XML is returned as `bytes` suitable for embedding via `pdf.attach()`.
///
/// -> bytes
#let build-zugferd-xml(ctx, item-data) = {
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

  trade-settlement.insert(
    "ram:SpecifiedTradeSettlementHeaderMonetarySummation",
    build-monetary-summation(net-total, gross-total, total-tax, currency),
  )

  let transaction = (
    "ram:ApplicableHeaderTradeAgreement": (
      "ram:SellerTradeParty": build-seller-trade-party(
        ctx.sender.name-inline,
        ctx.sender.address-inline,
        ctx.sender.city-name,
        ctx.sender.post-code,
        ctx.sender.country.code,
        ctx.sender.tax-nr,
        ctx.sender.vat-id,
        include-addresses,
      ),
      "ram:BuyerTradeParty": build-buyer-trade-party(
        ctx.recipient.name-inline,
        ctx.recipient.address-inline,
        ctx.recipient.city-name,
        ctx.recipient.post-code,
        ctx.recipient.country.code,
        ctx.recipient.tax-nr,
        ctx.recipient.vat-id,
        include-addresses,
      ),
    ),
    "ram:ApplicableHeaderTradeDelivery": (:),
    "ram:ApplicableHeaderTradeSettlement": trade-settlement,
  )

  if line-items != () {
    transaction.insert("ram:IncludedSupplyChainTradeLineItem", line-items)
  }

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
