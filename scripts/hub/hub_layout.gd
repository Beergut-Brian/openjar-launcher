## Where things stand in the hub, which jar a Jarling has walked up to, and where it can walk.
## Pure, so it can be tested.
## The jars sit on an arc at the back of the plaza, index 0 on the left as the camera sees it.
class_name HubLayout
extends RefCounted

const ARC_RADIUS := 8.5      # jar centres, metres from the plaza centre
const STAND_RADIUS := 6.2    # where a Jarling stands to look into a jar
const MAX_STEP_DEG := 24.0   # jar spacing when there are few games
const MAX_ARC_DEG := 150.0   # the whole row never wraps further round than this
const FOCUS_RANGE := 1.7     # a Jarling this close to the strip from a stand point to its jar has it in focus
const FOCUS_HOLD := 0.6      # ...and keeps it until it is this much further away (no flicker at the edge)
const FOCUS_SWITCH := 0.3    # a neighbour takes over only when it is this much nearer
const BLOCK_RADIUS := 1.95   # the jar's plinth plus a Jarling's tummy: you bump into a jar, not through it
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


## How far pos is from jar `index`'s focus strip: the line from its stand point to the jar itself, so
## walking up to the front of a jar or bumping into its side both count.
static func focus_distance(pos: Vector3, index: int, count: int) -> float:
	var a := stand_position(index, count)
	var b := jar_position(index, count)
	var p := Vector3(pos.x, 0.0, pos.z)
	var ab := b - a
	var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * k)


## Index of the jar whose focus strip is nearest to pos (-1 if count is 0).
static func nearest(pos: Vector3, count: int) -> int:
	var best := -1
	var best_d := INF
	for i in count:
		var d := focus_distance(pos, i, count)
		if d < best_d:
			best_d = d
			best = i
	return best


## Jar in focus for a Jarling at pos, or -1 when it is roaming. `current` is the jar it already had:
## it holds on a little longer, so a Jarling standing at the edge of the range does not flicker.
static func focus_at(pos: Vector3, count: int, current: int = -1) -> int:
	var i := nearest(pos, count)
	if i < 0:
		return -1
	var d := focus_distance(pos, i, count)
	if current >= 0 and current < count and current != i:
		var dc := focus_distance(pos, current, count)
		if dc <= FOCUS_RANGE + FOCUS_HOLD and (d > dc - FOCUS_SWITCH or d > FOCUS_RANGE):
			return current
	elif current == i and d <= FOCUS_RANGE + FOCUS_HOLD:
		return i
	return i if d <= FOCUS_RANGE else -1


## Where a Jarling that wants to be at pos ends up: on the island, and never inside a jar. The jars
## stand closer together than their plinths are wide, so the row is one smooth curved wall (round at
## both ends) that you slide along, with no dents between jars to get stuck in.
static func walkable(pos: Vector3, count: int) -> Vector3:
	var p := Vector2(pos.x, pos.z)
	var half := absf(angle(0, count)) if count > 0 else 0.0
	for _pass in 4:
		var moved := false
		var r := p.length()
		var a := atan2(p.x, -p.y)
		if count > 1 and absf(a) <= half and absf(r - ARC_RADIUS) < BLOCK_RADIUS - 0.001:
			p = p.normalized() * (ARC_RADIUS + (BLOCK_RADIUS if r > ARC_RADIUS else -BLOCK_RADIUS))
			moved = true
		for i in count:
			var j := jar_position(i, count)
			var c := Vector2(j.x, j.z)
			var off := p - c
			if off.length() < BLOCK_RADIUS - 0.001:
				# straight out, or towards the plaza centre when it is dead in the middle
				var out := off.normalized() if off.length() > 0.001 else -c.normalized()
				p = c + out * BLOCK_RADIUS
				moved = true
		p = p.limit_length(WALK_RADIUS)
		if not moved:
			break
	return Vector3(p.x, 0.0, p.y)
