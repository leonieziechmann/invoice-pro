// Countries of the parties: the ISO 3166-1 alpha-2 code, the printed name and
// how the city line (post code and city name) is parsed and printed.

#import "../utils/text.typ": plain-text

// --- Parsers and formatters ---

// Functions, so that a pattern is only compiled when a party needs it.
#let _euro-city-pattern() = regex("^\\s*(?:[A-Z]{1,2}-)?(\\d{4,5})\\s+(.+)$")
#let _uk-city-pattern() = regex(
  "(?i)^\\s*(.+?)(?:,\\s*|\\s+|\\n)\\s*([a-z]{1,2}\\d[a-z\\d]?\\s*\\d[a-z]{2})\\s*$",
)
#let _us-city-patterns() = (
  with-state: regex(
    "(?i)^\\s*(.+?)(?:,\\s*|\\s+)([a-z]{2})\\s+(\\d{5}(?:-\\d{4})?)\\s*$",
  ),
  without-state: regex("(?i)^\\s*(.+?)(?:,\\s*|\\s+)(\\d{5}(?:-\\d{4})?)\\s*$"),
)

#let _unparsed-city(city-str) = (name: city-str.trim(), post-code: none)

// "10115 Berlin", "D-10115 Berlin"
#let parse-city-euro(city-str) = {
  let m = city-str.match(_euro-city-pattern())
  if m != none {
    let pc-raw = m.captures.at(0, default: none)
    let name-raw = m.captures.at(1, default: none)
    (
      name: if name-raw != none { name-raw.trim() } else { "" },
      post-code: if pc-raw != none { pc-raw.trim() } else { none },
    )
  } else {
    _unparsed-city(city-str)
  }
}

/// A parser of city lines with a post code matching `pattern` (without
/// anchors or groups) `"before"`, `"after"` or on `"either"` side of the name.
/// Markers (`prefixes`, "D-10115") are dropped unless `keep-prefix`.
///
/// -> function
#let post-code-parser(
  pattern,
  position: "before",
  prefixes: (),
  keep-prefix: false,
  ignore-case: false,
) = {
  let flags = if ignore-case { "(?i)" } else { "" }
  let prefix = if prefixes.len() == 0 { "()" } else {
    "(?:(" + prefixes.join("|") + ")-)?"
  }
  let before = regex(
    flags + "^" + prefix + "(" + pattern + ")\\s+(.+)$",
  )
  let after = regex(
    flags + "^(.+?)(?:,\\s*|\\s+)" + prefix + "(" + pattern + ")$",
  )
  let result(name, marker, code) = {
    let code = if ignore-case { upper(code) } else { code }
    (
      name: name.trim(),
      post-code: if keep-prefix and marker not in (none, "") {
        marker + "-" + code
      } else { code },
    )
  }

  city-str => {
    let city-str = city-str.trim()
    if position in ("before", "either") {
      let m = city-str.match(before)
      if m != none {
        let (marker, code, name) = m.captures
        return result(name, marker, code)
      }
    }
    if position in ("after", "either") {
      let m = city-str.match(after)
      if m != none {
        let (name, marker, code) = m.captures
        return result(name, marker, code)
      }
    }
    _unparsed-city(city-str)
  }
}

// "10115 Berlin"
#let format-city-euro(parsed-city) = {
  if parsed-city == none { return none }
  let parts = ()
  if parsed-city.at("post-code", default: none) != none {
    parts.push(parsed-city.post-code)
  }
  if parsed-city.at("name", default: none) != none {
    parts.push(parsed-city.name)
  }
  parts.join(" ")
}

// "Valletta VLT 1117"
#let format-city-trailing(parsed-city) = {
  if parsed-city == none { return none }
  let parts = ()
  if parsed-city.at("name", default: none) != none {
    parts.push(parsed-city.name)
  }
  if parsed-city.at("post-code", default: none) != none {
    parts.push(parsed-city.post-code)
  }
  parts.join(" ")
}

#let parse-city-uk(city-str) = {
  let m = city-str.match(_uk-city-pattern())
  if m != none {
    let name-raw = m.captures.at(0, default: none)
    let pc-raw = m.captures.at(1, default: none)
    (
      name: if name-raw != none { name-raw.trim() } else { "" },
      post-code: if pc-raw != none { upper(pc-raw).trim() } else { none },
    )
  } else {
    _unparsed-city(city-str)
  }
}

