"""Semantic oracles: the XML says what the input and the printed PDF say.

The official validators only check that an e-invoice is well-formed and
consistent. The oracles check that it is *right*: every fact the generator
put into the invoice (`facts` in the manifest, or the `// facts:` header of a
regression case) must reach its business term, and the amounts the XML
states must be the ones printed on the PDF.

Every problem is a string "O-<name>: <detail>"; the part before the colon is
the oracle id used in failure signatures.

Facts (all optional; an absent fact is not checked):

  profile                  profile of the XML (BT-24)            O-profile
  invoice_nr, type_code    BT-1, BT-3                            O-BT1, O-BT3
  currency                 BT-5                                  O-BT5
  seller_name, buyer_name  BT-27, BT-44                          O-BT27, O-BT44
  seller_vat               BT-31                                 O-BT31
  seller_tax_nr            BT-32                                 O-BT32
  seller_ids               [[scheme, id], ..] in BT-29           O-BT29
  buyer_vat                BT-48                                 O-BT48
  buyer_ids                [[scheme, id], ..] in BT-46           O-BT46
  seller_legal_id, buyer_legal_id  [scheme, id] of BT-30, BT-47 ("" without scheme)  O-BT30, O-BT47
  seller_trading_name, buyer_trading_name  BT-28, BT-45          O-BT28, O-BT45
  seller_legal_info        BT-33                                 O-BT33
  buyer_reference          BT-10                                 O-BT10
  buyer_contact            {name, phone, email} of BG-9          O-BG9
  tax_representative       {name, vat, country} of BG-11         O-BG11
  payee                    {name, ids, legal_id} of BG-10 (not in MINIMUM)  O-BG10
  preceding_invoice        [BT-25, BT-26 (YYYYMMDD)] of BG-3     O-BT25
  notes                    [[subject code or "", text], ..] of the invoice notes
                           (BT-21, BT-22), in order              O-BT22
  seller_post_code/_city   BT-38, BT-37                          O-BT38, O-BT37
  buyer_post_code/_city_name  BT-53, BT-52                       O-BT53, O-BT52
  seller_country, buyer_country, ship_to_country  BT-40/55/80    O-BT40/55/80
  breakdown                [[category, rate], ..] of BG-23       O-BG23
  grounds                  [[category, text], ..] in BT-120      O-BT120
  doc_modifiers, item_modifiers  [{name, charge, percent|amount}]  O-BG20/21, O-BG27/28
  tax_mode                 "inclusive": amounts of modifiers are gross
  period                   [start, end] of BG-14 (YYYYMMDD)      O-BG14
  due_date                 BT-9 (YYYYMMDD)                       O-BT9
  iban                     BT-84                                 O-BT84
  payment_means            BT-81 of each payment means, in order O-BT81
  account_name             BT-85 (EN 16931, XRechnung)           O-BT85
  card                     [BT-87, BT-88] of the payment card (EN 16931, XRechnung)  O-BG18
  mandate, creditor_id     BT-89, BT-90                          O-BT89, O-BT90
  debtor_iban              BT-91                                 O-BT91
  paid                     true: BT-113 = BT-112, BT-115 = 0     O-BT113
  payment_terms            BT-20, exactly                        O-BT20
  units                    BT-130 of every line, in order        O-BT130
  line_names               BT-153 of every line, in order        O-BT153
  item_notes               [[line name, note], ..]: the note (BT-127) of the lines
                           of that name; the other lines have none   O-BT127
  item_origins             [[line name, country], ..]: the country of origin
                           (BT-159, EN 16931, XRechnung) of the lines of that
                           name; the other lines have none       O-BT159
  number_format            [decimal sign, group sign] of the printed amounts
  skip_oracles             oracle ids not to check for this case

Independent of the facts, the PDF text must contain the grand total and the
amount due (O-PDF-BT112, O-PDF-BT115) and every exemption reason of the XML
(O-PDF-BT120).

`check_diagnostics` checks invoice-pro's own messages in every case: each
error names its rule, the input field, what is wrong and a hint (O-DIAG).
"""

