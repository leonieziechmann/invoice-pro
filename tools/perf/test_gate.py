"""Unit tests of the performance gate's thresholds and of the live preview
of measure.py (no Typst).

  python3 -m unittest discover -s tools/perf -p 'test_gate.py'
"""

import queue
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gate  # noqa: E402
import measure  # noqa: E402


def row(lines, share, import_ms=5.0, serializer_ms=None, plain_einvoice_ms=0.0, lazy_loaded=()):
    plain = 100.0 * lines
    return {
        "lazy_loaded": list(lazy_loaded),
        "lines": lines,
        "plain_total_ms": plain,
        "zf_total_ms": plain * (1 + share / 100),
        "einvoice_ms": plain * share / 100,
        "import_ms": import_ms,
        "process_ms": plain * share / 100 - import_ms,
        "serializer_ms": serializer_ms,
        "plain_einvoice_ms": plain_einvoice_ms,
        "share_pct": share,
        "total_diff_pct": share,
    }


class Thresholds(unittest.TestCase):
    def test_green(self):
        self.assertEqual(gate.verdict([row(5, 14.9), row(50, 14.9), row(300, 10.0)], None, False), ([], []))

    def test_small_invoices_are_yellow_up_to_the_ceiling(self):
        red, yellow = gate.verdict([row(5, 20.0)], None, False)
        self.assertEqual((len(red), len(yellow)), (0, 1))
        red, yellow = gate.verdict([row(5, 20.0)], None, True)  # release gate
        self.assertEqual((len(red), len(yellow)), (1, 0))
        red, _ = gate.verdict([row(5, 25.1)], None, False)
        self.assertEqual(len(red), 1)

    def test_large_invoices_are_red_above_the_target(self):
        red, _ = gate.verdict([row(50, 15.1), row(300, 15.1)], None, False)
        self.assertEqual(len(red), 2)

    def test_component_budgets_and_plain_invoices(self):
        _, yellow = gate.verdict([row(50, 10.0, import_ms=13.0, serializer_ms=30.0)], None, False)
        self.assertEqual(len(yellow), 2)
        red, _ = gate.verdict([row(5, 10.0, plain_einvoice_ms=17.0)], 0.5, False)
        self.assertEqual(len(red), 1)
        self.assertEqual(gate.verdict([row(5, 10.0, plain_einvoice_ms=17.0)], None, False), ([], []))

    def test_linearity(self):
        rows = [row(300, 10.0), row(1000, 10.0)]
        rows[1]["process_ms"] = rows[0]["process_ms"] * 4.5
        red, _ = gate.verdict(rows, None, False)
        self.assertTrue(any("1000 / 300" in m for m in red))
        # The import (the same at every size) does not hide a loss of linearity.
        rows = [row(300, 10.0, import_ms=500.0), row(1000, 10.0, import_ms=500.0)]
        rows[0]["process_ms"], rows[1]["process_ms"] = 100.0, 450.0
        rows[0]["einvoice_ms"], rows[1]["einvoice_ms"] = 600.0, 950.0  # ratio 1.6 with the import
        red, _ = gate.verdict(rows, None, False)
        self.assertTrue(any("1000 / 300" in m for m in red))

    def test_lazy_loading(self):
        red, _ = gate.verdict([row(5, 10.0, lazy_loaded=["src/zugferd/guard/rare.typ"])], None, False)
        self.assertEqual(len(red), 1)
        self.assertIn("src/zugferd/guard/rare.typ", red[0])
        self.assertEqual(gate.verdict([row(5, 10.0)], None, False), ([], []))

    def test_missing_measurements_are_noted(self):
        self.assertEqual(gate.notes([row(50, 10.0, serializer_ms=20.0)]), [])
        self.assertEqual(len(gate.notes([row(50, 10.0)])), 1)


