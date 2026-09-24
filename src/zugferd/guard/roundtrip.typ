// G3, the round trip of the write guard (concept 4.4): the XML states
// exactly what the data model states. It compares the XML as Typst's XML
// parser reads it back (the document G4 parses anyway, ../zugferd.typ) with
// the model, through a binding table of its own (bindings.json): the syntax
// binding of EN 16931 to CII, business term by business term, independent
// of the builder (build.typ), so that a mistake of the builder cannot hide
// in both.
//
// The table lists the bindings of the children of an element (`header`,
// from the root element, and `line`, from an invoice line), each for the
// child element of the local name `e`:
//
// - a leaf `(e, t: term, m: key, k: kind, p: level)` compares the text of
//   the element with the value `m` (a key or an index) of the model part
//   the walk is at, or of its part `g` if given; `a` maps attributes of the
//   element to the paths of their values below that part;
// - `(e, c: bindings)` is an element that occurs once and whose children
//   the bindings `c` describe, at the model part `g` if given;
// - `(e, r: path, t: term, p: level, c: bindings)` is a repeated group: one
//   element per entry of the array at `path`;
// - `(e, s: (scheme: leaf))` are the tax registrations of a party, an
//   identifier per scheme.
//
// `p` is the first profile (by `levels`) whose schema has the element and
// whose Factur-X Schematron uses it (tools/zugferd/test_roundtrip.py checks
// every binding against the guard tables of every profile, which
// gen_guard.py compiles from the pinned XSDs and Schematrons). Findings:
//
// - differs: the XML states another value than the model;
// - dropped: the model has a value the XML does not state, although the
//   profile can state it;
// - extra: the XML states a value the model does not have;
// - count: an element occurs more often than the model has values for it,
//   or a repeated group (e.g. the VAT breakdown) has another number of
//   entries than the model.
//
// Values compare by their kind: "t" texts and codes as they are; amounts
// "a", quantities and prices "q" and rates "p" (in percent) as decimals, so
// "19.00" is 0.19 in the model; "a0" an amount and "q1" a quantity the XML
// leaves out when it is 0 or 1, "po" a rate it leaves out for the VAT
// category O (BR-O-05 to BR-O-07); "d" dates in the format 102; "b"
// indicators. Every finding is an error of the guard (report.typ names its
// rule and input field, and merges it with the validator's diagnostics).
//
// In the standard mode, the bindings of the header run: document, parties,
// references, delivery, payment, VAT breakdown, allowances and charges, and
// the totals; of the lines, only their number. The bindings of every line
// and the arithmetic of the written amounts run in the strict mode
// (`zugferd-strict: true`, strict.typ), which CI uses: comparing a line
// takes about 1.6 million instructions (0.4 ms), twenty times the budget of
// 0.02 ms for a check per line (tools/perf/README.md). The header takes
// about 7.5 million, whatever the number of lines.
//
// Performance: one call walks the whole document, with a stack instead of a
// call per element; an element and a binding cost a handful of operations
// when the values agree, and texts compare as strings first. A part of the
// model the invoice does not have (a payee, a ship-to party) is skipped
// with its elements, and the lines are counted without a step per line.

#let _table = json("bindings.json")
#let _levels = _table.levels

#let _zero = decimal("0")
#let _one = decimal("1")
#let _hundred = decimal("100")

// The element of an invoice line.
#let _line = "IncludedSupplyChainTradeLineItem"

// Lexical space of xs:decimal (as write.typ checks it).
#let _decimal = regex("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)$")

