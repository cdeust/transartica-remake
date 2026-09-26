extends SceneTree

const WorldDataScript = preload("res://scripts/world_data.gd")
const TravelWorldScript = preload("res://scripts/travel_world.gd")
const JourneyScript = preload("res://scripts/train_journey.gd")
const EngineStateScript = preload("res://scripts/engine_state.gd")
const EngineSessionScript = preload("res://scripts/engine_session.gd")
const RailNetworkScript = preload("res://scripts/rail_network.gd")
const ConsistScript = preload("res://scripts/train_consist.gd")
const TrainWagonsScript = preload("res://scripts/train_wagons.gd")
# 1.0 + 1.01 + 1.01 + 0.99 + 0.99 + 0.99: Consist.LENGTHS of the initial
# composition (locomotive, tender, general-quarters, boudoir, merchandise, barracks).
const CONSIST_HALF := 5.99 * 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var data = WorldDataScript.new()
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	_check(data.load_from_project(root_path), "private map and cities load", failures)
	if failures.is_empty():
		await _test_view(data, failures)
	if failures.is_empty():
		print("PASS: fixed camera, rigid overhead rotation at any heading, constant-chord bent convoy, wagon-table composition, switch clicks, fog and arc interpolation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_view(data, failures: Array[String]) -> void:
	var view = TravelWorldScript.new()
	view.size = Vector2(1200, 700)
	view.world_data = data
	view.journey = JourneyScript.new()
	var network = RailNetworkScript.new()
	network.load_bytes(data.map_bytes)
	view.network = network
	view.journey.network = network
	view.session = EngineSessionScript.new(EngineStateScript.new(), 1.0)
	root.add_child(view)
	await process_frame
	_test_occupied_track(view, failures)
	_test_vehicle_frames(view, failures)
	_test_vehicle_routes(view, failures)
	_test_geometry(view, failures)
	_test_fog_and_cities(view, data, failures)
	_test_top_down_and_switches(view, failures)
	_test_interpolation(view, failures)
	_test_bend_interpolation(view, failures)
	view.queue_free()
	await process_frame


func _test_geometry(view, failures: Array[String]) -> void:
	var world := Vector2(18.25, 41.75)
	var roundtrip: Vector2 = view._screen_to_world(view._world_to_screen(world))
	_check(roundtrip.distance_to(world) < 0.0001, "oblique projection round-trips", failures)
	var anchor := Vector2(310, 220)
	var before: Vector2 = view._screen_to_world(anchor)
	view.zoom_by(1.5, anchor)
	_check(view._screen_to_world(anchor).distance_to(before) < 0.0001, "zoom preserves its screen anchor", failures)
	_check(view._ground.size.is_equal_approx(view.size), "ground texture fills viewport", failures)


func _test_fog_and_cities(view, data, failures: Array[String]) -> void:
	var image: Image = view._discovery_mask.get_image()
	var known: Vector2i = view.discovery.current_position
	_check(image.get_pixel(known.x, known.y).r > 0.9, "current cell appears in discovery mask", failures)
	_check(image.get_pixel(0, 0).r < 0.1, "unknown cell remains fogged", failures)
	var hidden_index := _find_hidden_city(view, data)
	_check(hidden_index >= 0, "city list contains a hidden city for fog test", failures)
	if hidden_index >= 0:
		_check(not view._city_is_visible(data.cities[hidden_index]), "undiscovered city is hidden", failures)


func _test_interpolation(view, failures: Array[String]) -> void:
	view.follow_train()
	var start: Vector2 = view._visual_position
	view.journey.distance_ticks = 10
	view.update_train()
	var target: Vector2 = view._visual_to
	view._process(0.5)
	_check(view._visual_position.distance_to(start.lerp(target, 0.5)) < 0.0001, "train presentation interpolates over the session cycle", failures)
	view.session.paused = true
	var frozen: Vector2 = view._visual_position
	view._process(0.3)
	_check(view._visual_position == frozen, "paused session freezes presentation interpolation", failures)
	view.journey.reset()
	view.update_train()
	_check(not view._interpolating and view._visual_position.distance_to(Vector2(view.journey.fractional_position())) < 0.0001, "journey reset snaps visual position", failures)
	view.journey.position.x += 2
	view.update_train()
	_check(not view._interpolating, "large position jump snaps visual position", failures)


func _test_top_down_and_switches(view, failures: Array[String]) -> void:
	var origin: Vector2 = view._world_to_screen(Vector2(20, 30))
	var east: Vector2 = view._world_to_screen(Vector2(21, 30)) - origin
	var south: Vector2 = view._world_to_screen(Vector2(20, 31)) - origin
	_check(east.x > 0.0 and east.y > 0.0 and south.x < 0.0 and south.y > 0.0, "oblique map: east runs down-right, south down-left", failures)
	var switch_cell := Vector2i(54, 67)
	_check(not view.toggle_switch_at(switch_cell), "undiscovered switch cannot be clicked", failures)
	view.discovery.visit_cell(switch_cell)
	var toggled := [false]
	view.switch_toggled.connect(func(_cell: Vector2i) -> void: toggled[0] = true)
	_check(view.toggle_switch_at(switch_cell) and view.network.tile(switch_cell) == 23 and toggled[0], "click on a discovered switch flips it", failures)
	view.toggle_switch_at(switch_cell)
	_check(not view.toggle_switch_at(Vector2i(12, 62)), "plain track is not a switch", failures)
	view.discovery = preload("res://scripts/map_discovery.gd").new()
	view.following_train = false
	view.journey.reset()
	view.update_train()
	view.zoom = 1.0
	view.center_on_train()
	var fixed_camera: Vector2 = view.camera_world
	view.journey.distance_ticks = 10
	view.update_train()
	view._process(1.0)
	_check(view.camera_world == fixed_camera, "fixed camera stays put while the train is in view", failures)
	view.camera_world = Vector2(100, 10)
	view._keep_train_in_view()
	_check(view.camera_world.distance_to(_initial_route_point(CONSIST_HALF - (view._visual_position.x - 11.5)) + Vector2(0.5,0.5)) < 0.001, "fixed camera recentres on full consist midpoint", failures)
	view.journey.reset()
	view.update_train()


func _find_hidden_city(view, data) -> int:
	for index in data.cities.size():
		if not view.discovery.is_discovered(int(data.cities[index].x), int(data.cities[index].y)):
			return index
	return -1


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_vehicle_frames(view, failures: Array[String]) -> void:
	var renderer = view.train_renderer
	# Every original wagon type 1-25 has its own drawing (catalogue, owner
	# choice 2026-09-26): all of them must load and rotate rigidly.
	var kinds: Array = ConsistScript.TYPE_TO_KIND.values()
	_check(kinds.size() == 25 and ConsistScript.TYPE_TO_KIND.keys() == range(1, 26), "types 1-25 each map to one drawing", failures)
	# Overhead view (owner decision, 26 September): one rigid drawing per
	# vehicle, rotated continuously -- not one atlas frame per discrete
	# heading. Any rotation angle must keep the same unsheared scale, which is
	# what makes the screen gabarit heading-independent by construction.
	var angles := [0.0, PI / 6.0, PI / 3.0, PI / 2.0, 2.0 * PI / 3.0, PI, -PI / 4.0, 1.7]
	for kind in kinds:
		var frame: Dictionary = renderer.frame_for(kind)
		_check(not frame.is_empty(), "%s has a single overhead frame" % kind, failures)
		if frame.is_empty():
			continue
		_check(frame.texture != null and frame.texture.get_width() > 0 and frame.texture.get_height() > 0, "overhead atlas region is loaded", failures)
		var own_length: float = frame.front.distance_to(frame.rear)
		for angle in angles:
			var registration: Transform2D = renderer.registration(frame, Vector2(340, 210), angle, 0.5)
			_check(is_equal_approx(registration.x.length(), 0.5) and is_equal_approx(registration.y.length(), 0.5), "%s keeps one unsheared scale at any rotation" % kind, failures)
			_check(is_zero_approx(registration.x.dot(registration.y)), "%s rotation never shears the drawing" % kind, failures)
			var drawn_front: Vector2 = registration * frame.front
			var drawn_rear: Vector2 = registration * frame.rear
			_check(is_equal_approx(drawn_front.distance_to(drawn_rear), own_length * 0.5), "%s screen length is the same at every angle" % kind, failures)
	# Locomotive front/rear anchors span 495 texels = 1 authored cell.
	_check(absf(renderer.texels_per_cell - 495.0) < 0.1, "texel scale derives from the locomotive's own front/rear anchors", failures)
	# LENGTHS is pasted from tools/build_overhead_atlas.py: it must still match
	# the manifest the atlas was built with, or the drawn length and the rail
	# length would disagree.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(renderer.MANIFEST))
	for kind in kinds:
		var entry: Dictionary = manifest.vehicles.get(kind, {})
		_check(not entry.is_empty() and is_equal_approx(float(entry.length), ConsistScript.LENGTHS[kind]), "%s length matches the atlas manifest" % kind, failures)
		_check(not entry.is_empty() and ConsistScript.TYPE_TO_KIND[int(entry.type_id)] == kind, "%s is keyed by its own catalogue type" % kind, failures)
	_check(renderer.frame_for("unknown").is_empty(), "unsupported vehicle has no fabricated frame", failures)


func _test_vehicle_routes(view, failures: Array[String]) -> void:
	var renderer = view.train_renderer
	_check(renderer.poses(view,view.journey,view.consist,0.0).size() == 6, "original map supplies all six initial vehicle poses", failures)
	var journey = _wide_bend_journey()
	var consist = ConsistScript.new()
	var poses: Array[Dictionary] = renderer.poses(view,journey,consist,0.0)
	_check(poses.size() == 6, "synthetic bend supplies whole initial train", failures)
	# Owner constraint (tasks/lessons.md, "meme longueur a l'ecran"): every
	# vehicle's PROJECTED screen chord is the same at any heading, including
	# across this bend from a diagonal onto a cardinal segment -- the exact
	# case the anisotropic travel projection could otherwise distort.
	for index in poses.size():
		var pose: Dictionary = poses[index]
		var kind: String = pose.kind
		var chord: float = view._project(pose.front).distance_to(view._project(pose.rear))
		var target: float = ConsistScript.LENGTHS[kind] * view.WORLD_EAST.length()
		_check(absf(chord - target) < 0.05, "%s keeps its screen gabarit through the bend" % kind, failures)
		if index > 0:
			_check(pose.front.distance_to(poses[index - 1].rear) < 0.00001, "neighboring vehicle contacts join on route", failures)
	if poses.size() == 6:
		_check(poses[0].heading == 3 and poses[5].heading == 6, "locomotive is diagonal while tail remains east on bend", failures)
	var lagged: Array[Dictionary] = renderer.poses(view,journey,consist,0.25)
	_check(lagged.size() == 6 and lagged[0].front.distance_to(_wide_bend_point(0.25)) < 0.00001, "presentation lag follows route arc", failures)
	consist.vehicles.append("cannon")
	var extended: Array[Dictionary] = renderer.poses(view,journey,consist,0.0)
	_check(extended.size() == 7 and extended[-1].kind == "cannon", "buying a wagon adds its own rendered vehicle", failures)
	consist.vehicles[1] = "barracks"
	consist.vehicles[5] = "tender"
	var reordered: Array[Dictionary] = renderer.poses(view,journey,consist,0.0)
	_check(reordered.size() == 7 and reordered[1].kind == "barracks" and reordered[5].kind == "tender", "reordering changes rendered vehicle order", failures)
	_check(renderer.poses(view,journey,consist,300.0).is_empty(), "insufficient history omits poses without off-track extrapolation", failures)
	_test_wagon_table_composition(consist, failures)


# Owner requirement (tasks/todo.md, "Decision : train en vue de dessus"):
# rendered composition is a pure function of the wagon-rules table, not an
# independent list. Every original type 1-25 has its drawing; a type outside
# that range is left undrawn rather than substituted with an invented sprite.
func _test_wagon_table_composition(consist, failures: Array[String]) -> void:
	var wagons = TrainWagonsScript.new()
	consist.derive_from_wagons(wagons)
	var initial := ["locomotive", "tender", "general-quarters", "boudoir", "merchandise", "barracks"]
	_check(consist.vehicles == initial, "initial wagon table draws the six initial vehicles in order", failures)
	wagons.wagons.append([21, 0, 0, 0]) # TENDER: initial type, bought again.
	wagons.wagons.append([9, 0, 0, 0]) # HARPOON: one of the 19 types drawn by the catalogue.
	wagons.wagons.append([26, 0, 0, 0]) # outside wagon_names 1-25: no drawing, no invented sprite.
	consist.derive_from_wagons(wagons)
	_check(consist.vehicles == initial + ["tender", "harpoon"], "buying any original wagon type adds its own drawn vehicle; an unknown type adds nothing", failures)


func _bend_journey():
	var bytes := PackedByteArray()
	bytes.resize(RailNetworkScript.WIDTH * RailNetworkScript.HEIGHT)
	for x in range(2,12):
		bytes[x * RailNetworkScript.HEIGHT + 62] = 2
	bytes[12 * RailNetworkScript.HEIGHT + 62] = 6
	bytes[13 * RailNetworkScript.HEIGHT + 63] = 5
	var network = RailNetworkScript.new()
	network.load_bytes(bytes)
	var journey = JourneyScript.new()
	journey.network = network
	journey.position = Vector2i(13,63)
	journey.heading = 3
	journey.phase = 2
	return journey


# Same two-segment shape as _bend_journey (diagonal then straight, corner at
# the origin used below), with the straight run extended to the map's west
# edge. The overhead LENGTHS sum to more world distance than the oblique
# LENGTHS did (near-uniform vehicle spans, see train_consist.gd), and the
# chord-matching bisection in train_renderer.gd can consume up to ~2.2x a
# vehicle's nominal length on an unfavourable heading (its documented
# CHORD_BRACKET_HIGH): the original 10-cell run left too little route history
# for the full six-vehicle consist. This fixture exists only for the
# vehicle-route/chord tests; _test_bend_interpolation keeps the original
# corner position, which it relies on directly.
func _wide_bend_journey():
	var bytes := PackedByteArray()
	bytes.resize(RailNetworkScript.WIDTH * RailNetworkScript.HEIGHT)
	for x in range(0,24):
		bytes[x * RailNetworkScript.HEIGHT + 62] = 2
	bytes[24 * RailNetworkScript.HEIGHT + 62] = 6
	bytes[25 * RailNetworkScript.HEIGHT + 63] = 5
	var network = RailNetworkScript.new()
	network.load_bytes(bytes)
	var journey = JourneyScript.new()
	journey.network = network
	journey.position = Vector2i(25,63)
	journey.heading = 3
	journey.phase = 2
	return journey


func _wide_bend_point(distance: float) -> Vector2:
	# Same shape as _bend_point, corner moved to (24,62)/(25,63); see
	# _wide_bend_journey for why the straight run needed widening.
	var head := Vector2(25,63) + Vector2.ONE / 6.0
	var diagonal_length := sqrt(2.0) * (1.0 + 1.0 / 6.0)
	if distance <= diagonal_length:
		return head - Vector2.ONE * distance / sqrt(2.0)
	return Vector2(24.0 - (distance - diagonal_length),62.0)


func _test_bend_interpolation(view, failures: Array[String]) -> void:
	var journey = _bend_journey()
	journey.position = Vector2i(12,62)
	journey.heading = 6
	journey.phase = 0
	journey.distance_ticks = 22
	view.journey = journey
	view.session.paused = false
	view._snap_visual_position(journey.fractional_position())
	journey.advance(450)
	view.update_train()
	view._process(0.5)
	# Independent arc calculation across the entry/exit bend, using TIME ticks.
	var entry_length := 0.5 - 22.0 / 69.0
	var exit_length := sqrt(2.0) * ((23.0 + 21.0) / 69.0 - 0.5)
	var past_center := (entry_length + exit_length) * 0.5 - entry_length
	var expected := Vector2(12,62) + Vector2.ONE * past_center / sqrt(2.0)
	_check(view._visual_position.distance_to(expected) < 0.00001, "half-cycle visual interpolation follows bent rail instead of cutting across chord", failures)


func _test_occupied_track(view, failures: Array[String]) -> void:
	view.discovery = preload("res://scripts/map_discovery.gd").new()
	var marker: Vector2i = view.discovery.current_position
	_check(not view.discovery.is_discovered(9,64), "initial tail track is outside nose-only reveal", failures)
	view.update_train()
	var mask: Image = view._discovery_mask.get_image()
	# Actual TABLE-start route bends at (10,62) toward (9,63), then south.
	for cell in [Vector2i(12,62), Vector2i(11,62), Vector2i(10,62), Vector2i(9,63), Vector2i(9,64)]:
		_check(view.network.tile(cell) != 0, "fixture tail cell contains real track", failures)
		_check(view.discovery.is_discovered(cell.x,cell.y), "all occupied initial wagon track becomes discovered", failures)
		_check(mask.get_pixel(cell.x,cell.y).r > 0.9, "occupied wagon track also appears in shader mask", failures)
	_check(view.discovery.current_position == marker, "revealing occupied train leaves saved player marker unchanged", failures)
	_check(not view.discovery.is_discovered(0,0) and mask.get_pixel(0,0).r < 0.1, "remote map remains fogged", failures)
	view.center_on_train()
	_check(view.camera_world.distance_to(_initial_route_point(CONSIST_HALF) + Vector2(0.5,0.5)) < 0.00001, "initial camera centers full consist rather than locomotive nose", failures)
	view.consist.vehicles.append("boudoir")
	view.center_on_train()
	_check(view.camera_world.distance_to(_initial_route_point(CONSIST_HALF + ConsistScript.LENGTHS.boudoir * 0.5) + Vector2(0.5,0.5)) < 0.00001, "camera center adapts to added wagon length", failures)
	view.consist.vehicles.pop_back()
	view.center_on_train()


func _initial_route_point(distance: float) -> Vector2:
	# Independent fixture measured from original map cells: eastbound head at
	# (11.5,62), curve (10,62), diagonal to (9,63), then northbound vertical rail.
	if distance <= 1.5:
		return Vector2(11.5-distance,62)
	if distance <= 1.5 + sqrt(2.0):
		var diagonal := (distance-1.5)/sqrt(2.0)
		return Vector2(10-diagonal,62+diagonal)
	return Vector2(9,63 + distance-1.5-sqrt(2.0))