import re
from decimal import Decimal

from common import NS, dec, xtext, xtext1

HEADER = "rsm:SupplyChainTradeTransaction"
AGREEMENT = HEADER + "/ram:ApplicableHeaderTradeAgreement"
DELIVERY = HEADER + "/ram:ApplicableHeaderTradeDelivery"
SETTLEMENT = HEADER + "/ram:ApplicableHeaderTradeSettlement"
SUMMATION = SETTLEMENT + "/ram:SpecifiedTradeSettlementHeaderMonetarySummation"
LINES = HEADER + "/ram:IncludedSupplyChainTradeLineItem"

# Profiles whose XML carries these parts at all (src/zugferd/profile.typ):
# the addresses, the settlement, the payee, the notes and the document
# references; the invoice lines; the payment card, the account name and the
# country of origin of an item.
WITH_ADDRESSES = ("basic-wl", "basic", "en16931", "xrechnung")
WITH_LINES = ("basic", "en16931", "xrechnung")
WITH_DETAILS = ("en16931", "xrechnung")
CENT = Decimal("0.01")
# (decimal sign, group sign) of printed amounts, tried in turn when the case
# does not state the format of its locale.
NUMBER_FORMATS = [(",", "."), (".", ","), (".", "'"), (",", "\u00a0"), (",", " ")]


def _find(el, path):
    """Text of the first element at `path` below `el` (prefixes of NS)."""
    found = el.xpath(path, namespaces=NS)
    return found[0].text if found else None


def _nows(text):
    """Text without whitespace and without hyphenation at line ends."""
    text = re.sub(r"-\n", "", text or "")
    return re.sub(r"[\s\u00a0\u202f\u2009\u00ad]+", "", text)


def format_amount(value, number_format):
    """1234.5 -> '1.234,50' for (',', '.'), without sign."""
    decimal_sign, group_sign = number_format
    q = abs(Decimal(value)).quantize(CENT)
    whole, frac = f"{q:.2f}".split(".")
    groups = []
    while len(whole) > 3:
        groups.insert(0, whole[-3:])
        whole = whole[:-3]
    groups.insert(0, whole)
    return group_sign.join(groups) + decimal_sign + frac


def _split_bracket(name):
    """'Paket (5,5% S)' -> ('Paket', Decimal('5.5')); a bundle is split into
    one line per VAT group, labelled with the group's rate."""
    m = re.match(r"^(.*) \((-?[0-9]+(?:[.,][0-9]+)?)\s?% [A-Z]{1,2}\)$", name)
    if not m:
        return name, None
    return m.group(1), dec(m.group(2).replace(",", "."))


def _party_ids(doc, party):
    """[scheme, id] of the identifiers of a party (BT-29, BT-46): scheme ""
    for a plain ram:ID, the schemeID of a ram:GlobalID."""
    got = [["", e.text or ""] for e in doc.xpath(party + "/ram:ID", namespaces=NS)]
    got += [[e.get("schemeID") or "", e.text or ""] for e in doc.xpath(party + "/ram:GlobalID", namespaces=NS)]
    return got


def _legal_id(doc, party):
    """[scheme, id] of the legal registration identifier of a party (BT-30,
    BT-47, BT-61): scheme "" without one; None without identifier."""
    found = doc.xpath(party + "/ram:SpecifiedLegalOrganization/ram:ID", namespaces=NS)
    return [found[0].get("schemeID") or "", found[0].text or ""] if found else None


