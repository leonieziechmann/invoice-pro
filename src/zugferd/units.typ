// The codes of units given as text, loaded only for an invoice with one.

#import "code-lists.typ": lists
#import "../data/unit.typ": unit-db
#import "../locale/lang/lang.typ" as languages

// The Rec. 20 codes of the units of the `unit` module, by language file key.
#let _unit-codes = (
  piece: "H87",
  "set": "SET",
  pair: "PR",
  "lump-sum": "LS",
  hour: "HUR",
  day: "DAY",
  month: "MON",
  year: "ANN",
  kilogram: "KGM",
  gram: "GRM",
  tonne: "TNE",
  metre: "MTR",
  "square-metre": "MTK",
  millimetre: "MMT",
  centimetre: "CMT",
  kilometre: "KMT",
  litre: "LTR",
  "cubic-metre": "MTQ",
)

/// The codes of unit texts (lower case, no trailing "."): the unit database,
/// the unit names of every language and common abbreviations. Built on the
/// first call (memoized).
///
/// -> dictionary
#let unit-aliases() = {
  let table = (:)
  for (code, texts) in (
    HUR: ("hr", "hrs", "std", "stunde", "stunden"),
    MIN: ("min", "mins", "minute", "minutes", "minuten"),
    SEC: ("s", "sec", "sek", "second", "seconds", "sekunde", "sekunden"),
    WEE: ("wk", "wks", "week", "weeks", "woche", "wochen"),
    MON: ("mon",),
    ANN: ("yr", "yrs"),
    KGM: ("kilo", "kilos"),
    TNE: ("to", "tonnen"),
    MTR: ("meter", "meters", "lfm"),
    MTK: ("m2", "qm", "sqm", "square meter", "square meters"),
    MTQ: ("m3", "cbm", "cubic meter", "cubic meters"),
    LTR: ("ltr", "liter", "liters"),
    MLT: ("ml",),
    KWH: ("kwh",),
    MWH: ("mwh",),
    H87: ("st", "stk", "stck", "pc", "pcs", "pce"),
    LS: ("psch", "pausch", "pauschal", "flat", "flat rate", "lumpsum"),
    IE: ("person", "persons", "pers", "personen"),
    ZP: ("page", "pages", "seite", "seiten"),
    P1: ("%", "percent", "prozent"),
  ).pairs() {
    for text in texts { table.insert(text, code) }
  }
  // Plurals the language files lack, other than the singular with "s".
  for (code, texts) in (
    H87: ("pezzi", "unidades"),
    PR: ("paia", "pares"),
    HUR: ("ore",),
    DAY: ("giorni",),
    MON: ("mesi",),
    ANN: ("anni", "année", "années"),
    KGM: ("chilogrammi",),
    GRM: ("grammi",),
    TNE: ("tonnellate",),
    MTR: ("metri",),
    MTK: ("mètres carrés", "metri quadrati", "metros cuadrados"),
    MMT: ("millimetri",),
    CMT: ("centimetri",),
    KMT: ("chilometri",),
    LTR: ("litri",),
    MTQ: ("mètres cubes", "metri cubi", "metros cúbicos"),
  ).pairs() {
    for text in texts { table.insert(text, code) }
  }
  for unit in unit-db {
    if unit.symbol != none { table.insert(lower(unit.symbol), unit.code) }
    table.insert(lower(unit.name), unit.code)
  }
  for strings in (
    languages.de,
    languages.en,
    languages.fr,
    languages.it,
    languages.es,
  ) {
    for (key, names) in strings.units.pairs() {
      let code = _unit-codes.at(key, default: none)
      if code == none { continue }
      // A name, or its singular and plural.
      let names = if type(names) == dictionary { names.values() } else {
        (names,)
      }
      for name in names { table.insert(lower(name), code) }
    }
  }
  table
}

// Codes that are also German abbreviations: (meaning, abbreviation).
#let _ambiguous-unit-codes = (
  STK: ("stick", "Stück"),
  PAL: ("pascal", "Palette"),
  FL: ("flake ton", "Flasche"),
  GL: ("gram per litre", "Glas"),
  KT: ("kit", "Karton"),
)

/// The code of a unit text as `(code: .., issue: ..)`: a code as it is (with
/// the issue `ambiguous` for e.g. "STK"), the code of a unit name or
/// abbreviation, else "C62" with the issue `unknown`.
///
/// -> dictionary
#let resolve-text-unit(text) = {
  // A code as it is; case-sensitive, so "min" is looked up as a word.
  if (
    not text.contains(" ") and (" " + text + " ") in lists.unit.every
  ) {
    let ambiguous = _ambiguous-unit-codes.at(text, default: none)
    return (
      code: text,
      issue: if ambiguous != none {
        (
          kind: "ambiguous",
          text: text,
          meaning: ambiguous.first(),
          abbreviation: ambiguous.last(),
        )
      },
    )
  }
  let aliases = unit-aliases()
  let key = lower(text).trim(".", at: end)
  let code = aliases.at(key, default: none)
  // A plural with "s" ("heures", "kgs"), but not "ms" for "m".
  if code == none and key.ends-with("s") and key.clusters().len() > 2 {
    code = aliases.at(key.slice(0, -1), default: none)
  }
  if code != none { return (code: code, issue: none) }
  (code: "C62", issue: (kind: "unknown", text: text))
}