// Whether `text` (`none`: the XML leaves the element out) states the model
// value `value` of the kind `kind` (see the top of this file). `category` is
// the VAT category of the entry, for the kind "po".
#let _same(kind, text, value, category) = {
  if kind == "t" {
    return (
      text
        == if value == none or type(value) == str { value } else if (
          type(value) in (int, decimal)
        ) { str(value) }
    )
  }
  if kind == "d" {
    return (
      text
        == if type(value) == datetime and value.year() != none {
          value.display("[year][month][day]")
        }
    )
  }
  if kind == "b" {
    return (
      text
        == if value == true { "true" } else if value == false {
          "false"
        } else { value }
    )
  }
  if kind == "po" and category == "O" { value = none }
  if value != none {
    if kind in ("p", "po") { value = value * _hundred } else if (
      kind == "a0" and value == _zero
    ) { value = none } else if kind == "q1" and value == _one { value = none }
  }
  if value == none or text == none { return value == text }
  type(text) == str and _decimal in text and decimal(text) == value
}

// A finding (see the top of this file): `path` of local names, an entry of
// a repeated group as `(name, number)`, `expected` the value of the model,
// of the kind `k`. report.typ qualifies the path and shows the value.
#let _found(kind, path, term, stated, expected, k: none) = (
  kind: kind,
  rule: none,
  path: path,
  term: term,
  stated: stated,
  expected: expected,
  k: k,
)

