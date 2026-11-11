#!/usr/bin/env bash
# Smash Party (the browser game) as an Open Jar jar: serve the game folder on localhost, open it full
# screen in a kiosk browser window of its own, and exit when that window closes, so the launcher
# comes back. Installed next to openjar.json by kiosk/smash-party/install.sh (docs/smash-party.md).
#
# Why a kiosk window with a private profile, never `xdg-open`: xdg-open hands the URL to a browser
# that may already be running and returns at once, so the launcher would think the game had ended.
# A browser started with its own profile folder is a process of its own that lives exactly as long
# as its window. Chromium-family first (no first-run screens, sound without a click), Firefox next.
#
# The launcher's --profile= / --p1-char= / --p2-char= arguments are ignored: the game has its own
# drop-in join. Overrides (tests): SMASH_PARTY_GAME (game folder), SMASH_PARTY_BROWSER (a program
# to run instead of a browser, given the same arguments as Chromium), SMASH_PARTY_LOG.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
game="${SMASH_PARTY_GAME:-$here/game}"
log="${SMASH_PARTY_LOG:-$here/smash-party.log}"
[[ -f "$log" ]] && mv -f "$log" "$log.1"   # one launch per log (the server logs every file it sends)
say() { echo "smash-party: $*" | tee -a "$log" >&2; }

[[ -f "$game/index.html" ]] || { say "no game at $game (run install.sh)"; exit 3; }
command -v python3 >/dev/null || { say "python3 is needed to serve the game"; exit 4; }

# ---- the game, on a free localhost port (ES modules do not load from file://)
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server --bind 127.0.0.1 --directory "$game" "$port" >>"$log" 2>&1 &
server=$!
for _ in $(seq 1 50); do
  (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
  sleep 0.1
done
url="http://127.0.0.1:$port/index.html"

# ---- the browser
kind="" flat="" cmd=()
if [[ -n "${SMASH_PARTY_BROWSER:-}" ]]; then
  kind=chromium; cmd=("$SMASH_PARTY_BROWSER")
else
  for b in chromium chromium-browser google-chrome-stable google-chrome brave-browser; do
    command -v "$b" >/dev/null && { kind=chromium; cmd=("$b"); break; }
  done
  if [[ -z "$kind" ]] && command -v flatpak >/dev/null; then
    for id in org.chromium.Chromium com.google.Chrome com.brave.Browser org.mozilla.firefox; do
      flatpak info "$id" >/dev/null 2>&1 || continue
      flat=$id; cmd=(flatpak run "$id")
      [[ $id == org.mozilla.firefox ]] && kind=firefox || kind=chromium
      break
    done
  fi
  [[ -z "$kind" ]] && command -v firefox >/dev/null && { kind=firefox; cmd=(firefox); }
fi
if [[ -z "$kind" ]]; then
  say "no browser found (Chromium, Chrome, Brave or Firefox, native or Flatpak)"
  kill "$server" 2>/dev/null; exit 5
fi

# A profile folder the browser can always write: a Flatpak only sees its own ~/.var/app/<id>.
if [[ -n "$flat" ]]; then prof="$HOME/.var/app/$flat/cache/openjar-smash-party"
else prof="${XDG_CACHE_HOME:-$HOME/.cache}/openjar/smash-party-$kind"; fi
mkdir -p "$prof"

if [[ $kind == chromium ]]; then
  args=(--user-data-dir="$prof" --kiosk --start-fullscreen --no-first-run --no-default-browser-check
        --disable-session-crashed-bubble --disable-infobars --noerrdialogs --disable-translate
        --autoplay-policy=no-user-gesture-required --password-store=basic "$url")
else
  cat > "$prof/user.js" <<'PREFS'
user_pref("media.autoplay.default", 0);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("full-screen-api.warning.timeout", 0);
PREFS
  args=(--new-instance --no-remote --profile "$prof" --kiosk "$url")
fi

browser=""
stop() {   # the window closed, or the launcher asked us to stop (TERM): take everything down
  [[ -n "$browser" ]] && kill "$browser" 2>/dev/null
  [[ -n "$flat" ]] && flatpak kill "$flat" 2>/dev/null
  kill "$server" 2>/dev/null
}
trap 'stop; exit 0' TERM INT HUP

say "serving $game on $url, opening ${cmd[*]} ($kind)"
"${cmd[@]}" "${args[@]}" >>"$log" 2>&1 &
browser=$!
wait "$browser"
code=$?
browser=""
stop
say "browser closed (code $code)"
exit 0
