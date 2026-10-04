extends SceneTree

# MIT. Prove which corrected base shore PNGs are not the live obstacle art.
# source: obstacles.json code ownership and TravelTerrain's atlas-first dispatch.
const Terrain = preload("res://scripts/travel_terrain.gd")
const View = preload("res://tests/test_terrain_obstacles.gd").RecordingView
var failures: Array[String] = []


func _initialize() -> void:
	var terrain = Terrain.new()
	check(terrain.load_art(), "authored terrain loads")
	var view = View.new()
	# source: CARTE raw/signed resource conversion in world-terrain.md.
	for code in [114, -121, -117, -116]:
		var resource: int = terrain.resource_code(code)
		terrain.textures.erase(resource)
		view.draws.clear()
		check(terrain.draw_tile(view, Vector2i(2,3), code), "atlas draws without base shore PNG%d" % resource)
		check(view.draws.size() == 1, "one atlas rendering for resource%d" % resource)
		if view.draws.size() == 1:
			check(view.draws[0].texture == terrain.obstacles.atlas, "live rendering uses obstacle atlas for resource%d" % resource)
		check(terrain.obstacles.handles_rail(code), "atlas owns embedded rail, preventing generic overlay")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: live114/135/139/140 use obstacle atlas despite absent base PNGs")
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
