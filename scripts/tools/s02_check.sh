#!/usr/bin/env bash
# S-02 check: the hub under a real window manager (openbox) on a private Xvfb; samples the hub
# window's state while a 4 s fake game runs. Usage (a jar dir with a game that runs ~4 s):
#   OB_ROOT=<dir> OPENJAR_ROOT=<jars> HUB_DEMO="follow;1:go:0;6:a" scripts/tools/s02_check.sh <out_dir>
OUT=$1; shift; mkdir -p "$OUT"
W="${OB_ROOT:?set OB_ROOT to a dir holding root/ (openbox, xprop, xdotool: dpkg -x of their debs)}"
S="$HOME/.local/opt/syslibs"
export LD_LIBRARY_PATH="$W/root/usr/lib/x86_64-linux-gnu:$S/usr/lib/x86_64-linux-gnu"
export VK_ICD_FILENAMES="$S/icd/lvp_icd.json" LIBGL_DRIVERS_PATH="$S/usr/lib/x86_64-linux-gnu/dri"
N=$((90 + RANDOM % 9))
( cd "$S/xrun" && exec "$S/usr/bin/Xvfb-gary" ":$N" -screen 0 640x360x24 -nolisten tcp -xkbdir "$S/usr/share/X11/xkb" >/dev/null 2>&1 ) &
XP=$!
for i in $(seq 1 50); do [[ -e /tmp/.X11-unix/X$N ]] && break; sleep 0.1; done
export DISPLAY=":$N"
XDG_DATA_DIRS="$W/root/usr/share:/usr/share" XDG_CONFIG_DIRS="$W/root/etc/xdg" XDG_CONFIG_HOME="$W/cfg" "$W/root/usr/bin/openbox" --sm-disable >"$OUT/openbox.log" 2>&1 &
OB=$!
sleep 1
{ echo "openbox alive: $(kill -0 $OB 2>/dev/null && echo yes || echo no)"; "$W/root/usr/bin/xprop" -root _NET_SUPPORTING_WM_CHECK _NET_WM_NAME; } > "$OUT/root.txt" 2>&1
godot --display-driver x11 --rendering-driver vulkan --audio-driver Dummy --path . "$@" >"$OUT/godot.log" 2>&1 &
GP=$!
for t in $(seq 1 60); do
  sleep 0.5
  wid=$("$W/root/usr/bin/xdotool" search --onlyvisible --name "Open Jar" 2>/dev/null | head -1); [[ -z "$wid" ]] && wid=$("$W/root/usr/bin/xdotool" search --name "Open Jar" 2>/dev/null | head -1)
  [[ -z "$wid" ]] && continue
  st=$("$W/root/usr/bin/xprop" -id "$wid" _NET_WM_STATE WM_STATE 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')
  act=$("$W/root/usr/bin/xprop" -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')
  [[ $((act)) -eq $((wid)) ]] && st="$st active=hub" || st="$st active=other"
  echo "t=$(echo "$t*0.5" | awk '{print $1*0.5}') $st" >> "$OUT/states.txt"
done
kill $GP $OB $XP 2>/dev/null
wait 2>/dev/null
