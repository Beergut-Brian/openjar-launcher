## "Hold two buttons together for N seconds" detector, input-free so it can be unit tested.
## Feed it the button states each frame; update() returns true once per hold.
class_name HoldCombo
extends RefCounted

var hold_time: float
var held := 0.0
var _fired := false


func _init(seconds: float = 1.0) -> void:
	hold_time = seconds


## True on the frame the combo has been held for hold_time. Releasing either button re-arms it.
func update(a_down: bool, b_down: bool, delta: float) -> bool:
	if not (a_down and b_down):
		held = 0.0
		_fired = false
		return false
	if _fired:
		return false
	held += delta
	if held >= hold_time:
		_fired = true
		return true
	return false


## 0..1 while holding (for a fill meter); 0 once fired or released.
func progress() -> float:
	if _fired:
		return 0.0
	return clampf(held / hold_time, 0.0, 1.0)
