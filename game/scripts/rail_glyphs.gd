extends RefCounted
class_name RailGlyphs

const INK := Color("#173641") # source: tasks/evidence/chart-design.md; authored rail ink.
const RAIL_HIGHLIGHT := Color("#738c88") # source: authored restrained ice-metal highlight.
const UNKNOWN := Color("#899792") # source: authored marker for codes without a glyph mapping.
const CITY_CODE_MIN := 71 # source: tasks/evidence/transarctica-commerce-findings.md, city tile codes.
const CITY_CODE_MAX := 76 # source: tasks/evidence/transarctica-commerce-findings.md, city tile codes.


static func draw_tile(canvas: CanvasItem, code: int, origin: Vector2, tile_size: float) -> void:
	if code == 0 or _is_city_code(code):
		return
	var center := origin + Vector2.ONE * tile_size * 0.5
	var ports := ports_for_code(code)
	if ports.is_empty():
		_draw_unknown(canvas, center)
		return
	for port in ports:
		_draw_port(canvas, center, center + port * tile_size)
	if ports.size() > 2:
		canvas.draw_circle(center, minf(1.2, tile_size * 0.12), INK)


static func ports_for_code(code: int) -> Array[Vector2]:
	match code:
		2: return [Vector2(-0.5, 0), Vector2(0.5, 0)]
		3: return [Vector2(0, -0.5), Vector2(0, 0.5)]
		4: return [Vector2(0.5, -0.5), Vector2(-0.5, 0.5)]
		5: return [Vector2(-0.5, -0.5), Vector2(0.5, 0.5)]
		6: return [Vector2(-0.5, 0), Vector2(0.5, 0.5)]
		7: return [Vector2(0.5, 0), Vector2(-0.5, 0.5)]
		8: return [Vector2(0.5, 0), Vector2(-0.5, -0.5)]
		9: return [Vector2(-0.5, 0), Vector2(0.5, -0.5)]
		10: return [Vector2(0, 0.5), Vector2(-0.5, -0.5)]
		11: return [Vector2(0, 0.5), Vector2(0.5, -0.5)]
		12: return [Vector2(0, -0.5), Vector2(-0.5, 0.5)]
		13: return [Vector2(0, -0.5), Vector2(0.5, 0.5)]
		# 15/16: four-way per full rail-set neighbours and the TIME 0x0486 axis rule.
		14, 15, 16: return [Vector2(0, -0.5), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(-0.5, 0)]
		17, 49: return [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]
		18, 19: return [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, -0.5)]
		20, 21: return [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.5, -0.5)]
		22, 23: return [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, 0.5)]
		24, 25: return [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.5, 0.5)]
		26, 27: return [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(0.5, 0.5)]
		28, 29: return [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, 0.5)]
		30, 31: return [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(0.5, -0.5)]
		32, 33: return [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, -0.5)]
		# Second curve set: same TIME 0x14c9 case bodies as 6..13 (tasks/evidence/rail-network.md).
		42, 51: return ports_for_code(6)
		43, 57: return ports_for_code(7)
		45: return ports_for_code(8)
		44: return ports_for_code(9)
		47: return ports_for_code(10)
		46: return ports_for_code(11)
		55: return ports_for_code(12)
		48: return ports_for_code(13)
		# Straights of the 38-58 set, from full rail-set neighbours (tasks/evidence/rail-glyphs.md).
		38, 52, 53: return ports_for_code(3)
		39, 50, 54, 56, 58: return ports_for_code(2)
		40: return ports_for_code(5)
		41: return ports_for_code(4)
		_: return []


static func _draw_port(canvas: CanvasItem, center: Vector2, endpoint: Vector2) -> void:
	var track := PackedVector2Array([endpoint, center])
	canvas.draw_polyline(track, INK, 2.0, true)
	canvas.draw_polyline(track, RAIL_HIGHLIGHT, 0.8, true)


static func _draw_unknown(canvas: CanvasItem, center: Vector2) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -1.4), center + Vector2(1.4, 0),
		center + Vector2(0, 1.4), center + Vector2(-1.4, 0), center + Vector2(0, -1.4),
	])
	canvas.draw_polyline(diamond, UNKNOWN, 1.0, true)


static func _is_city_code(code: int) -> bool:
	return code >= CITY_CODE_MIN and code <= CITY_CODE_MAX
