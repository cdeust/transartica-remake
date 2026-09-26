extends RefCounted
class_name MapDiscovery

const WorldDataScript = preload("res://scripts/world_data.gd")
const SNAPSHOT_VERSION := 1 # source: authored snapshot schema for preview persistence.
const DEFAULT_REVEAL_RADIUS := 1 # source: user request for surroundings; preview choice, not original rule.

var reveal_radius := DEFAULT_REVEAL_RADIUS
var current_position := Vector2i(12, 62) # TABLE normal-game initial coordinates, map-discovery evidence.
var _cells := PackedByteArray()


func _init(radius: int = DEFAULT_REVEAL_RADIUS) -> void:
	reveal_radius = maxi(0, radius)
	_cells.resize(WorldDataScript.MAP_WIDTH * WorldDataScript.MAP_HEIGHT)
	_cells.fill(0)
	_reveal_around(current_position)


func visit_cell(position: Vector2i) -> bool:
	if not _is_valid(position):
		return false
	current_position = position
	_reveal_around(position)
	return true


# The owner's discovery modernization applies to the occupied train, not only
# its locomotive. Revealing a wagon must not move the saved player location.
func observe_cell(position: Vector2i) -> bool:
	if not _is_valid(position):
		return false
	var changed := false
	for x in range(position.x - reveal_radius, position.x + reveal_radius + 1):
		for y in range(position.y - reveal_radius, position.y + reveal_radius + 1):
			if _is_valid(Vector2i(x, y)) and not is_discovered(x, y):
				changed = true
	_reveal_around(position)
	return changed


func is_discovered(x: int, y: int) -> bool:
	if x < 0 or x >= WorldDataScript.MAP_WIDTH or y < 0 or y >= WorldDataScript.MAP_HEIGHT:
		return false
	return _cells[_index(x, y)] != 0


func discovered_bounds() -> Rect2i:
	var minimum := Vector2i(WorldDataScript.MAP_WIDTH, WorldDataScript.MAP_HEIGHT)
	var maximum := Vector2i(-1, -1)
	for x in WorldDataScript.MAP_WIDTH:
		for y in WorldDataScript.MAP_HEIGHT:
			if not is_discovered(x, y):
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < 0:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func snapshot() -> Dictionary:
	var cells: Array[Array] = []
	for x in WorldDataScript.MAP_WIDTH:
		for y in WorldDataScript.MAP_HEIGHT:
			if is_discovered(x, y):
				cells.append([x, y])
	return {
		"version": SNAPSHOT_VERSION,
		"current_position": [current_position.x, current_position.y],
		"discovered_cells": cells,
	}


func restore(state: Variant) -> bool:
	if not state is Dictionary or not _is_integer_number(state.get("version")) or int(state.version) != SNAPSHOT_VERSION:
		return false
	var next_position: Variant = _parse_position(state.get("current_position"))
	var raw_cells: Variant = state.get("discovered_cells")
	if next_position == null or not raw_cells is Array:
		return false
	var next_cells := PackedByteArray()
	next_cells.resize(WorldDataScript.MAP_WIDTH * WorldDataScript.MAP_HEIGHT)
	next_cells.fill(0)
	for raw_position in raw_cells:
		var position: Variant = _parse_position(raw_position)
		if position == null:
			return false
		next_cells[_index(position.x, position.y)] = 1
	_cells = next_cells
	current_position = next_position
	_reveal_around(current_position)
	return true


func _parse_position(value) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	if not _is_integer_number(value[0]) or not _is_integer_number(value[1]):
		return null
	var position := Vector2i(value[0], value[1])
	return position if _is_valid(position) else null


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floorf(value)


func _reveal_around(position: Vector2i) -> void:
	for x in range(position.x - reveal_radius, position.x + reveal_radius + 1):
		for y in range(position.y - reveal_radius, position.y + reveal_radius + 1):
			if _is_valid(Vector2i(x, y)):
				_cells[_index(x, y)] = 1


func _is_valid(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < WorldDataScript.MAP_WIDTH \
		and position.y >= 0 and position.y < WorldDataScript.MAP_HEIGHT


func _index(x: int, y: int) -> int:
	return x * WorldDataScript.MAP_HEIGHT + y
