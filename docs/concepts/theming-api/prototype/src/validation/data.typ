// Document data requirements (class "data"), keyed by document kind like the
// theme requirements. 0.5.0 ships the `invoice` row. The checks read the
// NORMALIZED parties (logic/country.typ), so every input spelling is covered.

#import "issue.typ": issue

#let _blank(v) = v == none or v == "" or v == [] or v == ()

/// Required document fields per kind. `when: "measure"` rows need the computed
/// line items and taxes (checked in root's draw); the others run in invoice().
/// Every row names its locale field label (strings.validation.field.<field>).
#let data-requirements = (
  invoice: (
    (
      id: "invoice-number",
      field: "invoice-number",
      when: "input",
      test: d => _blank(d.invoice-nr),
      message: "invoice::invoice-nr is missing; every invoice needs a unique, sequential number",
      de: "§ 14 Abs. 4 Nr. 4 UStG",
      bt: "BT-1",
      fix: "invoice(invoice-nr: \"2026-0001\")",
    ),
    (
      id: "sender-name",
      field: "sender-name",
      when: "input",
      test: d => _blank(d.sender.name),
      message: "invoice::sender::name is missing; the supplier's full name is required",
      de: "§ 14 Abs. 4 Nr. 1 UStG",
      bt: "BT-27",
      fix: "sender: (name: \"..\")",
    ),
    (
      id: "sender-address",
      field: "sender-address",
      when: "input",
      test: d => _blank(d.sender.address) and _blank(d.sender.city),
      message: "invoice::sender has no address (`address`, `city`); the supplier's full address is required",
      de: "§ 14 Abs. 4 Nr. 1 UStG",
      bt: "BG-5",
      fix: "sender: (address: \"..\", city: \"..\")",
    ),
    (
      id: "sender-tax-id",
      field: "sender-tax-id",
      when: "input",
      test: d => _blank(d.sender.vat-id) and _blank(d.sender.tax-nr),
      message: "invoice::sender has neither `vat-id` nor `tax-nr`; the supplier's VAT ID or tax number is required",
      de: "§ 14 Abs. 4 Nr. 2 UStG",
      bt: "BT-31, BT-32",
      fix: "sender: (vat-id: \"DE..\")  or  sender: (tax-nr: \"..\")",
    ),
    (
      id: "recipient-name",
      field: "recipient-name",
      when: "input",
      test: d => _blank(d.recipient.name),
      message: "invoice::recipient::name is missing; the recipient's full name is required",
      de: "§ 14 Abs. 4 Nr. 1 UStG",
      bt: "BT-44",
      fix: "recipient: (name: \"..\")",
    ),
    (
      id: "recipient-address",
      field: "recipient-address",
      when: "input",
      test: d => _blank(d.recipient.address) and _blank(d.recipient.city),
      message: "invoice::recipient has no address (`address`, `city`); the recipient's full address is required",
      de: "§ 14 Abs. 4 Nr. 1 UStG",
      bt: "BG-8",
      fix: "recipient: (address: \"..\", city: \"..\")",
    ),
    (
      id: "line-items",
      field: "line-items",
      when: "measure",
      test: d => d.items.len() == 0,
      message: "invoice: the document has no line items; an invoice must state the quantity and kind of the supply",
      de: "§ 14 Abs. 4 Nr. 5 UStG",
      bt: "BG-25",
      fix: "#line-items[#item([..], price: ..)]",
    ),
    (
      id: "recipient-vat-id",
      field: "recipient-vat-id",
      when: "measure",
      test: d => (
        d.taxes.any(t => t.category in ("AE", "K"))
          and _blank(d.recipient.vat-id)
      ),
      message: "invoice::recipient::vat-id is missing, but the invoice applies reverse charge or an intra-community supply; the recipient's VAT ID is required",
      de: "§ 14a Abs. 1, 3 UStG",
      bt: "BT-48",
      fix: "recipient: (vat-id: \"..\")",
    ),
  ),
)

/// National invoicing rules outside Germany, cited generically (the German
/// rows cite the exact number). EN 16931 business terms apply everywhere.
#let national-law = (
  at: "§ 11 Abs. 1 Z 3 UStG 1994",
  ch: "Art. 26 Abs. 2 MWSTG",
  fr: "Art. 242 nonies A, annexe II CGI",
  it: "Art. 21 DPR 633/1972",
  es: "Art. 6 RD 1619/2012",
)

/// Legal reference of a row for a region code ("de", "at", ..).
/// -> str
#let reference(row, region) = {
  let law = if region == "de" { row.de } else {
    national-law.at(str(region), default: none)
  }
  (law, "EN 16931 " + row.bt).filter(x => x != none).join("; ")
}

/// Checks the rows of `kind` that run at `when` against `data`.
/// `data` holds invoice-nr, sender, recipient (normalized) and, for "measure",
/// items and taxes.
/// -> array
#let check-data(kind, when, data, region: "de") = {
  data-requirements
    .at(kind, default: ())
    .filter(r => r.when == when)
    .filter(r => (r.test)(data))
    .map(r => issue(
      r.id,
      "data",
      r.message + " (" + reference(r, region) + ")",
      ref: reference(r, region),
      fix: r.fix,
      field: r.field,
    ))
}
