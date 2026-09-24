"""Unit tests of the generator of the XML write guard (gen_guard.py).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

The tests of the parts run on small synthetic schemas and rules and need
only lxml. With the Mustang CLI jar 2.14.0 ($MUSTANG_JAR) and the KoSIT
XRechnung configuration ($KOSIT_CONFIG), the tables are also regenerated:
they must equal the committed ones (drift test), come out the same twice,
and stay within the size budget.
"""

import io
import json
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import gen_guard as g  # noqa: E402

RSM = "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
RAM = "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"


def xsd(namespace, body, qualified=True):
    form = ' elementFormDefault="qualified"' if qualified else ""
    return (
        f'<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:rsm="{RSM}" '
        f'xmlns:ram="{RAM}" targetNamespace="{namespace}"{form}>{body}</xs:schema>'
    )


ROOT = xsd(
    RSM,
    f'<xs:import namespace="{RAM}" schemaLocation="ram.xsd"/>'
    '<xs:element name="CrossIndustryInvoice" type="rsm:CrossIndustryInvoiceType"/>'
    '<xs:complexType name="CrossIndustryInvoiceType"><xs:sequence>'
    '<xs:element name="ExchangedDocument" type="ram:ExchangedDocumentType"/>'
    "</xs:sequence></xs:complexType>",
)

DOCUMENT = (
    '<xs:complexType name="ExchangedDocumentType"><xs:sequence>'
    '<xs:element name="ID" type="xs:token"/>'
    '<xs:element name="TypeCode" type="ram:CodeType"/>'
    '<xs:element name="Name" type="xs:string" minOccurs="0" maxOccurs="unbounded"/>'
    "</xs:sequence></xs:complexType>"
    '<xs:simpleType name="CodeType"><xs:restriction base="xs:token"/></xs:simpleType>'
)


def jar(members):
    """A jar (zip) in memory with the given members, read without pins."""
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as z:
        for name, text in members.items():
            z.writestr(name, text)
    path = Path(tempfile.mkdtemp()) / "test.jar"
    path.write_bytes(data.getvalue())
    return g.Jar(path, pinned=False)


def schema(ram_body=DOCUMENT, root=ROOT, **kwargs):
    return g.Schema(
        jar({"schema/ZF_230/T/rsm.xsd": root, "schema/ZF_230/T/ram.xsd": xsd(RAM, ram_body, **kwargs)}),
        "T",
    )


def rule(context, test, rid="BR-T-1", kind="assert", source="CEN", mode="M1", priority=1000, codedb=None,
         variables=None):
    return g.Rule(
        source=source,
        artefact="test.xslt",
        mode=mode,
        priority=priority,
        context=context,
        kind=kind,
        test=test,
        id=rid,
        flag="fatal",
        text=f"[{rid}] test" if rid else "not used",
        variables=variables or {},
        codedb=codedb or {},
    )


def compiled(rules, s=None):
    s = s or schema()
    return g.Compiler("t", s, rules, g.known_tags([s])).compile()


def position(compiler, path):
    for pos in compiler.positions:
        if "/" + pos.path() == path:
            return pos
    raise AssertionError(f"no position {path}")


DOC = "/rsm:CrossIndustryInvoice/rsm:ExchangedDocument"

# A document with tax elements, for the rules of the VAT categories.
TAX_DOCUMENT = (
    '<xs:complexType name="ExchangedDocumentType"><xs:sequence>'
    '<xs:element name="ID" type="xs:token"/>'
    '<xs:element name="ApplicableTradeTax" type="ram:TradeTaxType" minOccurs="0" maxOccurs="unbounded"/>'
    "</xs:sequence></xs:complexType>"
    '<xs:complexType name="TradeTaxType"><xs:sequence>'
    '<xs:element name="CalculatedAmount" type="xs:decimal" minOccurs="0"/>'
    '<xs:element name="TypeCode" type="xs:token"/>'
    '<xs:element name="ExemptionReason" type="xs:string" minOccurs="0"/>'
    '<xs:element name="BasisAmount" type="xs:decimal" minOccurs="0"/>'
    '<xs:element name="CategoryCode" type="xs:token"/>'
    '<xs:element name="ExemptionReasonCode" type="xs:token" minOccurs="0"/>'
    '<xs:element name="RateApplicablePercent" type="xs:decimal" minOccurs="0"/>'
    "</xs:sequence></xs:complexType>"
)
TAX = DOC + "/ram:ApplicableTradeTax"
TAX_RULES = [
    rule(TAX + "[ram:CategoryCode = 'S']", "ram:RateApplicablePercent > 0", rid="BR-S-05"),
    rule(TAX + "[ram:CategoryCode = 'O']", "not(ram:RateApplicablePercent)", rid="BR-O-05"),
    rule(TAX + "/ram:CategoryCode[. = 'E']", "(../ram:ExemptionReason) or (../ram:ExemptionReasonCode)",
         rid="BR-E-10"),
    rule(TAX + "/ram:CategoryCode[. = 'E']", "../ram:CalculatedAmount = 0", rid="BR-E-09"),
    # For VAT only: exact, as the tax type must be "VAT".
    rule(TAX + "[ram:CategoryCode = 'Z'][upper-case(ram:TypeCode) = 'VAT']", "ram:RateApplicablePercent = 0",
         rid="BR-Z-05"),
    rule(TAX + "/ram:TypeCode", "contains(' VAT ', concat(' ', normalize-space(.), ' '))", rid="BR-T-CL"),
    # A sum of a category is a business rule.
    rule(TAX + "[ram:CategoryCode = 'S']", "ram:BasisAmount = 100", rid="BR-S-08"),
]


