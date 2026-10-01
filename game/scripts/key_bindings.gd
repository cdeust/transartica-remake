extends RefCounted

# MIT. Owner-approved configurable remake shortcuts, FIDELITE.md Commands.
# Defaults are the existing GameplayInput commands, not new original mechanics.
const DEFAULTS := {"lignite":KEY_L,"anthracite":KEY_A,"brake":KEY_B,"pause":KEY_SPACE,
	"help":KEY_H,"map":KEY_M,"journal":KEY_J,"regulator_down":KEY_LEFT,
	"regulator_up":KEY_RIGHT,"save":KEY_F5,"options":KEY_F6,"restart":KEY_R}
var keys: Dictionary = DEFAULTS.duplicate()
var path := ""

func load_settings(filename: String) -> void:
	path = filename
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var candidate: Dictionary = {}
	for action in DEFAULTS:
		candidate[action] = config.get_value("keys",action,DEFAULTS[action])
	if valid(candidate):
		keys = candidate

static func valid(candidate: Variant) -> bool:
	if not candidate is Dictionary or candidate.size() != DEFAULTS.size():
		return false
	var assigned: Array = []
	for action in DEFAULTS:
		var code: Variant = candidate.get(action)
		if not code is int or code <= 0 or code == KEY_ESCAPE or code in assigned:
			return false
		assigned.append(code)
	return true

func assign(action: String, code: int) -> bool:
	var candidate := keys.duplicate()
	candidate[action] = code
	if not valid(candidate):
		return false
	return _save(candidate)

func defaults() -> bool:
	return _save(DEFAULTS.duplicate())

func _save(candidate: Dictionary) -> bool:
	if path.is_empty() or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var config := ConfigFile.new()
	for action in DEFAULTS:
		config.set_value("keys",action,candidate[action])
	if config.save(path) != OK:
		return false
	keys = candidate
	return true

func canonical(event: InputEventKey) -> InputEventKey:
	var result: InputEventKey = event.duplicate()
	# An unbound former shortcut becomes inert instead of retaining a second bind.
	if event.physical_keycode in DEFAULTS.values():
		result.physical_keycode = KEY_NONE
	for action in keys:
		if event.physical_keycode == keys[action]:
			result.physical_keycode = DEFAULTS[action]
			break
	return result
