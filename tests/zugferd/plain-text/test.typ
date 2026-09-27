// The plain text of content as the e-invoice writes it: identifiers keep
// their ASCII hyphen, math reads as printed and multi-line texts such as
// payment terms (BT-20) can keep their line breaks.

#import "/src/utils/text.typ": plain-text

// --- 1. Hyphens: Typst sets a minus sign (U+2212) for "-" before a digit
// after an expression or styled text; an identifier needs the ASCII hyphen ---
#{
  let year = 2026
  assert.eq(plain-text([#{ year }-001]), "2026-001")
  assert.eq(plain-text([#str(year)-001]), "2026-001")
  assert.eq(plain-text([#{ "04011000" }-12345-67]), "04011000-12345-67")
  assert.eq(plain-text([RE-*2026*-001]), "RE-2026-001")
  assert.eq(plain-text([Nr. -5]), "Nr. -5")
  // Hyphen (U+2010), non-breaking hyphen (U+2011) and minus sign (U+2212)
  assert.eq(plain-text("A\u{2010}B\u{2011}C\u{2212}D"), "A-B-C-D")
  assert.eq(plain-text(decimal("-12.5")), "-12.5")
  // Dashes are no hyphens
  assert.eq(plain-text([10--12 Uhr]), "10–12 Uhr")
}

// --- 2. Math reads as printed, not as its digits run together ---
#{
  assert.eq(plain-text([Rohr $1/2$ Zoll]), "Rohr 1/2 Zoll")
  assert.eq(plain-text($(a+b)/2$), "(a+b)/2")
  assert.eq(plain-text([Faktor $x^2 + sqrt(2)$]), "Faktor x² + √2")
  assert.eq(plain-text([Fläche 20 m$""^2$]), "Fläche 20 m²")
  assert.eq(plain-text($root(3, x)$), "∛x")
  assert.eq(plain-text($sqrt(x+1) - 1/sqrt(2)$), "√(x+1) - 1/√2")
  assert.eq(plain-text($(2 dot 3)/(a b)$), "(2 ⋅ 3)/(a b)")
  assert.eq(plain-text($x_1 + x^n + x^(n+1)$), "x₁ + x^n + x^(n+1)")
  assert.eq(plain-text($f'$), "f′")
  assert.eq(plain-text($sin x$), "sin x")
  assert.eq(plain-text($2 dot 3 - 1$), "2 ⋅ 3 - 1")
}

// --- 3. Line breaks ---
#{
  // By default, all whitespace collapses into single spaces
  assert.eq(plain-text("a\nb"), "a b")
  assert.eq(plain-text([Line one \ line two]), "Line one line two")

  // `keep-newlines` keeps them, trims each line and collapses spaces
  assert.eq(plain-text("a\nb", keep-newlines: true), "a\nb")
  assert.eq(plain-text("a\r\nb\rc", keep-newlines: true), "a\nb\nc")
  assert.eq(
    plain-text(
      "  Zahlbar   in 30 Tagen. \r\n\t#SKONTO#  \n\n",
      keep-newlines: true,
    ),
    "Zahlbar in 30 Tagen.\n#SKONTO#",
  )
  assert.eq(
    plain-text([Zahlbar in 30 Tagen. \ *Skonto*], keep-newlines: true),
    "Zahlbar in 30 Tagen.\nSkonto",
  )
  assert.eq(
    plain-text(
      [
        Erster Absatz.

        Zweiter Absatz.
      ],
      keep-newlines: true,
    ),
    "Erster Absatz.\nZweiter Absatz.",
  )
  assert.eq(plain-text(none, keep-newlines: true), "")
}

// --- 4. The common values take a shorter way to the same text ---
// A string, a single text and a sequence of texts and spaces skip the walk
// of the content, and printable ASCII words the replacements: the result is
// that of the whole algorithm, which `reference` spells out.
#import "/src/utils/text.typ": _collect-text, _hyphens, invalid-xml-chars
#let reference(it, keep-newlines: false) = {
  let whitespace = regex("\\s+")
  let text = (
    _collect-text(it, if keep-newlines { "\n" } else { " " })
      .replace(invalid-xml-chars, "")
      .replace(_hyphens, "-")
  )
  if not keep-newlines { return text.replace(whitespace, " ").trim() }
  let lines = ()
  for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n") {
    lines.push(line.replace(whitespace, " ").trim())
  }
  lines.join("\n").trim("\n")
}
#{
  let year = 2026
  let values = (
    // Strings: ASCII, other whitespace (no-break, em and ideographic
    // spaces, line and paragraph separators, NEL), characters XML does not
    // allow, hyphens, line breaks, invisible characters that are no
    // whitespace (zero width space, BOM).
    "",
    " ",
    "a",
    "Consulting",
    "INV-2026-102",
    "  a  b  ",
    "a\tb",
    "a\u{00A0}b",
    "a\u{2003}b\u{3000}c",
    "a\u{2028}b\u{2029}c\u{0085}d",
    "a\u{200B}b\u{FEFF}c",
    "x\u{2212}1 A\u{2010}B\u{2011}C",
    "ctrl\u{0}\u{1F}\u{FFFE}chars",
    "line\nbreak",
    "cr\r\nlf\rcr",
    "  Zahlbar   in 30 Tagen. \r\n\t#SKONTO#  \n\n",
    "Café Straße",
    "tab\t\tend ",
    // Content: a single text, sequences of texts and spaces, and what else
    // an item name can hold.
    [],
    [ ],
    [Consulting],
    [Position 0 with a longer description text],
    [Travel & expenses],
    [ spaced ],
    [Café und Straße],
    [Nr. 5, 10 % off],
    [It's "quoted"],
    [A \ B],
    [Line one \ line two],
    [Beratung -- Phase 1],
    [10--12 Uhr],
    [*Bold* name],
    [_Emphasis_ and `raw`],
    [#link("https://example.com")[Site]],
    [Note#footnote[A footnote]],
    [a#h(1em)b#v(1em)c],
    [#box[Boxed] text],
    [#text(fill: red)[Red] text],
    [Rohr $1/2$ Zoll],
    [Fläche 20 m$""^2$],
    [#{ year }-001],
    [x#sym.minus;1],
    [
      Erster Absatz.

      Zweiter Absatz.
    ],
    // Other values
    $x^2 + sqrt(2)$,
    5,
    2.5,
    decimal("-12.50"),
    none,
    auto,
    sym.arrow,
    ("a", [b], 3),
  )
  for value in values {
    assert.eq(plain-text(value), reference(value), message: repr(value))
    assert.eq(
      plain-text(value, keep-newlines: true),
      reference(value, keep-newlines: true),
      message: repr(value),
    )
  }
  // The texts of section 1 to 3 once more, by the shorter way.
  assert.eq(plain-text([Travel & expenses]), "Travel & expenses")
  assert.eq(plain-text([ spaced ]), "spaced")
  assert.eq(plain-text("a\u{00A0} \u{2003}b"), "a b")
  assert.eq(plain-text([Café und Straße]), "Café und Straße")
}
