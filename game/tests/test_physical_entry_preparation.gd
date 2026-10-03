extends SceneTree
# requires-native-renderer
# MIT. Prepared Main integration fixtures, not native player acceptance.
# Source: TIME0x1c31 (DRILL),0x1fc8 (Hima),0x1e98 (central station),
# and0x1f53 (slope approach); tasks/evidence/campaign-completion.md.
const Dispatch = preload("res://scripts/journey_session.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []
var app

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _run() -> void:
	app = preload("res://scripts/main.gd").new()
	# No save is written by this test; suppress unrelated launch restore.
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/physical-entry-preparation-%d.SAV" % OS.get_process_id())
	app.size = Vector2(1280,800) # Source: project viewport fixture.
	root.add_child(app)
	app.set_process(false)
	await process_frame
	check(app.network.is_loaded() and app.campaign.state.data.has("regions"),"real Main loads source map and campaign")
	if failures.is_empty():
		_test_drill()
		_test_hima()
		_test_central()
		_test_physical_heading()
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: production physical-entry dispatch, DRILL passage, Hima transformation, central source flag, persisted map writes and physical slope heading")
	quit(0 if failures.is_empty() else 1)

func _prepare(cell: Vector2i, approach: int, reason := "station") -> void:
	app._trade_rng.seed = 1 # Source: existing campaign integration fixture seed.
	app._restart_engine()
	# The logical locomotive stays at START, deliberately remote from the
	# physical boundary. This isolates dispatch ordering after Stop.advance.
	app.journey.reverse = true
	app.journey.heading = 6
	app.journey.blocked = true
	app.journey.stop_reason = reason
	app.journey.physical_obstacle = cell
	app.journey.physical_heading = approach
	app.engine.brake = false
	app.session.paused = false
	check(app.journey.next_cell()!=cell,"fixture distinguishes physical boundary from logical next cell")

func _check_passage(cell: Vector2i, code: int, label: String) -> void:
	Dispatch._handle_boundary(app,false)
	check(app.network.tile(cell)==code,label+" source tile transformed before station handler")
	check(not app.journey.blocked and app.journey.stop_reason.is_empty(),label+" movement released")
	check(app.journey.physical_obstacle==Vector2i(-1,-1) and app.journey.physical_heading==0,label+" physical boundary cleared")
	check(not app._city_panel.visible and not app.works_dialog.visible and not app.campaign.screen.visible,label+" no station scene opened")
	check(not app.session.paused and not app.engine.brake,label+" no station pause or brake")
	check(app.journey.position==app.journey.START_POSITION,label+" logical position unchanged by preparation")
	var network = Rails.new()
	var loaded: bool = network.load_bytes(app.world_data.map_bytes)
	check(loaded,label+" restore reference map")
	var restored: bool = network.restore(app.network.snapshot())
	check(restored and network.tile(cell)==code,label+" map transformation survives snapshot restore")

func _test_drill() -> void:
	var cell := Vector2i(32,67)
	_prepare(cell,4)
	check(app.network.tile(cell)==35,"DRILL gate starts with original station35")
	app.wagons.wagons[-1][0]=8 # Source: last wagon DRILL qualifies.
	app.world_view.consist.derive_from_wagons(app.wagons)
	_check_passage(cell,2,"tail DRILL")
	_prepare(cell,4)
	Dispatch._handle_boundary(app,false)
	check(app.network.tile(cell)==35 and app.journey.at_station(),"without DRILL original station remains blocked")

func _test_hima() -> void:
	var cell := Vector2i(39,32)
	_prepare(cell,6)
	check(app.network.tile(cell)==34,"Hima gate starts with original station34")
	_check_passage(cell,2,"Hima")

func _test_central() -> void:
	var cell := Vector2i(157,68)
	_prepare(cell,8)
	check(app.network.tile(cell)==36,"central gate starts with original station36")
	check(not app.campaign.state.central_destroyed,"source central flag starts false")
	Dispatch._handle_boundary(app,false)
	check(app.network.tile(cell)==36 and app.journey.at_station(),"intact central station remains blocked")
	_prepare(cell,8)
	app.campaign.state.central_destroyed=true
	_check_passage(cell,3,"destroyed central station")
	var snapshot: Dictionary = app.campaign.state.snapshot()
	app.campaign.state.central_destroyed=false
	var restored: bool = app.campaign.state.restore(snapshot)
	check(restored and app.campaign.state.central_destroyed,"central destruction flag survives snapshot restore")

func _test_physical_heading() -> void:
	# TIME slope test requires approach1 and more than five wagons without a
	# BOILER. START has six source wagons; logical heading6 must not suppress it.
	_prepare(Vector2i(152,48),1,"special site")
	check(app.wagons.count()>5,"source initial composition qualifies for slope check")
	Dispatch._handle_boundary(app,false)
	check(app.campaign.state.pending.get("scene","")=="slope", "physical heading1 reaches source slope event despite logical heading6")
	check(app.campaign.screen.visible and app.session.paused,"physical pre-entry campaign event opens through real Main")
