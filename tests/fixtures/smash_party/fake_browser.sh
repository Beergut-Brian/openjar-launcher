#!/usr/bin/env bash
# Stands in for the kiosk browser in tests: logs its arguments, fetches the page it was given
# (the last argument), then closes after FAKE_BROWSER_SECONDS (default at once) like a window would.
out="${FAKE_BROWSER_OUT:?}"
printf '%s\n' "$@" > "$out.args"
url="${!#}"
python3 -c 'import sys, urllib.request; print(urllib.request.urlopen(sys.argv[1], timeout=5).read().decode())' "$url" > "$out.page" 2>&1
echo "$url" > "$out.url"
echo $$ > "$out.pid"
exec sleep "${FAKE_BROWSER_SECONDS:-0}"