/// G3: compares the parsed XML (`root`, its root element) with the data
/// model `model`, through the bindings of its header and, with `strict`,
/// of every line (see the top of this file). `terms` are the payment terms
/// the profile states (`profile-terms` of model.typ), which the model holds
/// in two forms; the date of a preceding invoice (BT-26) is stated only
/// with its number (BT-25). Returns the findings.
///
/// The caller runs it only on a document the serializer wrote without text
/// between elements (G1 reports that as "text"), so every child of an
/// element with children is an element.
///
/// One call walks the whole document, with a stack instead of a call per
/// element (a call hashes its arguments: the document and the model).
///
/// -> array
#let round-trip(root, model, terms, strict: false) = {
  let level = _levels.at(model.profile.id, default: 3)
  let invoice = model.invoice
  let derived = (
    terms: terms,
    preceding-date: if (
      invoice.at("preceding-invoice-nr", default: none) != none
    ) { invoice.at("preceding-invoice-date", default: none) },
  )
  let found = ()
  let stack = (
    (root, _table.header, model + (round-trip: derived), (root.tag,)),
  )
  while stack != () {
    let (node, spec, base, path) = stack.pop()
    // The elements below `node` by name; those that occur more than once
    // also in `many`.
    let children = (:)
    let many = (:)
    if node != none {
      let all = node.children
      if node.tag == "SupplyChainTradeTransaction" {
        // The lines (BG-25) precede the other elements of the transaction,
        // in the order of the schema that G1 checks: counted from the end,
        // without a step per line, and compared in the strict mode only.
        let k = 0
        for child in all.rev() {
          if child.tag == _line { break }
          k += 1
        }
        let lines = all.slice(0, all.len() - k)
        all = all.slice(all.len() - k)
        let entries = if level >= 2 { base.lines } else { () }
        let here = path + (_line,)
        if lines.len() != entries.len() {
          found.push(_found("count", here, "BG-25", lines.len(), entries.len()))
        }
        if strict {
          let n = 0
          for (element, line) in lines.zip(entries) {
            n += 1
            // The allowances and charges of the line in the order of the
            // XML, and the scheme of its standard identifier (GTIN).
            let adjustments = ()
            for a in line.allowances { adjustments.push(a + (charge: false)) }
            for c in line.charges { adjustments.push(c + (charge: true)) }
            stack.push((
              element,
              _table.line,
              line
                + (
                  adjustments: adjustments,
                  standard-scheme: if line.standard-id != none { "0160" },
                ),
              path + ((_line, n),),
            ))
          }
        }
      }
      for child in all { children.insert(child.tag, child) }
      if children.len() != all.len() {
        // Some element occurs more than once: the first one in `children`,
        // all of them in `many`.
        children = (:)
        for child in all {
          let tag = child.tag
          if tag not in children { children.insert(tag, child) } else if (
            tag in many
          ) { many.at(tag).push(child) } else {
            many.insert(tag, (children.at(tag), child))
          }
        }
      }
    }
    for b in spec {
      let element = children.at(b.e, default: none)
      if "m" in b {
        // A leaf.
        let value = if "g" not in b { base.at(b.m, default: none) } else {
          let part = base.at(b.g, default: none)
          if part != none { part.at(b.m, default: none) }
        }
        if element == none {
          // Lost, unless the profile cannot state it, or the XML leaves the
          // value out by its kind.
          if (
            value != none
              and level >= b.p
              and not _same(b.k, none, value, if b.k == "po" {
                base.at("category", default: none)
              })
          ) {
            found.push(_found(
              "dropped",
              path + (b.e,),
              b.t,
              none,
              value,
              k: b.k,
            ))
          }
          continue
        }
        if element.children != (value,) {
          let text = element.children.first(default: none)
          let category = if b.k == "po" { base.at("category", default: none) }
          if not _same(b.k, text, value, category) {
            let extra = _same(b.k, none, value, category)
            found.push(_found(
              if extra { "extra" } else { "differs" },
              path + (b.e,),
              b.t,
              if type(text) == str { text } else { "" },
              if not extra { value },
              k: b.k,
            ))
          }
        }
        if b.e in many {
          found.push(_found(
            "count",
            path + (b.e,),
            b.t,
            many.at(b.e).len(),
            1,
          ))
        }
        if "a" not in b { continue }
        // The attributes of the element.
        for (attribute, keys) in b.a {
          let expected = base
          for key in keys {
            if expected != none { expected = expected.at(key, default: none) }
          }
          if expected != none and type(expected) != str {
            expected = str(expected)
          }
          let stated = element.attrs.at(attribute, default: none)
          if stated != expected {
            found.push(_found(
              if stated == none { "dropped" } else if expected == none {
                "extra"
              } else { "differs" },
              path + (b.e, "@" + attribute),
              b.t,
              stated,
              expected,
            ))
          }
        }
      } else if "c" in b and "r" not in b {
        // An element that occurs once. A part of the model the invoice does
        // not have (e.g. a payee) is skipped unless the XML states it.
        let part = if "g" in b { base.at(b.g, default: none) } else { base }
        if part == none {
          if element == none { continue }
          part = (:)
        }
        stack.push((element, b.c, part, path + (b.e,)))
        if b.e in many {
          found.push(_found(
            "count",
            path + (b.e,),
            none,
            many.at(b.e).len(),
            1,
          ))
        }
      } else if "r" in b {
        // A repeated group: one element per entry of the model.
        let entries = base
        for key in b.r {
          if entries != none { entries = entries.at(key, default: none) }
        }
        if entries == none or level < b.p { entries = () }
        let elements = many.at(b.e, default: if element == none { () } else {
          (element,)
        })
        if elements.len() != entries.len() {
          found.push(_found(
            "count",
            path + (b.e,),
            b.t,
            elements.len(),
            entries.len(),
          ))
        }
        let n = 0
        for (element, entry) in elements.zip(entries) {
          n += 1
          stack.push((element, b.c, entry, path + ((b.e, n),)))
        }
      } else {
        // Tax registrations: an identifier per scheme.
        let here = path + (b.e, "ID")
        let stated = (:)
        let elements = many.at(b.e, default: if element == none { () } else {
          (element,)
        })
        for element in elements {
          for child in element.children {
            if child.tag != "ID" { continue }
            let scheme = child.attrs.at("schemeID", default: "")
            if scheme in stated {
              found.push(_found("count", here, scheme, 2, 1))
            }
            stated.insert(scheme, child.children.first(default: ""))
          }
        }
        for (scheme, leaf) in b.s {
          let value = base.at(leaf.m, default: none)
          let text = stated.remove(scheme, default: none)
          if text == value { continue }
          if text != none {
            found.push(_found(
              if value == none { "extra" } else { "differs" },
              here,
              leaf.t,
              text,
              value,
            ))
          } else if level >= leaf.p {
            found.push(_found("dropped", here, leaf.t, none, value))
          }
        }
        for (scheme, text) in stated {
          found.push(_found("extra", here, scheme, text, none))
        }
      }
    }
  }
  found
}
