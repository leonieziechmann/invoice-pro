// Serialization helpers of the ZUGFeRD XML: plain text extraction from
// content, number formatting and the dictionary to XML conversion.

#import "/src/zugferd/xml.typ": (
  dict-to-xml, fmt-amount, fmt-date, fmt-number, fmt-price, fmt-quantity,
  fmt-rate, plain-text, xml-escape,
)

// --- 1. plain-text: what the content reads on the page ---
#{
  assert.eq(plain-text("Fish & Chips"), "Fish & Chips")
  assert.eq(plain-text(none), "")
  assert.eq(plain-text(auto), "")
  assert.eq(plain-text(decimal("-12.5")), "-12.5")
  assert.eq(plain-text(("a", [b])), "a b")

  // Styled text, emphasis, links and boxes keep their text
  assert.eq(
    plain-text([*Bold* and _emph_ with #text(weight: "bold")[styled] text]),
    "Bold and emph with styled text",
  )
  assert.eq(plain-text(text(fill: red)[Styled as a whole]), "Styled as a whole")
  assert.eq(plain-text([#link("https://x.y")[Website] setup]), "Website setup")
  assert.eq(plain-text([Suite #box[B]]), "Suite B")

  // Smart quotes, shorthands and symbols
  assert.eq(plain-text(["quoted" and 'single']), "\"quoted\" and 'single'")
  assert.eq(plain-text([a -- b --- c]), "a – b — c")
  assert.eq(plain-text([#sym.arrow.r x]), "→ x")

  // Breaks and spacing collapse into single spaces
  assert.eq(plain-text([Line one \ line two]), "Line one line two")
  assert.eq(plain-text([A #h(1em) B]), "A B")
  assert.eq(
    plain-text([
      - a
      - b
    ]),
    "a b",
  )

  // Footnotes are not part of the text; characters XML cannot carry are removed
  assert.eq(plain-text([Name#footnote[note]]), "Name")
  assert.eq(plain-text("a\u{1}b\u{7}c"), "abc")
}

// --- 2. xml-escape ---
#{
  assert.eq(
    xml-escape("<a href=\"x\">R&D's</a>"),
    "&lt;a href=&quot;x&quot;&gt;R&amp;D&apos;s&lt;/a&gt;",
  )
  assert.eq(xml-escape([*A* & B]), "A &amp; B")
  assert.eq(xml-escape("a\u{0}b"), "ab")
}

// --- 3. Numbers: "." separator, ASCII minus, rounding half away from zero ---
#{
  assert.eq(fmt-amount(decimal("-2")), "-2.00")
  assert.eq(fmt-amount(1234.5), "1234.50")
  assert.eq(fmt-amount(decimal("0.005")), "0.01")
  assert.eq(fmt-amount(decimal("-0.005")), "-0.01")
  assert.eq(fmt-amount(decimal("-0.001")), "0.00")
  assert.eq(fmt-amount(none), "0.00")

  // Prices and quantities keep their decimals
  assert.eq(fmt-price(decimal("0.1234")), "0.1234")
  assert.eq(fmt-price(decimal("16.7983193277")), "16.798319")
  assert.eq(fmt-price(100), "100.00")
  assert.eq(fmt-quantity(decimal("0.125")), "0.125")
  assert.eq(fmt-quantity(decimal("-2")), "-2.00")

  assert.eq(fmt-number(decimal("7.50"), min-digits: 0), "7.5")
  assert.eq(fmt-number(19, min-digits: 0), "19")

  assert.eq(fmt-rate(19%), "19.00")
  assert.eq(fmt-rate(decimal("0.055")), "5.50")
  assert.eq(fmt-rate(0%), "0.00")

  assert.eq(fmt-date(datetime(year: 2026, month: 7, day: 6)), "20260706")
  assert.eq(fmt-date(none), none)
}

// --- 4. dict-to-xml ---
#{
  // Attributes, text, repeated elements and empty structural elements
  assert.eq(
    dict-to-xml((
      a: (
        b: "x & y",
        f: ("@s": "2", "": "v"),
        g: (:),
        h: ("1", "2"),
      ),
    )),
    "<a><b>x &amp; y</b><f s=\"2\">v</f><g /><h>1</h><h>2</h></a>",
  )

  // Missing values leave the element out instead of writing it empty
  assert.eq(
    dict-to-xml((
      a: (
        b: none,
        c: "",
        d: "  ",
        e: ("@schemeID": "VA", "": none),
        f: ("@schemeID": none, "": "v"),
      ),
    )),
    "<a><f>v</f></a>",
  )
}