def _party_details(check, facts, doc, profile):
    """The party details besides names, addresses and VAT identifiers."""
    seller = AGREEMENT + "/ram:SellerTradeParty"
    buyer = AGREEMENT + "/ram:BuyerTradeParty"
    # Legal registration identifiers, which every profile carries.
    for key, party, oracle in (("seller_legal_id", seller, "O-BT30"), ("buyer_legal_id", buyer, "O-BT47")):
        if facts.get(key):
            got = _legal_id(doc, party)
            check(oracle, got == list(facts[key]), f"{got} != {list(facts[key])}")
    for key, path, oracle in (
        ("seller_trading_name", seller + "/ram:SpecifiedLegalOrganization/ram:TradingBusinessName", "O-BT28"),
        ("buyer_trading_name", buyer + "/ram:SpecifiedLegalOrganization/ram:TradingBusinessName", "O-BT45"),
        ("seller_legal_info", seller + "/ram:Description", "O-BT33"),
        ("buyer_reference", AGREEMENT + "/ram:BuyerReference", "O-BT10"),
    ):
        if facts.get(key):
            got = xtext(doc, path)
            check(oracle, got == [facts[key]], f"{got} != {facts[key]!r}")
    if facts.get("buyer_contact"):
        contact = buyer + "/ram:DefinedTradeContact"
        got = {
            "name": xtext1(doc, contact + "/ram:PersonName"),
            "phone": xtext1(doc, contact + "/ram:TelephoneUniversalCommunication/ram:CompleteNumber"),
            "email": xtext1(doc, contact + "/ram:EmailURIUniversalCommunication/ram:URIID"),
        }
        want = {key: facts["buyer_contact"].get(key) for key in ("name", "phone", "email")}
        check("O-BG9", got == want, f"{got} != {want}")
    if facts.get("tax_representative"):
        representative = AGREEMENT + "/ram:SellerTaxRepresentativeTradeParty"
        got = {
            "name": xtext1(doc, representative + "/ram:Name"),
            "vat": xtext1(doc, representative + "/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']"),
            "country": xtext1(doc, representative + "/ram:PostalTradeAddress/ram:CountryID"),
        }
        want = {key: facts["tax_representative"].get(key) for key in ("name", "vat", "country")}
        check("O-BG11", got == want, f"{got} != {want}")
    if facts.get("payee") and profile in WITH_ADDRESSES:
        payee = SETTLEMENT + "/ram:PayeeTradeParty"
        got = {
            "name": xtext1(doc, payee + "/ram:Name"),
            "ids": _party_ids(doc, payee),
            "legal_id": _legal_id(doc, payee),
        }
        want = facts["payee"]
        want = {
            "name": want.get("name"),
            "ids": [list(pair) for pair in want.get("ids", [])],
            "legal_id": list(want["legal_id"]) if want.get("legal_id") else None,
        }
        check("O-BG10", got == want, f"{got} != {want}")


def _allowance_charges(elements):
    out = []
    for el in elements:
        charge = (_find(el, "ram:ChargeIndicator/udt:Indicator") or "").strip()
        out.append(
            {
                "charge": charge == "true",
                "reason": (_find(el, "ram:Reason") or "").strip(),
                "percent": dec(_find(el, "ram:CalculationPercent")),
                "basis": dec(_find(el, "ram:BasisAmount")),
                "amount": dec(_find(el, "ram:ActualAmount"), Decimal(0)),
                "rate": dec(_find(el, "ram:CategoryTradeTax/ram:RateApplicablePercent"), Decimal(0)),
            }
        )
    return out


