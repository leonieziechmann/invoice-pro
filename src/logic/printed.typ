// What the printed invoice shows besides the components, for IP-PRINT-03 and
// IP-PERIOD-03; known only where the theme says so (`prints`).

#import "../utils/text.typ": plain-text

/// What the root context knows about the printed invoice, `known` if the
/// theme says that it prints the reference signs.
///
/// -> dictionary
#let printed-record(theme, references, sender, recipient, body) = {
  let prints = theme.at("prints", default: (:))
  let party-extra = prints.at("party-extra", default: false)
  let lines = ()
  for party in (sender, recipient) {
    for key in ("name", "address", "city") {
      lines.push(party.at(key, default: none))
    }
  }
  (
    known: prints.at("references", default: false) == true,
    references: references,
    lines: lines,
    extra: if party-extra {
      (sender.at("extra", default: ()), recipient.at("extra", default: ()))
    } else { () },
    page-content: prints.at("page-content", default: false) == true,
    body: body,
  )
}

// A text as it is compared: in upper case, without spaces, dashes as "-", so
// that "DE 123 456 789" shows "DE123456789".
#let _compact(text) = (
  upper(text).replace(" ", "").replace("\u{2013}", "-").replace("\u{2014}", "-")
)

#let _shows(value, wanted) = {
  let text = _compact(plain-text(value))
  if text == "" { return false }
  for part in wanted {
    if text.contains(part) { return true }
  }
  false
}

#let _search(printed, wanted, except: ()) = {
  for reference in printed.at("references", default: ()) {
    if type(reference) != array or reference.len() != 2 { continue }
    if except.len() > 0 and plain-text(reference.first()) in except {
      continue
    }
    if _shows(reference.last(), wanted) { return true }
  }
  for line in printed.at("lines", default: ()) {
    if _shows(line, wanted) { return true }
  }
  for extra in printed.at("extra", default: ()) {
    let values = if type(extra) == dictionary { extra.values() } else if (
      type(extra) == array
    ) {
      extra.map(entry => if type(entry) == array { entry.last() } else {
        entry
      })
    } else { (extra,) }
    for value in values {
      if _shows(value, wanted) { return true }
    }
  }
  // The text of the invoice, e.g. `#info.sender.vat-id` in a closing note.
  _shows(printed.at("body", default: none), wanted)
}

#let _wanted(values) = {
  let wanted = ()
  for value in values {
    if value == none { continue }
    let text = _compact(plain-text(value))
    if text != "" { wanted.push(text) }
  }
  wanted
}

#let _known(printed) = (
  type(printed) == dictionary and printed.at("known", default: false)
)

/// Whether the printed invoice shows one of `identifiers`; `none` if unknown,
/// also when the theme prints content of its own on every page (a footer).
///
/// -> none | bool
#let shows-identifier(printed, identifiers) = {
  if not _known(printed) { return none }
  let wanted = _wanted(identifiers)
  if wanted.len() == 0 { return none }
  if _search(printed, wanted) { return true }
  if printed.at("page-content", default: false) { return none }
  false
}

/// Whether the printed invoice shows `value` other than in the references
/// titled one of `except`; `none` if the theme does not say what it prints.
///
/// -> none | bool
#let shows-text(printed, value, except: ()) = {
  if not _known(printed) { return none }
  let wanted = _wanted((value,))
  if wanted.len() == 0 { return none }
  _search(printed, wanted, except: except)
}
