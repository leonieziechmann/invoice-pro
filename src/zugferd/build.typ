#import "xml.typ": fmt-amount, fmt-date, fmt-rate, xml-escape

#let profile-urn(profile) = {
  if profile == "minimum" { "urn:factur-x.eu:1p0:minimum" } else if (
    profile == "basic-wl"
  ) { "urn:factur-x.eu:1p0:basicwl" } else if profile == "basic" {
    "urn:factur-x.eu:1p0:basic"
  } else { "urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:en16931" }
}

// Map common invoice-pro unit strings to UN/ECE recommendation 20 unit codes.
#let map-unit-code(unit) = {
  let u = if type(unit) == str { unit } else if unit == none { "" } else {
    str(unit)
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

#let build-line-item(item, pos) = {
  let unit-code = map-unit-code(item.unit)

  let item-id-xml = (
    (
      () => {
        let id = item.at("item-id", default: none)
        if id == none { return }
        if type(id) != dictionary { return }

        return {
          if "standard" in id {
            (
              "        <ram:GlobalID schemeID=\"0160\">"
                + xml-escape(id.standard)
                + "</ram:GlobalID>\n"
            )
          }

          if "seller" in id {
            (
              "        <ram:SellerAssignedID>"
                + xml-escape(id.seller)
                + "</ram:SellerAssignedID>\n"
            )
          }
        }
      }
    )()
      + ""
  )

  (
    "    <ram:IncludedSupplyChainTradeLineItem>\n"
      + "      <ram:AssociatedDocumentLineDocument>\n"
      + "        <ram:LineID>"
      + str(pos)
      + "</ram:LineID>\n"
      + "      </ram:AssociatedDocumentLineDocument>\n"
      + "      <ram:SpecifiedTradeProduct>\n"
      + "        <ram:Name>"
      + xml-escape(item.name)
      + "</ram:Name>\n"
      + item-id-xml
      + "      </ram:SpecifiedTradeProduct>\n"
      + "      <ram:SpecifiedLineTradeAgreement>\n"
      + "        <ram:NetPriceProductTradePrice>\n"
      + "          <ram:ChargeAmount>"
      + fmt-amount(item.price)
      + "</ram:ChargeAmount>\n"
      + "        </ram:NetPriceProductTradePrice>\n"
      + "      </ram:SpecifiedLineTradeAgreement>\n"
      + "      <ram:SpecifiedLineTradeDelivery>\n"
      + "        <ram:BilledQuantity unitCode=\""
      + unit-code
      + "\">"
      + fmt-amount(item.quantity)
      + "</ram:BilledQuantity>\n"
      + "      </ram:SpecifiedLineTradeDelivery>\n"
      + "      <ram:SpecifiedLineTradeSettlement>\n"
      + "        <ram:ApplicableTradeTax>\n"
      + "          <ram:TypeCode>VAT</ram:TypeCode>\n"
      + "          <ram:CategoryCode>"
      + xml-escape(item.tax.category)
      + "</ram:CategoryCode>\n"
      + "          <ram:RateApplicablePercent>"
      + fmt-rate(item.tax.rate)
      + "</ram:RateApplicablePercent>\n"
      + "        </ram:ApplicableTradeTax>\n"
      + "        <ram:SpecifiedTradeSettlementLineMonetarySummation>\n"
      + "          <ram:LineTotalAmount>"
      + fmt-amount(item.total)
      + "</ram:LineTotalAmount>\n"
      + "        </ram:SpecifiedTradeSettlementLineMonetarySummation>\n"
      + "      </ram:SpecifiedLineTradeSettlement>\n"
      + "    </ram:IncludedSupplyChainTradeLineItem>\n"
  )
}