class SchemaSubset(unittest.TestCase):
    """The generator understands a small subset of XML Schema and fails on
    anything else instead of guessing."""

    def test_the_subset(self):
        s = schema()
        self.assertEqual(s.root, ("rsm:CrossIndustryInvoice", "rsm:CrossIndustryInvoiceType"))
        doc = s.type("ram:ExchangedDocumentType")
        self.assertEqual([(p.tag, p.min, p.max) for p in doc.children], [
            ("ram:ID", 1, 1), ("ram:TypeCode", 1, 1), ("ram:Name", 0, g.UNBOUNDED),
        ])
        self.assertEqual(s.type(doc.children[1].type).base, "token")

    def assert_fails(self, message, **kwargs):
        with self.assertRaises(g.GenError) as caught:
            schema(**kwargs)
        self.assertIn(message, str(caught.exception))

    def test_unsupported_constructs_fail(self):
        seq = '<xs:complexType name="ExchangedDocumentType">{}</xs:complexType>'
        self.assert_fails("a choice between 2 elements", ram_body=seq.format(
            '<xs:choice><xs:element name="A" type="xs:token"/><xs:element name="B" type="xs:token"/></xs:choice>'))
        self.assert_fails("unsupported particle any", ram_body=seq.format("<xs:sequence><xs:any/></xs:sequence>"))
        self.assert_fails("unsupported content model all", ram_body=seq.format(
            '<xs:all><xs:element name="A" type="xs:token"/></xs:all>'))
        self.assert_fails("twice in one sequence", ram_body=seq.format(
            '<xs:sequence><xs:element name="A" type="xs:token"/><xs:element name="A" type="xs:token"/></xs:sequence>'))
        self.assert_fails("unsupported XSD attributes ['nillable']", ram_body=seq.format(
            '<xs:sequence><xs:element name="A" type="xs:token" nillable="true"/></xs:sequence>'))
        self.assert_fails("not a restriction without facets", ram_body=DOCUMENT.replace(
            '<xs:restriction base="xs:token"/>',
            '<xs:restriction base="xs:token"><xs:maxLength value="3"/></xs:restriction>'))
        self.assert_fails("unsupported base type xs:date", ram_body=DOCUMENT.replace(
            'name="ID" type="xs:token"', 'name="ID" type="xs:date"'))
        self.assert_fails("attribute use prohibited", ram_body=seq.format(
            '<xs:simpleContent><xs:extension base="xs:token">'
            '<xs:attribute name="a" type="xs:token" use="prohibited"/></xs:extension></xs:simpleContent>'))
        self.assert_fails("unsupported top-level construct group", ram_body=DOCUMENT + '<xs:group name="G"/>')
        self.assert_fails("elements are not qualified", qualified=False)

    def test_unknown_namespace_fails(self):
        other = ROOT.replace(f'targetNamespace="{RSM}"', 'targetNamespace="urn:other"')
        self.assert_fails("unknown target namespace urn:other", root=other)

    def test_pinned_artefacts(self):
        name = next(iter(g.PINS))
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as z:
            z.writestr(name, "not the pinned artefact")
        path = Path(tempfile.mkdtemp()) / "other.jar"
        path.write_bytes(data.getvalue())
        with self.assertRaises(g.GenError) as caught:
            g.Jar(path).read(name)
        self.assertIn("is not the pinned artefact", str(caught.exception))
        with self.assertRaises(g.GenError):
            g.Jar(path).read("schema/ZF_230/missing.xsd")


