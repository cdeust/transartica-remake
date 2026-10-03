extends SceneTree
# MIT. Renderer-only regression: source obstacle axes and map bytes stay unchanged.
# source: tasks/evidence/obstacles.md and inspected CARTE resource atlas.
const Obstacles = preload("res://scripts/terrain_obstacles.gd")
const Terrain = preload("res://scripts/travel_terrain.gd")
var failures: Array[String] = []

class RecordingView:
	extends RefCounted
	var draws: Array = []
	var transform := Transform2D.IDENTITY
	var world_data
	func _world_to_screen(point: Vector2) -> Vector2:
		return point * 16.0 # source: original CARTE16px test lattice.
	func _effective_zoom() -> float:
		return 1.0
	func draw_set_transform(position: Vector2, rotation: float) -> void:
		transform = Transform2D(rotation,position)
	func draw_set_transform_matrix(value: Transform2D) -> void:
		transform = value
	func draw_texture_rect(texture: Texture2D, destination: Rect2, tiled: bool) -> void:
		draws.append({"texture":texture,"destination":destination,"tiled":tiled,"transform":transform})
	func draw_texture_rect_region(texture: Texture2D, destination: Rect2, source: Rect2, tint := Color.WHITE) -> void:
		draws.append({"texture":texture,"destination":destination,"source":source,"tint":tint,"transform":transform})


func _initialize() -> void:
	var terrain = Terrain.new()
	_check(terrain.load_art(),"existing modern terrain loads")
	var view := RecordingView.new()
	view.world_data = preload("res://scripts/world_data.gd").new()
	_check(view.world_data.load_from_project(ProjectSettings.globalize_path("res://")),"source world data loads")
	var before: PackedByteArray = view.world_data.map_bytes.duplicate()
	_check_visible_obstacles(terrain,view)
	_check_landmarks(terrain,view)
	_check_registration(view)
	_check_authored_frames(terrain.obstacles,view)
	_check(view.world_data.map_bytes == before,"presentation leaves source map unchanged")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: visible source crevasses/lakes, real relief identities, measured atlas ports and unchanged map")
	quit(0 if failures.is_empty() else 1)


func _check_visible_obstacles(terrain, view: RecordingView) -> void:
	for code in [67,69,63,64,66,68,70,-116,114,-121,-117]:
		view.draws.clear()
		_check(terrain.draw_tile(view,Vector2i(2,3),code),"source obstacle%d is drawn despite missing ordinary texture" % code)
		_check(view.draws.size() == 1,"one visible obstacle per source cell%d" % code)
		_check(view.transform == Transform2D.IDENTITY,"obstacle resets drawing transform")
	for code in [0,1,150,151,-115]:
		view.draws.clear()
		_check(not terrain.draw_tile(view,Vector2i.ZERO,code),"blank/concealed code%d remains blank" % code)
		_check(view.draws.is_empty(),"no invented landmark for code%d" % code)


func _check_landmarks(terrain, view: RecordingView) -> void:
	for code in [77,81,82,83,84,85,148,80,147]:
		view.draws.clear()
		_check(terrain.draw_tile(view,Vector2i.ZERO,code),"source relief%d uses modern landmark" % code)
		var index := 11 if code in [80,147] else 8
		_check(view.draws[0].source == terrain.landmarks.REGIONS[index],"relief/tunnel%d is not a guessed building" % code)
	for code in range(116,133):
		_check(terrain.resource_code(code-256) == code,"forest resource identity remains unchanged")


func _check_registration(view: RecordingView) -> void:
	var obstacles = Obstacles.new()
	# source: deliberately offset/asymmetric fixture proves measured anchors, not frame center.
	var frame := {"rail_ports":[[7,13],[39,13]],"rail_gauge":8}
	for code in [67,69,63,64,-116,114,-121,-117]:
		obstacles.frames[code] = frame
		var cell := Vector2i(2,3)
		var transform: Transform2D = obstacles.registration(view,cell,code)
		var targets := Obstacles.target_ports(view,cell,code)
		_check((transform*Vector2(7,13)).is_equal_approx(targets[0]),"first measured port lands on source boundary%d" % code)
		_check((transform*Vector2(39,13)).is_equal_approx(targets[1]),"second measured port lands on source boundary%d" % code)
		_check(is_equal_approx((transform*Vector2(7,21)).distance_to(transform*Vector2(7,13)),obstacles.RAIL_GAUGE),"rail gauge stays consistent%d" % code)
		_check(obstacles.handles_rail(code),"atlas rail ownership is explicit%d" % code)
	var horizontal := Obstacles.target_ports(view,Vector2i.ZERO,67)
	var vertical := Obstacles.target_ports(view,Vector2i.ZERO,69)
	_check(horizontal[0].y == horizontal[1].y,"67 crosses north-south crevasse on east-west rail")
	_check(vertical[0].x == vertical[1].x,"69 crosses east-west crevasse on north-south rail")


func _check_authored_frames(obstacles, view: RecordingView) -> void:
	_check(obstacles.frames.size() == 8,"all six authored states load, including rotated NS lake states")
	for code in [67,63,69,64,-116,114,-121,-117]:
		_check(obstacles.frames.has(code),"authored rail-owning obstacle%d loads" % code)
		if not obstacles.frames.has(code):
			continue
		var frame: Dictionary = obstacles.frames[code]
		var transform: Transform2D = obstacles.registration(view,Vector2i(2,3),code)
		var targets := Obstacles.target_ports(view,Vector2i(2,3),code)
		for end in range(2):
			_check((transform*Obstacles._point(frame.rail_ports[end])).is_equal_approx(targets[end]),"actual atlas port%d connects code%d" % [end,code])
		_check(obstacles._valid_frame(frame),"actual measured frame is in atlas bounds")
	var valid: Dictionary = obstacles.frames[67].duplicate(true)
	for change in [{"region":[0,0,99999,480]},{"rail_ports":[[0,0],[0,0]]},{"rail_gauge":0},{"codes":[150]},{"rail_ports":[[-1,0],[40,0]]}]:
		var invalid := valid.duplicate(true)
		invalid.merge(change,true)
		_check(not obstacles._valid_frame(invalid),"invalid registration is rejected: %s" % str(change))


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