// "London \ SW1A 2AA" (two lines)
#let format-city-uk(parsed-city) = {
  if parsed-city == none { return none }
  let lines = ()
  if parsed-city.at("name", default: none) != none {
    lines.push(parsed-city.name)
  }
  if parsed-city.at("post-code", default: none) != none {
    lines.push(parsed-city.post-code)
  }
  lines.join([ \ ])
}

#let format-inline-city-uk(parsed-city) = {
  if parsed-city == none { return none }
  let parts = ()
  if parsed-city.at("name", default: none) != none {
    parts.push(parsed-city.name)
  }
  if parsed-city.at("post-code", default: none) != none {
    parts.push(parsed-city.post-code)
  }
  parts.join(", ")
}

#let parse-city-us(city-str) = {
  let patterns = _us-city-patterns()
  let m1 = city-str.match(patterns.with-state)
  if m1 != none {
    let name-raw = m1.captures.at(0, default: none)
    let state-raw = m1.captures.at(1, default: none)
    let pc-raw = m1.captures.at(2, default: none)
    (
      name: if name-raw != none { name-raw.trim() } else { "" },
      state: if state-raw != none { upper(state-raw) } else { none },
      post-code: if pc-raw != none { pc-raw.trim() } else { none },
    )
  } else {
    let m2 = city-str.match(patterns.without-state)
    if m2 != none {
      let name-raw = m2.captures.at(0, default: none)
      let pc-raw = m2.captures.at(1, default: none)
      (
        name: if name-raw != none { name-raw.trim() } else { "" },
        state: none,
        post-code: if pc-raw != none { pc-raw.trim() } else { none },
      )
    } else {
      (
        name: city-str.trim(),
        state: none,
        post-code: none,
      )
    }
  }
}

#let format-city-us(parsed-city) = {
  if parsed-city == none { return none }
  let city-state = ()
  if parsed-city.at("name", default: none) != none {
    city-state.push(parsed-city.name)
  }
  if parsed-city.at("state", default: none) != none {
    city-state.push(parsed-city.state)
  }
  let city-state-str = city-state.join(", ")

  let parts = ()
  if city-state-str != "" { parts.push(city-state-str) }
  if parsed-city.at("post-code", default: none) != none {
    parts.push(parsed-city.post-code)
  }
  parts.join(" ")
}

// --- Country builder ---

#let make-country(
  name: "",
  code: "",
  show-always: false,
  format-city: format-city-euro,
  format-inline-city: format-city-euro,
  parse-city-raw: parse-city-euro,
) = {
  let parse-city(city) = {
    if city == none or city == "" or city == () {
      none
    } else if type(city) == dictionary {
      let result = (
        name: city.at("name", default: none),
        post-code: city.at("post-code", default: none),
      )
      for (k, v) in city {
        result.insert(k, v)
      }
      result
    } else {
      // Content ([#plz #ort], [10115 *Berlin*]) is parsed as the text it shows.
      let text = plain-text(city)
      if text == "" { none } else { parse-city-raw(text) }
    }
  }

  (
    name: name,
    code: code,
    show-always: show-always,
    parse-city: parse-city,
    format-address: (name, address, city, country-name: none) => {
      let lines = ()
      if name != none and name != () and name != "" {
        lines.push(if type(name) == array { name.join([ \ ]) } else { name })
      }
      if address != none and address != () and address != "" {
        lines.push(if type(address) == array { address.join([ \ ]) } else {
          address
        })
      }

      let parsed-city = parse-city(city)
      let formatted-city = if parsed-city == none {
        none
      } else if "display" in parsed-city {
        parsed-city.display
      } else {
        format-city(parsed-city)
      }

      if formatted-city != none and formatted-city != "" {
        lines.push(formatted-city)
      }
      if country-name != none and country-name != "" {
        lines.push(country-name)
      }
      lines.join([ \ ])
    },
    format-inline: (name, address, city, country-name: none) => {
      let parts = ()
      if name != none and name != () and name != "" {
        parts.push(if type(name) == array { name.join(", ") } else { name })
      }
      if address != none and address != () and address != "" {
        parts.push(if type(address) == array { address.join(", ") } else {
          address
        })
      }

      let parsed-city = parse-city(city)
      let formatted-city = if parsed-city == none {
        none
      } else if "inline-display" in parsed-city {
        parsed-city.inline-display
      } else if "display" in parsed-city {
        parsed-city.display
      } else {
        format-inline-city(parsed-city)
      }

      if formatted-city != none and formatted-city != "" {
        parts.push(formatted-city)
      }
      if country-name != none and country-name != "" {
        parts.push(country-name)
      }
      parts.join(", ")
    },
  )
}