class RuleCompiler(unittest.TestCase):
    """Rules of the known shapes become constraints of positions; a rule on
    values is left to the validator; an unknown shape of a rule the guard
    must understand fails."""

    def test_required_and_counted_elements(self):
        c = compiled([
            rule(DOC, "ram:Name", rid="BR-T-1"),
            rule(DOC, "count(ram:Name) <= 1", rid="BR-T-2"),
        ])
        doc = position(c, DOC)
        self.assertEqual(doc.cmin["ram:Name"], [(1, "BR-T-1")])
        self.assertEqual(doc.cmax["ram:Name"], [(1, "BR-T-2")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["compiled", "compiled"])

    def test_elements_with_text(self):
        """The form of the XRechnung Schematron: `E[boolean(normalize-space(.))]`
        requires an E with text (BR-DE-3), `(A,B)[boolean(normalize-space(.))]`
        one of them (BR-DE-5); a condition on the text is a business rule."""
        c = compiled([
            rule(DOC, "ram:Name[boolean(normalize-space(.))]", rid="BR-DE-T1", source="XR"),
            rule(DOC, "(ram:ID,ram:Name)[boolean(normalize-space(.))]", rid="BR-DE-T2", source="XR"),
        ])
        doc = position(c, DOC)
        self.assertEqual(doc.cmin["ram:Name"], [(1, "BR-DE-T1")])
        self.assertEqual(doc.anyof, [(("ram:ID", "ram:Name"), "BR-DE-T2")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["compiled", "compiled"])
        c = compiled([rule(DOC, "ram:Name[normalize-space(.) = 'x']", rid="BR-DE-T3", source="XR")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["business"])

    def test_business_rules_are_left_to_the_validator(self):
        c = compiled([rule(DOC, "ram:ID = ../rsm:ExchangedDocument/ram:Name", rid="BR-T-3")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["business"])
        c = compiled([rule(DOC + "[ram:TypeCode = '380']", "ram:Name", rid="BR-T-4")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["business"])

    def test_code_lists(self):
        c = compiled([
            rule(DOC + "/ram:TypeCode", "contains(' 380 381 ', concat(' ', normalize-space(.), ' '))", rid="BR-T-5"),
            rule(
                DOC + "/ram:TypeCode",
                "document('FACTUR-X_T_codedb.xml')//cl[@id=1]/enumeration[@value=$codeValue1]",
                rid="FX-T-1",
                source="FX",
                codedb={"1": frozenset({"380", "384"})},
                # The variable of its template that selects the value.
                variables={"codeValue1": "."},
            ),
        ])
        leaf = position(c, DOC + "/ram:TypeCode")
        self.assertEqual(
            sorted((sorted(cl.codes), cl.rule) for cl in leaf.lists),
            [(["380", "381"], "BR-T-5"), (["380", "384"], "FX-T-1")],
        )

    def test_unknown_shapes_fail(self):
        with self.assertRaises(g.GenError):
            compiled([rule("//*[not(name() = 'x') and not(*) and not(normalize-space())]", "count(*) = 0")])
        # Reports only mark elements as not used in Factur-X.
        with self.assertRaises(g.GenError):
            compiled([rule(DOC, "ram:Name", rid="BR-T-6", kind="report")])
        with self.assertRaises(g.GenError):
            compiled([rule(DOC, "ram:Name = 'x'", rid=None, kind="report", source="FX")])
        # A code list the code database does not have.
        with self.assertRaises(g.GenError):
            compiled([rule(
                DOC + "/ram:TypeCode",
                "document('FACTUR-X_T_codedb.xml')//cl[@id=9]/enumeration[@value=$codeValue1]",
                rid="FX-T-2",
                source="FX",
                variables={"codeValue1": "."},
            )])

    def test_rules_of_the_vat_categories(self):
        """A rule on the rate, VAT amount or exemption reason of a tax
        element of a VAT category joins the table of that category; other
        rules of a category are business rules."""
        c = compiled(TAX_RULES, schema(TAX_DOCUMENT))
        tax = position(c, TAX)
        self.assertEqual(tax.categories, {
            "S": [("r", 1, "BR-S-05")],
            "O": [("r", None, "BR-O-05")],
            "E": [("e", True, "BR-E-10"), ("a", 0, "BR-E-09")],
            "Z": [("r", 0, "BR-Z-05")],
        })
        self.assertEqual(g.category_table(tax), (
            ("E", (("a", 0, "BR-E-09"), ("e", True, "BR-E-10"))),
            ("O", (("r", None, "BR-O-05"),)),
            ("S", (("r", 1, "BR-S-05"),)),
            ("Z", (("r", 0, "BR-Z-05"),)),
        ))
        self.assertEqual(
            [d for r, d, _ in c.dispositions if r.id != "BR-T-CL"],
            ["compiled"] * 5 + ["business"],
        )

    def test_a_rate_unless_one_category(self):
        """BR-48 (and the Factur-X rule that names it): a rate for every
        category the code lists of the category code know, but the one it
        names; a rate above 0 of a category takes the place of any rate."""
        fx = rule(TAX, "(ram:RateApplicablePercent) or (ram:CategoryCode = 'O')", rid="FX-SCH-A-000050",
                  source="FX")
        fx.text = "[BR-48]-Each VAT breakdown (BG-23) shall have a VAT category rate (BT-119)"
        c = compiled([
            rule(TAX + "/ram:CategoryCode", "contains(' S Z O ', concat(' ', normalize-space(.), ' '))",
                 rid="BR-CL-18"),
            rule(TAX + "/ram:TypeCode", "contains(' VAT ', concat(' ', normalize-space(.), ' '))", rid="BR-T-CL"),
            rule(TAX, "(.[upper-case(ram:TypeCode) = 'VAT']/ram:RateApplicablePercent) or "
                      "(.[upper-case(ram:TypeCode) = 'VAT']/ram:CategoryCode = 'O')", rid="BR-48"),
            fx,
            rule(TAX + "[ram:CategoryCode = 'S']", "ram:RateApplicablePercent > 0", rid="BR-S-05"),
        ], schema(TAX_DOCUMENT))
        tax = position(c, TAX)
        self.assertEqual(g.category_table(tax), (
            ("S", (("r", 1, "BR-S-05"),)),
            ("Z", (("r", "any", "BR-48"),)),
        ))
        self.assertEqual({d for _, d, _ in c.dispositions}, {"compiled"})
        with self.assertRaises(g.GenError):
            compiled([rule(TAX, "(.[upper-case(ram:TypeCode) = 'VAT']/ram:RateApplicablePercent) or "
                                "(ram:CategoryCode = 'O')", rid="BR-48")], schema(TAX_DOCUMENT))
        with self.assertRaises(g.GenError):
            compiled([rule(DOC, "(ram:RateApplicablePercent) or (ram:CategoryCode = 'O')", rid="BR-48")],
                     schema(TAX_DOCUMENT))

    def test_rules_of_the_vat_categories_that_fail(self):
        tax_schema = schema(TAX_DOCUMENT)
        # A test from the tax element that names its parent's children.
        with self.assertRaises(g.GenError):
            compiled([rule(TAX + "[ram:CategoryCode = 'S']", "../ram:RateApplicablePercent > 0")], tax_schema)
        # A rule for VAT only where the tax type may be another.
        with self.assertRaises(g.GenError) as caught:
            compiled([rule(TAX + "[ram:CategoryCode = 'Z'][upper-case(ram:TypeCode) = 'VAT']",
                           "ram:RateApplicablePercent = 0")], tax_schema)
        self.assertIn("whose tax type may be another", str(caught.exception))
        # Two validators that want different rates of one category.
        c = compiled([
            rule(TAX + "[ram:CategoryCode = 'M']", "ram:RateApplicablePercent > 0", rid="BR-AG-05"),
            rule(TAX + "[ram:CategoryCode = 'M']", "ram:RateApplicablePercent = 0", rid="FX-T-9", source="FX"),
        ], tax_schema)
        with self.assertRaises(g.GenError):
            g.category_table(position(c, TAX))

    def test_rules_of_no_position(self):
        c = compiled([rule(DOC + "/ram:Name/ram:Other", "ram:ID", rid="BR-T-8")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["unmatched"])

    def test_tautologies(self):
        c = compiled([rule(DOC, "true()", rid="BR-T-7")])
        self.assertEqual([d for _, d, _ in c.dispositions], ["tautology"])


class Output(unittest.TestCase):
    """The output: the Typst layout of the lists, the JSON of the nodes, and
    the fast paths of the writer."""

    def test_json_nodes(self):
        class Nodes:
            ids = {}

        class Names:
            vat = {}

            @staticmethod
            def name(codes):
                return "country"

        ref = g.ListRef(frozenset({"DE"}), "BR-CL-14", (("XX", "BR-X"),), False)
        leaf = ("L", "s", (("schemeID", "XSD", None, None),), ref, None, None, None)
        self.assertEqual(json.loads(g.emit_node(leaf, Nodes, Names)),
                         ["s", {"schemeID": [True, None, None]}, ["country", "BR-CL-14", {"XX": "BR-X"}, False],
                          None, None, None])
        self.assertEqual(g.emit_node(("L", "d", (), None, None, None, None), Nodes, Names), '"d"')
        Nodes.ids = {leaf: 3, ("L", "d", (), None, None, None, None): 4}
        node = ("C", (
            ("ram:ID", 0, 1, 1, ("N", leaf), "BR-1", None),
            ("ram:Amount", 1, 0, g.UNBOUNDED, ("N", ("L", "d", (), None, None, None, None)), None, "BR-2"),
            ("ram:Other", 2, 0, 0, ("F", "FX-1"), None, None),
        ), None, (), (), (), (), ())
        text = g.emit_node(node, Nodes, Names)
        # One child per line, and every child with six entries.
        self.assertEqual(text.count("\n"), 2)
        self.assertEqual(json.loads(text), {
            "n": 1,
            "u": {"ram:Other": "FX-1"},
            "c": {"ram:ID": [None, 0, 1, 1, 3, ["BR-1"]], "ram:Amount": ["d", 1, 0, None, 4, [None, "BR-2"]]},
        })

    def test_minimum_above_one_fails(self):
        class Nodes:
            ids = {}

        node = ("C", (("ram:ID", 0, 2, 2, ("N", ("L", "s", (), None, None, None, None)), None, None),),
                None, (), (), (), (), ())
        with self.assertRaises(g.GenError):
            g.emit_node(node, Nodes, None)

    def test_short_list_names_fail(self):
        class Names:
            @staticmethod
            def name(codes):
                return "d2"

        ref = g.ListRef(frozenset({"A"}), "BR-T", (), False)
        with self.assertRaises(g.GenError):
            g.emit_action(("N", ("L", "s", (), ref, None, None, None)), None, Names)

    def test_chunks(self):
        codes = [f"C{i:03}" for i in range(40)]
        lines = g.chunks(codes)
        self.assertTrue(all(len(line) <= 72 for line in lines))
        self.assertEqual(" ".join(lines).split(" "), codes)

    def test_fast_classes(self):
        optional = (("currencyID", None, None, None),)
        required = (("unitCode", "BR-23", None, None),)
        self.assertEqual(g.leaf_fast("s", (), None, None, None, None), "s")
        self.assertEqual(g.leaf_fast("d", optional, None, None, None, None), "d")
        self.assertEqual(g.leaf_fast("d", optional, None, None, (2, True, "BR-DEC-23"), None), "d2")
        self.assertIsNone(g.leaf_fast("d", required, None, None, None, None))
        self.assertIsNone(g.leaf_fast("x", (), None, None, None, None))
        self.assertIsNone(g.leaf_fast("s", (), None, None, None, "CII-DT-097"))
        ref = g.ListRef(frozenset({"VAT"}), "BR-T", (), False)
        self.assertIsNone(g.leaf_fast("s", (), ref, None, None, None))
        self.assertIs(g.leaf_list("s", (), ref, None, None, None), ref)
        self.assertIsNone(g.leaf_list("s", required, ref, None, None, None))

    def test_codes_with_spaces_fail(self):
        class Names:
            names = {frozenset({"A B"}): "bad"}
            base = {frozenset({"A B"}): frozenset({"A B"})}

        with self.assertRaises(g.GenError):
            g.emit_lists(Names())


SCHXSLT = (
    '<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" '
    'xmlns:svrl="http://purl.oclc.org/dsdl/svrl" xmlns:schxslt="https://doi.org/10.5281/zenodo.1495494" '
    'version="2.0">{}</xsl:transform>'
)


def schxslt_rule(context, test, rid, priority="3"):
    """A rule as SchXslt compiles it (the CEN Schematron of KoSIT)."""
    return (
        f'<xsl:template match="{context}" priority="{priority}" mode="d1"><schxslt:rule pattern="p1">'
        f'<xsl:if test="not({test})"><svrl:failed-assert location="x" flag="fatal" id="{rid}">'
        f'<xsl:attribute name="test">{test}</xsl:attribute><svrl:text>[{rid}] test</svrl:text>'
        "</svrl:failed-assert></xsl:if></schxslt:rule></xsl:template>"
    )


def kosit(templates, pinned=False):
    """An unpacked KoSIT configuration whose CEN Schematron has `templates`."""
    root = Path(tempfile.mkdtemp())
    (root / g.KOSIT_CEN).parent.mkdir(parents=True)
    (root / g.KOSIT_CEN).write_text(SCHXSLT.format("".join(templates)), encoding="utf-8")
    return g.KositConfig(root, pinned=pinned)


class NewestSchematron(unittest.TestCase):
    """The code lists of the newest CEN Schematron (KoSIT) narrow the older
    ones, and the global variables of the XRechnung Schematron are replaced
    in the tests of its rules."""

    def test_the_configuration_is_needed_and_pinned(self):
        with self.assertRaises(g.GenError) as caught:
            g.KositConfig(None)
        self.assertIn("KOSIT_CONFIG", str(caught.exception))
        with self.assertRaises(g.GenError) as caught:
            kosit([], pinned=True).read(g.KOSIT_CEN)
        self.assertIn("is not the pinned artefact", str(caught.exception))
        with self.assertRaises(g.GenError):
            g.KositConfig(tempfile.mkdtemp()).read(g.KOSIT_CEN)

    def test_code_lists_join_their_twins(self):
        codes = "contains(' {} ', concat(' ', normalize-space(.), ' '))"
        older = rule(DOC + "/ram:TypeCode", codes.format("380 381 384"), rid="BR-T-5", mode="M7", priority=1010)
        newest = g.load_cen_code_lists(kosit([
            schxslt_rule(DOC + "/ram:TypeCode", codes.format("380 381 389"), "BR-T-5"),
            # Not a code list: left out.
            schxslt_rule(DOC, "ram:ID", "BR-T-6"),
        ]), [older])
        self.assertEqual(len(newest), 1)
        self.assertTrue(newest[0].newest)
        self.assertEqual((newest[0].mode, newest[0].priority, newest[0].id), ("M7", 1010, "BR-T-5"))
        fx = rule(DOC + "/ram:TypeCode", codes.format("380 381"), rid="FX-T-1", source="FX")
        c = compiled([older, newest[0], fx])
        ref = g.combine_lists(position(c, DOC + "/ram:TypeCode").lists)
        # 384 only the newest list lacks: the rule of both versions; the
        # older list stays the primary one.
        self.assertEqual((sorted(ref.codes), ref.rule, ref.exceptions), (["380", "381"], "BR-T-5", (("384", "FX-T-1"),)))
        # A code list of the newest Schematron without a rule of the same id
        # and context in the older one fails.
        with self.assertRaises(g.GenError) as caught:
            g.load_cen_code_lists(kosit([schxslt_rule(DOC + "/ram:Name", codes.format("A"), "BR-T-7")]), [older])
        self.assertIn("has no rule of the same id and context", str(caught.exception))

    def test_global_values(self):
        from lxml import etree

        root = etree.fromstring(
            '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">'
            "<xsl:param name=\"cur\" select=\"/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/"
            "ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode\"/>"
            "<xsl:param name=\"profile\" select=\"if (x) then 'a' else 'b'\"/>"
            "<xsl:variable name=\"V\" select=\"'3.0'\"/>"
            "<xsl:variable name=\"ID\" select=\"concat('urn:x_', $V)\"/>"
            "<xsl:variable name=\"EXT\" select=\"concat($ID, '#ext_', $V)\"/>"
            "</xsl:stylesheet>"
        )
        values = g.global_values(root)
        self.assertEqual(values, {
            "cur": "/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/"
                   "ram:InvoiceCurrencyCode",
            "V": "'3.0'",
            "ID": "'urn:x_3.0'",
            "EXT": "'urn:x_3.0#ext_3.0'",
        })
        self.assertEqual(g.substitute("ram:ID = $ID or ram:ID = $EXT or $profile", values),
                         "ram:ID = 'urn:x_3.0' or ram:ID = 'urn:x_3.0#ext_3.0' or $profile")

    def test_one_of_several_values(self):
        c = compiled([rule(DOC, "ram:TypeCode = 'urn:a' or ram:TypeCode = 'urn:b#c'", rid="BR-DE-T")])
        leaf = position(c, DOC + "/ram:TypeCode")
        self.assertEqual([(sorted(cl.codes), cl.rule) for cl in leaf.lists], [(["urn:a", "urn:b#c"], "BR-DE-T")])
        # One value, or values of two elements, are business rules.
        for test in ("ram:TypeCode = 'a'", "ram:TypeCode = 'a' or ram:ID = 'b'"):
            c = compiled([rule(DOC, test, rid="BR-T-8")])
            self.assertEqual([d for _, d, _ in c.dispositions], ["business"], test)

    def test_a_count_through_an_element_that_occurs_once(self):
        root = xsd(
            RSM,
            f'<xs:import namespace="{RAM}" schemaLocation="ram.xsd"/>'
            '<xs:element name="CrossIndustryInvoice" type="rsm:CrossIndustryInvoiceType"/>'
            '<xs:complexType name="CrossIndustryInvoiceType"><xs:sequence>'
            '<xs:element name="SupplyChainTradeTransaction" type="ram:TransactionType"/>'
            "</xs:sequence></xs:complexType>",
        )
        body = (
            '<xs:complexType name="TransactionType"><xs:sequence>'
            '<xs:element name="ApplicableHeaderTradeSettlement" type="ram:SettlementType"/>'
            "</xs:sequence></xs:complexType>"
            '<xs:complexType name="SettlementType"><xs:sequence>'
            '<xs:element name="InvoiceCurrencyCode" type="xs:token"/>'
            '<xs:element name="SpecifiedTradeSettlementHeaderMonetarySummation" type="ram:SumType" {}/>'
            "</xs:sequence></xs:complexType>"
            '<xs:complexType name="SumType"><xs:sequence>'
            '<xs:element name="TaxTotalAmount" type="ram:AmountType" minOccurs="0" maxOccurs="2"/>'
            "</xs:sequence></xs:complexType>"
            '<xs:complexType name="AmountType"><xs:simpleContent><xs:extension base="xs:decimal">'
            '<xs:attribute name="currencyID" type="xs:token"/></xs:extension></xs:simpleContent></xs:complexType>'
        )
        test = (
            "count(ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxTotalAmount[@currencyID = "
            "/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/"
            "ram:InvoiceCurrencyCode]) <=1"
        )
        once = schema(body.format(""), root=root)
        c = compiled([rule("ram:ApplicableHeaderTradeSettlement", test, rid="PEPPOL-T-53")], once)
        settlement = position(
            c, "/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement"
        )
        self.assertEqual(settlement.xref, [("count", ("InvoiceCurrencyCode",), "PEPPOL-T-53")])
        twice = schema(body.format('maxOccurs="2"'), root=root)
        with self.assertRaises(g.GenError) as caught:
            compiled([rule("ram:ApplicableHeaderTradeSettlement", test, rid="PEPPOL-T-53")], twice)
        self.assertIn("may occur more than once", str(caught.exception))


class ListsOutput(unittest.TestCase):
    """lists.json: every code list in lines of its sorted codes, the tables
    of the VAT category rules, and the lists of the validator."""

    def test_layout(self):
        country = frozenset(f"C{i:02}" for i in range(60))
        checks = (("r", 0, "BR-AE-05"),)

        class Names:
            names = {
                country: "country",
                country - {"C01"}: "country-2",
                frozenset({"urn:" + "x" * 90}): "guideline",
            }
            vat = {(("AE", checks), ("O", (("r", None, "BR-O-05"),))): "vat-line"}

        validator = {
            "country": {"every": "country-2", "factur-x": "country"},
            "icd": {"every": "country", "newer": [f"02{i:02}" for i in range(31, 49)]},
        }
        text = g.emit_lists(Names(), validator)
        data = json.loads(text)
        self.assertEqual(data["generated"], g.LISTS_NOTICE)
        # Lines of at most 75 characters, the codes sorted; one code longer
        # than a line stays whole.
        self.assertEqual(" ".join(data["lists"]["country"]).split(" "), sorted(country))
        self.assertTrue(all(len(line) <= 75 for line in data["lists"]["country"]))
        self.assertNotIn("C01", " ".join(data["lists"]["country-2"]).split(" "))
        self.assertEqual(data["lists"]["guideline"], ["urn:" + "x" * 90])
        self.assertEqual(data["vat-rules"], {"vat-line": {"AE": [["r", 0, "BR-AE-05"]], "O": [["r", None, "BR-O-05"]]}})
        self.assertEqual(data["validator"]["country"], {"every": "country-2", "factur-x": "country"})
        self.assertEqual(data["validator"]["icd"]["newer"], [
            "0231 0232 0233 0234 0235 0236 0237 0238 0239 0240 0241 0242 0243 0244 0245",
            "0246 0247 0248",
        ])
        # A list takes lines of its own, so that a change of a code reads as
        # a diff of its line.
        self.assertIn('"country":[\n"C00 C01 ', text)
        # The drift test knows it as a file of the generator.
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "lists.json"
            path.write_text(text, encoding="utf-8")
            self.assertTrue(g.is_generated(path))

    def test_codes_with_whitespace_are_refused(self):
        class Names:
            names = {frozenset({"A B"}): "bad"}
            vat = {}

        with self.assertRaises(g.GenError):
            g.emit_lists(Names())


JAR = os.environ.get("MUSTANG_JAR")
KOSIT = os.environ.get("KOSIT_CONFIG")


@unittest.skipUnless(
    JAR and Path(JAR).is_file() and KOSIT and Path(KOSIT).is_dir(),
    "needs the Mustang CLI jar 2.14.0 ($MUSTANG_JAR) and the KoSIT XRechnung configuration ($KOSIT_CONFIG)",
)
class Tables(unittest.TestCase):
    """The committed tables are the generator's (the drift test of
    `gen_guard.py --check`), deterministically, within the size budget."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fresh = Path(cls.tmp.name)
        cls.stats = g.generate(JAR, cls.fresh, kosit_config=KOSIT)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_no_drift(self):
        self.assertEqual(g.compare(self.fresh), [])

    def test_drift_is_found(self):
        with tempfile.TemporaryDirectory() as committed:
            for name in g.OUTPUT_FILES:
                (Path(committed) / name).write_bytes((self.fresh / name).read_bytes())
            self.assertEqual(g.compare(self.fresh, committed), [])
            lists = Path(committed) / "lists.json"
            lists.write_text(lists.read_text(encoding="utf-8").replace(" DE ", " "), encoding="utf-8")
            (Path(committed) / "old.typ").write_text(g.HEADER, encoding="utf-8")
            (Path(committed) / "old.json").write_text(
                "{\n" + f'"generated":{g.json_value(g.JSON_NOTICE)},' + "\n}", encoding="utf-8"
            )
            diffs = g.compare(self.fresh, committed)
            self.assertEqual(len(diffs), 2)
            self.assertIn("committed/lists.json", diffs[0])
            self.assertIn("no longer writes: old.json, old.typ", diffs[1])

    def test_deterministic_and_small(self):
        with tempfile.TemporaryDirectory() as again:
            g.generate(JAR, again, kosit_config=KOSIT)
            for name in g.OUTPUT_FILES:
                self.assertEqual((self.fresh / name).read_bytes(), (Path(again) / name).read_bytes(), name)
        self.assertLessEqual(self.stats["bytes"]["total"], g.SIZE_BUDGET)
        for profile, info in self.stats["profiles"].items():
            self.assertGreater(info["nodes"], 10, profile)
            self.assertGreater(info["rules"].get("compiled", 0), 10, profile)

    def test_elements_the_builder_needs(self):
        # A builder that never writes a required element fails the generator.
        with tempfile.TemporaryDirectory() as tmp:
            builder = Path(tmp) / "build.typ"
            builder.write_text(g.BUILDER.read_text(encoding="utf-8").replace('"ram:TypeCode"', '"ram:X"'))
            with self.assertRaises(g.GenError) as caught:
                g.generate(JAR, tmp, builder=builder, kosit_config=KOSIT)
            self.assertIn("never writes", str(caught.exception))

    def test_codes_withdrawn_from_the_newest_lists(self):
        # The lists of the validator hold what every validation accepts:
        # the currencies and the scheme the CEN Schematron 1.3.16 withdrew
        # are missing from `every`, which the profiles based on EN 16931
        # apply, and the codes only it has are `newer`.
        data = json.loads((self.fresh / "lists.json").read_text(encoding="utf-8"))
        validator = data["validator"]
        self.assertEqual(validator["currency"]["newer"], ["CNH VED XCG ZWG"])
        every = set(" ".join(data["lists"][validator["currency"]["every"]]).split(" "))
        factur_x = set(" ".join(data["lists"][validator["currency"]["factur-x"]]).split(" "))
        for code in ("ANG", "BGN", "CUC", "HRK", "MRU", "STN", "UYW", "VES", "ZWL"):
            self.assertNotIn(code, every)
            self.assertIn(code, factur_x)
        self.assertIn("0231 0232", " ".join(validator["icd"]["newer"]))
        disposition = {
            (p, r["id"]): d
            for p, info in self.stats["profiles"].items()
            for d, rules in info["dispositions"].items()
            for r in rules
        }
        self.assertEqual(disposition[("xrechnung", "BR-DE-21")], "compiled")
        self.assertEqual(disposition[("xrechnung", "PEPPOL-EN16931-R053")], "compiled")


if __name__ == "__main__":
    unittest.main()
