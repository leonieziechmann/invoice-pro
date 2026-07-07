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
  assert.eq((de.parse-city)("8000 Zürich"), (name: "Zürich", post-code: "8000"))
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
