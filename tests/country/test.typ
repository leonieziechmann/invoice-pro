#import "/src/lib.typ": country

// --- DE Country Tests ---
#{
  let de = country.de()
  assert.eq(de.name, "Deutschland")
  assert.eq(de.code, "DE")

  // Customization via with()
  let de-custom = country.de.with(name: "Allemagne")()
  assert.eq(de-custom.name, "Allemagne")
  assert.eq(de-custom.code, "DE")

  // Parsing
  assert.eq((de.parse-city)("12345 Berlin"), (
    name: "Berlin",
    post-code: "12345",
  ))
  assert.eq((de.parse-city)("D-12345 Berlin"), (
    name: "Berlin",
    post-code: "12345",
  ))
  // A 4-digit number is no German post code: the line is not taken apart (the
  // e-invoice would otherwise carry a wrong post code for a wrong country)
  assert.eq((de.parse-city)("8000 Zürich"), (
    name: "8000 Zürich",
    post-code: none,
  ))
  assert.eq((de.parse-city)("A-1010 Wien"), (
    name: "A-1010 Wien",
    post-code: none,
  ))
  assert.eq((de.parse-city)("DE-01067 Dresden"), (
    name: "Dresden",
    post-code: "01067",
  ))
  assert.eq((de.parse-city)("Berlin"), (name: "Berlin", post-code: none))
  assert.eq(
    (de.parse-city)((name: "Berlin", post-code: "12345", display: "Custom")),
    (name: "Berlin", post-code: "12345", display: "Custom"),
  )

  // Formatting - Vertical
  assert.eq(
    (de.format-address)("My Company", "Street 1", "12345 Berlin"),
    [My Company \ Street 1 \ 12345 Berlin],
  )
  assert.eq(
    (de.format-address)(
      ("Name 1", "Name 2"),
      ("Street 1", "Street 2"),
      "12345 Berlin",
      country-name: "DEUTSCHLAND",
    ),
    [Name 1 \ Name 2 \ Street 1 \ Street 2 \ 12345 Berlin \ DEUTSCHLAND],
  )
  assert.eq(
    (de.format-address)("My Company", "Street 1", (
      name: "Berlin",
      post-code: "12345",
      display: "Overridden City Line",
    )),
    [My Company \ Street 1 \ Overridden City Line],
  )

  // Formatting - Inline
  assert.eq(
    (de.format-inline)("My Company", "Street 1", "12345 Berlin"),
    "My Company, Street 1, 12345 Berlin",
  )
  assert.eq(
    (de.format-inline)(
      ("Name 1", "Name 2"),
      ("Street 1", "Street 2"),
      "12345 Berlin",
      country-name: "DEUTSCHLAND",
    ),
    "Name 1, Name 2, Street 1, Street 2, 12345 Berlin, DEUTSCHLAND",
  )
  assert.eq(
    (de.format-inline)("My Company", "Street 1", (
      name: "Berlin",
      post-code: "12345",
      inline-display: "Overridden City Line",
    )),
    "My Company, Street 1, Overridden City Line",
  )
}

// --- UK Country Tests ---
#{
  let uk = country.uk()
  assert.eq(uk.name, "United Kingdom")
  assert.eq(uk.code, "GB")

  // Parsing
  assert.eq((uk.parse-city)("London SW1A 2AA"), (
    name: "London",
    post-code: "SW1A 2AA",
  ))
  assert.eq((uk.parse-city)("London, SW1A 2AA"), (
    name: "London",
    post-code: "SW1A 2AA",
  ))
  assert.eq((uk.parse-city)("London\nSW1A 2AA"), (
    name: "London",
    post-code: "SW1A 2AA",
  ))
  assert.eq((uk.parse-city)("London"), (name: "London", post-code: none))

  // Formatting - Vertical (UK zip code should be on its own line below city name)
  assert.eq(
    (uk.format-address)("My Company", "Street 1", (
      name: "London",
      post-code: "SW1A 2AA",
    )),
    [My Company \ Street 1 \ London \ SW1A 2AA],
  )
  assert.eq(
    (uk.format-address)("My Company", "Street 1", "London SW1A 2AA"),
    [My Company \ Street 1 \ London \ SW1A 2AA],
  )

  // Formatting - Inline
  assert.eq(
    (uk.format-inline)("My Company", "Street 1", (
      name: "London",
      post-code: "SW1A 2AA",
    )),
    "My Company, Street 1, London, SW1A 2AA",
  )
  assert.eq(
    (uk.format-inline)("My Company", "Street 1", "London SW1A 2AA"),
    "My Company, Street 1, London, SW1A 2AA",
  )
}