#let _code-pattern = regex("^[A-Za-z]{2}$")

// The upper-case ISO 3166-1 alpha-2 code of `code` (string or content), with
// "UK" as "GB"; `field` names the input in the error message.
#let normalize-code(code, field) = {
  let text = if type(code) in (str, content) { plain-text(code) } else { none }
  if text == none or text.match(_code-pattern) == none {
    panic(
      "`"
        + field
        + "`: "
        + repr(code)
        + " is not an ISO 3166-1 alpha-2 country code (two letters such as \"DE\" or \"FR\").",
    )
  }
  let code = upper(text)
  if code == "UK" { "GB" } else { code }
}

#let _regex-syntax = (
  "\\": true,
  ".": true,
  "+": true,
  "*": true,
  "?": true,
  "(": true,
  ")": true,
  "|": true,
  "[": true,
  "]": true,
  "{": true,
  "}": true,
  "^": true,
  "$": true,
  "#": true,
  "&": true,
  "~": true,
  "-": true,
)

#let _mask-pattern(mask) = {
  let pattern = ""
  for char in mask.clusters() {
    pattern += if char == "9" { "\\d" } else if char == "A" {
      "[A-Z]"
    } else if char == " " { "\\s?" } else if char in _regex-syntax {
      "\\" + char
    } else { char }
  }
  pattern
}

/// A country that is not predefined in the `country` module.
///
/// - `code`: the ISO 3166-1 alpha-2 code, e.g. `"NO"` (required).
/// - `name`: the printed name of the country.
/// - `show-always`: print the country line even for domestic addresses.
/// - `post-code`: a mask (`9` a digit, `A` a letter, e.g. `"A9A 9A9"`) or an
///   array of masks; `auto` accepts 4 or 5 digits.
/// - `post-code-position`: `"before"` or `"after"` the city name.
///
/// -> dictionary
#let custom(
  code: none,
  name: none,
  show-always: false,
  post-code: auto,
  post-code-position: "before",
) = {
  let code = normalize-code(code, "country.custom: code")
  if name != none and type(name) not in (str, content) {
    panic(
      "`country.custom: name` must be a string or content, got "
        + repr(name)
        + ".",
    )
  }
  if post-code-position not in ("before", "after") {
    panic(
      "`country.custom: post-code-position` must be \"before\" or \"after\", got "
        + repr(post-code-position)
        + ".",
    )
  }
  let masks = if type(post-code) == array { post-code } else { (post-code,) }
  if (
    post-code != auto
      and (masks.len() == 0 or masks.any(mask => type(mask) != str))
  ) {
    panic(
      "`country.custom: post-code` must be a mask such as \"9999\" or \"A9A 9A9\" (9 = digit, A = letter), an array of masks or auto, got "
        + repr(post-code)
        + ".",
    )
  }
  // The post code may carry the country code as marker ("NO-0154 Oslo").
  let parse-city-raw = if post-code == auto {
    if post-code-position == "before" { parse-city-euro } else {
      post-code-parser("\\d{4,5}", position: "after", prefixes: (code,))
    }
  } else {
    post-code-parser(
      masks.map(_mask-pattern).join("|"),
      position: post-code-position,
      prefixes: (code,),
      ignore-case: true,
    )
  }
  let format-city = if post-code-position == "before" {
    format-city-euro
  } else { format-city-trailing }
  make-country(
    name: if name == none { "" } else { name },
    code: code,
    show-always: show-always,
    format-city: format-city,
    format-inline-city: format-city,
    parse-city-raw: parse-city-raw,
  )
}

// --- Countries ---
// A city line without a post code of the country's format is not split.

#let _digits(count, ..prefixes) = post-code-parser(
  "\\d{" + str(count) + "}",
  prefixes: prefixes.pos(),
)

#let de(name: "Deutschland", code: "DE", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "D", "DE"),
)
#let at(name: "Österreich", code: "AT", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "A", "AT"),
)
#let ch(name: "Schweiz", code: "CH", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "CH"),
)
#let fr(name: "France", code: "FR", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "F", "FR"),
)
#let it(name: "Italia", code: "IT", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "I", "IT"),
)
#let es(name: "España", code: "ES", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "E", "ES"),
)