def _check_modifiers(check, oracle, facts_mods, found, inclusive, line_rates=None):
    """Every declared modifier is written with its name, percentage and amount."""
    for mod in facts_mods:
        parts = [p for p in found if p["charge"] == mod["charge"] and p["reason"] == mod["name"]]
        kind = "charge" if mod["charge"] else "allowance"
        if not check(oracle, parts, f"{kind} {mod['name']!r} is missing"):
            continue
        if "percent" in mod:
            want = Decimal(mod["percent"])
            for p in parts:
                if p["percent"] is not None:
                    check(oracle, p["percent"] == want, f"{kind} {mod['name']!r}: percentage {p['percent']} != {want}")
                if p["percent"] is not None and p["basis"] is not None:
                    expected = (p["basis"] * p["percent"] / 100).quantize(CENT)
                    check(
                        oracle,
                        abs(expected - p["amount"]) <= CENT,
                        f"{kind} {mod['name']!r}: {p['amount']} != {p['basis']} x {p['percent']} %",
                    )
        if "amount" in mod:
            want = Decimal(mod["amount"])
            if inclusive:
                total = sum((p["amount"] * (1 + p["rate"] / 100) for p in parts), Decimal(0))
            else:
                total = sum((p["amount"] for p in parts), Decimal(0))
            check(
                oracle,
                abs(total - want) <= CENT * len(parts),
                f"{kind} {mod['name']!r}: written {'gross ' if inclusive else ''}total {total:.4f} != {want}",
            )


def _check_payment(check, facts, doc, profile):
    """The payment means (BG-16) and payment terms the input states: the codes
    (BT-81), the account name (BT-85), the payment card (BG-18), the direct
    debit (BT-89, BT-90, BT-91), a paid invoice (BT-113, BT-115) and the terms
    (BT-20)."""
    means = SETTLEMENT + "/ram:SpecifiedTradeSettlementPaymentMeans"
    terms = SETTLEMENT + "/ram:SpecifiedTradePaymentTerms"
    expected = {
        "O-BT81": ("payment_means", means + "/ram:TypeCode"),
        "O-BT85": ("account_name", means + "/ram:PayeePartyCreditorFinancialAccount/ram:AccountName"),
        "O-BT89": ("mandate", terms + "/ram:DirectDebitMandateID"),
        "O-BT90": ("creditor_id", SETTLEMENT + "/ram:CreditorReferenceID"),
        "O-BT91": ("debtor_iban", means + "/ram:PayerPartyDebtorFinancialAccount/ram:IBANID"),
        "O-BT20": ("payment_terms", terms + "/ram:Description"),
    }
    for oracle, (fact, path) in expected.items():
        if facts.get(fact) is None or (fact == "account_name" and profile not in WITH_DETAILS):
            continue
        want = facts[fact] if isinstance(facts[fact], list) else [facts[fact]]
        got = xtext(doc, path)
        check(oracle, got == want, f"{got} != {want!r}")
    if facts.get("card") is not None and profile in WITH_DETAILS:
        card = means + "/ram:ApplicableTradeSettlementFinancialCard"
        got = [xtext1(doc, card + "/ram:ID"), xtext1(doc, card + "/ram:CardholderName")]
        check("O-BG18", got == list(facts["card"]), f"{got} != {facts['card']!r}")
    if facts.get("paid"):
        grand = dec(xtext1(doc, SUMMATION + "/ram:GrandTotalAmount"))
        paid = dec(xtext1(doc, SUMMATION + "/ram:TotalPrepaidAmount"))
        due = dec(xtext1(doc, SUMMATION + "/ram:DuePayableAmount"))
        check("O-BT113", paid == grand and due == 0, f"paid {paid}, due {due} of {grand}")


def _check_references(check, facts, doc):
    """The preceding invoice (BG-3) and the invoice notes (BT-21, BT-22)."""
    if facts.get("preceding_invoice"):
        reference = SETTLEMENT + "/ram:InvoiceReferencedDocument"
        got = [[e.findtext("ram:IssuerAssignedID", namespaces=NS),
                e.findtext("ram:FormattedIssueDateTime/qdt:DateTimeString", namespaces=NS)]
               for e in doc.xpath(reference, namespaces=NS)]
        want = [list(facts["preceding_invoice"])]
        check("O-BT25", got == want, f"{got} != {want}")
    if facts.get("notes"):
        got = [[_find(n, "ram:SubjectCode") or "", _find(n, "ram:Content") or ""]
               for n in doc.xpath("rsm:ExchangedDocument/ram:IncludedNote", namespaces=NS)]
        want = [list(note) for note in facts["notes"]]
        # Every note, in order; notes of other inputs may come between them.
        rest = iter(got)
        check("O-BT22", all(note in rest for note in want), f"{want} not in {got}")


