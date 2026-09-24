"""The architecture of the e-invoice path (no Typst, no Java).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

The printed invoice and its XML are one invoice (docs/docs/e-invoicing.md,
"Printed = Written"): the data model of the e-invoice (src/zugferd/model.typ)
takes the amounts the invoice computed and prints, and the serializer
(src/zugferd/build.typ) writes the model. No module of the e-invoice path
computes the amounts of an invoice a second time, so they cannot drift apart:
none imports a module of src/logic that computes them. The one derivation,
the net amounts of gross prices from the printed gross amounts, has a module
of its own (src/logic/net-amounts.typ), which the rules of the equivalence
check (IP-PRINT-01, IP-CALC-*) compare with the printed invoice.
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LOGIC = REPO / "src" / "logic"
EINVOICE = REPO / "src" / "zugferd"

# The modules of src/logic that compute the amounts of an invoice: the
# lines, bundles, allowances and charges, the VAT groups and the cash
# discounts.
CALCULATION = (
    "calc-bundle.typ",
    "calc-item.typ",
    "cash-discount.typ",
    "group-by-tax.typ",
    "modifier-applicator.typ",
    "tax-applicator.typ",
)

# Every import, also one inside a function (a module that loads on demand).
_IMPORT = re.compile(r'\bimport\s+"([^"]+)"')


def imported_modules(path):
    """The files a Typst module imports by relative or root path."""
    found = set()
    for spec in _IMPORT.findall(path.read_text(encoding="utf-8")):
        if spec.startswith("@"):
            continue
        target = REPO / spec.lstrip("/") if spec.startswith("/") else path.parent / spec
        found.add(target.resolve())
    return found


def reachable(path, within):
    """The modules `path` imports under `within`, directly or through other
    modules under it, and the files it reaches outside (not followed)."""
    seen, outside, todo = set(), set(), [path.resolve()]
    while todo:
        module = todo.pop()
        for target in imported_modules(module):
            if not target.is_relative_to(within.resolve()):
                outside.add(target)
            elif target not in seen:
                seen.add(target)
                todo.append(target)
    return seen, outside


class OneSourceOfTruth(unittest.TestCase):
    def test_the_calculation_modules_exist(self):
        # A renamed or new module must not slip out of the check unnoticed.
        for name in CALCULATION:
            self.assertTrue((LOGIC / name).is_file(), name)

    def test_the_e_invoice_path_computes_no_amounts(self):
        calculation = {(LOGIC / name).resolve() for name in CALCULATION}
        modules = sorted(EINVOICE.rglob("*.typ"))
        self.assertIn(EINVOICE / "model.typ", modules)
        self.assertIn(EINVOICE / "build.typ", modules)
        for module in modules:
            with self.subTest(str(module.relative_to(REPO))):
                used = set()
                for target in imported_modules(module):
                    if target.is_relative_to(LOGIC.resolve()):
                        # What a module of src/logic imports from there, too.
                        used |= {target} | reachable(target, LOGIC)[0]
                self.assertEqual(sorted(p.name for p in used & calculation), [])

    def test_the_net_amounts_of_gross_prices_are_the_one_derivation(self):
        # The model reads them from logic/net-amounts.typ, which computes
        # nothing else: it imports no calculation module either.
        self.assertIn((LOGIC / "net-amounts.typ").resolve(), imported_modules(EINVOICE / "model.typ"))
        seen, _ = reachable(LOGIC / "net-amounts.typ", LOGIC)
        self.assertEqual(sorted(p.name for p in seen if p.name in CALCULATION), [])


if __name__ == "__main__":
    unittest.main()
