// The notes of an invoice (BT-22, subject code BT-21).

/// Normalizes the `notes` of an invoice, a text or an array of texts and
/// `(text: .., subject-code: ..)` (UNTDID 4451), into such dictionaries.
///
/// -> array
#let normalize-notes(notes) = {
  if notes == none { return () }
  let entries = if type(notes) == array { notes } else { (notes,) }
  let result = ()
  for (i, entry) in entries.enumerate() {
    let (text, code) = if type(entry) in (str, content) {
      (entry, none)
    } else if (
      type(entry) == dictionary
        and entry.keys().all(key => key in ("text", "subject-code"))
        and type(entry.at("text", default: none)) in (str, content)
        and type(entry.at("subject-code", default: none)) in (str, type(none))
    ) {
      (entry.text, entry.at("subject-code", default: none))
    } else {
      panic(
        "invoice::notes must be a text, or an array of texts and dictionaries `(text: .., subject-code: ..)`, got "
          + repr(entry)
          + if type(notes) == array { " at index " + str(i) }
          + ".",
      )
    }
    result.push((text: text, subject-code: code))
  }
  result
}