/// Generates a ZUGFeRD 2.x / Factur-X 1.0 CrossIndustryInvoice XML document
/// from the fully-computed invoice context.
///
/// The XML is returned as `bytes` suitable for embedding via `pdf.attach()`.
///
/// -> bytes
#let build-zugferd-xml(ctx, item-data) = {
  let profile = ctx.zugferd
  let currency = ctx.locale.currency.code
  let country = upper(ctx.locale.meta.region)

  let bank = ctx.global.at("bank", default: none)

  let items = item-data.items
  let taxes = item-data.taxes
  let net-total = item-data.net-total
  let gross-total = item-data.gross-total

  let include-line-items = profile in ("basic", "en16931")
  let include-addresses = profile != "minimum"

  // Line items block
  let line-items-xml = if include-line-items {
    items.enumerate().map(((i, item)) => build-line-item(item, i + 1)).join("")
  } else { "" }

  // Tax breakdown blocks (one per tax bracket)
  let total-tax = taxes.values().map(t => t.absolute).sum(default: decimal("0"))
  let tax-xml = taxes
    .values()
    .map(tax => {
      let exemption-xml = if tax.at("grounds", default: none) != none {
        (
          "      <ram:ExemptionReason>"
            + xml-escape(tax.grounds)
            + "</ram:ExemptionReason>\n"
        )
      } else { "" }
      (
        "    <ram:ApplicableTradeTax>\n"
          + "      <ram:CalculatedAmount>"
          + fmt-amount(tax.absolute)
          + "</ram:CalculatedAmount>\n"
          + "      <ram:TypeCode>VAT</ram:TypeCode>\n"
          + exemption-xml
          + "      <ram:BasisAmount>"
          + fmt-amount(tax.basis)
          + "</ram:BasisAmount>\n"
          + "      <ram:CategoryCode>"
          + xml-escape(tax.category)
          + "</ram:CategoryCode>\n"
          + "      <ram:RateApplicablePercent>"
          + fmt-rate(tax.rate)
          + "</ram:RateApplicablePercent>\n"
          + "    </ram:ApplicableTradeTax>\n"
      )
    })
    .join("")

  // Payment means block (SEPA credit transfer = type code 58)
  let payment-xml = if bank != none and bank.iban != "" {
    let bic-xml = if bank.bic != "" {
      (
        "      <ram:PayeeSpecifiedCreditorFinancialInstitution>\n"
          + "        <ram:BICID>"
          + xml-escape(bank.bic)
          + "</ram:BICID>\n"
          + "      </ram:PayeeSpecifiedCreditorFinancialInstitution>\n"
      )
    } else { "" }
    (
      "    <ram:SpecifiedTradeSettlementPaymentMeans>\n"
        + "      <ram:TypeCode>58</ram:TypeCode>\n"
        + "      <ram:PayeePartyCreditorFinancialAccount>\n"
        + "        <ram:IBANID>"
        + xml-escape(bank.iban)
        + "</ram:IBANID>\n"
        + "      </ram:PayeePartyCreditorFinancialAccount>\n"
        + bic-xml
        + "    </ram:SpecifiedTradeSettlementPaymentMeans>\n"
    )
  } else { "" }

  // Seller postal address (omitted in minimum profile)
  let seller-address-xml = if include-addresses {
    (
      "        <ram:PostalTradeAddress>\n"
        + "          <ram:LineOne>"
        + xml-escape(ctx.sender.address)
        + "</ram:LineOne>\n"
        + "          <ram:CityName>"
        + xml-escape(ctx.sender.city)
        + "</ram:CityName>\n"
        + "          <ram:CountryID>"
        + country
        + "</ram:CountryID>\n"
        + "        </ram:PostalTradeAddress>\n"
    )
  } else { "" }

  let tax-nr-xml = if ctx.tax-nr != none {
    (
      "        <ram:SpecifiedTaxRegistration>\n"
        + "          <ram:ID schemeID=\"VA\">"
        + xml-escape(ctx.tax-nr)
        + "</ram:ID>\n"
        + "        </ram:SpecifiedTaxRegistration>\n"
    )
  } else { "" }

  let invoice-nr-str = if ctx.invoice-nr != none {
    xml-escape(ctx.invoice-nr)
  } else { "" }

  let xml = (
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      + "<rsm:CrossIndustryInvoice"
      + " xmlns:rsm=\"urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100\""
      + " xmlns:qdt=\"urn:un:unece:uncefact:data:standard:QualifiedDataType:100\""
      + " xmlns:ram=\"urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100\""
      + " xmlns:udt=\"urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100\""
      + " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n"
      + "  <rsm:ExchangedDocumentContext>\n"
      + "    <ram:GuidelineSpecifiedDocumentContextParameter>\n"
      + "      <ram:ID>"
      + profile-urn(profile)
      + "</ram:ID>\n"
      + "    </ram:GuidelineSpecifiedDocumentContextParameter>\n"
      + "  </rsm:ExchangedDocumentContext>\n"
      + "  <rsm:ExchangedDocument>\n"
      + "    <ram:ID>"
      + invoice-nr-str
      + "</ram:ID>\n"
      + "    <ram:TypeCode>380</ram:TypeCode>\n"
      + "    <ram:IssueDateTime>\n"
      + "      <udt:DateTimeString format=\"102\">"
      + fmt-date(ctx.invoice-date)
      + "</udt:DateTimeString>\n"
      + "    </ram:IssueDateTime>\n"
      + "  </rsm:ExchangedDocument>\n"
      + "  <rsm:SupplyChainTradeTransaction>\n"
      + line-items-xml
      + "    <ram:ApplicableHeaderTradeAgreement>\n"
      + "      <ram:SellerTradeParty>\n"
      + "        <ram:Name>"
      + xml-escape(ctx.sender.name)
      + "</ram:Name>\n"
      + seller-address-xml
      + tax-nr-xml
      + "      </ram:SellerTradeParty>\n"
      + "      <ram:BuyerTradeParty>\n"
      + "        <ram:Name>"
      + xml-escape(ctx.recipient.name)
      + "</ram:Name>\n"
      + "      </ram:BuyerTradeParty>\n"
      + "    </ram:ApplicableHeaderTradeAgreement>\n"
      + "    <ram:ApplicableHeaderTradeDelivery/>\n"
      + "    <ram:ApplicableHeaderTradeSettlement>\n"
      + "      <ram:PaymentReference>"
      + invoice-nr-str
      + "</ram:PaymentReference>\n"
      + "      <ram:InvoiceCurrencyCode>"
      + currency
      + "</ram:InvoiceCurrencyCode>\n"
      + payment-xml
      + tax-xml
      + "      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n"
      + "        <ram:LineTotalAmount>"
      + fmt-amount(net-total)
      + "</ram:LineTotalAmount>\n"
      + "        <ram:TaxBasisTotalAmount>"
      + fmt-amount(net-total)
      + "</ram:TaxBasisTotalAmount>\n"
      + "        <ram:TaxTotalAmount currencyID=\""
      + currency
      + "\">"
      + fmt-amount(total-tax)
      + "</ram:TaxTotalAmount>\n"
      + "        <ram:GrandTotalAmount>"
      + fmt-amount(gross-total)
      + "</ram:GrandTotalAmount>\n"
      + "        <ram:DuePayableAmount>"
      + fmt-amount(gross-total)
      + "</ram:DuePayableAmount>\n"
      + "      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n"
      + "    </ram:ApplicableHeaderTradeSettlement>\n"
      + "  </rsm:SupplyChainTradeTransaction>\n"
      + "</rsm:CrossIndustryInvoice>"
  )

  bytes(xml)
}
