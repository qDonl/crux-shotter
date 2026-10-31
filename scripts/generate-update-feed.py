#!/usr/bin/env python3
"""Sign a built DMG and merge it into the feed. Never writes the private seed to the repo."""
import argparse
import base64
import datetime
import os
from pathlib import Path
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET

NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", NAMESPACE)


def element(name):
    return f"{{{NAMESPACE}}}{name}"


def merge_item(feed, info, archive, signature, size):
    version = info["CruxShotReleaseVersion"]
    build = info["CFBundleVersion"]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?", version) or not build.isdigit():
        raise ValueError("Invalid release version or build number")
    if archive != f"CruxShotter-{version}.dmg" or len(base64.b64decode(signature, validate=True)) != 64 or size <= 0:
        raise ValueError("Invalid update archive or signature")
    channel = feed.find("channel")
    if channel is None:
        raise ValueError("Missing RSS channel")
    # A build number is immutable once published. Re-running for that build replaces its entry.
    for item in list(channel.findall("item")):
        if item.findtext(element("version")) == build:
            channel.remove(item)
    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"CruxShotter {version}"
    ET.SubElement(item, element("version")).text = build
    ET.SubElement(item, element("shortVersionString")).text = version
    ET.SubElement(item, element("minimumSystemVersion")).text = info["LSMinimumSystemVersion"]
    if "-" in version:
        ET.SubElement(item, element("channel")).text = "preview"
    ET.SubElement(item, "link").text = f"https://github.com/qDonl/crux-shotter/releases/tag/v{version}"
    ET.SubElement(item, "pubDate").text = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    ET.SubElement(item, "enclosure", {
        "url": f"https://github.com/qDonl/crux-shotter/releases/download/v{version}/{archive}",
        element("edSignature"): signature, "length": str(size), "type": "application/octet-stream",
    })
    channel.insert(0, item)
    return feed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("sparkle_bin", type=Path)
    parser.add_argument("--feed", type=Path, default=Path("appcast.xml"))
    parser.add_argument("--output", type=Path, default=Path("build/appcast.xml"))
    args = parser.parse_args()
    with (args.app / "Contents/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    seed = os.environ.get("SPARKLE_PRIVATE_KEY")
    if not seed:
        key_file = Path(os.environ.get("SPARKLE_PRIVATE_KEY_FILE",
            str(Path.home() / "Library/Application Support/CruxShotter/ReleaseSigning/ed25519.key")))
        seed = key_file.read_text().strip()
    # The secret is passed through stdin; never in command arguments or console output.
    sign = [str(args.sparkle_bin / "sign_update"), "--ed-key-file", "-"]
    signature = subprocess.check_output(sign + ["-p", str(args.archive)], input=seed.encode()).decode().strip()
    subprocess.run(["swift", str(Path(__file__).with_name("verify-update-signature.swift")),
        info["SUPublicEDKey"], str(args.archive), signature], check=True)
    feed = merge_item(ET.parse(args.feed).getroot(), info, args.archive.name, signature, args.archive.stat().st_size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(feed)
    ET.ElementTree(feed).write(args.output, encoding="utf-8", xml_declaration=True)
    subprocess.run(sign + [str(args.output)], input=seed.encode(), check=True)
    print(f"Signed update feed: {args.output}")


if __name__ == "__main__":
    main()
