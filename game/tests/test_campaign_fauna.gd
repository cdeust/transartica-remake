extends SceneTree

# requires-native-renderer
# MIT. Source callback counts, shared cooldown and interrupted real scene saves.
const Main = preload("res://scripts/main.gd")
const Fauna = preload("res://scripts/campaign_fauna.gd")
const Hazards = preload("res://scripts/campaign_hazards.gd")
const Ambush = preload("res://scripts/campaign_ambush.gd")
var failures: Array[String] = []

class Straight extends RefCounted:
	func tile(_cell): return 2
	func turn(_cell, heading): return heading
	func is_switch(_cell): return false


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # Reproducible authored fixture; no production constant.
	var fauna := Fauna.new()
	fauna.initialize(rng)
	fauna.cell = Vector2i(40, 40)
	var network := Straight.new()
	for tick in 5:
		check(not fauna.advance(network, rng), "wolf has no commit before sixth TIME callback")
	check(fauna.advance(network, rng) and fauna.cell == Vector2i(41, 40), "wolf two callbacks per phase, three phases per tile")
	fauna.oslo()
	for tick in 12:
		fauna.advance(network, rng)
	check(fauna.cell == Vector2i(126, 15) and fauna.phase == 0, "Oslo holds wolf until attack completes")
	var prior := fauna.snapshot()
	var corrupt := prior.duplicate(true)
	corrupt.phase = 1
	check(not fauna.restore(corrupt) and fauna.snapshot() == prior, "wolf invalid snapshot rejected without mutation")
	var hazards := Hazards.new()
	var calendar = preload("res://scripts/game_calendar.gd").new()
	var target: Vector2i = Hazards.MOLES[0]
	hazards.mole_times[target.x % 10] = -1
	var before := rng.state
	check(hazards.player_mole(target, calendar, rng) and rng.state != before, "disabled car mole stamp forces ambush and still consumes rnd6")
	check(not hazards.player_mole(target, calendar, rng), "same day cooldown suppresses immediate second ambush")
	calendar.day += 1
	calendar.hour = 0
	check(not hazards.player_mole(target, calendar, rng), "next day before prior hour remains in cooldown")
	calendar.day += 1
	while true:
		var probe := RandomNumberGenerator.new()
		probe.state = rng.state
		if probe.randi_range(0, 5) == 0:
			break
		rng.randi_range(0, 5)
	check(hazards.player_mole(target, calendar, rng), "older than previous day and rnd6 zero permits new ambush")
	await _real_scene()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: source wolf phases, mole cooldown and actual staged ambush save/resume")
	quit(0 if failures.is_empty() else 1)


