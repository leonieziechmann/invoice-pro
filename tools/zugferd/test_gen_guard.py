"""Unit tests of the generator of the XML write guard (gen_guard.py).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

The tests of the parts run on small synthetic schemas and rules and need
only lxml. With the Mustang CLI jar 2.14.0 ($MUSTANG_JAR), the tables are
also regenerated: they must equal the committed ones (drift test), come out
the same twice, and stay within the size budget.
"""

import io
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
    """The Typst output: typstyle's layout, and the fast paths of the
    writer."""

    def test_import_layout(self):
        self.assertEqual(g.import_line("lists.typ", ["country", "currency"]),
                         '#import "lists.typ": country, currency')
        names = ["country", "currency-2", "document-type", "note-subject", "payment-means", "tax-type",
                 "vat-category"]
        self.assertEqual(g.import_line("lists.typ", names), (
            '#import "lists.typ": (\n'
            "  country, currency-2, document-type, note-subject, payment-means, tax-type,\n"
            "  vat-category,\n"
            ")"
        ))

    def test_chunks_and_wrap(self):
        codes = [f"C{i:03}" for i in range(40)]
        lines = g.chunks(codes)
        self.assertTrue(all(len(line) <= 72 for line in lines))
        self.assertEqual(" ".join(lines).split(" "), codes)
        self.assertEqual(g.wrap("#let x = (", ["1", "2"], ")", 0), "#let x = (1, 2)")

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


JAR = os.environ.get("MUSTANG_JAR")


@unittest.skipUnless(JAR and Path(JAR).is_file(), "needs the Mustang CLI jar 2.14.0 ($MUSTANG_JAR)")
class Tables(unittest.TestCase):
    """The committed tables are the generator's (the drift test of
    `gen_guard.py --check`), deterministically, within the size budget."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fresh = Path(cls.tmp.name)
        cls.stats = g.generate(JAR, cls.fresh)

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
            lists = Path(committed) / "lists.typ"
            lists.write_text(lists.read_text(encoding="utf-8").replace(" DE ", " "), encoding="utf-8")
            (Path(committed) / "old.typ").write_text(g.HEADER, encoding="utf-8")
            diffs = g.compare(self.fresh, committed)
            self.assertEqual(len(diffs), 2)
            self.assertIn("committed/lists.typ", diffs[0])
            self.assertIn("no longer writes: old.typ", diffs[1])

    def test_deterministic_and_small(self):
        with tempfile.TemporaryDirectory() as again:
            g.generate(JAR, again)
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
                g.generate(JAR, tmp, builder=builder)
            self.assertIn("never writes", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
