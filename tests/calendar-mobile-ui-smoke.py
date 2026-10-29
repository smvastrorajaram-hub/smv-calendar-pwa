#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import re
from urllib.parse import urlsplit

repo = Path(".")
out = repo / "_site"
source = repo / "_source" / "public" / "horoscope"

required = [
    "index.html", "calendar-mobile-ui.css", "calendar-mobile-ui.mjs",
    "daily-calendar.mjs", "calendar-worker.mjs", "sw.js",
    "offline/swiss_vedic.browser.mjs", "offline/transit_panchang.browser.mjs",
    "offline/vendor/wasm/swisseph.wasm", "offline/vendor/wasm/swisseph.data",
]
missing = [path for path in required if not (out / path).is_file()]
assert not missing, f"Missing build output assets: {missing}"

html = (out / "index.html").read_text(encoding="utf-8")
assert 'href="calendar-mobile-ui.css?v=20261029-screenshot-v1"' in html
assert 'src="calendar-mobile-ui.mjs?v=20261029-screenshot-v1"' in html
assert "smv-calendar-brand" in html
assert "calendar.smvastroservices.in" in html

ui = (out / "calendar-mobile-ui.mjs").read_text(encoding="utf-8")
css = (out / "calendar-mobile-ui.css").read_text(encoding="utf-8")
sw = (out / "sw.js").read_text(encoding="utf-8")
assert "smvCalendarQuickSummary" in ui
assert "MutationObserver" in ui
assert "smvCalendarMobileNav" in ui
assert "calendar-mobile-ui.css" in sw and "calendar-mobile-ui.mjs" in sw
assert "#4c2b7b" in css and "#f3efff" in css
assert "smvCalendarMobileNav" in ui and "calRasiPalan" in ui

for lang in ("en", "ta"):
    manifest = json.loads((out / f"manifest-{lang}.webmanifest").read_text(encoding="utf-8"))
    assert manifest["scope"] == "/"
    assert manifest["start_url"].startswith("/?lang=")
    assert manifest["theme_color"] == "#4c2b7b"
    assert manifest["background_color"] == "#f3efff"

# Every local stylesheet/module referenced by the built HTML must resolve.
for attr, path in re.findall(r'\b(href|src)="([^"]+)"', html):
    item = urlsplit(path)
    if not path or item.scheme or path.startswith(("#", "data:")):
        continue
    rel = item.path.lstrip("/")
    if not rel or rel.endswith("/"):
        rel += "index.html"
    if rel in ("",):
        rel = "index.html"
    assert (out / rel).is_file(), f"Unresolved local {attr}: {path}"

# The calendar presentation build must never rewrite calculation/WASM/India place sources.
protected = [
    "calendar-worker.mjs",
    "offline/swiss_vedic.browser.mjs",
    "offline/transit_panchang.browser.mjs",
    "offline/vendor/wasm/swisseph.js",
    "offline/vendor/wasm/swisseph.mjs",
    "offline/vendor/wasm/swisseph.wasm",
    "offline/vendor/wasm/swisseph.data",
    "offline/places/india-manifest.json",
]
for rel in protected:
    src, dst = source / rel, out / rel
    assert src.is_file() and dst.is_file(), f"Protected asset missing: {rel}"
    assert hashlib.sha256(src.read_bytes()).digest() == hashlib.sha256(dst.read_bytes()).digest(), f"Protected asset altered: {rel}"

source_places = source / "offline" / "places" / "india"
output_places = out / "offline" / "places" / "india"
if source_places.exists():
    source_files = sorted(p.relative_to(source_places).as_posix() for p in source_places.rglob("*") if p.is_file())
    output_files = sorted(p.relative_to(output_places).as_posix() for p in output_places.rglob("*") if p.is_file())
    assert source_files == output_files, "Offline India locations file set differs from the source build."
    for rel in source_files:
        src, dst = source_places / rel, output_places / rel
        assert src.stat().st_size == dst.stat().st_size, f"Offline India location asset size mismatch: {rel}"
        assert hashlib.sha256(src.read_bytes()).digest() == hashlib.sha256(dst.read_bytes()).digest(), f"Offline India location asset altered: {rel}"

# Check CSS braces without downloading any additional parser.
for path in ("calendar-mobile-ui.css", "daily-calendar.css", "calendar-rasi-palan.css"):
    text = (out / path).read_text(encoding="utf-8")
    assert text.count("{") == text.count("}"), f"CSS braces are unbalanced in {path}"

print("SMV CALENDAR screenshot UI build smoke: PASS")
print("Local asset links: PASS")
print("Swiss Ephemeris/WASM and calculation modules: byte-identical")
print("India offline location assets: file set, sizes and SHA-256 verified")
