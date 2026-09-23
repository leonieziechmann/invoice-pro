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
