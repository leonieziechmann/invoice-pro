// Serializes the e-invoice data model (see `model.typ`) into a ZUGFeRD 2.x /
// Factur-X 1.0 CrossIndustryInvoice XML document.
//
// Elements are inserted in the order of the Factur-X schemas, and whatever the
// schema of the selected profile does not know is left out.

#import "xml.typ": (
  dict-to-xml, fmt-amount, fmt-date, fmt-price, fmt-quantity, fmt-rate,
  xml-escape,
)
#import "model.typ": (
  build-model, determine-delivery-dates, first-of, get-electronic-address,
  map-unit-code, text-or-none,
)
#import "profile.typ": profile-urn, profiles

#let _date(date) = (
  "udt:DateTimeString": (
    "@format": "102",
    "": fmt-date(date),
  ),
)

// Emits the exchanged document context dictionary
#let build-document-context(profile) = {
  let doc-context = (:)
  if profile.business-process != none {
    doc-context.insert(
      "ram:BusinessProcessSpecifiedDocumentContextParameter",
      ("ram:ID": profile.business-process),
    )
  }
  doc-context.insert(
    "ram:GuidelineSpecifiedDocumentContextParameter",
    ("ram:ID": profile.guideline),
  )
  doc-context
}

// Emits the exchanged document details
#let build-exchanged-document(invoice) = (
  "ram:ID": invoice.number,
  "ram:TypeCode": invoice.type-code,
  "ram:IssueDateTime": _date(invoice.issue-date),
)

// Emits a postal address (BG-5, BG-8, BG-15). ZUGFeRD knows three address
// lines; any further lines are joined into the third one.
#let build-postal-address(address) = {
  let lines = address.at("lines", default: ())
  let postal = (:)
  if address.at("post-code", default: none) != none {
    postal.insert("ram:PostcodeCode", address.post-code)
  }
  if lines.len() > 0 { postal.insert("ram:LineOne", lines.at(0)) }
  if lines.len() > 1 { postal.insert("ram:LineTwo", lines.at(1)) }
  if lines.len() > 2 {
    postal.insert("ram:LineThree", lines.slice(2).join(", "))
  }
  if address.at("city", default: none) != none {
    postal.insert("ram:CityName", address.city)
  }
  postal.insert("ram:CountryID", address.at("country", default: none))
  if address.at("state", default: none) != none {
    postal.insert("ram:CountrySubDivisionName", address.state)
  }
  postal
}

#let _identifiers(party) = {
  let res = (:)
  if party.at("id", default: none) != none {
    res.insert("ram:ID", party.id)
  }
  let global-id = party.at("global-id", default: none)
  if global-id != none {
    res.insert("ram:GlobalID", (
      "@schemeID": global-id.scheme,
      "": global-id.id,
    ))
  }
  res
}

#let _electronic-address(address) = {
  if address == none { return none }
  (
    "ram:URIID": (
      "@schemeID": address.scheme,
      "": address.id,
    ),
  )
}

// Emits the seller trade party details (BG-4)
#let build-seller-trade-party(party, profile) = {
  let res = if profile.party-ids { _identifiers(party) } else { (:) }
  res.insert("ram:Name", party.name)

  let contact = party.contact
  if profile.seller-contact and contact != none {
    let details = (:)
    if contact.name != none {
      details.insert("ram:PersonName", contact.name)
    }
    if contact.phone != none {
      details.insert("ram:TelephoneUniversalCommunication", (
        "ram:CompleteNumber": contact.phone,
      ))
    }
    if contact.email != none {
      details.insert("ram:EmailURIUniversalCommunication", (
        "ram:URIID": contact.email,
      ))
    }
    if details.len() > 0 {
      res.insert("ram:DefinedTradeContact", details)
    }
  }

  if profile.addresses {
    res.insert("ram:PostalTradeAddress", build-postal-address(party.address))
    res.insert(
      "ram:URIUniversalCommunication",
      _electronic-address(party.electronic-address),
    )
  } else if party.address.country != none {
    // MINIMUM has no addresses, but the seller country code is still
    // mandatory (BR-08, BR-09).
    res.insert("ram:PostalTradeAddress", (
      "ram:CountryID": party.address.country,
    ))
  }

  let tax-registrations = ()
  if party.vat-id != none {
    tax-registrations.push(("ram:ID": ("@schemeID": "VA", "": party.vat-id)))
  }
  if party.tax-nr != none {
    tax-registrations.push(("ram:ID": ("@schemeID": "FC", "": party.tax-nr)))
  }
  if tax-registrations.len() > 0 {
    res.insert("ram:SpecifiedTaxRegistration", tax-registrations)
  }
  res
}