#let be(name: "België", code: "BE", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "B", "BE"),
)
#let bg(name: "Bulgaria", code: "BG", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "BG"),
)
#let cy(name: "Cyprus", code: "CY", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "CY"),
)
// "110 00 Praha 1"
#let cz(name: "Česko", code: "CZ", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{3}\\s?\\d{2}", prefixes: ("CZ",)),
)
#let dk(name: "Danmark", code: "DK", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "DK"),
)
#let ee(name: "Eesti", code: "EE", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "EE"),
)
#let fi(name: "Suomi", code: "FI", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "FI"),
)
// "105 57 Athina"
#let gr(name: "Greece", code: "GR", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{3}\\s?\\d{2}", prefixes: ("GR",)),
)
#let hr(name: "Hrvatska", code: "HR", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(5, "HR"),
)
#let hu(name: "Magyarország", code: "HU", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "H", "HU"),
)
// The Eircode follows the city line: "Dublin 2 D02 X285".
#let ie(name: "Ireland", code: "IE", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  format-city: format-city-uk,
  format-inline-city: format-inline-city-uk,
  parse-city-raw: post-code-parser(
    "(?:[AC-FHKNPRTV-Y]\\d{2}|D6W)\\s?[0-9AC-FHKNPRTV-Y]{4}",
    position: "either",
    ignore-case: true,
  ),
)
// The official post codes of LT, LU and LV include the marker ("LV-1050").
#let lt(name: "Lietuva", code: "LT", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser(
    "\\d{5}",
    prefixes: ("LT",),
    keep-prefix: true,
  ),
)
#let lu(name: "Luxembourg", code: "LU", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser(
    "\\d{4}",
    prefixes: ("L",),
    keep-prefix: true,
  ),
)
#let lv(name: "Latvija", code: "LV", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser(
    "\\d{4}",
    prefixes: ("LV",),
    keep-prefix: true,
  ),
)
// "Valletta VLT 1117"
#let mt(name: "Malta", code: "MT", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  format-city: format-city-trailing,
  format-inline-city: format-city-trailing,
  parse-city-raw: post-code-parser("[A-Z]{3}\\s?\\d{4}", position: "either"),
)
// "1012 AB Amsterdam"
#let nl(name: "Nederland", code: "NL", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{4}\\s?[A-Z]{2}", prefixes: ("NL",)),
)
// "00-950 Warszawa"
#let pl(name: "Polska", code: "PL", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{2}-\\d{3}", prefixes: ("PL",)),
)
// "1000-001 Lisboa"
#let pt(name: "Portugal", code: "PT", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{4}-\\d{3}", prefixes: ("PT",)),
)
#let ro(name: "România", code: "RO", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(6, "RO"),
)
// "114 55 Stockholm"
#let se(name: "Sverige", code: "SE", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{3}\\s?\\d{2}", prefixes: ("S", "SE")),
)
#let si(name: "Slovenija", code: "SI", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: _digits(4, "SI"),
)
// "811 01 Bratislava"
#let sk(name: "Slovensko", code: "SK", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  parse-city-raw: post-code-parser("\\d{3}\\s?\\d{2}", prefixes: ("SK",)),
)

#let uk(name: "United Kingdom", code: "GB", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  format-city: format-city-uk,
  format-inline-city: format-inline-city-uk,
  parse-city-raw: parse-city-uk,
)
#let gb = uk

#let us(name: "United States", code: "US", show-always: false) = make-country(
  name: name,
  code: code,
  show-always: show-always,
  format-city: format-city-us,
  format-inline-city: format-city-us,
  parse-city-raw: parse-city-us,
)

// --- Resolution ---
#let region-to-country = (
  de: de,
  at: at,
  ch: ch,
  fr: fr,
  it: it,
  es: es,
  be: be,
  bg: bg,
  cy: cy,
  cz: cz,
  dk: dk,
  ee: ee,
  fi: fi,
  gr: gr,
  hr: hr,
  hu: hu,
  ie: ie,
  lt: lt,
  lu: lu,
  lv: lv,
  mt: mt,
  nl: nl,
  pl: pl,
  pt: pt,
  ro: ro,
  se: se,
  si: si,
  sk: sk,
  uk: uk,
  gb: uk,
  us: us,
)

// The country of a locale region such as "de" (the default of the parties).
#let country-from-region(region) = {
  let key = lower(region)
  if key in region-to-country {
    region-to-country.at(key)()
  } else {
    make-country(code: upper(region))
  }
}

// The predefined country of a code, or a custom one without name.
#let country-from-code(code, field) = {
  let code = normalize-code(code, field)
  let key = lower(code)
  if key in region-to-country {
    region-to-country.at(key)()
  } else {
    custom(code: code)
  }
}

