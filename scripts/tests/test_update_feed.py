import base64
import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("feed", Path(__file__).parents[1] / "generate-update-feed.py")
feed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feed)


class UpdateFeedTests(unittest.TestCase):
    def info(self, version="0.0.6-alpha", build="6"):
        return {"CruxShotReleaseVersion": version, "CFBundleVersion": build, "LSMinimumSystemVersion": "14.0"}

    def merge(self, tree, version="0.0.6-alpha", build="6"):
        return feed.merge_item(tree, self.info(version, build), f"CruxShotter-{version}.dmg",
                               base64.b64encode(bytes(64)).decode(), 100)

    def test_preview_channel_and_exact_archive_metadata(self):
        tree = self.merge(ET.fromstring("<rss><channel/></rss>"))
        item = tree.find("channel/item")
        self.assertEqual(item.findtext(feed.element("channel")), "preview")
        self.assertEqual(item.findtext(feed.element("version")), "6")
        self.assertEqual(item.findtext(feed.element("minimumSystemVersion")), "14.0")
        self.assertEqual(item.find("enclosure").get("url"),
            "https://github.com/qDonl/crux-shotter/releases/download/v0.0.6-alpha/CruxShotter-0.0.6-alpha.dmg")

    def test_stable_has_default_channel_and_preserves_older_items(self):
        tree = self.merge(ET.fromstring("<rss><channel/></rss>"))
        self.merge(tree, "0.0.6", "7")
        self.assertEqual(len(tree.findall("channel/item")), 2)
        self.assertIsNone(tree.find("channel/item").find(feed.element("channel")))

    def test_repeated_build_replaces_entry(self):
        tree = self.merge(ET.fromstring("<rss><channel/></rss>"))
        self.merge(tree)
        self.assertEqual(len(tree.findall("channel/item")), 1)

    def test_invalid_version_build_signature_and_archive_are_rejected(self):
        tree = ET.fromstring("<rss><channel/></rss>")
        for version, build in [("../evil", "6"), ("0.0.6", "six")]:
            with self.assertRaises(ValueError):
                self.merge(tree, version, build)
        for archive, signature in [("OtherApp.dmg", base64.b64encode(bytes(64)).decode()),
                                   ("CruxShotter-0.0.6-alpha.dmg", "invalid")]:
            with self.assertRaises(ValueError):
                feed.merge_item(tree, self.info(), archive, signature, 100)


if __name__ == "__main__":
    unittest.main()
