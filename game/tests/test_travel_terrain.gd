extends SceneTree

# Tests presentation identity, signed-map resources and distinct authored town parts.
func _initialize() -> void:
	var terrain = preload("res://scripts/travel_terrain.gd").new()
	var failures: Array[String] = []
	if not terrain.load_art() or terrain.textures.size() != 79:
		failures.append("Authored scenery resource set must load completely")
	for resource in range(128,152):
		if terrain.resource_code(resource-256) != resource:
			failures.append("Signed scenery does not retain original resource number")
	var town_hashes: Array[String] = []
	for resource in range(71,77):
		var digest := FileAccess.get_sha256("res://assets/travel/terrain/%d.png" % resource)
		if digest.is_empty() or digest in town_hashes:
			failures.append("Each original town piece needs distinct authored art")
		town_hashes.append(digest)
	for code in [2,3,18,-18,34,35,-115]:
		if terrain.textures.has(terrain.resource_code(code)):
			failures.append("Scenery cannot replace traversal or concealed-site glyphs")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: authored scenery coverage, signed resources, six distinct town parts and rail separation")
	quit(0 if failures.is_empty() else 1)
