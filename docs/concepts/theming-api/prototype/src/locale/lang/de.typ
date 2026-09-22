/// German language overrides.
#let resolve-plural(v, n) = {
  if type(v) != dictionary { return v }
  if v.len() == 0 { return none }
  let num = if type(n) == decimal or type(n) == int or type(n) == float {
    float(n)
  } else if type(n) == str {
    float(n)
  } else {
    1.0
  }
  let fallback = v.pairs().first(default: (none, none)).last()
  if num == 1 {
    v.at("singular", default: fallback)
  } else {
    v.at("plural", default: fallback)
  }
}

#let de = (
  meta: (
    lang: "de",
    resolve-plural: resolve-plural,
  ),

  document: (
    invoice: "Rechnung",
    page: (current, total) => [Seite #current von #total],
    continued-on: page => [Fortsetzung auf Seite #page],
  ),

  address: (
    recipient: "Rechnungsempfänger:in",
    sender: "Rechnungssteller:in",
  ),

  sections: (
    details: "Rechnungsdetails",
    payment: "Zahlung",
    bank-details: "Bankverbindung",
    how-to-pay: "So bezahlen Sie",
  ),

  reference: (
    tax-number: "Steuernummer",
    invoice-number: "Rechnungsnummer",
    vat-id: "USt-IdNr.",
    invoice-date: "Rechnungsdatum",
    service-time: "Leistungszeitraum",
    customer-number: "Kundennummer",
    buyer-reference: "Leitweg-ID / Referenz",
    recipient-vat-id: "Empfänger:in USt-IdNr.",
    recipient-tax-number: "Empfänger:in Steuernummer",
    order-number: "Bestellnummer",
    order-date: "Bestelldatum",
    project: "Projekt",
    contract-number: "Vertragsnummer",
    quote-number: "Angebotsnummer",
    delivery-note-number: "Lieferscheinnummer",
    delivery-address: "Lieferadresse",
    preceding-invoice-number: "Vorherige Rechnungsnummer",
    due-date: "Fälligkeitsdatum",
    payment-reference: "Verwendungszweck",
    contact-person: "Ansprechpartner:in",
    contact-phone: "Telefon",
    contact-email: "E-Mail",
  ),

  line-items: (
    position: "Pos.",
    item-id: "Art.-Nr.",
    unit: "Einheit",
    description: "Bezeichnung",
    quantity: "Menge",
    unit-price: "Einzelpreis",
    price: "Preis",
    total: "Gesamtpreis",
    vat: "USt.",
    net: "netto",
    gross: "brutto",
    discount: "Rabatt",
    surcharge: "Zuschlag",
    subtotal: "Zwischensumme",
    prepayment: "Anzahlung",
  ),

  summary: (
    sum: "Summe",
    vat-tax: "Umsatzsteuer",
    total: "Gesamtbetrag",
    including: "inkl.",
    excluding: "zzgl.",
    prepayment: "Anzahlung",
    amount-due: "Fälliger Betrag",
  ),

  global-info: (
    tax-statement: (
      tax-text,
      rate,
      vat-tax,
    ) => [Alle Artikel sind #tax-text #rate #vat-tax.],
    unit: "Einheit für alle Artikel:",
    quantity: "Menge für alle Artikel:",
    date: "Leistungsdatum für alle Artikel:",
  ),

  units: (
    piece: "Stück",
    "set": (singular: "Satz", plural: "Sätze"),
    pair: (singular: "Paar", plural: "Paare"),
    "lump-sum": (singular: "Pauschale", plural: "Pauschalen"),
    hour: (singular: "Stunde", plural: "Stunden"),
    day: (singular: "Tag", plural: "Tage"),
    month: (singular: "Monat", plural: "Monate"),
    year: (singular: "Jahr", plural: "Jahre"),
    kilogram: "Kilogramm",
    gram: "Gramm",
    tonne: (singular: "Tonne", plural: "Tonnen"),
    metre: "Meter",
    "square-metre": "Quadratmeter",
    millimetre: "Millimeter",
    centimetre: "Zentimeter",
    kilometre: "Kilometer",
    litre: "Liter",
    "cubic-metre": "Kubikmeter",
  ),

  bank-details: (
    account-holder: "Kontoinhaber:in",
    bank: "Kreditinstitut",
    iban: "IBAN",
    bic: "BIC",
    reference: "Verwendungszweck",
  ),

  payment: (
    text: (
      sum,
      deadline,
    ) => [Bitte überweisen Sie den Gesamtbetrag in Höhe von *#sum* #deadline auf das unten angegebene Konto.],
    text-due: (
      sum,
      deadline,
    ) => [Bitte überweisen Sie den fälligen Betrag in Höhe von *#sum* #deadline auf das unten angegebene Konto.],

    deadline-date: date => ("bis zum", date).join(" "),
    deadline-days: days => (
      "innerhalb von",
      str(days),
      "Tagen",
    ).join(" "),
    deadline-soon: "sofort nach Erhalt",
  ),

  signature: (
    closing: "Mit freundlichen Grüßen,",
    thanks: "Vielen Dank für Ihren Auftrag.",
  ),

  legal: (
    vat-exemption: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
  ),

  errors: (
    name-missing: "Name fehlt!",
    address-missing: "Adresse fehlt!",
    city-missing: "Stadt fehlt!",
    ambiguous-tax: "Mehrdeutiger Steuersatz von 0 % erkannt.",
    invalid-tax: "Ungültiger Steuersatz erkannt: ",
  ),

  validation: (
    marker: field => [‹fehlt: #field›],
    missing: field => [*Fehlt:* #field],
    part-empty: name => [‹#raw(name) liefert keine Ausgabe›],
    badge: n => (
      "ENTWURF · " + str(n) + if n == 1 { " Problem" } else { " Probleme" }
    ),
    watermark: "ENTWURF",
    e-invoice-short: "keine E-Rechnung",
    report-title: "Prüfbericht",
    report-intro: n => [Dieses Dokument ist *nicht versandfertig*: invoice-pro hat #n #if n == 1 [Problem] else [Probleme] gefunden. Die Markierungen ‹…› zeigen, wo Angaben fehlen. Diese Seite, das Badge und die Markierungen verschwinden, sobald alles vollständig ist.],
    report-strict: [Mit `validation: "strict"` (oder `--input invoice-pro-validation=strict`) bricht die Kompilierung stattdessen bei jedem Problem ab. Empfohlen für den Versand und für CI.],
    e-invoice-withheld: profile => [*Die E-Rechnung (factur-x.xml, Profil #profile) wurde nicht eingebettet*, weil Pflichtangaben fehlen. Ein unvollständiger Datensatz würde beim Empfang automatisch weiterverarbeitet.],
    number: "Nr.",
    problem: "Problem",
    reference: "Rechtsgrundlage",
    fix: "Behebung",
    classes: (
      data: "Pflichtangabe",
      e-invoice: "E-Rechnung",
      theme: "Theme",
      lint: "Prüfung",
    ),
    fields: (
      invoice-number: "Rechnungsnummer",
      sender-name: "Name Rechnungssteller:in",
      sender-address: "Anschrift Rechnungssteller:in",
      sender-tax-id: "USt-IdNr. oder Steuernummer",
      recipient-name: "Name Rechnungsempfänger:in",
      recipient-address: "Anschrift Rechnungsempfänger:in",
      recipient-vat-id: "USt-IdNr. Rechnungsempfänger:in",
      line-items: "Rechnungspositionen",
      buyer-electronic-address: "elektronische Adresse Käufer:in",
      seller-electronic-address: "elektronische Adresse Verkäufer:in",
      buyer-reference: "Käuferreferenz / Leitweg-ID",
      seller-contact-name: "Kontaktperson Verkäufer:in",
      seller-contact-phone: "Telefon Verkäufer:in",
      seller-contact-email: "E-Mail Verkäufer:in",
    ),
    issues: (
      iban: a => [Die IBAN #raw(a.iban) ist ungültig (Prüfziffern nach ISO 13616).],
      part-empty: a => [Der Part #raw(a.part) liefert keine Ausgabe, trägt aber gesetzlich vorgeschriebene Angaben.],
      part-none: a => [Der Part #raw(a.part) trägt gesetzlich vorgeschriebene Angaben und darf nicht `none` sein; stattdessen umhüllen (`wrap`) oder den Renderer ersetzen.],
      role: a => [Das Layout #raw(a.layout) muss #a.parts.map(raw).join[ oder ] in #if a.exactly [genau einem] else [mindestens einem] #if a.tagged [getaggten Bereich (erste Seite oder Textfluss)] else [auf Seite 1 gezeichneten Bereich] platzieren (gefunden: #a.found). Er trägt gesetzlich vorgeschriebene Angaben: #a.why. Das Aussehen lässt sich über den Renderer ändern, die Platzierung muss bleiben.],
      overprint: a => [Der Bereich #raw(a.area) ist auf Folgeseiten fest platziert (#raw("pages: \"" + a.pages + "\"")) und würde dort den Inhalt überdrucken; `pages: "first"` verwenden oder ihn in die Ränder verschieben.],
      window: a => [Der Bereich #raw(a.area) überlappt den Anschriftbereich #raw(a.window); verschieben oder verkleinern, Sichtfenster müssen frei bleiben.],
      qr-bill-paper: a => [Das Layout #raw(a.layout) enthält `qr-bill`; der Zahlteil braucht A4-Hochformat (SIX QR-Rechnung: 210 × 105 mm).],
      envelope: a => [Der Umschlag #raw(a.envelope) nimmt das gefaltete Blatt nicht auf: Falzpaket #str(a.packet-w).replace(".", ",") × #str(a.packet-h).replace(".", ",") mm, Umschlag #str(a.envelope-w).replace(".", ",") × #str(a.envelope-h).replace(".", ",") mm. Papier, `marks.fold` oder `fold` des Umschlags prüfen.],
      fine-size: a => [Das Token `sizes.fine` (#raw(a.size)) muss eine absolute Länge von mindestens 6 pt sein (Minimum nach DIN 5008 für Rücksendeangabe und Pflichtangaben im Fuß).],
      logo-alt: a => [Das Logo-Bild braucht einen Alternativtext, z. B. `image("logo.svg", alt: "ACME GmbH")`. PDF/UA-1 verlangt ihn; geprüft wird immer, weil ein Dokument `--pdf-standard` nicht sehen kann.],
      cmyk: a => [#raw(a.path) ist eine CMYK-Farbe. Typst kann kein CMYK-Ausgabeprofil einbetten, daher lehnt PDF/A-3 (ZUGFeRD) sie ab; `rgb()` oder `oklch()` verwenden.],
      pdf-image-stationery: a => [Das Briefpapier für #raw(a.page) bettet ein PDF-Bild ein. PDF/A- und PDF/UA-Exporte können keine PDF-Bilder einbetten (Einschränkung von Typst); den Briefkopf in SVG umwandeln.],
      pdf-image-logo: a => [Das Logo ist ein PDF-Bild. PDF/A- und PDF/UA-Exporte können keine PDF-Bilder einbetten (Einschränkung von Typst); SVG oder PNG verwenden.],
      contrast: a => [#if a.bg-name == none [Das Farbpaar #raw(a.fg-name)] else [#raw(a.fg-name) auf #raw(a.bg-name)] (#a.fg auf #a.bg) hat einen Kontrast von #str(a.ratio).replace(".", ","):1, unter `checks.min-contrast` #str(a.min).replace(".", ","):1.],
      footer-fit: a => [Der Fuß ist #str(a.need).replace(".", ",") mm hoch, der untere Rand lässt zwischen `footer-descent` und dem #str(a.clearance).replace(".", ",") mm großen `footer-clearance` aber nur #str(a.avail).replace(".", ",") mm. Den berechneten Rand verwenden, `margin.bottom` erhöhen oder den Fuß kürzen.],
      identity: a => [#if a.what == "number" [Die Rechnungsnummer] else [Das Rechnungsdatum] (#a.shown) erscheint nicht im Inhalt der ersten Seite; der Bereich mit `title` muss #raw(if a.what == "number" { "view.document.number" } else { "view.document.date.text" }) ausgeben.],
    ),
    roles: (
      title: "Identität des Dokuments: Rechnungsnummer und -datum",
      recipient: "Name und Anschrift der Rechnungsempfänger:in",
      supplier: "Name und Anschrift der Rechnungssteller:in",
      tax-id: "USt-IdNr. oder Steuernummer der Rechnungssteller:in",
    ),
  ),
)
