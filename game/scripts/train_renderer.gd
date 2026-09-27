extends RefCounted

const Rails = preload("res://scripts/rail_network.gd")
const Consist = preload("res://scripts/train_consist.gd")
const MANIFEST := "res://assets/travel/vehicles-overhead.json"

# Overhead view (owner decision, 26 September 2026, tasks/todo.md "Decision :
# train en vue de dessus"): one rigid top-down drawing per vehicle, at a
# single fixed pixel scale. Every heading is the SAME raster rotated by the
# projected travel angle, so the drawn gabarit (length and width in screen
# pixels) is mathematically identical at every heading and every point along
# a curve: rotating a rigid image can never stretch, shear or mirror it. This
# replaces the discrete 8-heading oblique atlas and its MIRRORS table, which
# could not guarantee that invariant because each heading was an independent
# hand-drawn perspective (tasks/lessons.md, "les wagons sont toujours plus
# gros quand ils changent de direction").
var _frame := {}
# Atlas texels per map cell, from the locomotive's front/rear anchors and its
# authored length (Consist.LENGTHS.locomotive == 1.0 cell east-equivalent).
var texels_per_cell := 0.0

# Chord-matching bisection (see _bisected_rear below): fixed iteration count,
# not a tolerance loop. 24 halvings of a bracket at most 2.2x a vehicle's
# nominal world length shrink the remaining uncertainty in world distance to
# well under 1e-6 cell, far below one screen pixel at any reachable zoom;
# termination therefore does not depend on how the loop body behaves.
const CHORD_ITERATIONS := 24
const CHORD_BRACKET_LOW := 0.35
const CHORD_BRACKET_HIGH := 2.2


func load_assets() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary or not parsed.has("vehicles"):
		return false
	var texture := load("res://assets/travel/" + String(parsed.file)) as Texture2D
	if texture == null:
		return false
	var pixels := texture.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	for kind in parsed.vehicles:
		var entry: Dictionary = parsed.vehicles[kind]
		var rect: Array = entry.region
		var region := Rect2(rect[0], rect[1], rect[2], rect[3])
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		atlas.filter_clip = true
		_frame[kind] = {
			"texture": atlas,
			"bounds": Rect2(pixels.get_region(Rect2i(region)).get_used_rect()),
			"front": Vector2(entry.front[0], entry.front[1]),
			"rear": Vector2(entry.rear[0], entry.rear[1]),
		}
	var reference: Dictionary = _frame.get("locomotive", {})
	if reference.is_empty():
		return false
	texels_per_cell = reference.front.distance_to(reference.rear) / Consist.LENGTHS.locomotive
	return true


# Every heading shares the one drawing; "unknown" kinds have no fabricated frame.
func frame_for(kind: String) -> Dictionary:
	if not _frame.has(kind):
		return {}
	return _frame[kind]


# Rigid placement: the sprite's own front/rear anchor midpoint sits on the
# screen midpoint of the true rail-contact points, rotated so the sprite's
# front->rear axis matches the screen-projected travel direction. scale is
# the single texel-to-pixel factor shared by every vehicle and heading; no
# stretch, shear or per-heading mirror is ever applied.
func registration(frame: Dictionary, center: Vector2, rotation: float, scale: float) -> Transform2D:
	# Transform2D(rotation, position) is Godot's 2-argument constructor; it does
	# NOT take a scale. Build the rotated+scaled basis explicitly so x/y stay
	# orthogonal unit-scale*scale vectors at every angle (the invariant the
	# overhead view depends on), then place it by hand via basis_xform.
	var basis_x := Vector2(cos(rotation), sin(rotation)) * scale
	var basis_y := Vector2(-sin(rotation), cos(rotation)) * scale
	var basis := Transform2D(basis_x, basis_y, Vector2.ZERO)
	var anchor: Vector2 = (frame.front + frame.rear) * 0.5
	return Transform2D(basis.x, basis.y, center - basis.basis_xform(anchor))


# Screen pixels per atlas texel at the view's current zoom.
func texel_scale(view) -> float:
	var cell: Vector2 = view._world_to_screen(Vector2(1.0, 0.0)) - view._world_to_screen(Vector2.ZERO)
	return cell.length() / texels_per_cell


