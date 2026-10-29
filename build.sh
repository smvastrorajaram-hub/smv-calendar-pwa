#!/usr/bin/env bash
set -euo pipefail

SRC="_source/public/horoscope"
CAL="$SRC/calendar"
OUT="_site"

test -f "$CAL/index.html"
test -f "$CAL/calendar-pwa.mjs"
test -f "$CAL/sw.js"
test -f "calendar-mobile-ui.css"
test -f "calendar-mobile-ui.mjs"
test -f "tests/calendar-mobile-ui-smoke.py"
test -f "$SRC/daily-calendar.mjs"
test -f "$SRC/calendar-worker.mjs"
test -d "$SRC/offline"

rm -rf "$OUT"
mkdir -p "$OUT"

# Calendar needs the Horoscope shared calculation/WASM/location assets.
cp -a "$SRC/." "$OUT/"

# Promote the Calendar PWA shell to this independent site's root.
cp "$CAL/index.html" "$OUT/index.html"
cp "$CAL/calendar-pwa.mjs" "$OUT/calendar-pwa.mjs"
cp "$CAL/sw.js" "$OUT/sw.js"
cp "$CAL/manifest-en.webmanifest" "$OUT/manifest-en.webmanifest"
cp "$CAL/manifest-ta.webmanifest" "$OUT/manifest-ta.webmanifest"
cp "calendar-mobile-ui.css" "$OUT/calendar-mobile-ui.css"
cp "calendar-mobile-ui.mjs" "$OUT/calendar-mobile-ui.mjs"
rm -rf "$OUT/calendar"

printf '%s\n' "calendar.smvastroservices.in" > "$OUT/CNAME"

python3 - <<'PY'
from pathlib import Path
import json

out = Path("_site")

# Calendar index: parent-relative shared assets become root-relative within this repo.
p = out / "index.html"
s = p.read_text(encoding="utf-8")
replacements = {
    'href="../assets/': 'href="assets/',
    'src="../assets/': 'src="assets/',
    'href="../horoscope.css': 'href="horoscope.css',
    'href="../daily-calendar.css': 'href="daily-calendar.css',
    'href="../calendar-v226.css': 'href="calendar-v226.css',
    'src="../location-search-online-offline.js': 'src="location-search-online-offline.js',
    'src="../horoscope.js': 'src="horoscope.js',
    'src="../daily-calendar.mjs': 'src="daily-calendar.mjs',
    '<a href="../../" target="_blank" rel="noopener">SMV ASTRO</a>':
        '<a href="https://smvastroservices.in/" target="_blank" rel="noopener">SMV ASTRO</a>',
    '<a href="../" target="_blank" rel="noopener">SMV HOROSCOPE</a>':
        '<a href="https://horoscope.smvastroservices.in/" target="_blank" rel="noopener">SMV HOROSCOPE</a>',
    '<meta name="theme-color" content="#0f514c">':
        '<meta name="theme-color" content="#4c2b7b">',
    '<body class="calendar-only">':
        '<body class="calendar-only smv-calendar-refresh">',
    '<nav class="calendar-product-nav" aria-label="SMV services">':
        '<div class="smv-calendar-brand"><strong>SMV CALENDAR</strong><span class="smv-calendar-brand-tagline" data-en="Panchangam · Hora · Rasi Palan" data-ta="பஞ்சாங்கம் · ஹோரை · ராசி பலன்">Panchangam · Hora · Rasi Palan</span></div>\n<nav class="calendar-product-nav" aria-label="SMV services">',
    '</head>':
        '<link rel="stylesheet" href="calendar-mobile-ui.css?v=20261029-screenshot-v1">\n</head>',
    '</body>':
        '<script type="module" src="calendar-mobile-ui.mjs?v=20261029-screenshot-v1"></script>\n</body>',
}
for a,b in replacements.items():
    count = s.count(a)
    if count != 1:
        raise SystemExit(f"Expected exactly one index replacement target; found {count}: {a}")
    s = s.replace(a,b)

if 'rel="canonical"' not in s:
    s = s.replace(
        '<title>SMV CALENDAR</title>',
        '<title>SMV CALENDAR</title>\n<link rel="canonical" href="https://calendar.smvastroservices.in/">'
    )
p.write_text(s, encoding="utf-8")

# Independent root-scope manifests and root icon URLs.
for lang in ("en", "ta"):
    p = out / f"manifest-{lang}.webmanifest"
    data = json.loads(p.read_text(encoding="utf-8"))
    data["id"] = "/"
    data["start_url"] = f"/?lang={lang}&source=calendar-subdomain-pwa"
    data["scope"] = "/"
    data["theme_color"] = "#4c2b7b"
    data["background_color"] = "#f3efff"
    for icon in data.get("icons", []):
        src = icon.get("src", "")
        src = src.replace("/horoscope/assets/", "/assets/")
        src = src.replace("../assets/", "/assets/")
        icon["src"] = src
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# Calendar install logic is now at origin root, not /horoscope/calendar/.
p = out / "calendar-pwa.mjs"
s = p.read_text(encoding="utf-8")
s = s.replace("smv-calendar-controller-reload-v217", "smv-calendar-controller-reload-independent-ui-v1")
s = s.replace("'/horoscope/calendar/sw.js'", "'/sw.js'")
s = s.replace("./sw.js?v=217", "./sw.js?v=independent-ui-v1")
s = s.replace("manifest-${lang}.webmanifest?v=217", "manifest-${lang}.webmanifest?v=independent-ui-v1")
p.write_text(s, encoding="utf-8")

# Calendar page detection + icon path for the new independent origin.
p = out / "daily-calendar.mjs"
s = p.read_text(encoding="utf-8")
s = s.replace(
    "const calendarAppPage=location.pathname.startsWith('/horoscope/calendar/');",
    "const calendarAppPage=true;"
)
s = s.replace("/horoscope/assets/calendar-192.png", "/assets/calendar-192.png")
p.write_text(s, encoding="utf-8")

# Root-scoped Calendar service worker.
p = out / "sw.js"
s = p.read_text(encoding="utf-8")
s = s.replace(
    "const CACHE='smv-calendar-v228-today-color-maincss';",
    "const CACHE='smv-calendar-independent-v1-'+self.registration.scope;"
)
s = s.replace("'../", "'./")
s = s.replace("if(!u.pathname.startsWith('/horoscope/calendar/'))return;", "if(!u.pathname.startsWith('/'))return;")
p.write_text(s, encoding="utf-8")
PY

# Keep only runtime files from the source tree.
rm -f "$OUT"/AUDIT*.md "$OUT"/README*.md "$OUT"/FINAL-*.md 2>/dev/null || true

echo "SMV CALENDAR independent PWA build: PASS"
