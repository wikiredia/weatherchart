#!/usr/bin/env bash
# Fetches the current Open-Meteo hourly forecast for Antwerpen, Sint-Job-in-'t-Goor
# and Brasschaat, and writes a self-contained HTML dashboard (React + Chart.js)
# with three per-location charts: rain (blue), temperature (yellow), UV index (red).
#
# Usage: ./generate-weather-chart.sh [output.html]
#   output.html defaults to weather-chart.html next to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${1:-$SCRIPT_DIR/weather-chart.html}"
TEMPLATE="$SCRIPT_DIR/weather-chart.template.html"

command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "error: template not found at $TEMPLATE" >&2; exit 1; }

# Fixed order: Antwerpen, Sint-Job-in-'t-Goor, Brasschaat
LATS="51.22047,51.29907,51.2912"
LONS="4.40026,4.57289,4.49182"

API_URL="https://api.open-meteo.com/v1/forecast?latitude=${LATS}&longitude=${LONS}&hourly=temperature_2m,precipitation,uv_index&timezone=Europe%2FBrussels&forecast_days=2"

RAW_JSON="$(mktemp)"
trap 'rm -f "$RAW_JSON"' EXIT

echo "Fetching hourly forecast from Open-Meteo..." >&2
curl -fsS "$API_URL" -o "$RAW_JSON" || { echo "error: fetch failed" >&2; exit 1; }

echo "Building chart data and writing $OUTPUT..." >&2
python3 - "$RAW_JSON" "$TEMPLATE" "$OUTPUT" <<'PY'
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

raw_path, template_path, output_path = sys.argv[1:4]

NAMES = ["Antwerpen", "Sint-Job-in-'t-Goor", "Brasschaat"]

with open(raw_path, encoding="utf-8") as f:
    raw = json.load(f)

if len(raw) != len(NAMES):
    sys.exit(f"error: expected {len(NAMES)} locations in API response, got {len(raw)}")

# Find the current hour (Europe/Brussels) in the first location's hourly series,
# then take a 24-hour window starting there — same window for every location,
# since Open-Meteo returns matching timestamps across all of them.
now_hour_iso = datetime.now(ZoneInfo("Europe/Brussels")).strftime("%Y-%m-%dT%H:00")
times = raw[0]["hourly"]["time"]
try:
    start_idx = times.index(now_hour_iso)
except ValueError:
    start_idx = 0  # fallback: start of the returned range
end_idx = start_idx + 24

data = {"labels": times[start_idx:end_idx], "locations": []}
for name, loc in zip(NAMES, raw):
    hourly = loc["hourly"]
    data["locations"].append({
        "name": name,
        "temp": hourly["temperature_2m"][start_idx:end_idx],
        "precip": hourly["precipitation"][start_idx:end_idx],
        "uv": hourly["uv_index"][start_idx:end_idx],
    })

data_json = json.dumps(data)

with open(template_path, encoding="utf-8") as f:
    template = f.read()

if "__DATA_JSON__" not in template:
    sys.exit("error: template is missing the __DATA_JSON__ placeholder")

html = template.replace("__DATA_JSON__", data_json, 1)

with open(output_path, "w", encoding="utf-8") as f:
    f.write(html)

print(f"Wrote {output_path} ({len(data['labels'])} hourly points, "
      f"{data['labels'][0]} -> {data['labels'][-1]})")
PY

echo "Done." >&2