// Emits the buyer trade party details (BG-7)
//
// Note: unlike the seller, EN16931 only defines a VAT identifier (BT-48,
// schemeID "VA") for the buyer — there is no buyer equivalent of the
// seller's national tax number (BT-32, schemeID "FC"), so `tax-nr` is
// intentionally not used here.
#let build-buyer-trade-party(party, profile) = {
  let res = if profile.party-ids { _identifiers(party) } else { (:) }
  res.insert("ram:Name", party.name)
  if profile.addresses {
    res.insert("ram:PostalTradeAddress", build-postal-address(party.address))
    res.insert(
      "ram:URIUniversalCommunication",
      _electronic-address(party.electronic-address),
    )
  }
  if profile.buyer-vat-id and party.vat-id != none {
    res.insert("ram:SpecifiedTaxRegistration", (
      "ram:ID": ("@schemeID": "VA", "": party.vat-id),
    ))
  }
  res
}

// Emits the ship-to trade party details (BG-13 Deliver to / BT-70-80)
#let build-ship-to-trade-party(party) = {
  let res = _identifiers(party)
  if party.at("name", default: none) != none {
    res.insert("ram:Name", party.name)
  }
  let address = party.address
  if (
    address.lines.len() > 0
      or address.city != none
      or address.post-code != none
      or address.country != none
  ) {
    res.insert("ram:PostalTradeAddress", build-postal-address(address))
  }
  res
}

// Emits a single ram:SpecifiedTradeAllowanceCharge (discount/surcharge) entry.
//
// `tax-category`/`tax-rate` are mandatory for document-level allowances/charges
// (BR-53), but intentionally omitted at line level, since the line already
// declares its own tax category via its own ApplicableTradeTax.
#let build-allowance-charge(
  is-charge,
  amount,
  reason,
  tax-category: none,
  tax-rate: none,
) = {
  let entry = (
    "ram:ChargeIndicator": (
      "udt:Indicator": if is-charge { "true" } else { "false" },
    ),
    "ram:ActualAmount": fmt-amount(calc.abs(amount)),
  )
  // A reason is mandatory (BR-33, BR-38, BR-42, BR-44).
  entry.insert("ram:Reason", first-of(
    text-or-none(reason),
    if is-charge { "Surcharge" } else { "Discount" },
  ))
  if tax-category != none {
    let category = (
      "ram:TypeCode": "VAT",
      "ram:CategoryCode": tax-category,
    )
    // Amounts not subject to VAT carry no rate (BR-O-06, BR-O-07).
    if tax-category != "O" {
      category.insert("ram:RateApplicablePercent", fmt-rate(tax-rate))
    }
    entry.insert("ram:CategoryTradeTax", category)
  }
  entry
}

// Emits the header-level SpecifiedTradeAllowanceCharge entries for the
// document level allowances and charges, one per VAT category (BR-53).
#let build-header-allowance-charges(entries) = entries.map(
  entry => build-allowance-charge(
    entry.charge,
    entry.amount,
    entry.reason,
    tax-category: entry.category,
    tax-rate: entry.rate,
  ),
)

// Emits a single supply chain line item (BG-25)
#let build-line-item(line, profile) = {
  // Inserted in XSD sequence order (GlobalID, SellerAssignedID,
  // BuyerAssignedID), all before ram:Name. The BASIC profile's TradeProduct
  // only allows GlobalID, so the seller/buyer IDs (BT-155/BT-156) are dropped.
  let product = (:)
  if line.standard-id != none {
    product.insert("ram:GlobalID", (
      "@schemeID": "0160",
      "": line.standard-id,
    ))
  }
  if profile.item-ids {
    if line.seller-id != none {
      product.insert("ram:SellerAssignedID", line.seller-id)
    }
    if line.buyer-id != none {
      product.insert("ram:BuyerAssignedID", line.buyer-id)
    }
  }
  product.insert("ram:Name", line.name)
  if profile.item-description and line.description != none {
    product.insert("ram:Description", line.description)
  }

  // BT-146 is the price of BT-149 units, e.g. a price per 100 pieces.
  let price = ("ram:ChargeAmount": fmt-price(line.price))
  if line.base-quantity != decimal("1") {
    price.insert("ram:BasisQuantity", (
      "@unitCode": line.unit-code,
      "": fmt-quantity(line.base-quantity),
    ))
  }

  let applicable-trade-tax = (
    "ram:TypeCode": "VAT",
    "ram:CategoryCode": line.category,
  )
  // A line not subject to VAT carries no rate (BR-O-05).
  if line.category != "O" {
    applicable-trade-tax.insert(
      "ram:RateApplicablePercent",
      fmt-rate(line.rate),
    )
  }

  let line-settlement = ("ram:ApplicableTradeTax": applicable-trade-tax)
  let line-allowance-charges = (
    line.allowances.map(a => build-allowance-charge(false, a.amount, a.reason))
      + line.charges.map(c => build-allowance-charge(true, c.amount, c.reason))
  )
  if line-allowance-charges != () {
    line-settlement.insert(
      "ram:SpecifiedTradeAllowanceCharge",
      line-allowance-charges,
    )
  }
  line-settlement.insert(
    "ram:SpecifiedTradeSettlementLineMonetarySummation",
    ("ram:LineTotalAmount": fmt-amount(line.net)),
  )

  (
    "ram:AssociatedDocumentLineDocument": (
      "ram:LineID": line.id,
    ),
    "ram:SpecifiedTradeProduct": product,
    "ram:SpecifiedLineTradeAgreement": (
      "ram:NetPriceProductTradePrice": price,
    ),
    "ram:SpecifiedLineTradeDelivery": (
      "ram:BilledQuantity": (
        "@unitCode": line.unit-code,
        "": fmt-quantity(line.quantity),
      ),
    ),
    "ram:SpecifiedLineTradeSettlement": line-settlement,
  )
}

