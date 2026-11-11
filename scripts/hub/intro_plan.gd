## The hub intro's timeline and where everyone lands. Pure (no nodes), so tests can check it.
## The jar rattles, its lid pops, the whole playable roster tumbles out one after another (the
## stream gets faster as the roster grows, so the intro never gets longer than ~8 s), each one says
## a happy bark as it lands (at most MAX_VOICES at once), the logo drops in with a thump, everyone
## cheers, then they all hop back into the jar and the camera glides to the island. A skips it.
class_name IntroPlan
extends RefCounted

const JAR_AT := Vector3(0, 0, 0.6)     # the big intro jar: plaza centre, in front of the row of jars
const JAR_SCALE := 1.35
const T_POP := 0.75          # the lid pops off
const T_FIRST := 0.95        # the first character leaves the jar
const FLIGHT := 0.75         # mouth to landing
const GAP_MAX := 0.16        # a small roster tumbles out at this spacing...
const SPREAD_MAX := 2.4      # ...a big one squeezes into this many seconds
const LOGO_AFTER := 0.3      # the logo starts falling this long after the last landing
const LOGO_FALL := 0.45      # ...and thumps down this long after that
const HOLD := 1.4            # everybody cheers under the logo
const BACK_GAP := 0.035      # then they hop back in, quickly one after another
const BACK_FLIGHT := 0.45
const OUTRO := 0.5           # the lid drops back on, the jar poofs away
const SHAKE_TIME := 0.15     # the logo thump jolts the camera this long...
const SHAKE_MAX := 0.05      # ...by at most this many metres, decaying to nothing
const MAX_VOICES := 3        # landing voices at once: lively, never a wall of noise
## Happy barks to land with, in rotation (only the ones a character has). The last lander says its
## catchphrase instead, since it lands when the others have quietened down.
const LAND_BARKS := ["join", "cheer", "ready", "swap_in", "win"]
const ROW_START := 3.0       # landing rows: arcs in front of the jar, this far out...
const ROW_STEP := 1.35       # ...then this much further per row
const SEAT := 1.15           # a lander's elbow room along a row
const FAN_DEG := 150.0       # rows fan out this wide, centred on the camera side
const MAX_RADIUS := 9.4      # nobody lands past the island's walkable edge (HubLayout.WALK_RADIUS)


static func gap(n: int) -> float:
	return minf(GAP_MAX, SPREAD_MAX / float(maxi(n - 1, 1)))


static func launch_time(i: int, n: int) -> float:
	return T_FIRST + i * gap(n)


static func land_time(i: int, n: int) -> float:
	return launch_time(i, n) + FLIGHT


## The logo starts to fall; it thumps down at thump_time.
static func logo_time(n: int) -> float:
	return (land_time(n - 1, n) if n > 0 else T_FIRST) + LOGO_AFTER


static func thump_time(n: int) -> float:
	return logo_time(n) + LOGO_FALL


static func back_time(i: int, n: int) -> float:
	return thump_time(n) + HOLD + i * BACK_GAP


static func end_time(n: int) -> float:
	return (back_time(n - 1, n) + BACK_FLIGHT if n > 0 else thump_time(n) + HOLD) + OUTRO


## Where each of n characters lands: rows of arcs round the jar on the camera side, filled from
## the middle outwards, the first ones (Jeff, Chuck) front and centre. Never closer than SEAT.
static func landing_spots(n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var row := 0
	while out.size() < n:
		var r := ROW_START + row * ROW_STEP
		var fan := deg_to_rad(FAN_DEG) * minf(1.0, MAX_RADIUS / maxf(r, 0.01))
		var seats := maxi(1, int(r * fan / SEAT) + 1)
		var take := mini(seats, n - out.size())
		var row_spots: Array[Vector3] = []
		var step := fan / float(maxi(seats - 1, 1))
		for k in take:
			# fill from the middle, symmetric: odd rows 0, +1, -1, +2 ...; even rows +0.5, -0.5, +1.5 ...
			var off := float(floori((k + 1) / 2.0)) * (1.0 if k % 2 == 1 else -1.0)
			if take % 2 == 0:
				off = (float(floori(k / 2.0)) + 0.5) * (1.0 if k % 2 == 0 else -1.0)
			var a := off * step
			var p := JAR_AT + Vector3(sin(a) * r, 0, cos(a) * r)
			if Vector2(p.x, p.z).length() > MAX_RADIUS:
				continue
			row_spots.append(p)
		out.append_array(row_spots)
		row += 1
		if row > 12:
			break   # the island is full; a roster this big would be a nice problem to have
	return out


## The voice line for a lander, as a res:// path, or "" if it has none. info is Roster.info(id).
static func voice_path(info: Dictionary, i: int, n: int) -> String:
	if info.is_empty():
		return ""
	var phrase: String = info.get("catchphrase", "")
	if i == n - 1 and phrase != "" and ResourceLoader.exists(phrase):
		return phrase
	var barks: Array = info.get("barks", [])
	var voice: String = info.get("voice", "")
	if voice == "" or barks.is_empty():
		return phrase if phrase != "" and ResourceLoader.exists(phrase) else ""
	var happy := LAND_BARKS.filter(func(b: String) -> bool: return barks.has(b))
	var bark: String = happy[i % happy.size()] if not happy.is_empty() else barks[i % barks.size()]
	var path := "%s%s.ogg" % [voice, bark]
	return path if ResourceLoader.exists(path) else ""


## Camera for intro time t: close on the jar while it pops, easing back as the roster spills out,
## up for the logo, then out to the hub's wide shot (where the hub's own glide picks up).
static func camera(t: float, n: int, wide_pos: Vector3, wide_look: Vector3) -> Array[Vector3]:
	var close_pos := JAR_AT + Vector3(0, 3.8, 11.5)
	var close_look := JAR_AT + Vector3(0, 3.6, 0)
	var mid_pos := JAR_AT + Vector3(0, 5.0, 12.0)
	var mid_look := JAR_AT + Vector3(0, 2.2, 0)
	var spill := smoothstep(T_POP, logo_time(n), t)
	var out := smoothstep(back_time(0, n), end_time(n), t)
	var pos := close_pos.lerp(mid_pos, spill).lerp(wide_pos, out)
	var look := close_look.lerp(mid_look, spill).lerp(wide_look, out)
	return [pos, look]


## The thump's camera jolt `since` seconds after the logo lands: a quick wobble, mostly down (the
## logo hits the ground), decaying to exactly zero at SHAKE_TIME. Zero before the thump too.
static func shake(since: float) -> Vector3:
	if since < 0.0 or since >= SHAKE_TIME:
		return Vector3.ZERO
	var k := since / SHAKE_TIME
	var fade := (1.0 - k) * (1.0 - k)
	var w := since * TAU / 0.05   # a 20 Hz wobble: three kicks in the 0.15 s
	return (Vector3(sin(w * 1.3) * 0.35, -absf(cos(w)), 0) * SHAKE_MAX * fade).limit_length(SHAKE_MAX)