// --- US Country Tests ---
#{
  let us = country.us()
  assert.eq(us.name, "United States")
  assert.eq(us.code, "US")

  // Parsing
  assert.eq((us.parse-city)("New York, NY 10001"), (
    name: "New York",
    state: "NY",
    post-code: "10001",
  ))
  assert.eq((us.parse-city)("New York NY 10001"), (
    name: "New York",
    state: "NY",
    post-code: "10001",
  ))
  assert.eq((us.parse-city)("New York 10001"), (
    name: "New York",
    state: none,
    post-code: "10001",
  ))
  assert.eq((us.parse-city)("New York"), (
    name: "New York",
    state: none,
    post-code: none,
  ))

  // Formatting - Vertical
  assert.eq(
    (us.format-address)("My Company", "Street 1", (
      name: "New York",
      state: "NY",
      post-code: "10001",
    )),
    [My Company \ Street 1 \ New York, NY 10001],
  )
  assert.eq(
    (us.format-address)("My Company", "Street 1", "New York, NY 10001"),
    [My Company \ Street 1 \ New York, NY 10001],
  )

  // Formatting - Inline
  assert.eq(
    (us.format-inline)("My Company", "Street 1", (
      name: "New York",
      state: "NY",
      post-code: "10001",
    )),
    "My Company, Street 1, New York, NY 10001",
  )
}

// --- Post codes in the format of each predefined country ---
#{
  // (country, city line, expected post code, expected city name)
  let cases = (
    (country.at, "1010 Wien", "1010", "Wien"),
    (country.at, "A-1010 Wien", "1010", "Wien"),
    (country.be, "1000 Bruxelles", "1000", "Bruxelles"),
    (country.bg, "1000 Sofia", "1000", "Sofia"),
    (country.ch, "8001 Zürich", "8001", "Zürich"),
    (country.ch, "CH-8001 Zürich", "8001", "Zürich"),
    (country.cy, "1010 Nicosia", "1010", "Nicosia"),
    (country.cz, "110 00 Praha 1", "110 00", "Praha 1"),
    (country.cz, "11000 Praha 1", "11000", "Praha 1"),
    (country.de, "10115 Berlin", "10115", "Berlin"),
    (country.dk, "1050 København K", "1050", "København K"),
    (country.ee, "10111 Tallinn", "10111", "Tallinn"),
    (country.es, "28001 Madrid", "28001", "Madrid"),
    (country.fi, "00100 Helsinki", "00100", "Helsinki"),
    (country.fr, "75002 Paris", "75002", "Paris"),
    (country.fr, "75002 Paris Cedex 02", "75002", "Paris Cedex 02"),
    (country.gr, "105 57 Athina", "105 57", "Athina"),
    (country.hr, "10000 Zagreb", "10000", "Zagreb"),
    (country.hu, "1051 Budapest", "1051", "Budapest"),
    (country.ie, "Dublin 2 D02 X285", "D02 X285", "Dublin 2"),
    (country.ie, "Cork, t12 x70a", "T12 X70A", "Cork"),
    (country.it, "00187 Roma", "00187", "Roma"),
    (country.lt, "LT-01100 Vilnius", "LT-01100", "Vilnius"),
    (country.lu, "L-1648 Luxembourg", "L-1648", "Luxembourg"),
    (country.lv, "LV-1050 Riga", "LV-1050", "Riga"),
    (country.mt, "Valletta VLT 1117", "VLT 1117", "Valletta"),
    (country.mt, "VLT 1117 Valletta", "VLT 1117", "Valletta"),
    (country.nl, "1012 AB Amsterdam", "1012 AB", "Amsterdam"),
    (country.nl, "3731 AA De Bilt", "3731 AA", "De Bilt"),
    (country.pl, "00-950 Warszawa", "00-950", "Warszawa"),
    (country.pt, "1000-001 Lisboa", "1000-001", "Lisboa"),
    (country.ro, "010011 Bucuresti", "010011", "Bucuresti"),
    (country.se, "114 55 Stockholm", "114 55", "Stockholm"),
    (country.si, "1000 Ljubljana", "1000", "Ljubljana"),
    (country.sk, "811 01 Bratislava", "811 01", "Bratislava"),
    (country.uk, "London SW1A 2AA", "SW1A 2AA", "London"),
    (country.us, "New York, NY 10118", "10118", "New York"),
  )
  for (c, raw, post-code, name) in cases {
    let parsed = (c().parse-city)(raw)
    assert.eq(
      (parsed.post-code, parsed.name),
      (post-code, name),
      message: c().code
        + " "
        + repr(raw)
        + ": expected "
        + repr((post-code, name))
        + ", got "
        + repr((parsed.post-code, parsed.name)),
    )
  }

  // A post code of another format is not taken apart
  for (c, raw) in (
    (country.nl, "1012 Amsterdam"),
    (country.nl, "3731 De Bilt"),
    (country.pl, "00950 Warszawa"),
    (country.at, "10115 Berlin"),
    (country.ch, "A-1010 Wien"),
    (country.se, "1234 Stockholm"),
  ) {
    assert.eq(
      (c().parse-city)(raw),
      (name: raw, post-code: none),
      message: c().code + " " + repr(raw),
    )
  }

  // The city line is printed in the order of the country
  assert.eq(
    (country.mt().format-inline)(none, none, "VLT 1117 Valletta"),
    "Valletta VLT 1117",
  )
  assert.eq(
    (country.ie().format-address)(none, none, "Dublin 2 D02 X285"),
    [Dublin 2 \ D02 X285],
  )
  assert.eq(
    (country.nl().format-address)(none, none, "1012 AB Amsterdam"),
    "1012 AB Amsterdam",
  )
}

