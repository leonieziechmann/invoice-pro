// The code lists of the XML guard and of the validator, and the rules of
// the VAT categories, as tools/zugferd/gen_guard.py compiles them from the
// official artefacts into lists.json (do not edit it: rerun the generator;
// scripts/zugferd-corpus checks for drift). Each code list is the
// intersection of the lists of every validator that applies where a profile
// uses it (see the tables of the profiles, <profile>.json next to this
// file).
//
// A list is a string of its codes, each between two spaces: a code without
// spaces is in a list when `" " + code + " "` is in the string, one
// substring search. lists.json has the codes of a list in lines, joined
// here. The lists are JSON, as Typst reads JSON natively: loading them took
// three times as long as Typst source.

#let _data = json("lists.json")

/// The code lists by name.
///
/// -> dictionary
#let lists = {
  let out = (:)
  for (name, lines) in _data.lists {
    out.insert(name, " " + lines.join(" ") + " ")
  }
  out
}

/// The rules of the VAT categories on the tax of a line (BG-30), a VAT
/// breakdown (BG-23), an allowance and a charge, by name: per category code,
/// the checks (check, value, rule) of the rate ("r": 1 above 0, 0 zero, none
/// absent, "any" there), the VAT amount ("a": 0) and the exemption reason
/// ("e": true required, false forbidden); see write.typ.
///
/// -> dictionary
#let vat-rules = _data.vat-rules

/// The code lists of the validator (src/zugferd/rules/); see VALIDATOR_LISTS
/// of tools/zugferd/gen_guard.py. Per name and kind, a list of `lists` the
/// entry names (e.g. `every`, `factur-x`) or codes of the entry's own (e.g.
/// `newer`, the codes only the newest version of the EN 16931 code list
/// has), as a string of codes like a list of `lists`.
///
/// -> dictionary
#let validator = {
  let out = (:)
  for (name, entry) in _data.validator {
    let kinds = (:)
    for (kind, value) in entry {
      kinds.insert(kind, if type(value) == array {
        " " + value.join(" ") + " "
      } else { lists.at(value) })
    }
    out.insert(name, kinds)
  }
  out
}
