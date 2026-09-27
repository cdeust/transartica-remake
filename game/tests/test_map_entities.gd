extends SceneTree

const Entities = preload("res://scripts/map_entities.gd")
const Enemies = preload("res://scripts/enemy_trains.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var failures: Array[String] = []


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
	if failures.is_empty():
		print("PASS: map entities visibility, live slots, save removal and six city types")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