// Emits the payment means block (BG-16)
#let build-payment-means(means, profile) = {
  if means == none {
    return none
  }
  let entry = (
    "ram:TypeCode": means.type-code,
    "ram:PayeePartyCreditorFinancialAccount": (
      "ram:IBANID": means.iban,
    ),
  )
  if profile.bic and means.bic != none {
    entry.insert("ram:PayeeSpecifiedCreditorFinancialInstitution", (
      "ram:BICID": means.bic,
    ))
  }
  entry
}

// Emits the tax breakdown block (BG-23)
#let build-applicable-trade-tax(taxes) = {
  taxes.map(tax => {
    let entry = (
      "ram:CalculatedAmount": fmt-amount(tax.amount),
      "ram:TypeCode": "VAT",
    )
    if tax.reason != none {
      entry.insert("ram:ExemptionReason", tax.reason)
    }
    entry.insert("ram:BasisAmount", fmt-amount(tax.basis))
    entry.insert("ram:CategoryCode", tax.category)
    entry.insert("ram:RateApplicablePercent", fmt-rate(tax.rate))
    entry
  })
}

// Emits the SpecifiedTradePaymentTerms block (BT-9, BT-20), if any data is
// available.
#let build-payment-terms(payment) = {
  let terms = (:)
  if payment.terms != none {
    terms.insert("ram:Description", payment.terms)
  }
  if payment.due-date != none {
    terms.insert("ram:DueDateDateTime", _date(payment.due-date))
  }
  if terms.len() == 0 { none } else { terms }
}

// Emits the header monetary summation block (BG-22).
//
// `line` (BT-106) is the sum of line net amounts *before* document-level
// allowances/charges, while `net` (BT-109) is the total *after* them — they
// only coincide when there are no global discounts/surcharges.
//
// With `include-breakdown: false` (MINIMUM profile) only BT-109, BT-110,
// BT-112 and BT-115 are emitted; the amount due still accounts for prepayments.
#let build-monetary-summation(totals, currency, include-breakdown: true) = {
  let summation = (:)
  if include-breakdown {
    summation.insert("ram:LineTotalAmount", fmt-amount(totals.line))
    if totals.charge != decimal("0") {
      summation.insert("ram:ChargeTotalAmount", fmt-amount(totals.charge))
    }
    if totals.allowance != decimal("0") {
      summation.insert("ram:AllowanceTotalAmount", fmt-amount(totals.allowance))
    }
  }
  summation.insert("ram:TaxBasisTotalAmount", fmt-amount(totals.net))
  summation.insert("ram:TaxTotalAmount", (
    "@currencyID": currency,
    "": fmt-amount(totals.tax),
  ))
  summation.insert("ram:GrandTotalAmount", fmt-amount(totals.gross))
  if include-breakdown and totals.prepaid != decimal("0") {
    summation.insert("ram:TotalPrepaidAmount", fmt-amount(totals.prepaid))
  }
  summation.insert("ram:DuePayableAmount", fmt-amount(totals.due))
  summation
}

