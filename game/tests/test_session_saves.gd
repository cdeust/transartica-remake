extends SceneTree
# requires-native-renderer
# Source: native AudioStreamWAV playback; Dummy mixer leaks measured in cadence review.

const Saves = preload("res://scripts/session_saves.gd")
const Slots = preload("res://scripts/save_slots.gd")
var failures: Array[String] = []
var directory: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	directory = ProjectSettings.globalize_path("res://../.cache/session-saves-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scripts/main.gd").new()
	app.save_path_override = directory.path_join("automatic.json")
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app._restart_engine()
	app.session.paused = true
	app.engine.lignite = 1777
	app.calendar.day = 7
	app.clock.set_elapsed(123.0)
	app.world_view.following_train = true
	app.stoup.push(105)
	var path := Slots.slot_path(directory, "FIRST")
	var before := Saves.snapshot(app)
	_check(Saves.save(app, path).ok, "named save written")
	app.engine.lignite = 1
	app.calendar.day = 1
	app.stoup.pop()
	app.world_view.inspecting_map = true
	_check(Saves.restore(app, path).ok, "named save restored")
	_check(Saves.snapshot(app) == before, "roundtrip all persisted fields including stoup")
	_test_inspection(app, path)
	_test_invalid(app, path)
	_test_slots(app)
	_test_write_failure(app)
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory.path_join("BLOCK.SAV"))
	DirAccess.remove_absolute(directory)
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: transactional named saves, complete roundtrip, invalid paths and write failure")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_invalid(app, path: String) -> void:
	var before := Saves.snapshot(app)
	for field in ["session", "discovery", "network", "journey", "wagons", "trade", "stoup", "zoom", "travel_camera"]:
		var invalid := before.duplicate(true)
		invalid[field] = "malformed"
		_write(path, JSON.stringify(invalid))
		_check(not Saves.restore(app, path).ok, "reject malformed " + field)
		_check(Saves.snapshot(app) == before, "malformed " + field + " leaves state untouched")
	_write(path, "{}")
	_check(not Saves.restore(app, path).ok, "reject named slot without session")
	_check(Saves.snapshot(app) == before, "empty named save leaves state untouched")
	_write(path, "{broken")
	_check(not Saves.restore(app, path).ok, "reject malformed JSON")
	_check(Saves.snapshot(app) == before, "malformed JSON leaves state untouched")


func _test_slots(app) -> void:
	_check(Slots.normalize_name("a_b c-123456789") == "ABC12345", "original book charset and limit")
	_check(Slots.normalize_name("12abc34") == "ABC34", "reject leading digits during book typing")
	for name in ["", "../MAIN", "A/B", "a", "123456789", "1ABC", "123", "A.SAV", "A\\B"]:
		_check(Slots.slot_path(directory, name).is_empty(), "reject invalid slot " + name)
	_write(directory.path_join("Z.SAV"), "old save")
	_write(directory.path_join("A.SAV"), "old save")
	_write(directory.path_join("invalid.SAV"), "ignored")
	_write(directory.path_join("NOTSAVE.json"), "ignored")
	_check(Slots.list_names(directory) == ["A", "FIRST", "Z"], "stable valid slots only")
	# A destination directory forces rename failure after the temporary write.
	var blocked := directory.path_join("BLOCK.SAV")
	DirAccess.make_dir_absolute(blocked)
	_check(not Saves.save(app, blocked).ok, "report replacement failure")
	_check(DirAccess.dir_exists_absolute(blocked), "failed replacement preserves target")
	_check(not FileAccess.file_exists(blocked + ".tmp-" + str(OS.get_process_id())), "failed write removes temp")
	_check(Saves.save(app, directory.path_join("Z.SAV")).ok, "confirmed replacement succeeds")
	_check(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("Z.SAV"))) is Dictionary, "replacement complete")


func _test_write_failure(app) -> void:
	var path := directory.path_join("KEPT.SAV")
	_write(path, "existing save must survive")
	var temporary := path + ".tmp-" + str(OS.get_process_id())
	DirAccess.make_dir_absolute(temporary)
	_check(not Saves.save(app, path).ok, "report temporary write failure")
	_check(FileAccess.get_file_as_string(path) == "existing save must survive", "write failure preserves previous save bytes")
	DirAccess.remove_absolute(temporary)


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _test_inspection(app, path: String) -> void:
	_check(not app.world_view.inspecting_map, "normal save clears stale inspection")
	app.world_view.inspecting_map = true
	var state := Saves.snapshot(app)
	_check(Saves.save(app, path).ok, "inspection save written")
	app.world_view.inspecting_map = false
	_check(Saves.restore(app, path).ok and app.world_view.inspecting_map, "inspection camera state roundtrips")
	state.travel_camera.erase("inspecting")
	_write(path, JSON.stringify(state))
	_check(Saves.restore(app, path).ok and not app.world_view.inspecting_map, "legacy camera defaults to normal framing")
	state.travel_camera.inspecting = "invalid"
	_write(path, JSON.stringify(state))
	var before := Saves.snapshot(app)
	_check(not Saves.restore(app, path).ok and Saves.snapshot(app) == before, "invalid inspection flag rejected transactionally")
	app.world_view.inspecting_map = true
	app._restart_engine()
	_check(not app.world_view.inspecting_map, "new game clears inspection")
