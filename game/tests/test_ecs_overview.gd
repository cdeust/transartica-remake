extends SceneTree

const Overview = preload("res://scripts/ecs_overview.gd")
# source: tasks/evidence/map-orientation-audit.md, CARTE192/palette196 RGB digest.
const SOURCE_RGB_SHA256 := "35fdef97b7ac4d1afc271c2e8fa8b35181c9eab374d9c23c3fb19a3e7ab54a3a" # source: tasks/evidence/map-orientation-audit.md
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(Overview.PLAN_PATH)) != OK or not parser.data is Dictionary:
		push_error("private general plan unavailable; run tools/export_general_plan.py")
		quit(1)
		return
	var data: Dictionary = parser.data
	_test_exact_plan(data)
	_test_invalid_schema(data)
	_test_invalid_runs(data)
	_test_loading()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: original general-plan RGB hash, invalid schemas/runs, marker axes, explicit missing data")
	quit(0 if failures.is_empty() else 1)


func _test_exact_plan(data: Dictionary) -> void:
	var pixels: PackedByteArray = Overview.decode_plan(data)
	_check(pixels.size() == 320 * 149 * 3, "source dimensions produce complete RGB image")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels)
	_check(hash.finish().hex_encode() == SOURCE_RGB_SHA256, "all source RGB bytes preserved, not procedural network")
	var original: Dictionary = data.duplicate(true)
	Overview.decode_plan(data)
	_check(data == original, "decoding leaves source data untouched")


func _test_invalid_schema(data: Dictionary) -> void:
	for raw in [null, [], "plan"]:
		_check(Overview.decode_plan(raw).is_empty(), "reject non-dictionary plan")
	for key in ["version", "width", "height", "palette", "rows"]:
		var missing: Dictionary = data.duplicate(true)
		missing.erase(key)
		_check(Overview.decode_plan(missing).is_empty(), "reject missing " + key)
	for pair in [["version", 2], ["width", 319], ["height", 150], ["rows", []], ["palette", []]]:
		var invalid: Dictionary = data.duplicate(true)
		invalid[pair[0]] = pair[1]
		_check(Overview.decode_plan(invalid).is_empty(), "reject wrong " + pair[0])
	for color in [null, [0, 0], [0, 0, 256], [0, -1, 0], [0.5, 0, 0], ["0", 0, 0], [false, 0, 0]]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.palette[0] = color
		_check(Overview.decode_plan(invalid).is_empty(), "reject malformed palette channel")


func _test_invalid_runs(data: Dictionary) -> void:
	for row in [null, [], [[0, 319]], [[0, 321]], [[0, 200], [0, 121]], [[16, 320]],
			[[-1, 320]], [[0, 0]], [[0, -1]], [[0, 319.5]], [[0.5, 320]], [["0", 320]],
			[[0, "320"]], [[0, true]], [[0]], [[0, 320, 1]]]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.rows[0] = row
		_check(Overview.decode_plan(invalid).is_empty(), "reject invalid row/run")
	var invalid: Dictionary = data.duplicate(true)
	invalid.rows.remove_at(0)
	_check(Overview.decode_plan(invalid).is_empty(), "reject incomplete row count")


func _test_loading() -> void:
	var view = Overview.new()
	_check(view.load_plan(Overview.PLAN_PATH), "load exact private plan")
	_check(view.plan_texture != null and view.plan_texture.get_size() == Vector2(320, 149), "texture retains source extent")
	_check(view.map_point(Vector2(12, 62)) == Vector2(26, 127), "original start marker anchor")
	_check(view.map_point(Vector2(0, 0)) == Vector2(2, 3), "original map origin offset")
	_check(view.map_point(Vector2(159, 71)) == Vector2(320, 145), "original positive x/right and y/down")
	var absent := "res://../.cache/missing-general-plan-%s.json" % OS.get_process_id()
	_check(not FileAccess.file_exists(absent), "missing-data fixture is actually absent")
	_check(not view.load_plan(absent), "missing historical data fails explicitly")
	_check(view.plan_texture == null and not view.unavailable_reason.is_empty(), "missing data clears stale map and explains absence")
	view.free()


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
