extends SceneTree

const Entities = preload("res://scripts/map_entities.gd")
const Enemies = preload("res://scripts/enemy_trains.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var failures: Array[String] = []

# Capture the actual map symbol's transformed drawing, using the real hero art.
# Source: owner4Oct close-up report; fixed gabarit in complete-train-scale.md.
class SymbolCanvas:
	extends RefCounted
	var world_data = null
	var encounters
	var journey = {"position": Vector2i.ZERO}
	var wagons = null
	var train_renderer
	var zoom := 1.0
	var transform := Transform2D.IDENTITY
	var corners: Array[Vector2] = []

	func _world_to_screen(point: Vector2) -> Vector2:
		return preload("res://scripts/travel_world.gd").WORLD_EAST * point.x * zoom

	func draw_set_transform_matrix(value: Transform2D) -> void:
		transform = value

	func draw_texture(texture: Texture2D, origin: Vector2) -> void:
		_record(Rect2(origin, texture.get_size()))

	func draw_texture_rect(_texture: Texture2D, rect: Rect2, _tile: bool, _color: Color) -> void:
		_record(rect)

	func _record(rect: Rect2) -> void:
		corners.assign([transform * rect.position, transform * (rect.position + Vector2(rect.size.x, 0)), transform * rect.end, transform * (rect.position + Vector2(0, rect.size.y))])


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var wagons = Wagons.new()
	check(Entities.observation_radius(wagons) == 1, "Initial train radius is one")
	wagons.wagons.append([10, 0, 0, 0])
	check(Entities.observation_radius(wagons) == 2, "Observation wagon radius two")
	wagons.wagons.append([4, 2, 0, 0])
	check(Entities.observation_radius(wagons) == 4, "Type4 state2 outranks type10")
	wagons.wagons[-1][1] = 3
	check(Entities.observation_radius(wagons) == 2, "State3 does not contribute")
	wagons.reset()
	var enemies = Enemies.new()
	enemies.slots[0] = [1, -27, 63, 6, 0, 0, 20, 10]
	enemies.slots[1] = [-1, -26, 62, 4, 0, 0, 0, 19]
	var visible := Entities.visible_enemies(enemies, Vector2i(12, 62), wagons)
	check(visible.size() == 1 and visible[0].slot == 0, "Inclusive square includes diagonal, excludes distance2")
	check(visible[0].cell == Vector2i(13, 63) and visible[0].heading == 6, "Uses live coordinates and heading")
	check(Entities.visible_enemies(enemies, Vector2i(10, 62), wagons).is_empty(), "Enemy leaving vision disappears")
	wagons.wagons.append([10, 0, 0, 0])
	check(Entities.visible_enemies(enemies, Vector2i(12, 62), wagons).size() == 2, "Negative scripted state is active")
	var saved := enemies.snapshot()
	var restored = Enemies.new()
	check(restored.restore(saved), "Enemy snapshot restores")
	check(Entities.visible_enemies(restored, Vector2i(12, 62), wagons).size() == 2, "Restored live slots visible")
	restored.remove(0)
	var removed = Enemies.new()
	check(removed.restore(restored.snapshot()), "Removed snapshot restores")
	visible = Entities.visible_enemies(removed, Vector2i(12, 62), wagons)
	check(visible.size() == 1 and visible[0].slot == 1, "Removed enemy stays absent after save")
	var world = preload("res://scripts/world_data.gd").new()
	check(world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")), "Private world data loads")
	var kinds := {}
	var entities = Entities.new()
	entities.art.load_private(Entities.MAP_ART)
	for city in world.cities:
		kinds[int(city.kind)] = true
		var code: int = absi(world.map_code(int(city.x), int(city.y)))
		check(entities.art.textures.has(str(code)), "Source city tile available: %s" % city.name)
	check(kinds.size() == 6, "All six city kinds covered by real source tiles")
	_check_enemy_symbol(entities)
	if failures.is_empty():
		print("PASS: map entities visibility, live slots, save removal and six city types")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_enemy_symbol(entities) -> void:
	var renderer = preload("res://scripts/train_renderer.gd").new()
	check(renderer.load_assets(), "Actual locomotive artwork loads")
	var canvas := SymbolCanvas.new()
	canvas.train_renderer = renderer
	var enemies = Enemies.new()
	canvas.encounters = {"enemies": enemies}
	var frame: Dictionary = renderer.frame_for("locomotive")
	for heading in preload("res://scripts/rail_network.gd").DELTAS:
		if heading == 5:
			continue
		enemies.slots[0] = [1, -39, 0, heading, 0, 0, 0, 1]
		for zoom in [0.5, 1.0, 2.0]:
			canvas.zoom = zoom
			canvas.corners.clear()
			entities.draw(canvas)
			check(canvas.corners.size() == 4, "One visible enemy produces a symbol")
			if canvas.corners.size() != 4:
				continue
			var center: Vector2 = (canvas.corners[0] + canvas.corners[2]) * 0.5
			# Compare rendered pixels; rotated float transforms can leave subpixel noise.
			check(center.round() == canvas._world_to_screen(Vector2(1.5, 0.5)).round(), "Enemy symbol stays centered on its cell")
			var length: float = canvas.corners[0].distance_to(canvas.corners[3])
			var expected: float = preload("res://scripts/travel_world.gd").WORLD_EAST.length() * zoom * renderer.WAGON_CELL_RATIO
			check(is_equal_approx(length, expected), "Enemy symbol preserves one locomotive's length at every heading/zoom")
			var width: float = canvas.corners[0].distance_to(canvas.corners[1])
			check(is_equal_approx(width / length, frame.texture.get_width() / float(frame.texture.get_height())), "Hero crop proportions stay rigid")
