extends RefCounted

# Source: tasks/screen-length-contract.md. Existing authored map projection.
const EAST := Vector2(180.0, 100.0)
const SOUTH := Vector2(-180.0, 100.0)
var points := PackedVector2Array()


func _init(route: PackedVector2Array) -> void:
	points = route


# Source: cumulative Euclidean length of the projected, traversed polyline.
# Animation lag remains in world units; wagon spacing is in zoom-1 pixels.
func sample(distance_pixels: float, lag_world: float) -> Dictionary:
	var remaining := distance_pixels
	var lag := maxf(lag_world, 0.0)
	for index in range(points.size() - 1, 0, -1):
		var start := points[index - 1]
		var end := points[index]
		var world_length := start.distance_to(end)
		if world_length == 0.0:
			continue
		if lag >= world_length:
			lag -= world_length
			continue
		end = end.lerp(start, lag / world_length)
		lag = 0.0
		var delta := end - start
		var screen_length := (EAST * delta.x + SOUTH * delta.y).length()
		if remaining <= screen_length:
			return {"ok": true, "position": end.lerp(start, remaining / screen_length)}
		remaining -= screen_length
	return {"ok": false, "reason": "insufficient route history"}
