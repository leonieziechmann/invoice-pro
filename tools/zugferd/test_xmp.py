"""Unit tests of the Factur-X PDF check (xmp.py): reading Mustang's report on
a PDF, the verdict of the expected failure, and the XMP references."""

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402
import xmp  # noqa: E402

XMP_ERRORS = "\n".join(f'      <error type="{t}">{text}</error>' for t, text in sorted(xmp.EXPECTED_PDF_ERRORS))

# Mustang's report on a PDF of invoice-pro: PDF/A compliant, valid XML, and
# the Factur-X XMP metadata missing.
PDF_REPORT = f"""<?xml version="1.0" encoding="UTF-8"?>
<validation filename="E.pdf" datetime="2026-09-24 01:28:22">
  <pdf>ValidationResult [flavour=3b, totalAssertions=11079, assertions=[], isCompliant=true]
    <info><signature>unknown</signature><duration unit="ms">1391</duration></info>
    <messages>
{XMP_ERRORS}
    </messages>
    <summary status="invalid"/>
  </pdf>
  <xml>
    <info><version>2</version><profile>urn:cen.eu:en16931:2017</profile><validator version="2.14.0"/></info>
    <messages>
      <notice type="27" location="/x">[BR-DE-21] Das Element "Specification identifier" (BT-24) soll ... [ID BR-DE-21]</notice>
    </messages>
    <summary status="valid"/>
  </xml>
  <messages></messages>
  <summary status="invalid"/>
</validation>"""


def report(pdf_errors=None, compliant="true", xml_status="valid", xml_errors=""):
    text = PDF_REPORT.replace("isCompliant=true", f"isCompliant={compliant}")
    if pdf_errors is not None:
        text = text.replace(XMP_ERRORS, "\n".join(f'<error type="{t}">{m}</error>' for t, m in pdf_errors))
    text = text.replace('<summary status="valid"/>\n  </xml>', f'{xml_errors}<summary status="{xml_status}"/>\n  </xml>')
    return common.parse_mustang_pdf_report(text)


class PdfReport(unittest.TestCase):
    def test_parts(self):
        parsed = common.parse_mustang_pdf_report(PDF_REPORT)
        self.assertEqual((parsed["status"], parsed["pdf"]["status"], parsed["pdf"]["compliant"]), ("invalid", "invalid", True))
        self.assertEqual(set(parsed["pdf"]["errors"]), xmp.EXPECTED_PDF_ERRORS)
        self.assertEqual((parsed["xml"]["status"], parsed["xml"]["errors"]), ("valid", {}))

    def test_expected_failure(self):
        self.assertEqual(xmp.pdf_verdict(report()), ("expected", []))

    def test_the_metadata_is_there(self):
        # Typst writes the Factur-X XMP metadata: the check turns around.
        verdict, problems = xmp.pdf_verdict(report(pdf_errors=[]))
        self.assertEqual(verdict, "xpass")
        self.assertIn("turn this expected failure into a check", problems[0])

    def test_other_problems_fail(self):
        # A regression of the PDF/A output of Typst.
        errors = sorted(xmp.EXPECTED_PDF_ERRORS) + [(3, "PDF/A: the font is not embedded")]
        self.assertEqual(xmp.pdf_verdict(report(pdf_errors=errors))[0], "fail")
        self.assertEqual(xmp.pdf_verdict(report(compliant="false"))[0], "fail")
        invalid_xml = report(xml_status="invalid", xml_errors='<error type="24">[BR-CO-10]-Sum [ID BR-CO-10]</error>')
        verdict, problems = xmp.pdf_verdict(invalid_xml)
        self.assertEqual(verdict, "fail")
        self.assertIn("BR-CO-10", problems[0])
        # Some of the metadata, but not all of it.
        partly = [e for e in xmp.EXPECTED_PDF_ERRORS if "Version" not in e[1]]
        self.assertEqual(xmp.pdf_verdict(report(pdf_errors=partly))[0], "fail")

    def test_combined_pdf_must_be_valid(self):
        valid = PDF_REPORT.replace(XMP_ERRORS, "").replace('<summary status="invalid"/>', '<summary status="valid"/>')
        self.assertEqual(xmp.combined_verdict(common.parse_mustang_pdf_report(valid)), [])
        self.assertTrue(xmp.combined_verdict(report()))

    def test_new_definitions_of_typst(self):
        self.assertEqual(xmp.new_definitions(["attach", "embed", "artifact"]), [])
        self.assertEqual(xmp.new_definitions(["attach", "artifact", "metadata"]), ["metadata"])


class References(unittest.TestCase):
    def test_normalize(self):
        raw = ("<dc:creator><rdf:Seq><rdf:li>runner</rdf:li></rdf:Seq></dc:creator>"
               "<dc:date>\n <rdf:Seq>\n  <rdf:li>2026-09-24T01:27:02+00:00</rdf:li></rdf:Seq></dc:date>"
               "<xmp:CreateDate>2026-09-24T01:27:02+00:00</xmp:CreateDate>")
        self.assertEqual(
            xmp.normalize(raw),
            "<dc:creator><rdf:Seq><rdf:li>(normalized)</rdf:li></rdf:Seq></dc:creator>"
            "<dc:date>\n <rdf:Seq>\n  <rdf:li>1980-01-01T00:00:00+00:00</rdf:li></rdf:Seq></dc:date>"
            "<xmp:CreateDate>1980-01-01T00:00:00+00:00</xmp:CreateDate>",
        )

    def test_references(self):
        # One reference per profile letter, each with the values of its profile.
        levels = {"M": "MINIMUM", "W": "BASIC WL", "B": "BASIC", "E": "EN 16931", "X": "XRECHNUNG"}
        self.assertEqual(sorted(letter for letter, _ in xmp.DOCUMENTS.values()), sorted(levels))
        for letter, level in levels.items():
            found = xmp.facts((xmp.REFERENCES / f"mustang-{letter}.xmp").read_text(encoding="utf-8"))
            self.assertEqual(found["values"]["ConformanceLevel"], [level])
            self.assertEqual(found["values"]["DocumentType"], ["INVOICE"])
            self.assertEqual(found["schema"]["namespaceURI"], "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#")
            self.assertEqual([p[0] for p in found["schema"]["properties"]],
                             ["DocumentFileName", "DocumentType", "Version", "ConformanceLevel"])


if __name__ == "__main__":
    unittest.main()
