extends SceneTree
# MIT. Exact earned fixtures replay production geometry and boundary dispatch.
# The adapter excludes fauna/UI; this is a model regression, not native play.
var Stop
const Dispatch = preload("res://scripts/journey_session.gd")
const Rails = preload("res://scripts/rail_network.gd")
class CampaignAdapter:
	extends RefCounted
	var state = preload("res://scripts/campaign_state.gd").new()
	var app
	func before_entry(cell: Vector2i, heading: int, after_spy := false) -> bool:
		var event: Dictionary = state.prepare_entry(cell,heading,app.wagons,app.network,after_spy)
		return not event.is_empty()
class BoundaryAdapter:
	extends RefCounted
	var app
	func handle_boundary() -> bool:
		return app.journey.at_station()
class AppAdapter:
	extends RefCounted
	var journey = preload("res://scripts/train_journey.gd").new()
	var network = Rails.new()
	var wagons = preload("res://scripts/train_wagons.gd").new()
	var world = preload("res://scripts/world_actions.gd").new()
	var campaign = CampaignAdapter.new()
	var world_view = preload("res://scripts/travel_world.gd").new()
	var _world_session = BoundaryAdapter.new()
var failures: Array[String] = []
var prepared: Array[Vector2i] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	Stop = load("res://../.cache/reverse-hidden-contact-fix-20261004/before-stop.gd" if "--before-stop" in OS.get_cmdline_user_args() else "res://scripts/reverse_contact_stop.gd")
	var data = preload("res://scripts/world_data.gd").new()
	check(data.load_from_project(ProjectSettings.globalize_path("res://")),"reference data loads")
	var earned = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-hidden-partial-earned.json"))
	for name in ["reverse-hidden-zero10347","reverse-hidden-zero10355","reverse-hidden-partial-earned"]:
		var app = AppAdapter.new()
		app.campaign.app = app
		app._world_session.app = app
		app.world.journey = app.journey
		app.world.wagons = app.wagons
		app.world_view.journey = app.journey
		app.world_view.network = app.network
		check(app.world_view.train_renderer.load_assets(),"production vehicle calibration loads")
		var saved = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/%s.json" % name))
		check(app.network.load_bytes(data.map_bytes),"reference network loads")
		app.network.set_city_anchors(data.city_anchors())
		check(app.network.restore(saved.network),"earned network restores")
		app.journey.network = app.network
		check(app.journey.restore(saved.journey),"earned journey restores")
		check(app.wagons.restore(earned.wagons),"earned composition restores")
		check(app.campaign.state.restore(earned.campaign.state) and app.campaign.state.load_data(),"earned campaign restores")
		app.world_view.consist.derive_from_wagons(app.wagons)
		var original_cell: Vector2i = app.journey.position
		var original_arc: float = app.journey.distance_travelled()
		var original_phase: int = app.journey.phase
		var original_ticks: int = app.journey.distance_ticks
		var initial_count := contacts(app)
		var prepared_count := 0
		while not app.journey.blocked and contacts(app)<app.wagons.count():
			Stop.advance(app.world_view,app.journey,300)
			check(app.journey.position==original_cell and app.journey.phase==original_phase and app.journey.distance_ticks==original_ticks,"incomplete physical contacts cannot advance TIME")
			if not app.journey.blocked:
				check(false,"missing hidden contact must reach pre-entry dispatch")
				break
			if app.network.tile(app.journey.boundary_cell())==-115:
				var cell: Vector2i = app.journey.boundary_cell()
				var before: Dictionary = app.network.snapshot()
				Dispatch._handle_boundary(app,false)
				prepared.append(cell)
				prepared_count += 1
				check(app.network.tile(cell)!=-115,"source reveals exact physical hidden cell")
				check(is_equal_approx(app.journey.distance_travelled(),original_arc),"preparation preserves physical arc")
				var after: Dictionary = app.network.snapshot()
				check(after.switches.size()==before.switches.size()+1,"one hidden tile prepared, no fullmap reveal")
		if contacts(app)==app.wagons.count():
			while not app.journey.blocked:
				Stop.advance(app.world_view,app.journey,300)
				if app.journey.blocked and app.network.tile(app.journey.boundary_cell())==-115:
					Dispatch._handle_boundary(app,false)
				check(contacts(app)==app.wagons.count(),"recovered full footprint retains21 contacts until physical station")
		check(prepared_count>0,"physical source preparation reached")
		check(app.journey.at_station() and app.journey.boundary_cell()==Vector2i(51,23),"revealed station retains physical stop and station dispatch")
		check(contacts(app)>initial_count,"valid connected contacts recover without crossing terminal")
		print(name," initial=",initial_count," recovered=",contacts(app)," individually_prepared=",prepared_count," stopped=",app.journey.boundary_cell())
		app.campaign.app = null
		app._world_session.app = null
		app.world_view.free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: exact10347/10355/10361 hidden contacts prepare individually without movement and stop at revealed station51,23")
	quit(0 if failures.is_empty() else 1)
func contacts(app) -> int:
	return app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0).size()