def _check_line_details(check, facts, lines, profile):
    """The note (BT-127) and the country of origin (BT-159) of the lines, by
    the name of the line (BT-153): the lines with a name of the facts have
    its value, every other line has none."""
    for fact, oracle, path, profiles in (
        ("item_notes", "O-BT127", "ram:AssociatedDocumentLineDocument/ram:IncludedNote/ram:Content", WITH_LINES),
        ("item_origins", "O-BT159", "ram:SpecifiedTradeProduct/ram:OriginTradeCountry/ram:ID", WITH_DETAILS),
    ):
        if facts.get(fact) is None or profile not in profiles:
            continue
        want = {name: value for name, value in facts[fact]}
        names = set()
        for line in lines:
            name = _find(line, "ram:SpecifiedTradeProduct/ram:Name") or ""
            names.add(name)
            got = [e.text or "" for e in line.xpath(path, namespaces=NS)]
            expected = [want[name]] if name in want else []
            check(oracle, got == expected, f"line {name!r}: {got} != {expected}")
        for name in want:
            check(oracle, name in names, f"no line {name!r}")


def check(facts, doc, pdf_text, profile):
    """Problems of one case (list of "O-<id>: detail")."""
    problems = []
    skip = set(facts.get("skip_oracles", []))

    def check_(oracle, ok, detail=""):
        if not ok and oracle not in skip:
            problems.append(f"{oracle}: {detail}")
        return ok

    guideline_profile = facts.get("profile")
    if guideline_profile:
        check_("O-profile", profile == guideline_profile, f"{profile} != {guideline_profile}")
    if facts.get("invoice_nr") is not None:
        got = xtext(doc, "rsm:ExchangedDocument/ram:ID")
        check_("O-BT1", got == [facts["invoice_nr"]], f"{got} != {facts['invoice_nr']!r}")
    if facts.get("type_code"):
        got = xtext(doc, "rsm:ExchangedDocument/ram:TypeCode")
        check_("O-BT3", got == [facts["type_code"]], f"{got} != {facts['type_code']!r}")
    if facts.get("currency"):
        got = xtext(doc, SETTLEMENT + "/ram:InvoiceCurrencyCode")
        check_("O-BT5", got == [facts["currency"]], f"{got} != {facts['currency']!r}")

    seller = AGREEMENT + "/ram:SellerTradeParty"
    buyer = AGREEMENT + "/ram:BuyerTradeParty"
    if facts.get("seller_name"):
        got = xtext(doc, seller + "/ram:Name")
        check_("O-BT27", got == [facts["seller_name"]], f"{got} != {facts['seller_name']!r}")
    if facts.get("buyer_name"):
        got = xtext(doc, buyer + "/ram:Name")
        check_("O-BT44", got == [facts["buyer_name"]], f"{got} != {facts['buyer_name']!r}")
    if facts.get("seller_vat"):
        got = xtext(doc, seller + "/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']")
        check_("O-BT31", got == [facts["seller_vat"]], f"{got} != {facts['seller_vat']!r}")
    if facts.get("seller_tax_nr"):
        got = xtext(doc, seller + "/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='FC']")
        check_("O-BT32", got == [facts["seller_tax_nr"]], f"{got} != {facts['seller_tax_nr']!r}")
    # MINIMUM has no seller identifier and no buyer identifiers.
    if facts.get("seller_ids") and profile != "minimum":
        got = _party_ids(doc, seller)
        for pair in facts["seller_ids"]:
            check_("O-BT29", list(pair) in got, f"seller identifier {pair} not in {got}")
    if facts.get("buyer_ids") and profile != "minimum":
        got = _party_ids(doc, buyer)
        for pair in facts["buyer_ids"]:
            check_("O-BT46", list(pair) in got, f"buyer identifier {pair} not in {got}")
    if facts.get("buyer_vat") and profile != "minimum":
        got = xtext(doc, buyer + "/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']")
        check_("O-BT48", got == [facts["buyer_vat"]], f"{got} != {facts['buyer_vat']!r}")
    if facts.get("seller_country"):
        got = xtext(doc, seller + "/ram:PostalTradeAddress/ram:CountryID")
        check_("O-BT40", got == [facts["seller_country"]], f"{got} != {facts['seller_country']!r}")
    _party_details(check_, facts, doc, profile)

    if profile in WITH_ADDRESSES:
        for key, path, oracle in (
            ("seller_post_code", seller + "/ram:PostalTradeAddress/ram:PostcodeCode", "O-BT38"),
            ("seller_city", seller + "/ram:PostalTradeAddress/ram:CityName", "O-BT37"),
            ("buyer_post_code", buyer + "/ram:PostalTradeAddress/ram:PostcodeCode", "O-BT53"),
            ("buyer_city_name", buyer + "/ram:PostalTradeAddress/ram:CityName", "O-BT52"),
        ):
            if facts.get(key):
                got = xtext(doc, path)
                check_(oracle, got == [facts[key]], f"{got} != {facts[key]!r}")
        if facts.get("buyer_country"):
            got = xtext(doc, buyer + "/ram:PostalTradeAddress/ram:CountryID")
            check_("O-BT55", got == [facts["buyer_country"]], f"{got} != {facts['buyer_country']!r}")
        if facts.get("ship_to_country"):
            got = xtext(doc, DELIVERY + "/ram:ShipToTradeParty/ram:PostalTradeAddress/ram:CountryID")
            check_("O-BT80", got == [facts["ship_to_country"]], f"{got} != {facts['ship_to_country']!r}")

        # VAT breakdown (BG-23): the categories and rates the input asked for.
        taxes = doc.xpath(SETTLEMENT + "/ram:ApplicableTradeTax", namespaces=NS)
        if facts.get("breakdown") is not None:
            got = sorted((_find(t, "ram:CategoryCode") or "", _norm_rate(_find(t, "ram:RateApplicablePercent"))) for t in taxes)
            want = sorted((category, _norm_rate(rate)) for category, rate in facts["breakdown"])
            check_("O-BG23", got == want, f"{got} != {want}")

        # BT-120: every exemption ground the user wrote reaches its category.
        reasons = {}
        for t in taxes:
            reasons.setdefault(_find(t, "ram:CategoryCode"), []).append(_find(t, "ram:ExemptionReason") or "")
        for category, text in facts.get("grounds", []):
            check_(
                "O-BT120",
                any(text in r for r in reasons.get(category, [])),
                f"{category} {text!r} not in {reasons.get(category)}",
            )

        inclusive = facts.get("tax_mode") == "inclusive"
        header_ac = _allowance_charges(
            doc.xpath(SETTLEMENT + "/ram:SpecifiedTradeAllowanceCharge", namespaces=NS)
        )
        _check_modifiers(check_, "O-BG20/21", facts.get("doc_modifiers", []), header_ac, inclusive)

        if facts.get("period"):
            start = xtext(doc, SETTLEMENT + "/ram:BillingSpecifiedPeriod/ram:StartDateTime/udt:DateTimeString")
            end = xtext(doc, SETTLEMENT + "/ram:BillingSpecifiedPeriod/ram:EndDateTime/udt:DateTimeString")
            check_("O-BG14", start + end == list(facts["period"]), f"{start + end} != {list(facts['period'])}")
        if facts.get("due_date"):
            got = xtext(doc, SETTLEMENT + "/ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime/udt:DateTimeString")
            check_("O-BT9", got == [facts["due_date"]], f"{got} != {facts['due_date']!r}")
        if facts.get("iban"):
            got = xtext(
                doc,
                SETTLEMENT + "/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:IBANID",
            )
            check_("O-BT84", got == [facts["iban"]], f"{got} != {facts['iban']!r}")
        _check_payment(check_, facts, doc, profile)
        _check_references(check_, facts, doc)

    if profile in WITH_LINES:
        lines = doc.xpath(LINES, namespaces=NS)
        rate_path = "ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent"
        if facts.get("line_names") is not None:
            names = [_find(line, "ram:SpecifiedTradeProduct/ram:Name") or "" for line in lines]
            rates = [dec(_find(line, rate_path)) for line in lines]
            check_("O-BT153", _names_match(names, rates, facts["line_names"]), f"{names} != {facts['line_names']}")
        if facts.get("units") is not None:
            units = [line.xpath("string(ram:SpecifiedLineTradeDelivery/ram:BilledQuantity/@unitCode)", namespaces=NS)
                     for line in lines]
            check_("O-BT130", units == list(facts["units"]), f"{units} != {facts['units']}")
        # Line allowances and charges (BG-27/28) have the VAT rate of their line.
        line_ac = []
        for line in lines:
            rate = dec(_find(line, rate_path), Decimal(0))
            for part in _allowance_charges(
                line.xpath("ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeAllowanceCharge", namespaces=NS)
            ):
                part["rate"] = rate
                line_ac.append(part)
        _check_modifiers(check_, "O-BG27/28", facts.get("item_modifiers", []), line_ac, facts.get("tax_mode") == "inclusive")
        _check_line_details(check_, facts, lines, profile)

    # The printed PDF states the amounts of the XML.
    if pdf_text is not None:
        text = _nows(pdf_text)
        formats = [tuple(facts["number_format"])] if facts.get("number_format") else NUMBER_FORMATS
        for bt, path in (("BT112", SUMMATION + "/ram:GrandTotalAmount"), ("BT115", SUMMATION + "/ram:DuePayableAmount")):
            value = xtext1(doc, path)
            if value is not None and dec(value) is not None:
                printed = [format_amount(value, f) for f in formats]
                check_(
                    "O-PDF-" + bt,
                    any(_nows(p) in text for p in printed),
                    f"{value} ({' / '.join(printed)}) is not printed",
                )
        if profile in WITH_ADDRESSES:
            for reason in xtext(doc, SETTLEMENT + "/ram:ApplicableTradeTax/ram:ExemptionReason"):
                for part in reason.split("; "):
                    check_("O-PDF-BT120", _nows(part) in text, f"exemption reason {part!r} is not printed")
    return problems


def check_diagnostics(diagnostics):
    """Every error names the rule, the input field, the problem and a hint
    how to fix it, so that a user can act on it (list of "O-DIAG: detail")."""
    problems = []
    for d in diagnostics:
        if d.get("level") != "error":
            continue
        missing = [key for key in ("rule", "field", "message", "hint") if not d.get(key)]
        if missing:
            problems.append(f"O-DIAG: error [{d.get('rule') or '?'}] {d.get('field') or ''} has no {', '.join(missing)}")
    return problems


def _norm_rate(rate):
    """'19.00' -> '19', '5.50' -> '5.5'; no rate (allowed for O) -> '0'."""
    value = dec(rate) if rate is not None else None
    return "0" if value is None else format(value.normalize(), "f")


def _names_match(names, rates, expected):
    """Line names in order; a bundle split per VAT group repeats its name
    with the rate of each group, which must be the line's rate."""
    got = []
    for name, rate in zip(names, rates):
        base, bracket_rate = _split_bracket(name)
        if bracket_rate is not None:
            if rate is None or bracket_rate != rate:
                return False
            if got and got[-1] == base:
                continue
            got.append(base)
        else:
            got.append(name)
    return got == list(expected)
