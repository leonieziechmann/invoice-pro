"""Unit tests of the oracles of the party details (no Typst, no Java).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

The legal registration identifiers (BT-30, BT-47), trading names (BT-28,
BT-45), the seller's legal information (BT-33), the buyer reference (BT-10)
and contact (BG-9), the seller tax representative (BG-11) and the payee
(BG-10) each reach their business term, or the oracle names the difference.
"""

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402
import oracles  # noqa: E402

CII = """<?xml version="1.0" encoding="UTF-8"?>
<rsm:CrossIndustryInvoice
  xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
  xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
  xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
<rsm:SupplyChainTradeTransaction>
<ram:ApplicableHeaderTradeAgreement>
  <ram:BuyerReference>04011000-1234512345-06</ram:BuyerReference>
  <ram:SellerTradeParty>
    <ram:Name>Muster GmbH</ram:Name>
    <ram:Description>Geschäftsführer: Max Muster</ram:Description>
    <ram:SpecifiedLegalOrganization>
      <ram:ID schemeID="0009">12345678200010</ram:ID>
      <ram:TradingBusinessName>Muster Design</ram:TradingBusinessName>
    </ram:SpecifiedLegalOrganization>
  </ram:SellerTradeParty>
  <ram:BuyerTradeParty>
    <ram:Name>Kunde AG</ram:Name>
    <ram:SpecifiedLegalOrganization><ram:ID>Amtsgericht Köln, HRB 4711</ram:ID></ram:SpecifiedLegalOrganization>
    <ram:DefinedTradeContact>
      <ram:PersonName>Frau Beispiel</ram:PersonName>
      <ram:EmailURIUniversalCommunication><ram:URIID>einkauf@kunde.example</ram:URIID></ram:EmailURIUniversalCommunication>
    </ram:DefinedTradeContact>
  </ram:BuyerTradeParty>
  <ram:SellerTaxRepresentativeTradeParty>
    <ram:Name>Fiskal GmbH</ram:Name>
    <ram:PostalTradeAddress><ram:CountryID>DE</ram:CountryID></ram:PostalTradeAddress>
    <ram:SpecifiedTaxRegistration><ram:ID schemeID="VA">DE987654328</ram:ID></ram:SpecifiedTaxRegistration>
  </ram:SellerTaxRepresentativeTradeParty>
</ram:ApplicableHeaderTradeAgreement>
<ram:ApplicableHeaderTradeSettlement>
  <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
  <ram:PayeeTradeParty>
    <ram:GlobalID schemeID="0088">4000001543212</ram:GlobalID>
    <ram:Name>Factoring Bank AG</ram:Name>
    <ram:SpecifiedLegalOrganization><ram:ID>HRB 12345</ram:ID></ram:SpecifiedLegalOrganization>
  </ram:PayeeTradeParty>
</ram:ApplicableHeaderTradeSettlement>
</rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>"""

FACTS = {
    "seller_legal_id": ["0009", "12345678200010"],
    "buyer_legal_id": ["", "Amtsgericht Köln, HRB 4711"],
    "seller_trading_name": "Muster Design",
    "seller_legal_info": "Geschäftsführer: Max Muster",
    "buyer_reference": "04011000-1234512345-06",
    "buyer_contact": {"name": "Frau Beispiel", "email": "einkauf@kunde.example"},
    "tax_representative": {"name": "Fiskal GmbH", "vat": "DE987654328", "country": "DE"},
    "payee": {"name": "Factoring Bank AG", "ids": [["0088", "4000001543212"]], "legal_id": ["", "HRB 12345"]},
}


def oracle_ids(problems):
    return sorted(p.split(":")[0] for p in problems)


class PartyDetails(unittest.TestCase):
    def setUp(self):
        self.doc = common.parse_xml(CII.encode("utf-8"))

    def test_facts_that_hold(self):
        self.assertEqual(oracles.check(FACTS, self.doc, None, "en16931"), [])
        # The legal registration identifiers are part of every profile.
        self.assertEqual(oracles.check(FACTS, self.doc, None, "minimum"), [])

    def test_wrong_facts_are_reported(self):
        wrong = {
            # e.g. a SIRET written without its scheme, or as SIREN
            "seller_legal_id": ["", "12345678200010"],
            "buyer_legal_id": ["0002", "123456782"],
            "buyer_trading_name": "Kunde Shop",
            "seller_legal_info": "Sitz: Berlin",
            "buyer_reference": "991-33333TEST-33",
            "buyer_contact": {"name": "Frau Beispiel", "phone": "+49 30 123456", "email": "einkauf@kunde.example"},
            "tax_representative": {"name": "Fiskal GmbH", "vat": "DE123456788", "country": "DE"},
            "payee": {"name": "Factoring Bank AG", "ids": [["", "4000001543212"]]},
        }
        self.assertEqual(
            oracle_ids(oracles.check(wrong, self.doc, None, "en16931")),
            ["O-BG10", "O-BG11", "O-BG9", "O-BT10", "O-BT30", "O-BT33", "O-BT45", "O-BT47"],
        )

    def test_missing_parties(self):
        doc = common.parse_xml(
            CII.replace("<ram:SellerTaxRepresentativeTradeParty>", "<ram:Other>")
            .replace("</ram:SellerTaxRepresentativeTradeParty>", "</ram:Other>")
            .encode("utf-8")
        )
        problems = oracles.check({"tax_representative": FACTS["tax_representative"]}, doc, None, "en16931")
        self.assertEqual(oracle_ids(problems), ["O-BG11"])
        self.assertIn("'name': None", problems[0])


if __name__ == "__main__":
    unittest.main()