class Trace(unittest.TestCase):
    def test_einvoice_time_counts_outermost_events_only(self):
        def span(name, file, start, end):
            args = {"file": file, "line": 1} if file else None
            return [
                {"name": name, "ph": "B", "ts": start, "args": args},
                {"name": name, "ph": "E", "ts": end, "args": args},
            ]

        events = (
            [{"name": "compile once", "ph": "B", "ts": 0, "args": None}]
            + span("eval", "/src/lib.typ", 1, 2)
            # import of the e-invoice modules with a nested module
            + [{"name": "eval", "ph": "B", "ts": 10, "args": {"file": "/src/zugferd/zugferd.typ", "line": 1}}]
            + span("eval", "/src/zugferd/model.typ", 11, 15)
            + [{"name": "eval", "ph": "E", "ts": 20, "args": {"file": "/src/zugferd/zugferd.typ", "line": 1}}]
            # a call of process-zugferd from the root component
            + [{"name": "func call", "ph": "B", "ts": 30, "args": {"file": "/src/components/root.typ", "line": 9}}]
            + span("func call", "/src/zugferd/zugferd.typ", 31, 61)
            + [{"name": "func call", "ph": "E", "ts": 70, "args": {"file": "/src/components/root.typ", "line": 9}}]
            + [{"name": "compile once", "ph": "E", "ts": 100, "args": None}]
        )
        result = gate.aggregate(events)
        self.assertEqual(result["total"], 100)
        self.assertEqual(result["einvoice"], 40)  # 10 import + 30 call
        self.assertEqual(result["einvoice_import"], 10)
        self.assertEqual(gate.lazy_loads(result["inclusive"]), [])

    def test_lazy_loads_are_found_by_module_and_by_call(self):
        registry = gate.function_key(*gate.LAZY_CALLS[0])
        self.assertIsNotNone(registry, "LAZY_CALLS names a function that does not exist")
        inclusive = {
            "eval /src/zugferd/zugferd.typ:1": 5.0,
            "eval /src/zugferd/guard/rare.typ:1": 1.0,
            registry: 1.0,
        }
        self.assertEqual(
            gate.lazy_loads(inclusive),
            ["src/zugferd/guard/rare.typ", f"{gate.LAZY_CALLS[0][0]} ({gate.LAZY_CALLS[0][1]})"],
        )
        for module in gate.LAZY_MODULES:
            self.assertTrue((gate.REPO / module).exists(), module)


class Watch(unittest.TestCase):
    """measure.py --watch: the reports of `typst watch` and the edits."""

    def watcher(self, directory, lines=()):
        # A watcher without its process: `compiled` reads the lines.
        watcher = object.__new__(measure.Watcher)
        watcher.source = "#item([A], price: 10.50)\n#item([B], price: 7)\n"
        watcher.text = watcher.source
        watcher.copy = str(Path(directory) / ".copy.typ")
        watcher.reported = 0.0
        watcher.lines = queue.Queue()
        for line in lines:
            watcher.lines.put(line)
        return watcher

    def test_reports_in_milliseconds(self):
        with tempfile.TemporaryDirectory() as tmp:
            watcher = self.watcher(tmp, [
                "watching doc.typ\n",
                "[20:27:06] compiling ...\n",
                "[20:27:06] compiled successfully in 8.47 s\n",
                "[20:27:21] compiled with warnings in 6.22 ms\n",
                "[20:27:22] compiled successfully in 850 µs\n",
            ])
            self.assertAlmostEqual(watcher.compiled(), 8470.0)
            self.assertAlmostEqual(watcher.compiled(), 6.22)
            self.assertAlmostEqual(watcher.compiled(), 0.85)

    def test_a_failed_compile_stops_the_measurement(self):
        with tempfile.TemporaryDirectory() as tmp:
            watcher = self.watcher(tmp, ["[20:46:31] compiled with errors\n"])
            with self.assertRaises(SystemExit) as caught:
                watcher.compiled(timeout=0.5, again=0.1)
            self.assertIn("does not compile", str(caught.exception))

    def test_every_edit_is_a_new_price_of_the_first_item(self):
        with tempfile.TemporaryDirectory() as tmp:
            watcher = self.watcher(tmp)
            prices = set()
            for n in range(30):
                watcher.edit(n)
                text = Path(watcher.copy).read_text(encoding="utf-8")
                self.assertEqual(text, watcher.text)
                first, second = re.findall(r"price: ([0-9.]+)", text)
                self.assertEqual(second, "7")
                prices.add(first)
            self.assertEqual(len(prices), 30)
            self.assertNotIn("10.50", prices)


if __name__ == "__main__":
    unittest.main()
