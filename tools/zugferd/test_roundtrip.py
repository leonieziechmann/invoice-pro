"""The binding table of the round trip of the write guard (G3,
src/zugferd/guard/bindings.json, see src/zugferd/guard/roundtrip.typ)
against the guard tables of every profile (src/zugferd/guard/<profile>.json,
which gen_guard.py generates from the pinned XSDs and Schematrons and
checks for drift).

A binding says from which profile on the XML can state its element (`p`, by
`levels`). That profile and every richer one must have the element at its
position in their schema and use it; every poorer profile must not, so that
the round trip calls a value "dropped" exactly where the profile could have
stated it. Every element and attribute of a binding exists in the schema of
EN 16931, so no binding names an element the XML can never have. A binding
compared as a decimal (an amount, a quantity, a rate) is a decimal leaf of
the schema, whose lexical form the write guard checks (G2) before the round
trip reads it as a decimal.
"""

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GUARD = REPO / "src" / "zugferd" / "guard"
PROFILES = ("minimum", "basic-wl", "basic", "en16931", "xrechnung")
PREFIXES = ("ram:", "rsm:", "udt:", "qdt:")
KINDS = {"t", "a", "a0", "q", "q1", "p", "po", "d", "b"}
# The kinds that compare as decimals: the round trip reads their text as a
# decimal, which only the write guard's check of a decimal leaf (G2) makes
# safe.
DECIMALS = {"a", "a0", "q", "q1", "p", "po"}
LINE = "IncludedSupplyChainTradeLineItem"


def load_bindings():
    return json.loads((GUARD / "bindings.json").read_text(encoding="utf-8"))


def load_table(profile):
    return json.loads((GUARD / f"{profile}.json").read_text(encoding="utf-8"))


def variants(table, index):
    """The complex nodes of the node `index`: the node, or the variants of a
    node the Schematron treats by the value of a discriminator (e.g. an
    allowance or a charge by its indicator)."""
    node = table["nodes"][index]
    if isinstance(node, dict) and "d" in node:
        values = list(node["m"].values()) + [node.get("o")]
        return [table["nodes"][v] for v in values if isinstance(v, int)]
    return [node]


def child(table, index, name):
    """(node index, used) of the child `name` (a local name) of the complex
    node `index`: `used` is false when the profile marks it as not used;
    (None, False) when its schema has no such child there."""
    if index is None:
        return None, False
    found = None
    for node in variants(table, index):
        if not isinstance(node, dict) or "c" not in node:
            continue
        for prefix in PREFIXES:
            tag = prefix + name
            if tag in node["c"]:
                if tag not in node.get("u", {}):
                    return node["c"][tag][4], True
                found = node["c"][tag][4]
    return found, False


def scheme_used(table, index, scheme):
    """Whether the profile uses a tax registration (the node `index`, a
    dispatch by `@schemeID`) of the scheme."""
    node = table["nodes"][index]
    value = node["m"].get(scheme, node.get("o"))
    return isinstance(value, int)


def leaf_kind(table, index):
    """The kind of a leaf node ("s" text, "d" decimal, "b" indicator, "x"
    binary), or None for a node that is no leaf."""
    node = table["nodes"][index]
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return node[0]
    return None


def attributes(table, index):
    """The attributes a leaf node allows, with whether the profile uses them."""
    if index is None:
        return {}
    node = table["nodes"][index]
    if isinstance(node, list) and len(node) > 1 and isinstance(node[1], dict):
        return {name: spec[1] is None for name, spec in node[1].items()}
    return {}


def problems_of(spec, table, index, level, path, out):
    """Problems of the bindings `spec` below the node `index` of a profile of
    the level `level`: a binding whose profiles differ from the table's."""
    for b in spec:
        name = b["e"]
        here = f"{path}/{name}"
        node, used = child(table, index, name)
        stated = node is not None and used
        if "w" in b:
            # A leaf in a wrapper element: the element it wraps.
            here = f"{here}/{b['w']}"
            node, used = child(table, node if stated else None, b["w"])
            stated = node is not None and used
        if "s" in b:
            for scheme, leaf in b["s"].items():
                can = stated and scheme_used(table, node, scheme)
                if can != (leaf["p"] <= level):
                    out.append(f"{here}[{scheme}] ({leaf['t']}): stated from level {leaf['p']}, "
                               f"the profile {'can' if can else 'cannot'} state it")
            continue
        if "m" in b or "r" in b:
            if stated != (b["p"] <= level):
                out.append(f"{here} ({b['t']}): stated from level {b['p']}, the profile "
                           f"{'can' if stated else 'cannot'} state it")
        if "m" in b and stated and (b["k"] in DECIMALS) != (leaf_kind(table, node) == "d"):
            out.append(f"{here} ({b['t']}): the kind {b['k']!r} does not fit the leaf {leaf_kind(table, node)!r}")
        if "m" in b and stated:
            allowed = attributes(table, node)
            for attribute in b.get("a", {}):
                if not allowed.get(attribute, False):
                    out.append(f"{here}/@{attribute} ({b['t']}): the profile does not use the attribute")
        if "c" in b:
            problems_of(b["c"], table, node if stated else None, level, here, out)