// --- A city given as composed or styled content keeps its spaces ---
#{
  let plz = "10115"
  let ort = "Berlin"
  let de = country.de()
  assert.eq((de.parse-city)([#plz #ort]), (name: "Berlin", post-code: "10115"))
  assert.eq((de.parse-city)([10115 *Berlin*]), (
    name: "Berlin",
    post-code: "10115",
  ))
  assert.eq((country.uk().parse-city)([London \ SW1A 2AA]), (
    name: "London",
    post-code: "SW1A 2AA",
  ))
  assert.eq((de.format-inline)(none, none, [#plz #ort]), "10115 Berlin")
}

// --- Countries outside the module and ISO codes ---
#{
  import "/src/logic/country.typ": resolve-country

  // An ISO code as string or content is the country of that code
  let ch = resolve-country("CH", "de")
  assert.eq((ch.code, ch.name), ("CH", "Schweiz"))
  assert.eq((ch.parse-city)("8001 Zürich").post-code, "8001")
  assert.eq(resolve-country("ch", "de").code, "CH")
  assert.eq(resolve-country(" fr ", "de").code, "FR")
  assert.eq(resolve-country([AT], "de").code, "AT")
  assert.eq(resolve-country("uk", "de").code, "GB")
  assert.eq(resolve-country("GB", "de").name, "United Kingdom")
  assert.eq(resolve-country("FI", "de").name, "Suomi")
  // A country outside the module keeps its code
  let no = resolve-country("NO", "de")
  assert.eq((no.code, no.name), ("NO", ""))
  assert.eq((no.parse-city)("0154 Oslo"), (name: "Oslo", post-code: "0154"))
  // `auto`, `none` and an empty value (e.g. an empty column of imported data)
  // state no country: the country of the locale region
  assert.eq(resolve-country(auto, "at").code, "AT")
  assert.eq(resolve-country(none, "de").code, "DE")
  assert.eq(resolve-country("", "at").code, "AT")
  assert.eq(resolve-country(" ", "at").code, "AT")
  assert.eq(resolve-country([], "ch").code, "CH")

  // Anything else is an error instead of a silently replaced country
  let message = catch(() => resolve-country(
    "Germany",
    "de",
    field: "recipient.country",
  ))
  assert(
    message.contains(
      "`recipient.country` must be a country of the `country` module",
    )
      and message.contains("got \\\"Germany\\\""),
    message: message,
  )
  assert(catch(() => resolve-country(49, "de")).contains("got 49"))

  // A country dictionary is completed: `(code:, name:)` suffices
  let norway = resolve-country((code: "NO", name: "Norge"), "de")
  assert.eq((norway.code, norway.name), ("NO", "Norge"))
  assert.eq(
    (norway.format-address)(
      none,
      none,
      "0154 Oslo",
      country-name: "NO - Norge",
    ),
    [0154 Oslo \ ] + "NO - Norge",
  )
  // ... with the post code format of the predefined country of that code
  let france = resolve-country((code: "fr", name: "Frankreich"), "de")
  assert.eq((france.code, france.name), ("FR", "Frankreich"))
  assert.eq((france.parse-city)("75002 Paris").post-code, "75002")
  assert(
    catch(() => resolve-country((name: "Norge"), "de")).contains(
      "has no `code`",
    ),
  )
  // Codes of customized countries are checked and upper-cased; "UK" is the
  // United Kingdom's ISO code "GB" in every form, not only as a string
  assert.eq(resolve-country(country.de.with(code: "de"), "fr").code, "DE")
  assert.eq(resolve-country((code: "UK", name: "Britain"), "de").code, "GB")
  assert.eq(resolve-country(country.uk.with(code: "uk"), "de").code, "GB")
  assert.eq(country.custom(code: "uk").code, "GB")
  assert(
    catch(() => resolve-country(
      country.de.with(code: "Deutschland"),
      "de",
      field: "sender.country",
    )).contains("Deutschland\\\" is not an ISO 3166-1 alpha-2 country code"),
  )

  // `country.custom` creates a country that is not predefined
  let no = country.custom(code: "no", name: "Norge")
  assert.eq((no.code, no.name, no.show-always), ("NO", "Norge", false))
  assert.eq((no.parse-city)("0154 Oslo"), (name: "Oslo", post-code: "0154"))
  let ca = country.custom(
    code: "CA",
    name: "Canada",
    post-code: "A9A 9A9",
    post-code-position: "after",
  )
  assert.eq((ca.parse-city)("Toronto ON m5v 2t6"), (
    name: "Toronto ON",
    post-code: "M5V 2T6",
  ))
  assert.eq(
    (ca.format-inline)(none, none, "Toronto ON M5V 2T6"),
    "Toronto ON M5V 2T6",
  )
  // The post code may carry the country code as marker, as for the
  // predefined countries
  let norway = country.custom(code: "NO", post-code: "9999")
  assert.eq((norway.parse-city)("NO-0154 Oslo"), (
    name: "Oslo",
    post-code: "0154",
  ))
  assert.eq((norway.parse-city)("0154 Oslo").post-code, "0154")
  let jp = country.custom(code: "JP", post-code: ("999-9999", "9999999"))
  assert.eq((jp.parse-city)("100-0001 Tokyo"), (
    name: "Tokyo",
    post-code: "100-0001",
  ))
  assert.eq((jp.parse-city)("1000001 Tokyo").post-code, "1000001")
  assert.eq((jp.parse-city)("10001 Tokyo").post-code, none)
  assert.eq(resolve-country(country.custom.with(code: "IS"), "de").code, "IS")
  assert(catch(() => country.custom()).contains("`country.custom: code`"))
  assert(
    catch(() => country.custom(code: "NOR")).contains(
      "NOR\\\" is not an ISO 3166-1 alpha-2 country code",
    ),
  )
  assert(
    catch(() => country.custom(code: "NO", post-code: 9999)).contains(
      "`country.custom: post-code` must be a mask",
    ),
  )
  assert(
    catch(() => country.custom(
      code: "NO",
      post-code-position: "left",
    )).contains("`country.custom: post-code-position` must be"),
  )

  // `country.gb` is the United Kingdom, as documented
  assert.eq(country.gb().code, "GB")
}
