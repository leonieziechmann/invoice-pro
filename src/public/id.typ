// Typed party identifiers, one constructor per scheme. A constructor never
// stops the compilation: an e-invoice reports its `problems` (IP-ID-01).

#import "../utils/text.typ": plain-text

// Compiled on first use only: most invoices create no typed identifier.
#let _patterns() = (
  // Whitespace and invisible format characters.
  blank: regex("[\\s\\p{Cf}]+"),
  // Invisible characters, and the spaces left around them.
  invisible: regex("\\p{Cf}"),
  spaces: regex(" {2,}"),
  separators: regex("[\\s\\p{Cf}./-]+"),
  digits: regex("^[0-9]+$"),
  uid-ch: regex("^CHE[0-9]{9}$"),
  uid-ch-suffix: regex("(MWST|TVA|IVA|HR|RC)+$"),
  leitweg: regex("^[0-9]{2,12}(-[0-9A-Z]{1,30})?-[0-9]{2}$"),
  lower: regex("[a-z]"),
)

#let _quoted(text) = "\"" + text + "\""

#let _text(value) = {
  if value == none or value == auto { return "" }
  if type(value) in (str, content, symbol, int) { return plain-text(value) }
  none
}

#let _result(scheme, id, kind, problems) = (
  scheme: scheme,
  id: id,
  kind: kind,
  problems: problems,
)

#let _type-problem(name, value) = (
  "The "
    + name
    + " must be given as text, e.g. `\"..\"`, but it is "
    + repr(type(value))
    + "."
)

// --- Check digits ---

// Luhn (ISO/IEC 7812-1).
#let _luhn(digits) = {
  let total = 0
  let double = false
  for digit in digits.codepoints().rev() {
    let value = int(digit)
    if double {
      value *= 2
      if value > 9 { value -= 9 }
    }
    total += value
    double = not double
  }
  calc.rem(total, 10) == 0
}

// GS1 check digit (weights 3 and 1).
#let _gs1(digits) = {
  let values = digits.codepoints()
  let total = 0
  let weight = 3
  for digit in values.slice(0, -1).rev() {
    total += int(digit) * weight
    weight = 4 - weight
  }
  calc.rem(10 - calc.rem(total, 10), 10) == int(values.last())
}

// Luhn, or for La Poste (SIREN 356 000 000) a digit sum divisible by 5.
#let _siret-check(digits) = {
  if _luhn(digits) { return true }
  if not digits.starts-with("356000000") { return false }
  let total = 0
  for digit in digits.codepoints() { total += int(digit) }
  calc.rem(total, 5) == 0
}

// Swiss UID: modulo 11 (eCH-0097); a check digit 10 is never assigned.
#let _uid-ch-check(id) = {
  let digits = id.slice(3).codepoints()
  let total = 0
  for (digit, weight) in digits.slice(0, 8).zip((5, 4, 3, 2, 7, 6, 5, 4)) {
    total += int(digit) * weight
  }
  let rest = calc.rem(total, 11)
  let check = if rest == 0 { 0 } else { 11 - rest }
  check != 10 and check == int(digits.last())
}

// ISO/IEC 7064 MOD 97-10 (A = 10 .. Z = 35); valid if it leaves 1.
#let _mod97(text) = {
  let rest = 0
  for character in text.codepoints() {
    if character in "0123456789" {
      rest = calc.rem(rest * 10 + int(character), 97)
    } else {
      rest = calc.rem(rest * 100 + str.to-unicode(character) - 55, 97)
    }
  }
  rest
}

// --- Numeric identifiers ---

#let _numeric(value, scheme, kind, name, length, example, check) = {
  let text = _text(value)
  if text == none {
    return _result(scheme, "", kind, (_type-problem(name, value),))
  }
  let patterns = _patterns()
  let id = text.replace(patterns.separators, "")
  let problems = ()
  if id == "" {
    problems.push("The " + name + " is empty.")
  } else if id.match(patterns.digits) == none or id.len() != length {
    problems.push(
      "The "
        + name
        + " "
        + _quoted(text)
        + " must have "
        + str(length)
        + " digits, e.g. "
        + _quoted(example)
        + ".",
    )
  } else if check != none and not check(id) {
    problems.push(
      "The check digit of the " + name + " " + _quoted(text) + " is wrong.",
    )
  }
  _result(scheme, id, kind, problems)
}

/// A Global Location Number (GLN) of GS1, scheme `0088`.
///
/// -> dictionary
#let gln(
  /// The GLN, e.g. `"4000001123452"`.
  /// -> str | content | int
  value,
) = _numeric(value, "0088", "party", "GLN", 13, "4000001123452", _gs1)

/// A D-U-N-S number of Dun & Bradstreet, scheme `0060`.
///
/// -> dictionary
#let duns(
  /// The D-U-N-S number, e.g. `"15-048-3782"`.
  /// -> str | content | int
  value,
) = _numeric(value, "0060", "party", "D-U-N-S number", 9, "150483782", none)