/// Serializes an e-invoice data model into the CrossIndustryInvoice XML.
///
/// -> str
#let build-xml(model) = {
  let profile = model.profile
  let invoice = model.invoice
  let payment = model.payment

  let header-agreement = (:)
  if invoice.buyer-reference != none {
    header-agreement.insert("ram:BuyerReference", invoice.buyer-reference)
  }
  header-agreement.insert(
    "ram:SellerTradeParty",
    build-seller-trade-party(model.seller, profile),
  )
  header-agreement.insert(
    "ram:BuyerTradeParty",
    build-buyer-trade-party(model.buyer, profile),
  )
  if invoice.order-nr != none {
    header-agreement.insert("ram:BuyerOrderReferencedDocument", (
      "ram:IssuerAssignedID": invoice.order-nr,
    ))
  }
  if profile.document-references and invoice.contract-nr != none {
    header-agreement.insert("ram:ContractReferencedDocument", (
      "ram:IssuerAssignedID": invoice.contract-nr,
    ))
  }

  let header-delivery = (:)
  if profile.addresses {
    if model.ship-to != none {
      header-delivery.insert(
        "ram:ShipToTradeParty",
        build-ship-to-trade-party(model.ship-to),
      )
    }
    if model.delivery.date != none {
      header-delivery.insert("ram:ActualDeliverySupplyChainEvent", (
        "ram:OccurrenceDateTime": _date(model.delivery.date),
      ))
    }
  }
  if profile.document-references and invoice.despatch-nr != none {
    header-delivery.insert("ram:DespatchAdviceReferencedDocument", (
      "ram:IssuerAssignedID": invoice.despatch-nr,
    ))
  }

  let trade-settlement = (:)
  if profile.settlement {
    // BT-83: same value as printed in the bank details and the EPC-QR code.
    trade-settlement.insert("ram:PaymentReference", payment.reference)
  }
  trade-settlement.insert("ram:InvoiceCurrencyCode", model.currency)
  if profile.settlement {
    trade-settlement.insert(
      "ram:SpecifiedTradeSettlementPaymentMeans",
      build-payment-means(payment.means, profile),
    )
    let applicable-taxes = build-applicable-trade-tax(model.taxes)
    if applicable-taxes != () {
      trade-settlement.insert("ram:ApplicableTradeTax", applicable-taxes)
    }
    let period = model.delivery.period
    if period != none {
      trade-settlement.insert("ram:BillingSpecifiedPeriod", (
        "ram:StartDateTime": _date(period.first()),
        "ram:EndDateTime": _date(period.last()),
      ))
    }
    let header-allowance-charges = build-header-allowance-charges(
      model.allowance-charges,
    )
    if header-allowance-charges != () {
      trade-settlement.insert(
        "ram:SpecifiedTradeAllowanceCharge",
        header-allowance-charges,
      )
    }
    trade-settlement.insert(
      "ram:SpecifiedTradePaymentTerms",
      build-payment-terms(payment),
    )
  }
  trade-settlement.insert(
    "ram:SpecifiedTradeSettlementHeaderMonetarySummation",
    build-monetary-summation(
      model.totals,
      model.currency,
      include-breakdown: profile.settlement,
    ),
  )
  if profile.document-references and invoice.preceding-invoice-nr != none {
    let reference = ("ram:IssuerAssignedID": invoice.preceding-invoice-nr)
    // BT-26: the date of the preceding invoice.
    let date = invoice.at("preceding-invoice-date", default: none)
    if type(date) == datetime {
      reference.insert("ram:FormattedIssueDateTime", (
        "qdt:DateTimeString": ("@format": "102", "": fmt-date(date)),
      ))
    }
    trade-settlement.insert("ram:InvoiceReferencedDocument", reference)
  }

  let transaction = (:)
  if profile.lines and model.lines != () {
    transaction.insert(
      "ram:IncludedSupplyChainTradeLineItem",
      model.lines.map(line => build-line-item(line, profile)),
    )
  }
  transaction.insert("ram:ApplicableHeaderTradeAgreement", header-agreement)
  transaction.insert("ram:ApplicableHeaderTradeDelivery", header-delivery)
  transaction.insert("ram:ApplicableHeaderTradeSettlement", trade-settlement)

  let data = (
    "rsm:CrossIndustryInvoice": (
      "@xmlns:rsm": "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
      "@xmlns:qdt": "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
      "@xmlns:ram": "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
      "@xmlns:udt": "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100",
      "@xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
      "rsm:ExchangedDocumentContext": build-document-context(profile),
      "rsm:ExchangedDocument": build-exchanged-document(invoice),
      "rsm:SupplyChainTradeTransaction": transaction,
    ),
  )

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + dict-to-xml(data)
}

/// Generates a ZUGFeRD 2.x / Factur-X 1.0 CrossIndustryInvoice XML document
/// from the fully-computed invoice context, without validating it.
///
/// The XML is returned as `bytes` suitable for embedding via `pdf.attach()`.
///
/// -> bytes
#let build-zugferd-xml(ctx, item-data, payment-goal, bank: auto) = {
  let bank = if bank == auto {
    ctx.at("global", default: (:)).at("bank", default: none)
  } else { bank }
  let model = build-model(
    ctx,
    item-data,
    payment-goal: payment-goal,
    bank: bank,
  )
  bytes(build-xml(model))
}
