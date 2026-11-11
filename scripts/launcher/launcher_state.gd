## Launcher's remembered state, stored through the Save autoload (or any node with the same API).
## Keys are listed in docs/contracts.md, "Launcher save keys".
class_name LauncherState
extends RefCounted

const LAST_CARD := "launcher.last_card"
const PROFILE := "launcher.profile"
const SHOW_DEV := "launcher.show_dev"
const INTRO_DATE := "launcher.intro_date"


static func last_card(save: Node) -> String:
	var v = save.get_value(LAST_CARD, "")
	return v if v is String else ""


static func set_last_card(save: Node, slug: String) -> void:
	save.set_value(LAST_CARD, slug)


static func profile(save: Node) -> String:
	var v = save.get_value(PROFILE, LaunchArgs.DEFAULT_PROFILE)
	return v if v in LaunchArgs.PROFILES else LaunchArgs.DEFAULT_PROFILE


static func set_profile(save: Node, id: String) -> void:
	save.set_value(PROFILE, id)


## Dev builds are shown for this launcher run only (Kaden, 2026-11-10: only main-branch games show;
## hold LB + RB to see the dev ones). Never restored at boot, so every start shows stable games only.
## SHOW_DEV stays as a key name so an old save's value is simply ignored.
static var _show_dev_session := false


static func show_dev(_save: Node = null) -> bool:
	return _show_dev_session


static func set_show_dev(_save: Node, on: bool) -> void:
	_show_dev_session = on


## Tests: back to a fresh boot.
static func reset_session() -> void:
	_show_dev_session = false


static func intro_date(save: Node) -> String:
	var v = save.get_value(INTRO_DATE, "")
	return v if v is String else ""


## The intro plays on the first boot of each (local) day.
static func should_play_intro(save: Node, today: String) -> bool:
	return intro_date(save) != today


static func mark_intro_played(save: Node, today: String) -> void:
	save.set_value(INTRO_DATE, today)


static func today() -> String:
	return Time.get_date_string_from_system()
