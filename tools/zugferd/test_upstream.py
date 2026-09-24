"""Unit tests of the weekly upstream check (upstream.py), without GitHub."""

import sys
import unittest
import unittest.mock
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import upstream  # noqa: E402

RELEASES = {
    "ZUGFeRD/mustangproject": [
        {"tag_name": "core-2.26.0", "html_url": "https://example.test/core-2.26.0"},
        {"tag_name": "core-2.27.0-rc1", "prerelease": True},
        {"tag_name": "core-2.9.1", "html_url": "https://example.test/core-2.9.1"},
        {"tag_name": "validator-1.0.0"},
    ],
    "itplr-kosit/validator": [
        {"tag_name": "v1.6.3", "html_url": "https://example.test/v1.6.3"},
        {"tag_name": "v1.7.0", "draft": True},
    ],
    "itplr-kosit/validator-configuration-xrechnung": [
        {"tag_name": "release-2025-07-10"},
        {"tag_name": "v2026-08-31", "html_url": "https://example.test/v2026-08-31"},
    ],
    "typst/typst": [
        {"tag_name": "v0.15.0-rc.1", "prerelease": True},
        {"tag_name": "v0.15.1", "html_url": "https://example.test/v0.15.1"},
        {"tag_name": "v0.14.2"},
    ],
}


def fetch(repo):
    return RELEASES[repo]


class Upstream(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(upstream.version_key("1.6.3"), (1, 6, 3))
        self.assertEqual(upstream.version_key("2026-08-31"), (2026, 8, 31))
        # Numbers, not text: 2.26.0 is newer than 2.9.1.
        self.assertGreater(upstream.version_key("2.26.0"), upstream.version_key("2.9.1"))

    def test_latest_release(self):
        # Pre-releases, drafts and tags of other artifacts do not count.
        self.assertEqual(upstream.latest("mustang-cli", fetch("ZUGFeRD/mustangproject")),
                         ("2.26.0", "https://example.test/core-2.26.0"))
        self.assertEqual(upstream.latest("kosit-validator", fetch("itplr-kosit/validator"))[0], "1.6.3")
        # Both tag styles of the XRechnung configuration.
        self.assertEqual(upstream.latest("xrechnung-configuration",
                                         fetch("itplr-kosit/validator-configuration-xrechnung"))[0], "2026-08-31")
        self.assertEqual(upstream.latest("typst", fetch("typst/typst"))[0], "0.15.1")
        self.assertIsNone(upstream.latest("typst", [{"tag_name": "nightly"}]))

    def test_compare_and_report(self):
        pinned = {"mustang-cli": "2.14.0", "kosit-validator": "1.6.3",
                  "xrechnung-configuration": "2026-08-31", "typst": "0.14.2"}
        behind = upstream.compare(pinned, fetch)
        self.assertEqual([(b[0], b[1], b[2]) for b in behind],
                         [("mustang-cli", "2.14.0", "2.26.0"), ("typst", "0.14.2", "0.15.1")])
        text = upstream.markdown(behind, pinned, today="2026-09-28")
        self.assertIn("| Mustang CLI | 2.14.0 | 2.26.0 | https://example.test/core-2.26.0 |", text)
        self.assertIn("typst/typst/issues/5667", text)
        self.assertIn("Up to date: KoSIT validator 1.6.3, XRechnung configuration of KoSIT 2026-08-31.", text)
        self.assertIn("_Checked on 2026-09-28", text)
        self.assertEqual(upstream.compare({"kosit-validator": "1.6.3"}, fetch), [])

    def test_errors(self):
        with self.assertRaises(upstream.UpstreamError):
            upstream.compare({"pdfbox": "3.0.0"}, fetch)
        with self.assertRaises(upstream.UpstreamError):
            upstream.compare({"typst": "0.14.2"}, lambda repo: [{"tag_name": "nightly"}])
        with unittest.mock.patch("sys.stderr"):
            self.assertEqual(upstream.main(["--pinned", "typst"]), 2)
            self.assertEqual(upstream.main([]), 2)


if __name__ == "__main__":
    unittest.main()