/// The SIREN of a French company, scheme `0002`.
///
/// -> dictionary
#let siren(
  /// The SIREN, e.g. `"123 456 782"`.
  /// -> str | content | int
  value,
) = _numeric(value, "0002", "legal", "SIREN", 9, "123456782", _luhn)

/// The SIRET of a French establishment, scheme `0009`.
///
/// -> dictionary
#let siret(
  /// The SIRET, e.g. `"123 456 782 00010"`.
  /// -> str | content | int
  value,
) = _numeric(
  value,
  "0009",
  "legal",
  "SIRET",
  14,
  "12345678200010",
  _siret-check,
)

/// The Swiss enterprise identification number (UID), scheme `0183`.
///
/// -> dictionary
#let uid-ch(
  /// The UID, e.g. `"CHE-123.456.788"`.
  /// -> str | content
  value,
) = {
  let name = "Swiss UID"
  let text = _text(value)
  if text == none {
    return _result("0183", "", "legal", (_type-problem(name, value),))
  }
  let patterns = _patterns()
  let id = upper(text.replace(patterns.separators, "")).replace(
    patterns.uid-ch-suffix,
    "",
  )
  let problems = ()
  if id == "" {
    problems.push("The " + name + " is empty.")
  } else if id.match(patterns.uid-ch) == none {
    problems.push(
      "The "
        + name
        + " "
        + _quoted(text)
        + " must be \"CHE\" followed by 9 digits, e.g. \"CHE-123.456.788\".",
    )
  } else if not _uid-ch-check(id) {
    problems.push(
      "The check digit of the " + name + " " + _quoted(text) + " is wrong.",
    )
  }
  _result("0183", id, "legal", problems)
}

/// A register number without a scheme, stated after its `court`.
///
/// -> dictionary
#let register(
  /// The register number, e.g. `"HRB 4711"`.
  /// -> str | content | int
  value,
  /// The register court, e.g. `"Amtsgericht München"`.
  /// -> none | str | content
  court: none,
) = {
  let name = "register number"
  let number = _text(value)
  let court-text = _text(court)
  let problems = ()
  if number == none {
    problems.push(_type-problem(name, value))
    number = ""
  }
  if court-text == none {
    problems.push(_type-problem("register court", court))
    court-text = ""
  }
  let patterns = _patterns()
  let visible(text) = (
    text.replace(patterns.invisible, "").replace(patterns.spaces, " ").trim()
  )
  number = visible(number)
  court-text = visible(court-text)
  if number == "" and problems == () {
    problems.push("The " + name + " is empty.")
  }
  let id = if court-text == "" { number } else if number == "" {
    court-text
  } else { court-text + ", " + number }
  _result(none, id, "legal", problems)
}

/// The Leitweg-ID of a German public buyer (BT-10, EAS `0204`).
///
/// -> dictionary
#let leitweg(
  /// The Leitweg-ID, e.g. `"04011000-1234512345-06"`.
  /// -> str | content
  value,
) = {
  let name = "Leitweg-ID"
  let text = _text(value)
  if text == none {
    return _result("0204", "", "routing", (_type-problem(name, value),))
  }
  let patterns = _patterns()
  let id = text.replace(patterns.blank, "")
  let problems = ()
  if id == "" {
    problems.push("The " + name + " is empty.")
  } else if id.match(patterns.leitweg) == none {
    problems.push(
      "The "
        + name
        + " "
        + _quoted(text)
        + " must consist of up to 12 digits, optionally up to 30 "
        + if id.contains(patterns.lower) { "capital " } else { "" }
        + "letters and digits, and 2 check digits, separated by \"-\", e.g. \"04011000-1234512345-06\".",
    )
  } else if _mod97(id.replace("-", "")) != 1 {
    problems.push(
      "The check digits of the " + name + " " + _quoted(text) + " are wrong.",
    )
  }
  _result("0204", id, "routing", problems)
}

/// An identifier with the code of its scheme, not checked.
///
/// -> dictionary
#let custom(
  /// The code of the scheme, e.g. `"0208"`.
  /// -> str | content
  scheme,
  /// The identifier.
  /// -> str | content | int
  id,
) = {
  let patterns = _patterns()
  let scheme-text = _text(scheme)
  let id-text = _text(id)
  let problems = ()
  if scheme-text == none {
    problems.push(_type-problem("scheme of the identifier", scheme))
    scheme-text = ""
  }
  if id-text == none {
    problems.push(_type-problem("identifier", id))
    id-text = ""
  }
  let scheme-code = upper(scheme-text.replace(patterns.blank, ""))
  let value = id-text.replace(patterns.blank, "")
  if scheme-code == "" and problems == () {
    problems.push(
      "The identifier "
        + _quoted(id-text)
        + " has no scheme: `id.custom` takes the code of the scheme first, e.g. `id.custom(\"0208\", \"0123456749\")`.",
    )
  }
  if value == "" and problems == () {
    problems.push(
      "The identifier of the scheme " + _quoted(scheme-code) + " is empty.",
    )
  }
  _result(
    if scheme-code == "" { none } else { scheme-code },
    value,
    "custom",
    problems,
  )
}
