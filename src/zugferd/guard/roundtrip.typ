// G3, the round trip of the write guard (concept 4.4): the XML, as Typst's
// parser reads it back for G4 (../zugferd.typ), states exactly what the data
// model states. The binding table (bindings.json) is the syntax binding of
// EN 16931 to CII, maintained apart from the builder (build.typ) so that a
// mistake of the builder cannot hide in both;
// tools/zugferd/test_roundtrip.py checks it against the schemas of the
// profiles.
//
// The table lists the bindings of the children of the root element
// (`header`) and of an invoice line (`line`), each for the child element of
// the local name `e`:
//
// - a leaf `(e, t: term, m: key, k: kind, p: level)` compares the text of
//   the element (with `w`, of the element `w` it wraps) with the value `m`
//   (a key or an index) of the model part at hand, or of its part `g`; `a`
//   maps attributes to the paths of their values below that part;
// - `(e, c: bindings)` is an element whose children `c` describe, at the
//   model part `g` if given (a part the model does not have is skipped);
// - `(e, r: path, t: term, p: level, c: bindings)` a repeated group: an
//   element per entry of the array at `path`;
// - `(e, s: (scheme: leaf))` the tax registrations of a party.
//
// `p` is the first profile (by `levels`) that can state the element. Kinds:
// "t" text, "d" date (format 102), "b" indicator; decimals: "a" amount, "q"
// quantity or price, "p" rate in percent ("19.00" is 0.19 in the model),
// "a0" and "q1" an amount 0 and a quantity 1 the XML leaves out, "po" a
// rate it leaves out for the VAT category O.
//
// Findings (errors, see report.typ): "differs", another value; "dropped", a
// value of the model the XML leaves out although the profile can state it;
// "extra", a value the model does not have; "count", an element more often
// than the model has values for it, or another number of entries of a
// repeated group.
//
// The standard mode compares the header and counts the lines; the strict
// mode (`zugferd-strict`, which CI uses) compares every line as well: that
// takes about 1.6 million instructions (0.4 ms) per line, twenty times the
// budget of a check per line (tools/perf/README.md). One call walks the
// document with a stack, without a call per element.

#let _table = json("bindings.json")

#let _zero = decimal("0")
#let _one = decimal("1")
#let _hundred = decimal("100")

// The element of an invoice line.
#let _line = "IncludedSupplyChainTradeLineItem"

// Whether `text` (`none`: the element is left out) states the model value
// `value` of the kind `kind`; `category` is the VAT category of the entry
// (for "po"). Decimals compare by value: the round trip runs on a document
// the serializer wrote without findings, so every number of it has the
// lexical form of a decimal (G2).
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
  if value != none {
    if kind == "po" and category == "O" { value = none } else if (
      kind in ("p", "po")
    ) { value = value * _hundred } else if kind == "a0" and value == _zero {
      value = none
    } else if kind == "q1" and value == _one { value = none }
  }
  if value == none or text == none { return value == text }
  type(text) == str and decimal(text) == value
}

// A finding: `path` of local names, an entry of a repeated group as
// `(name, number)`; `expected` the value of the model, of the kind `k`.
// report.typ qualifies the path and shows the values.
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
/// model `model` through the bindings of its header and, with `strict`, of
/// every line (see the top of this file). `terms` are the payment terms the
/// profile states (`profile-terms` of model.typ); the date of a preceding
/// invoice (BT-26) is stated only with its number (BT-25). Returns the
/// findings.
///
/// The caller runs it on a document the serializer wrote without findings
/// (G1, G2): every element is known at its position and every value has its
/// lexical form.
///
/// -> array
#let round-trip(root, model, terms, strict: false) = {
  let level = _table.levels.at(model.profile.id, default: 3)
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
    // The child elements by name; those that occur more than once also in
    // `many`.
    let children = (:)
    let many = (:)
    if node != none {
      let all = node.children
      if node.tag == "SupplyChainTradeTransaction" {
        // The lines (BG-25) come first, in schema order (G1): counted from
        // the end, without a step per line, and compared in the strict mode.
        let k = 0
        for child in all.rev() {
          if child.tag == _line { break }
          k += 1
        }
        let lines = all.slice(0, all.len() - k)
        all = all.slice(all.len() - k)
        let entries = if level >= 2 { base.lines } else { () }
        if lines.len() != entries.len() {
          found.push(_found(
            "count",
            path + (_line,),
            "BG-25",
            lines.len(),
            entries.len(),
          ))
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
        if element != none {
          if b.e in many {
            found.push(_found(
              "count",
              path + (b.e,),
              b.t,
              many.at(b.e).len(),
              1,
            ))
          }
          if "w" in b {
            // The element the wrapper holds, its only child.
            let inner = element.children
            element = inner.first(default: none)
            if inner.len() != 1 or element.tag != b.w {
              let named = ()
              for child in inner {
                if child.tag == b.w { named.push(child) }
              }
              if named.len() > 1 {
                found.push(_found(
                  "count",
                  path + (b.e, b.w),
                  b.t,
                  named.len(),
                  1,
                ))
              }
              element = named.first(default: none)
            }
          }
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
              path + (b.e,) + if "w" in b { (b.w,) } else { () },
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
              path + (b.e,) + if "w" in b { (b.w,) } else { () },
              b.t,
              if type(text) == str { text } else { "" },
              if not extra { value },
              k: b.k,
            ))
          }
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
              path
                + (b.e,)
                + if "w" in b { (b.w,) } else { () }
                + ("@" + attribute,),
              b.t,
              stated,
              expected,
            ))
          }
        }
      } else if "r" in b {
        // A repeated group: an element per entry of the model.
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
      } else if "c" in b {
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
