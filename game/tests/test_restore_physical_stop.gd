extends SceneTree
# requires-native-renderer
# MIT. Production restore regression using unchanged earned player save7190.
# This replay verifies presentation state; it is not new campaign progress.
const Saves = preload("res://scripts/session_saves.gd")
const FIXTURE := "res://../reference-private/validation/reverse-physical-stop-earned.json"
var failures: Array[String] = []
var app
var draw_observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func boundary(value: Array) -> Vector2i:
	# JSON.parse_string produces float coordinates; production snapshot writes
	# integer coordinates. Array equality distinguishes these element types.
	return Vector2i(int(value[0]),int(value[1]))

func _observe_draw() -> void:
	var view = app.world_view
	# Exact lag formula used by TravelWorld._draw_train, evaluated at its
	# CanvasItem draw signal, not a separate lag0 geometry oracle.
	var lag: float = maxf(0.0,app.journey.distance_travelled()-view._visual_arc) if view._visual_initialized else 0.0
	var contacts: Array = view.train_renderer.poses(view,app.journey,view.consist,lag)
	draw_observations.append({"lag":lag,"count":contacts.size()})

func _run() -> void:
	check(FileAccess.file_exists(FIXTURE),"unchanged earned7190 fixture exists")
	if not failures.is_empty():
		_finish()
		return
	var original: String = FileAccess.get_file_as_string(FIXTURE)
	var saved: Variant = JSON.parse_string(original)
	check(saved is Dictionary and saved.get("journey") is Dictionary,"earned fixture parses")
	if not failures.is_empty():
		_finish()
		return
	check(saved.wagons.size()==13,"earned fixture contains its thirteen purchased vehicles")
	app = preload("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/restore-physical-stop-%d.SAV" % OS.get_process_id())
	app.size = Vector2(1280,800) # Source: project viewport fixture.
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	var result: Dictionary = Saves.restore(app,ProjectSettings.globalize_path(FIXTURE))
	check(result.ok,"real SessionSaves restores earned physical stop")
	if result.ok:
		_check_restored(saved)
		# Expose the map underneath the restored works overlay. No command is
		# sent to the dialogue, and no journey update is used to repair its arc.
		app._modal.show()
		app._map_panel.show()
		app.world_view.show()
		app.world_view.draw.connect(_observe_draw)
		app.world_view.queue_redraw()
		await RenderingServer.frame_post_draw
		check(not draw_observations.is_empty(),"restored map reaches actual CanvasItem draw")
		for observation in draw_observations:
			check(is_zero_approx(observation.lag),"actual draw uses zero restored interpolation lag")
			check(observation.count==saved.wagons.size(),"actual draw contact query retains all thirteen vehicles")
		check(app.works_dialog.visible and app.session.paused,"draw does not dismiss works or resume motion")
		check(is_equal_approx(app.world_view._visual_arc,app.journey.distance_travelled()),"paused draw keeps restored arc synchronized")
	check(FileAccess.get_file_as_string(FIXTURE)==original,"earned fixture remains byte-for-byte unchanged")
	app.queue_free()
	await process_frame
	_finish()

func _check_restored(saved: Dictionary) -> void:
	var view = app.world_view
	check(app.works_dialog.visible and app.session.paused,"works restores visible and suspends simulation")
	check(app.journey.at_obstacle() and app.journey.boundary_cell()==Vector2i(6,9),"physical crevasse boundary restores")
	check(boundary(app.journey.snapshot().physical_obstacle)==boundary(saved.journey.physical_obstacle),"persisted physical boundary unchanged")
	check(app.journey.snapshot().physical_heading==saved.journey.physical_heading,"persisted approach heading unchanged")
	check(view._visual_initialized,"restore initializes visual position before paused update")
	check(is_equal_approx(view._visual_arc,app.journey.distance_travelled()),"restore snaps visual arc to saved journey arc")
	check(view._visual_position.is_equal_approx(app.journey.fractional_position()),"restore snaps head to saved fractional position")
	check(not view._interpolating,"restored paused train has no pending interpolation")
	var diagnostic_lag: float = maxf(0.0,app.journey.distance_travelled()-view._visual_arc)
	check(is_zero_approx(diagnostic_lag),"native console lag agrees with restored drawing")
	check(view.train_renderer.poses(view,app.journey,view.consist,diagnostic_lag).size()==saved.wagons.size(),"restored diagnostic contacts retain complete earned consist")
	var snapshot: Dictionary = Saves.snapshot(app)
	check(boundary(snapshot.journey.physical_obstacle)==boundary(saved.journey.physical_obstacle) and snapshot.works.visible,"production snapshot retains paused works boundary")

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: earned7190 production restore, paused works boundary, synchronized visual arc and thirteen contacts at actual map draw")
	quit(0 if failures.is_empty() else 1)
