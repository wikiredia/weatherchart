# Daily Weather Chart

Fetches the current Open-Meteo hourly forecast for Antwerpen, Sint-Job-in-'t-Goor,
and Brasschaat, and writes a self-contained HTML dashboard (React + Chart.js)
with three per-location charts: rain (blue), temperature (yellow), UV index (red).

## Files

- `generate-weather-chart.sh` — fetches data and writes the HTML. Takes ~1 second.
- `weather-chart.template.html` — the HTML/JS template; the script injects fresh
  data into the `__DATA_JSON__` placeholder.
- `weather-chart.html` — generated output (gitignored; regenerated on every run).

## Usage

```bash
./generate-weather-chart.sh [output.html]
```

Defaults to writing `weather-chart.html` next to the script.

## Requirements

- `curl`, `python3` (both are present in the default Claude Code cloud environment)
- Network access to `api.open-meteo.com` — this is **not** on the default
  Trusted allowlist for Claude Code routines/cloud environments. If running
  this via a routine, add `api.open-meteo.com` under the environment's
  Custom allowed domains, or the fetch will fail with a 403.

## Automation (Claude Code routine)

This repo is meant to be run by a scheduled Claude Code routine using the
Haiku model — the routine's job is just "run the script, confirm it worked,"
no reasoning required since fetch and chart logic are both fixed.

Suggested routine prompt:

> Run `bash generate-weather-chart.sh` from the repo root. Confirm the exit
> code is 0 and that weather-chart.html was written. Report success with the
> output line the script prints, or report the error. Do not modify any files.