#let _invalid-country(value, field) = panic(
  "`"
    + field
    + "` must be a country of the `country` module (e.g. `country.fr`), `country.custom(code: \"NO\", name: \"Norge\")` or an ISO 3166-1 alpha-2 code such as \"FR\", got "
    + repr(value)
    + ".",
)

// Completes a country dictionary with the parsers and formatters of its code.
#let _complete-country(country, field) = {
  if "code" not in country {
    panic(
      "`"
        + field
        + "`: the country dictionary has no `code`. Use e.g. `country.custom(code: \"NO\", name: \"Norge\")`.",
    )
  }
  let code = normalize-code(country.code, field + ".code")
  for key in ("parse-city", "format-address", "format-inline") {
    if key in country and type(country.at(key)) != function {
      panic(
        "`"
          + field
          + "."
          + key
          + "` must be a function, got "
          + repr(country.at(key))
          + ".",
      )
    }
  }
  let base = if ("parse-city", "format-address", "format-inline").all(key => (
    key in country
  )) { (name: "", show-always: false) } else {
    country-from-code(code, field + ".code")
  }
  base + country + (code: code)
}

// An empty text (e.g. an empty column of imported data) states no country.
#let _states-no-country(value) = (
  value == auto
    or value == none
    or (type(value) in (str, content) and plain-text(value) == "")
)

/// Resolves the `country` of a party: `country.fr`, a country dictionary or
/// an ISO 3166-1 alpha-2 code; `auto`, `none` and `""` give the country of
/// `default-region`. Any other value is an error, never replaced silently.
///
/// -> dictionary
#let resolve-country(country-opt, default-region, field: "country") = {
  if _states-no-country(country-opt) {
    return country-from-region(default-region)
  }
  let kind = type(country-opt)
  if kind in (str, content) {
    let code = plain-text(country-opt)
    if code.match(_code-pattern) == none {
      _invalid-country(country-opt, field)
    }
    return country-from-code(code, field)
  }
  let country = if kind == function { country-opt() } else if (
    kind == dictionary
  ) { country-opt } else { _invalid-country(country-opt, field) }
  if type(country) != dictionary { _invalid-country(country-opt, field) }
  _complete-country(country, field)
}

// The `region` key of a party, an alias of `country` that also accepts the
// regions of the `locale` module (`region.de`).
#let _resolve-region(region-opt, default-region, field) = {
  if type(region-opt) == function {
    import "../locale/region/region.typ"
    let locale-regions = (
      (region.at, "at"),
      (region.ch, "ch"),
      (region.de, "de"),
      (region.es, "es"),
      (region.fr, "fr"),
      (region.it, "it"),
    )
    for (region-fn, code) in locale-regions {
      if region-opt == region-fn { return country-from-region(code) }
    }
  }
  if (
    type(region-opt) == dictionary
      and type(region-opt.at("meta", default: none)) == dictionary
      and "region" in region-opt.meta
  ) {
    return country-from-region(region-opt.meta.region)
  }
  resolve-country(region-opt, default-region, field: field)
}

/// The country of a party (`country` or `region`) and whether it states one
/// (`explicit`); else `default-country` or the country of `default-region`.
///
/// -> dictionary
#let resolve-party-country(
  party,
  default-region,
  default-country: auto,
  field: "party",
) = {
  let country-opt = party.at("country", default: auto)
  if not _states-no-country(country-opt) {
    return (
      country: resolve-country(
        country-opt,
        default-region,
        field: field + ".country",
      ),
      explicit: true,
    )
  }
  let region-opt = party.at("region", default: none)
  if not _states-no-country(region-opt) {
    return (
      country: _resolve-region(region-opt, default-region, field + ".region"),
      explicit: true,
    )
  }
  if default-country != auto {
    return (country: default-country, explicit: false)
  }
  (country: country-from-region(default-region), explicit: false)
}

// A post code given as a number would lose its leading zeros ("01067"), so
// it is rejected instead of converted.
#let _check-city(city, field) = {
  if city == () { return none }
  if city == none or type(city) in (str, content) { return city }
  if type(city) != dictionary {
    panic(
      "`"
        + field
        + ".city` must be a string such as \"10115 Berlin\", content or a dictionary `(name: \"Berlin\", post-code: \"10115\")`, got "
        + repr(city)
        + ".",
    )
  }
  for key in ("name", "post-code", "state", "display", "inline-display") {
    let value = city.at(key, default: none)
    if value != none and type(value) not in (str, content) {
      panic(
        "`"
          + field
          + ".city."
          + key
          + "` must be a string"
          + if key == "post-code" {
            " such as \"01067\", so that leading zeros are kept"
          } else { "" }
          + ", got "
          + repr(value)
          + ".",
      )
    }
  }
  city
}

