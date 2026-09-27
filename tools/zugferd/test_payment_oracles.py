"""Unit tests of the payment oracles (no Typst, no Java).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'
"""

import sys
import unittest
from pathlib import Path

from lxml import etree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import oracles  # noqa: E402

# The settlement of an XRechnung paid by SEPA direct debit, with a cash
# discount in the payment terms.
XML = """<rsm:CrossIndustryInvoice
  xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
  xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
  xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
<rsm:SupplyChainTradeTransaction><ram:ApplicableHeaderTradeSettlement>
  <ram:CreditorReferenceID>DE98ZZZ09999999999</ram:CreditorReferenceID>
  <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
  <ram:SpecifiedTradeSettlementPaymentMeans>
    <ram:TypeCode>59</ram:TypeCode>
    <ram:PayerPartyDebtorFinancialAccount><ram:IBANID>DE02120300000000202051</ram:IBANID></ram:PayerPartyDebtorFinancialAccount>
  </ram:SpecifiedTradeSettlementPaymentMeans>
  <ram:SpecifiedTradePaymentTerms>
    <ram:Description>#SKONTO#TAGE=14#PROZENT=2.00#
</ram:Description>
    <ram:DirectDebitMandateID>M-2026-017</ram:DirectDebitMandateID>
  </ram:SpecifiedTradePaymentTerms>
  <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
    <ram:GrandTotalAmount>119.00</ram:GrandTotalAmount>
    <ram:TotalPrepaidAmount>119.00</ram:TotalPrepaidAmount>
    <ram:DuePayableAmount>0.00</ram:DuePayableAmount>
  </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
</ram:ApplicableHeaderTradeSettlement></rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>"""

CARD = XML.replace(
    "<ram:TypeCode>59</ram:TypeCode>",
    "<ram:TypeCode>54</ram:TypeCode><ram:ApplicableTradeSettlementFinancialCard>"
    "<ram:ID>1234</ram:ID><ram:CardholderName>Erika Kunde</ram:CardholderName>"
    "</ram:ApplicableTradeSettlementFinancialCard>",
)

FACTS = {
    "payment_means": ["59"],
    "mandate": "M-2026-017",
    "creditor_id": "DE98ZZZ09999999999",
    "debtor_iban": "DE02120300000000202051",
    "paid": True,
    "payment_terms": "#SKONTO#TAGE=14#PROZENT=2.00#\n",
}


def ids(problems):
    return sorted(p.split(":")[0] for p in problems)


class PaymentOracles(unittest.TestCase):
    def setUp(self):
        self.doc = etree.fromstring(XML.encode())

    def test_facts_that_the_xml_states(self):
        self.assertEqual(oracles.check(FACTS, self.doc, None, "xrechnung"), [])

    def test_every_payment_fact_is_checked(self):
        wrong = {
            "payment_means": ["58"],
            "mandate": "M-1",
            "creditor_id": "DE00ZZZ09999999999",
            "debtor_iban": "DE00120300000000202051",
            "payment_terms": "#SKONTO#TAGE=14#PROZENT=2.00#",
            "account_name": "Factoring Bank AG",
            "card": ["1234", None],
        }
        self.assertEqual(
            ids(oracles.check(wrong, self.doc, None, "xrechnung")),
            ["O-BG18", "O-BT20", "O-BT81", "O-BT85", "O-BT89", "O-BT90", "O-BT91"],
        )

    def test_payment_card(self):
        doc = etree.fromstring(CARD.encode())
        facts = {"payment_means": ["54"], "card": ["1234", "Erika Kunde"]}
        self.assertEqual(oracles.check(facts, doc, None, "en16931"), [])
        self.assertEqual(ids(oracles.check({"card": ["1234", None]}, doc, None, "en16931")), ["O-BG18"])

    def test_paid_invoice(self):
        unpaid = etree.fromstring(XML.replace("<ram:DuePayableAmount>0.00", "<ram:DuePayableAmount>119.00").encode())
        self.assertEqual(ids(oracles.check({"paid": True}, unpaid, None, "en16931")), ["O-BT113"])
        self.assertEqual(oracles.check({"paid": False}, unpaid, None, "en16931"), [])

    def test_minimum_states_no_payment_means(self):
        self.assertEqual(oracles.check({"payment_means": ["10"]}, self.doc, None, "minimum"), [])


if __name__ == "__main__":
    unittest.main()