func _real_scene() -> void:
	DirAccess.make_dir_recursive_absolute("res://../.cache/fauna")
	var app = Main.new()
	app.size = root.get_visible_rect().size
	app.save_path_override = "res://../.cache/fauna/interrupted.SAV"
	root.add_child(app)
	await process_frame
	await process_frame
	app.campaign.reset()
	_reports(app)
	app.wagons.wagons = [[1,0,0,0],[21,0,0,0],[2,0,0,0],[3,0,0,0],[7,0,0,5],[23,0,0,40],[17,0,11,9]]
	app.campaign.state.fauna.oslo()
	check(app.campaign.before_entry(Vector2i(126,15)), "actual wolf presence intercepts candidate entry")
	check(app.campaign.screen.scene == "wolf" and app.campaign.page == 0 and app.wagons.wagons[5][3] == 40, "initial report shows defenders before losses")
	app.campaign.screen.continued.emit()
	var after_human: Array = app.wagons.snapshot()
	check(app.campaign.page == 1 and after_human[5][3] < 40 and app.campaign.state.pending.applied == 1, "human loss commits on second source page")
	await _capture(app, "wolf-human")
	check(app.save_view(), "actual interrupted human report save accepted")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(app.save_path_override))
	check(Fauna.new().restore(parsed.campaign.state.fauna), "JSON wolf state validates")
	check(preload("res://scripts/campaign_ambush_snapshot.gd").valid(parsed.campaign.state.pending), "JSON ambush stage validates")
	check(preload("res://scripts/campaign_state.gd").new().restore(parsed.campaign.state), "JSON campaign state validates")
	app.campaign.reset()
	app.wagons.reset()
	var result: Dictionary = preload("res://scripts/session_saves.gd").restore(app, app.save_path_override)
	check(result.ok and app.campaign.page == 1 and app.wagons.snapshot() == after_human, "actual restore retains page and settled human loss: " + result.notice)
	app.campaign._show_page()
	check(app.wagons.snapshot() == after_human, "resume presentation never applies human losses twice")
	app.campaign.screen.continued.emit()
	check(app.campaign.page == 2 and app.wagons.wagons[6][3] == 5, "wolf removes floor half food on material page")
	var saved: Dictionary = app.campaign.snapshot()
	var broken: Dictionary = saved.duplicate(true)
	broken.state.pending.applied = 1
	check(not app.campaign.restore(broken) and app.campaign.snapshot() == saved, "mismatched loss stage rejects atomically")
	app.campaign.screen.continued.emit()
	check(app.campaign.state.pending.is_empty() and not app.campaign.state.fauna.frozen, "final report relocates wolf and resumes roaming")
	app.campaign.state.hazards.mole_times[Hazards.MOLES[0].x % 10] = -1
	check(app.campaign.before_entry(Hazards.MOLES[0]) and app.campaign.screen.scene == "mole", "actual forced mole report")
	app.campaign.screen.continued.emit()
	var anthracite: int = app.engine.anthracite
	app.campaign.screen.continued.emit()
	check(app.engine.anthracite < anthracite and app.wagons.wagons[4][1] == 3, "mole fuel loss and first eligible wagon destruction")
	await _capture(app, "mole-material")
	check(app.save_view(), "mole material stage saves")
	var stocks := [app.engine.lignite, app.engine.anthracite]
	result = preload("res://scripts/session_saves.gd").restore(app, app.save_path_override)
	app.campaign._show_page()
	check(result.ok and [app.engine.lignite, app.engine.anthracite] == stocks, "mole material report resumes without repeated fuel loss")
	var legacy: Dictionary = app.campaign.state.snapshot()
	legacy.pending = {}
	legacy.erase("fauna")
	legacy.delivery_open = true
	var candidate = preload("res://scripts/campaign_state.gd").new()
	check(candidate.restore(legacy) and candidate.fauna.frozen, "explicit legacy migration recovers known Oslo blockade")
	app.queue_free()
	await process_frame


func _capture(app, name: String) -> void:
	app.campaign.screen.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	check(app.campaign.screen.size.x > 0 and captured.get_pixel(captured.get_width() / 2, captured.get_height() / 3).get_luminance() > 0, "native ambush has visible scene artwork " + name)
	check(captured.save_png("res://../.cache/fauna/" + name + ".png") == OK, "native ambush capture " + name)


func _reports(app) -> void:
	var wagon = preload("res://scripts/train_wagons.gd").new()
	wagon.wagons = [[7,0,0,12],[5,0,0,7],[23,0,0,9]]
	var human := Ambush.human(wagon, 2, app.campaign.state.data.ambush_phrases)
	check(wagon.wagons[0][3] == 6 and wagon.wagons[1][3] == 4 and wagon.wagons[2][3] == 5,
		"golden TEXTEK human quantities use integer loss in source order")
	check(human.back().ends_with("3"), "golden mammoth report uses reduced load divided again")
	var spies: Array = app.campaign.state.spies.duplicate(true)
	var herd := [[0,40,0,6,0,29]]
	var context := {"wolf_heading": 4, "nomad_heading": 6, "herds": herd}
	var formatter = preload("res://scripts/spy_report.gd")
	for code in [40,60,70]:
		spies[0][7] = code
		var lines: Array[String] = formatter.format(0, spies, app.encounters.enemies, app.campaign.state.data, context)
		check(lines.size() == 4, "source spy report mover branch " + str(code))
		if code == 40:
			check("20" in lines[2] and "29" not in lines[2], "large herd spy report rounds down to tens")
