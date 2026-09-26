// The Factur-X 1.0.07 (ZUGFeRD 2.3) profiles and what each schema allows.

#let _base = (
  // BT-23
  business-process: none,
  // BG-25
  lines: false,
  // BG-5, BG-8, BG-15 (beyond the seller country), BT-34, BT-49, BG-13
  addresses: false,
  // BG-16, BG-20, BG-21, BG-23, BT-20, BT-83
  settlement: false,
  // BT-29, BT-46
  party-ids: false,
  // BT-48
  buyer-vat-id: false,
  // BG-6
  seller-contact: false,
  // BT-28 (BT-30 and BT-47 are in every profile)
  seller-trading-name: false,
  // BT-33
  seller-legal-info: false,
  // BT-45
  buyer-trading-name: false,
  // BG-9
  buyer-contact: false,
  // BG-10
  payee: false,
  // BG-11
  tax-representative: false,
  // BT-86
  bic: false,
  // BT-85
  account-name: false,
  // BG-18; else a card payment states only its code (BT-81).
  payment-card: false,
  // BT-155, BT-156
  item-ids: false,
  // BT-154
  item-description: false,
  // BT-12, BT-16, BT-25
  document-references: false,
  // BT-21, BT-22
  notes: false,
  // BT-11
  procuring-project: false,
  // BT-159
  item-origin: false,
  // BR-*
  en16931: false,
  // BR-DE-*, on top of EN 16931
  xrechnung: false,
  // "xrechnung.xml" for XRechnung (ZUGFeRD 2.3)
  file-name: "factur-x.xml",
)

#let profiles = (
  minimum: _base
    + (
      name: "MINIMUM",
      guideline: "urn:factur-x.eu:1p0:minimum",
    ),
  basic-wl: _base
    + (
      name: "BASIC WL",
      guideline: "urn:factur-x.eu:1p0:basicwl",
      addresses: true,
      settlement: true,
      party-ids: true,
      buyer-vat-id: true,
      seller-trading-name: true,
      payee: true,
      tax-representative: true,
      document-references: true,
      notes: true,
    ),
  // A CIUS of EN 16931, hence the EN 16931 prefix.
  basic: _base
    + (
      name: "BASIC",
      guideline: "urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic",
      lines: true,
      addresses: true,
      settlement: true,
      party-ids: true,
      buyer-vat-id: true,
      seller-trading-name: true,
      payee: true,
      tax-representative: true,
      document-references: true,
      notes: true,
      en16931: true,
    ),
  en16931: _base
    + (
      name: "EN 16931 (COMFORT)",
      guideline: "urn:cen.eu:en16931:2017",
      business-process: "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0",
      lines: true,
      addresses: true,
      settlement: true,
      party-ids: true,
      buyer-vat-id: true,
      seller-contact: true,
      seller-trading-name: true,
      seller-legal-info: true,
      buyer-trading-name: true,
      buyer-contact: true,
      payee: true,
      tax-representative: true,
      bic: true,
      account-name: true,
      payment-card: true,
      item-ids: true,
      item-description: true,
      procuring-project: true,
      item-origin: true,
      document-references: true,
      notes: true,
      en16931: true,
    ),
  xrechnung: _base
    + (
      name: "XRechnung 3.0",
      guideline: "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0",
      business-process: "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0",
      lines: true,
      addresses: true,
      settlement: true,
      party-ids: true,
      buyer-vat-id: true,
      seller-contact: true,
      seller-trading-name: true,
      seller-legal-info: true,
      buyer-trading-name: true,
      buyer-contact: true,
      payee: true,
      tax-representative: true,
      bic: true,
      account-name: true,
      payment-card: true,
      item-ids: true,
      item-description: true,
      procuring-project: true,
      item-origin: true,
      document-references: true,
      notes: true,
      en16931: true,
      xrechnung: true,
      file-name: "xrechnung.xml",
    ),
)

/// Resolves the profile of the XML. `auto` lists the candidates, best first:
/// `"xrechnung"` for a buyer in Germany, then `"en16931"`.
///
/// -> dictionary
#let resolve-profile(requested, buyer-country) = {
  let automatic = requested == auto
  let candidates = if not automatic { (requested,) } else if (
    buyer-country == "DE"
  ) { ("xrechnung", "en16931") } else { ("en16931",) }
  (
    id: candidates.first(),
    requested: requested,
    automatic: automatic,
    candidates: candidates,
    skipped: (),
    ..profiles.at(candidates.first(), default: profiles.en16931),
  )
}

/// A resolved profile switched to another of its candidates.
///
/// -> dictionary
#let switch-profile(profile, id) = profile + profiles.at(id) + (id: id)
