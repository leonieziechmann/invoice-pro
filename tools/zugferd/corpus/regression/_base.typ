// Shared definitions of the regression cases (not a case itself).
//
// Every case imports this file, states its expectation in the header and
// keeps only what reproduces its finding:
//
//   // expect: <CLASS> [RULE ...]   see tools/zugferd/run.py
//   // finding: <audit finding id or issue>
//   // facts: {<JSON>}              values the XML must carry (oracles.py)

#import "/src/lib.typ": *
#import "/tools/zugferd/harness.typ": harness

#let date = datetime(year: 2026, month: 9, day: 1)

#let contact = (
  name: "Max Muster",
  phone: "+49 30 1234567",
  email: "rechnung@muster.example",
)

#let seller-de = (
  name: "Muster GmbH",
  address: "Hauptstraße 1",
  city: (name: "Berlin", post-code: "10115"),
  country: country.de,
  tax-nr: "30/123/45678",
  vat-id: "DE123456788",
  contact: contact,
)

#let buyer-de = (
  name: "Kunde AG",
  address: "Domstraße 5",
  city: (name: "Köln", post-code: "50667"),
  country: country.de,
  vat-id: "DE987654328",
  email: "eingang@kunde.example",
  buyer-reference: "04011000-12345-34",
)

#let buyer-fr = (
  name: "Client SAS",
  address: "10 Avenue Foch",
  city: (name: "Lyon", post-code: "69001"),
  country: country.fr,
  vat-id: "FR61954506077",
  email: "compta@client.example",
)

#let buyer-at = (
  name: "Kunde GmbH",
  address: "Ringstraße 7",
  city: (name: "Graz", post-code: "8010"),
  country: country.at,
  vat-id: "ATU87654324",
  email: "buchhaltung@kunde.example",
)

#let buyer-us = (
  name: "Acme Inc.",
  address: "350 Fifth Avenue",
  city: (name: "New York", post-code: "10118"),
  country: country.us,
  email: "ap@acme.example",
)

#let bank = bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)

/// The invoice settings every case shares: the harness theme and the
/// "report" mode, so one compilation yields the XML and the diagnostics.
#let setup = (
  theme: harness(themes.blank),
  locale: locale.de-de,
  zugferd-errors: "report",
  date: date,
)
