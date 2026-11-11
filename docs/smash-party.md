# Smash Party in the launcher (C-14)

The original Smash Party is a browser game (`Beergut-Brian/smash-party`, `index.html` + ES modules).
Until its Godot rebuild ships, it is a jar on Jar Island like any other game. The files live in
`kiosk/smash-party/` (Godot ignores that folder):

| File | What it does |
| --- | --- |
| `openjar.json` | `"command": ["smash-party.sh"]` instead of `binary`, and `"jar": "store/jar.tscn"` |
| `smash-party.sh` | serves `game/` on a free `127.0.0.1` port, opens it full screen in a kiosk browser window of its own, exits when that window closes |
| `store/jar.tscn` | the jar's tiny world: a toy car looping a ring road past a crate stack that pops, cones. No text |
| `install.sh` | copies all of that plus the game into `<games folder>/smash-party/` |

## Install on the TV box

Once, and again whenever Smash Party changes (it only ever writes `~/Games/openjar/smash-party/`):

```
cd ~/openjar-launcher            # any checkout of this repo
kiosk/smash-party/install.sh     # shallow-clones the game from GitHub
# or from a local checkout:  kiosk/smash-party/install.sh ~/openjar/smash-party
```

As an `openjar-tv/update.sh`-style step (to add at the end of `update.sh`, before `shortcuts.py`):

```bash
# Smash Party (browser) until its Godot rebuild ships Releases; update.sh then owns the folder.
if [[ ! -f "$ROOT/smash-party/.release" ]]; then
  "$HOME/openjar-launcher/kiosk/smash-party/install.sh" "" "$ROOT" || echo "smash-party install failed"
fi
```

(`""` means "the default source", the GitHub repo.) `install.sh` refuses to touch a folder that
has a `.release` marker, so once the rebuild ships, `update.sh`'s download replaces the browser
version and nothing fights over it. `shortcuts.py` makes no Steam tile for it (no `binary`), so
Smash Party lives only inside the launcher, which is what we want.

The box needs `python3` (Bazzite has it) and a browser (below).

## Which browser, and why a kiosk window

The script picks the first of: native `chromium` / `chromium-browser` / `google-chrome(-stable)` /
`brave-browser`, then Flatpak `org.chromium.Chromium` / `com.google.Chrome` / `com.brave.Browser` /
`org.mozilla.firefox`, then native `firefox`. Bazzite ships Firefox as a Flatpak, so on a stock box
it is Firefox unless a Chromium-family browser is installed (`flatpak install flathub
org.chromium.Chromium` is recommended: sound plays without a click, no first-run screens).

**Choice: a kiosk window with its own profile folder, never the system browser via `xdg-open`.**
`xdg-open` hands the URL to a browser that may already be running and returns at once, so the
launcher would think the game had ended and pop back while the game is still up. A browser started
with its own profile (`--user-data-dir` for Chromium, `--new-instance --profile` for Firefox) is a
process of its own that lives exactly as long as its window, so "the window closed" is "the game
exited", and the hub comes back. Kiosk mode is full screen with no address bar or tabs. Chromium
gets `--autoplay-policy=no-user-gesture-required`; Firefox gets a `user.js` that allows autoplay and
skips welcome screens. The profile lives in `~/.cache/openjar/` (native) or the Flatpak's own
`~/.var/app/<id>/cache/` so it is always writable. ES modules do not load from `file://`, hence
the local server; it binds to `127.0.0.1` only and dies with the window.

## Getting back to the hub

- **Hold Start for 2 s** (any pad): the launcher asks the script to stop (`SIGTERM`); the script
  closes its browser (and `flatpak kill`s a Flatpak one) and the server, and the hub comes back
  with the Jarling popping out of the jar. A short Start press is still the game's own pause.
  Start held on the way back does not count towards quitting the launcher. See
  `docs/contracts.md`, "the home hold".
- On a keyboard, Alt+F4 (Chromium kiosk also takes Ctrl+Shift+W) closes the window, same result.

## Not verified here (needs the TV)

The producer box has no browser and no window manager, so the real browser window was never
opened here. Tested: the real manifest scans and launches through the hub, the script serves the
real game (index.html over http), exits when the "browser" exits, takes it down on `SIGTERM`, and
the home hold brings the hub back (`tests/test_smash_party.gd`, `tests/test_hub.gd::
test_a_command_jar_launches_and_the_home_hold_brings_you_back`), with a fake browser. On the TV,
check: the window opens full screen, pads join, Start held 2 s comes home, and the launcher reads
pads while it is not focused (Godot's default; `input_devices/joypads/ignore_joypad_on_unfocused_application`
is off). Logs: `~/Games/openjar/smash-party/smash-party.log` and the launcher's
`launcher: home hold, stopping smash-party` line.
