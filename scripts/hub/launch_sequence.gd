## The launch animation's clock: A at a jar starts it, the game only starts on its last beat (GO).
## Pure (no nodes), so tests can step it. The hub poses everything from `t` each frame and plays one
## sound per beat. start() refuses while it runs, so A spam can never launch twice.
class_name LaunchSequence
extends RefCounted

enum Beat { RATTLE, LID_POP, LEAP, LID_LAND, SPLASH, DIVE, GO }

const T_POP := 0.5        # the lid spins off
const T_LEAP := 0.8       # the Jarling takes off
const T_LID_LAND := 1.25  # the lid lands somewhere funny
const T_SPLASH := 1.3     # the Jarling drops through the jar mouth
const T_DIVE := 1.45      # it lands in the tiny world and the camera dives in after it
const T_GO := 2.3         # the screen is full of the jar's world: start the game
## Beat → time, in order.
const BEATS := [[Beat.RATTLE, 0.0], [Beat.LID_POP, T_POP], [Beat.LEAP, T_LEAP], [Beat.LID_LAND, T_LID_LAND],
	[Beat.SPLASH, T_SPLASH], [Beat.DIVE, T_DIVE], [Beat.GO, T_GO]]

var active := false
var t := 0.0
var _next := 0


## False (and nothing changes) if a launch is already playing.
func start() -> bool:
	if active:
		return false
	active = true
	t = 0.0
	_next = 0
	return true


## Moves the clock on and returns the beats reached, in order. GO is always the last one and
## ends the sequence; however big delta is, no beat is skipped.
func advance(delta: float) -> Array[int]:
	var out: Array[int] = []
	if not active:
		return out
	t = minf(t + maxf(delta, 0.0), T_GO)
	while _next < BEATS.size() and t >= BEATS[_next][1]:
		out.append(BEATS[_next][0])
		_next += 1
	if _next >= BEATS.size():
		active = false
	return out


func cancel() -> void:
	active = false


## 0..1 progress of t between two times.
static func phase(time: float, from: float, to: float) -> float:
	return clampf((time - from) / (to - from), 0.0, 1.0)


static func smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
