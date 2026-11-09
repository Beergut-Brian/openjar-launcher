## Where things stand in the hub, and which jar a sideways push hops to. Pure, so it can be tested.
## The jars sit on an arc at the back of the plaza, index 0 on the left as the camera sees it.
class_name HubLayout
extends RefCounted

const ARC_RADIUS := 8.5      # jar centres, metres from the plaza centre
const STAND_RADIUS := 6.2    # where a Jarling stands to look into a jar
const MAX_STEP_DEG := 24.0   # jar spacing when there are few games
const MAX_ARC_DEG := 150.0   # the whole row never wraps further round than this
const FOCUS_RANGE := 1.7     # a Jarling this close to a stand point has that jar in focus
const WALK_RADIUS := 10.6    # Jarlings never leave the island


## Number of jars to build: one per entry, and a single empty jar when nothing is installed.
static func spot_count(entry_count: int) -> int:
	return maxi(entry_count, 1)


static func step_deg(count: int) -> float:
	if count <= 1:
		return 0.0
	return minf(MAX_STEP_DEG, MAX_ARC_DEG / float(count - 1))


## Angle of jar `index` of `count`, radians, 0 = straight ahead of the camera, + to the right.
static func angle(index: int, count: int) -> float:
	return deg_to_rad((index - (count - 1) * 0.5) * step_deg(count))


static func on_arc(a: float, radius: float) -> Vector3:
	return Vector3(sin(a) * radius, 0.0, -cos(a) * radius)


static func jar_position(index: int, count: int) -> Vector3:
	return on_arc(angle(index, count), ARC_RADIUS)


static func stand_position(index: int, count: int) -> Vector3:
	return on_arc(angle(index, count), STAND_RADIUS)


## Index of the stand point nearest to pos (-1 if count is 0).
static func nearest(pos: Vector3, count: int) -> int:
	var best := -1
	var best_d := INF
	for i in count:
		var d := pos.distance_squared_to(stand_position(i, count))
		if d < best_d:
			best_d = d
			best = i
	return best


## Jar in focus for a Jarling at pos, or -1 when it is roaming.
static func focus_at(pos: Vector3, count: int) -> int:
	var i := nearest(pos, count)
	if i >= 0 and pos.distance_to(stand_position(i, count)) <= FOCUS_RANGE:
		return i
	return -1


## Where a sideways push (dir -1 / +1) sends a Jarling. From a jar: the next jar, clamped at the
## ends of the row. While roaming: the nearest jar if it lies that way, else the one past it.
static func hop_target(focus: int, dir: int, pos: Vector3, count: int) -> int:
	if count <= 0:
		return -1
	if focus >= 0:
		return clampi(focus + dir, 0, count - 1)
	var i := nearest(pos, count)
	var dx := stand_position(i, count).x - pos.x
	if dx * dir >= -0.3:
		return i
	return clampi(i + dir, 0, count - 1)


## True when a stick vector means "hop sideways" rather than "walk": pushed over, not up or down.
static func is_hop_push(v: Vector2) -> bool:
	return absf(v.x) > 0.55 and absf(v.y) < 0.45