def binding_problems(bindings, profile):
    """Problems of the header and line bindings in one profile."""
    table = load_table(profile)
    level = bindings["levels"][profile]
    out = []
    problems_of(bindings["header"], table, 0, level, "CrossIndustryInvoice", out)
    transaction, _ = child(table, 0, "SupplyChainTradeTransaction")
    line, used = child(table, transaction, LINE)
    problems_of(bindings["line"], table, line if used else None, level, LINE, out)
    return out


def shape_problems(bindings):
    """Bindings of an unknown form, kind or level."""
    out = []
    levels = set(bindings["levels"].values())

    def visit(spec, path):
        for b in spec:
            here = f"{path}/{b.get('e')}"
            if not isinstance(b.get("e"), str):
                out.append(f"{here}: no element name")
            if "m" in b:
                if b.get("k") not in KINDS:
                    out.append(f"{here}: unknown kind {b.get('k')!r}")
                if b.get("p") not in levels or not isinstance(b.get("t"), str):
                    out.append(f"{here}: no term or level")
                if not isinstance(b["m"], (str, int)) or not isinstance(b.get("g", ""), (str, int)):
                    out.append(f"{here}: a model key is a text or an index")
                if not isinstance(b.get("w", ""), str):
                    out.append(f"{here}: the element a wrapper holds is a name")
            elif "s" in b:
                for scheme, leaf in b["s"].items():
                    if leaf.get("k") != "t" or leaf.get("p") not in levels or not isinstance(leaf.get("m"), str):
                        out.append(f"{here}[{scheme}]: a tax registration is a text of a key")
            elif "c" in b:
                if "r" in b and (not isinstance(b["r"], list) or b.get("p") not in levels):
                    out.append(f"{here}: a repeated group has the path of its entries and a level")
                visit(b["c"], here)
            else:
                out.append(f"{here}: neither leaf, group nor tax registrations")

    visit(bindings["header"], "header")
    visit(bindings["line"], "line")
    return out


class Bindings(unittest.TestCase):
    def setUp(self):
        self.bindings = load_bindings()

    def test_the_form_of_every_binding(self):
        self.assertEqual(set(self.bindings["levels"]), set(PROFILES))
        self.assertEqual(shape_problems(self.bindings), [])

    def test_the_profiles_of_every_binding(self):
        for profile in PROFILES:
            with self.subTest(profile=profile):
                self.assertEqual(binding_problems(self.bindings, profile), [])

    def test_a_wrong_level_or_name_is_found(self):
        wrong = json.loads(json.dumps(self.bindings))
        document = next(b for b in wrong["header"] if b["e"] == "ExchangedDocument")
        # The document number is stated in every profile, the note from
        # BASIC WL on; an unknown element in none.
        number = next(b for b in document["c"] if b["e"] == "ID")
        number["p"] = 1
        document["c"].append({"e": "Unknown", "t": "BT-0", "m": "x", "k": "t", "p": 0})
        problems = binding_problems(wrong, "minimum")
        self.assertEqual(len(problems), 2)
        self.assertIn("CrossIndustryInvoice/ExchangedDocument/ID (BT-1)", problems[0])
        self.assertIn("Unknown", problems[1])

    def test_a_decimal_binds_a_decimal_leaf(self):
        # The round trip reads the text of an amount as a decimal, which the
        # write guard checks it is; a text is compared as it is.
        wrong = json.loads(json.dumps(self.bindings))
        document = next(b for b in wrong["header"] if b["e"] == "ExchangedDocument")
        next(b for b in document["c"] if b["e"] == "ID")["k"] = "a"
        problems = binding_problems(wrong, "minimum")
        self.assertEqual(len(problems), 1)
        self.assertIn("ExchangedDocument/ID (BT-1): the kind 'a'", problems[0])


if __name__ == "__main__":
    unittest.main()