#let normalize-party(
  party,
  default-region,
  is-recipient: false,
  sender-country-code: none,
  recipient-country-code: none,
  // For a party without `country`; `auto`: the country of `default-region`.
  default-country: auto,
  // The party in error messages; `auto`: "sender" or "recipient".
  field: auto,
) = {
  if type(party) != dictionary { return party }
  let field = if field != auto { field } else if is-recipient {
    "recipient"
  } else { "sender" }

  let has-street = "street" in party and party.street != none
  let has-address = "address" in party and party.address != none
  if has-street and has-address {
    panic(
      "Both 'street' and 'address' are populated for "
        + field
        + ", but they are mutually exclusive.",
    )
  }

  let (country: resolved-country, explicit: country-explicit) = (
    resolve-party-country(
      party,
      default-region,
      default-country: default-country,
      field: field,
    )
  )

  let city-raw = _check-city(party.at("city", default: none), field)
  let parsed-city = none
  if city-raw != none {
    if type(city-raw) == dictionary {
      parsed-city = city-raw
    } else {
      parsed-city = (resolved-country.parse-city)(city-raw)
    }
  }

  let format-poly-block(val) = {
    if val == none { none } else if type(val) == array {
      val.join([ \ ])
    } else { val }
  }

  let format-poly-inline(val) = {
    if val == none { none } else if type(val) == array { val.join(", ") } else {
      val
    }
  }

  let name-raw = party.at("name", default: none)
  let name-vertical = format-poly-block(name-raw)
  let name-inline = format-poly-inline(name-raw)

  let address-raw = if has-street { party.street } else {
    party.at("address", default: none)
  }
  let address-vertical = format-poly-block(address-raw)
  let address-inline = format-poly-inline(address-raw)

  // Raw: the e-invoice takes their plain text itself.
  let address-lines = if address-raw == none {
    ()
  } else if type(address-raw) == array {
    address-raw
  } else {
    (address-raw,)
  }

  // The country line is printed for a country other than the other party's
  // or the locale region's.
  let display-country-name = none
  if resolved-country.code != none and lower(resolved-country.code) != "base" {
    let show-country = resolved-country.at("show-always", default: false)
    if not show-country {
      if is-recipient {
        if (
          (
            sender-country-code != none
              and lower(resolved-country.code) != lower(sender-country-code)
          )
            or (
              default-region != "base"
                and lower(resolved-country.code) != lower(default-region)
            )
        ) {
          show-country = true
        }
      } else {
        if (
          (
            recipient-country-code != none
              and lower(resolved-country.code) != lower(recipient-country-code)
          )
            or (
              default-region != "base"
                and lower(resolved-country.code) != lower(default-region)
            )
        ) {
          show-country = true
        }
      }
    }

    if show-country {
      display-country-name = if (
        resolved-country.name != none and resolved-country.name != ""
      ) {
        resolved-country.code + " - " + resolved-country.name
      } else {
        resolved-country.code
      }
    }
  }

  let city-vertical = if parsed-city != none {
    (resolved-country.format-address)(
      none,
      none,
      parsed-city,
      country-name: display-country-name,
    )
  } else { none }

  let city-inline = if parsed-city != none {
    (resolved-country.format-inline)(
      none,
      none,
      parsed-city,
      country-name: display-country-name,
    )
  } else { none }

  {
    party
    (
      name: name-vertical,
      address-lines: address-lines,
      address: address-vertical,
      city: city-vertical,
      name-inline: name-inline,
      address-inline: address-inline,
      city-inline: city-inline,
      country: resolved-country,
      // Whether the party states its country, else it is a default.
      country-explicit: country-explicit,
      city-name: none,
      post-code: none,
      state: none,
      tax-nr: party.at("tax-nr", default: none),
      vat-id: party.at("vat-id", default: none),
    )

    if parsed-city != none {
      (city-name: parsed-city.at("name", default: none))
    }
    if parsed-city != none {
      (post-code: parsed-city.at("post-code", default: none))
    }
    if parsed-city != none {
      (state: parsed-city.at("state", default: none))
    }
  }
}
