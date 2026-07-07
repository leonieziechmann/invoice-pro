// --- Regional Parsers and Formatters ---

#let parse-city-euro(city-str) = {
  let m = city-str.match(regex("^\\s*(?:[A-Z]{1,2}-)?(\\d{4,5})\\s+(.+)$"))
  if m != none {
    let pc-raw = m.captures.at(0, default: none)
    let name-raw = m.captures.at(1, default: none)
    (
      name: if name-raw != none { name-raw.trim() } else { "" },
      post-code: if pc-raw != none { pc-raw.trim() } else { none },
    )
  } else {
    (
      name: city-str.trim(),
      post-code: none,
    )
  }
}

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

#let parse-city-uk(city-str) = {
  let m = city-str.match(
    regex(
      "(?i)^\\s*(.+?)(?:,\\s*|\\s+|\\n)\\s*([a-z]{1,2}\\d[a-z\\d]?\\s*\\d[a-z]{2})\\s*$",
    ),
  )
  if m != none {
    let name-raw = m.captures.at(0, default: none)
    let pc-raw = m.captures.at(1, default: none)
    (
      name: if name-raw != none { name-raw.trim() } else { "" },
      post-code: if pc-raw != none { upper(pc-raw).trim() } else { none },
    )
  } else {
    (
      name: city-str.trim(),
      post-code: none,
    )
  }
}

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
  let m1 = city-str.match(
    regex(
      "(?i)^\\s*(.+?)(?:,\\s*|\\s+)([a-z]{2})\\s+(\\d{5}(?:-\\d{4})?)\\s*$",
    ),
  )
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
    let m2 = city-str.match(
      regex("(?i)^\\s*(.+?)(?:,\\s*|\\s+)(\\d{5}(?:-\\d{4})?)\\s*$"),
    )
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

// --- Country Module Builder ---

#let make-country(
  name: "",
  code: "",
  format-city: format-city-euro,
  format-inline-city: format-city-euro,
  parse-city-raw: parse-city-euro,
) = {
  let to-string(it) = {
    if type(it) == str { it } else if it == none or it == auto { "" } else if (
      type(it) != content
    ) {
      str(it)
    } else if it.has("text") { it.text } else if it.has("children") {
      it.children.map(to-string).join()
    } else if it.has("body") { to-string(it.body) } else { "" }
  }

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
      parse-city-raw(to-string(city))
    }
  }

  (
    name: name,
    code: code,
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

// --- Exported Country Functions ---

#let de(name: "Deutschland", code: "DE") = make-country(name: name, code: code)
#let at(name: "Österreich", code: "AT") = make-country(name: name, code: code)
#let ch(name: "Schweiz", code: "CH") = make-country(name: name, code: code)
#let fr(name: "France", code: "FR") = make-country(name: name, code: code)
#let it(name: "Italia", code: "IT") = make-country(name: name, code: code)
#let es(name: "España", code: "ES") = make-country(name: name, code: code)

#let be(name: "België", code: "BE") = make-country(name: name, code: code)
#let bg(name: "Bulgaria", code: "BG") = make-country(name: name, code: code)
#let cy(name: "Cyprus", code: "CY") = make-country(name: name, code: code)
#let cz(name: "Česko", code: "CZ") = make-country(name: name, code: code)
#let dk(name: "Danmark", code: "DK") = make-country(name: name, code: code)
#let ee(name: "Eesti", code: "EE") = make-country(name: name, code: code)
#let gr(name: "Greece", code: "GR") = make-country(name: name, code: code)
#let hr(name: "Hrvatska", code: "HR") = make-country(name: name, code: code)
#let hu(name: "Magyarország", code: "HU") = make-country(name: name, code: code)
#let ie(name: "Ireland", code: "IE") = make-country(name: name, code: code)
#let lt(name: "Lietuva", code: "LT") = make-country(name: name, code: code)
#let lu(name: "Luxembourg", code: "LU") = make-country(name: name, code: code)
#let lv(name: "Latvija", code: "LV") = make-country(name: name, code: code)
#let mt(name: "Malta", code: "MT") = make-country(name: name, code: code)
#let nl(name: "Nederland", code: "NL") = make-country(name: name, code: code)
#let pl(name: "Polska", code: "PL") = make-country(name: name, code: code)
#let pt(name: "Portugal", code: "PT") = make-country(name: name, code: code)
#let ro(name: "România", code: "RO") = make-country(name: name, code: code)
#let se(name: "Sverige", code: "SE") = make-country(name: name, code: code)
#let si(name: "Slovenija", code: "SI") = make-country(name: name, code: code)
#let sk(name: "Slovensko", code: "SK") = make-country(name: name, code: code)

#let uk(name: "United Kingdom", code: "GB") = make-country(
  name: name,
  code: code,
  format-city: format-city-uk,
  format-inline-city: format-inline-city-uk,
  parse-city-raw: parse-city-uk,
)

#let us(name: "United States", code: "US") = make-country(
  name: name,
  code: code,
  format-city: format-city-us,
  format-inline-city: format-city-us,
  parse-city-raw: parse-city-us,
)

// --- Helper mapping ---
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

#let resolve-country(country-opt, default-region) = {
  if type(country-opt) == function {
    country-opt()
  } else if type(country-opt) == dictionary {
    country-opt
  } else {
    // country-opt is auto
    let region-lower = lower(default-region)
    if region-lower in region-to-country {
      region-to-country.at(region-lower)()
    } else {
      make-country(code: upper(default-region))
    }
  }
}

#let normalize-party(
  party,
  default-region,
  is-recipient: false,
  sender-country-code: none,
) = {
  if type(party) != dictionary { return party }

  // 1. Resolve country
  let country-opt = party.at("country", default: auto)
  let resolved-country = resolve-country(country-opt, default-region)

  // 2. Parse / extract city data
  let city-raw = party.at("city", default: none)
  let parsed-city = none
  if city-raw != none {
    if type(city-raw) == dictionary {
      parsed-city = city-raw
    } else {
      parsed-city = (resolved-country.parse-city)(city-raw)
    }
  }

  // 3. Format name and address
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

  let address-raw = party.at("address", default: none)
  let address-vertical = format-poly-block(address-raw)
  let address-inline = format-poly-inline(address-raw)

  // 4. Format city (handling international country name printing)
  let display-country-name = none
  if (
    is-recipient
      and sender-country-code != none
      and resolved-country.code != none
  ) {
    if resolved-country.code != sender-country-code {
      display-country-name = resolved-country.name
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

  // 5. Build normalized dictionary
  let result = party
  result.insert("name", name-vertical)
  result.insert("address", address-vertical)
  result.insert("city", city-vertical)
  result.insert("name-inline", name-inline)
  result.insert("address-inline", address-inline)
  result.insert("city-inline", city-inline)
  result.insert("country", resolved-country)

  // Expose parsed fields
  result.insert("city-name", if parsed-city != none {
    parsed-city.at("name", default: none)
  } else { none })
  result.insert("post-code", if parsed-city != none {
    parsed-city.at("post-code", default: none)
  } else { none })
  result.insert("state", if parsed-city != none {
    parsed-city.at("state", default: none)
  } else { none })
  result.insert("tax-nr", party.at("tax-nr", default: none))
  result.insert("vat-id", party.at("vat-id", default: none))

  result
}