# The travel projection (view.WORLD_EAST / WORLD_SOUTH) is anisotropic: a
# world-length segment projects to ~206px/cell east-west, ~141px/cell on the
# SE/NW diagonal and ~255px/cell on the NE/SW diagonal (verified from the
# authored constants). Consist.LENGTHS is calibrated in "east-equivalent"
# cells (tasks/todo.md, train_consist.gd). If poses() simply added
# Consist.LENGTHS[kind] of world arc per vehicle regardless of heading, the
# same LENGTHS value would project to a visibly different screen chord on a
# diagonal than on a cardinal heading -- exactly the "gap/overlap on turns"
# defect already rejected once (tasks/checkpoint-codex-2026-09-26.md). This
# bisects the world arc consumed by one vehicle so its PROJECTED chord (the
# quantity the owner's constraint is actually about: same gabarit on screen)
# is constant, while its front and rear anchors remain exact rail samples
# (journey.sample_behind), preserving "chaque vehicule suit le trajet
# reellement parcouru".
func _bisected_rear(view, journey, front_distance: float, front_screen: Vector2, kind: String) -> Dictionary:
	var nominal: float = Consist.LENGTHS[kind]
	var target: float = nominal * view.WORLD_EAST.length()
	var low := front_distance + nominal * CHORD_BRACKET_LOW
	var high := front_distance + nominal * CHORD_BRACKET_HIGH
	var last_ok := {}
	var last_distance := front_distance
	# invariant: after each iteration, [low, high] still brackets the distance
	# whose projected chord equals target, given chord(distance) monotonic
	# non-decreasing over this range (true for rail turns, which are bounded
	# 45-degree steps, never a reversal within one vehicle's length).
	for _i in CHORD_ITERATIONS:
		var mid := (low + high) * 0.5
		var sample: Dictionary = journey.sample_behind(mid)
		if not sample.ok:
			high = mid
			continue
		last_ok = sample
		last_distance = mid
		var chord := front_screen.distance_to(view._project(sample.position))
		if chord < target:
			low = mid
		else:
			high = mid
	if last_ok.is_empty():
		return {"ok": false}
	# Missing history also shrinks the bracket: it does not prove that a full
	# vehicle fits. Source: PR #3 short-history regression (0.6 of 1 cell),
	# tasks/validation/pr3-review-20260927.md; retain Godot float comparison.
	if not is_equal_approx(front_screen.distance_to(view._project(last_ok.position)), target):
		return {"ok": false}
	return {"ok": true, "distance": last_distance, "position": last_ok.position}


func poses(view, journey, consist, lag: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var distance := maxf(lag, 0.0)
	for kind in consist.vehicles:
		var front: Dictionary = journey.sample_behind(distance)
		if not front.ok:
			break
		var front_screen: Vector2 = view._project(front.position)
		var rear_search := _bisected_rear(view, journey, distance, front_screen, kind)
		if not rear_search.ok:
			break
		var rear_position: Vector2 = rear_search.position
		var middle: Dictionary = journey.sample_behind((distance + rear_search.distance) * 0.5)
		var heading := _heading_for(front.position - rear_position, middle.heading if middle.ok else front.heading)
		result.append({"kind": kind, "front": front.position, "rear": rear_position, "center": (front.position + rear_position) * 0.5, "heading": heading})
		distance = rear_search.distance
	return result


func _heading_for(delta: Vector2, fallback: int) -> int:
	if delta.is_zero_approx():
		return fallback
	var best := fallback
	var score := -INF
	for heading in Rails.DELTAS:
		if heading == 5:
			continue
		var alignment := delta.normalized().dot(Vector2(Rails.DELTAS[heading]).normalized())
		if alignment > score:
			score = alignment
			best = heading
	return best


func draw(view, journey, consist, lag: float) -> void:
	var vehicles := poses(view, journey, consist, lag)
	var scale := texel_scale(view)
	vehicles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return view._project(a.center).y < view._project(b.center).y)
	for vehicle in vehicles:
		var frame := frame_for(vehicle.kind)
		if frame.is_empty():
			continue
		var front: Vector2 = view._world_to_screen(vehicle.front + Vector2(0.5, 0.5))
		var rear: Vector2 = view._world_to_screen(vehicle.rear + Vector2(0.5, 0.5))
		var rotation := (front - rear).angle() - PI * 0.5 if not (front - rear).is_zero_approx() else 0.0
		view.draw_set_transform_matrix(registration(frame, (front + rear) * 0.5, rotation, scale))
		view.draw_texture(frame.texture, Vector2.ZERO)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)


func screen_bounds(view, journey, consist, lag: float) -> Rect2:
	var result := Rect2()
	var initialized := false
	var scale := texel_scale(view)
	for vehicle in poses(view, journey, consist, lag):
		var frame := frame_for(vehicle.kind)
		if frame.is_empty():
			continue
		var front: Vector2 = view._world_to_screen(vehicle.front + Vector2(0.5, 0.5))
		var rear: Vector2 = view._world_to_screen(vehicle.rear + Vector2(0.5, 0.5))
		var rotation := (front - rear).angle() - PI * 0.5 if not (front - rear).is_zero_approx() else 0.0
		var transform := registration(frame, (front + rear) * 0.5, rotation, scale)
		var rect: Rect2 = frame.bounds
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var screen: Vector2 = transform * point
			result = result.expand(screen) if initialized else Rect2(screen, Vector2.ZERO)
			initialized = true
	return result
