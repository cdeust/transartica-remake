extends RefCounted
# MIT. Visible source obstacles; no changes to rail traversal or map bytes.
# source: tasks/evidence/obstacles.md, YODA67→63/69→64 and lake repair writes.
const MANIFEST := "res://assets/travel/terrain/obstacles.json"
const MASTER := "res://assets/travel/terrain/landmarks-master.png"
# source: inspected isolated last-row artwork on the1448×1086 authored master.
const CREVASSE := Rect2i(377,720,345,315)
const LAKE := Rect2i(730,720,348,315)
const RAIL_GAUGE := 20.0 # source: rail_art.gd TRACK_GAUGE, unchanged presentation gauge.
var fallback: Dictionary = {}
var atlas: Texture2D
var frames: Dictionary = {}


func load_art() -> void:
	var master := load(MASTER) as Texture2D
	if master != null:
		fallback = {"crevasse":ImageTexture.create_from_image(master.get_image().get_region(CREVASSE)),
			"lake":ImageTexture.create_from_image(master.get_image().get_region(LAKE))}
	frames.clear()
	if not FileAccess.file_exists(MANIFEST):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary or not manifest.get("frames") is Array:
		return
	atlas = load("res://assets/travel/terrain/" + str(manifest.get("file",""))) as Texture2D
	if atlas == null:
		return
	for frame in manifest.frames:
		if not _valid_frame(frame):
			frames.clear()
			return
		for code in frame.codes:
			if frames.has(int(code)):
				frames.clear()
				return
			frames[int(code)] = frame


func _valid_frame(frame: Variant) -> bool:
	if not frame is Dictionary or not frame.get("codes") is Array or not frame.get("region") is Array:
		return false
	if frame.codes.is_empty() or frame.region.size() != 4 or not frame.get("rail_ports") is Array or frame.rail_ports.size() != 2:
		return false
	for value in frame.region:
		if not _finite_number(value) or float(value) != floorf(float(value)):
			return false
	var region := Rect2i(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
	if not region.has_area() or not Rect2i(Vector2i.ZERO,atlas.get_size()).encloses(region):
		return false
	for port in frame.rail_ports:
		if not port is Array or port.size() != 2 or not _finite_number(port[0]) or not _finite_number(port[1]):
			return false
		if not Rect2(Vector2.ZERO,Vector2(region.size)).has_point(_point(port)):
			return false
	var gauge: Variant = frame.get("rail_gauge")
	if not _finite_number(gauge) or float(gauge) <= 0 or _point(frame.rail_ports[0]).is_equal_approx(_point(frame.rail_ports[1])):
		return false
	for code in frame.codes:
		if not _finite_number(code) or float(code) != floorf(float(code)) or not kind_axis(int(code)).has("kind"):
			return false
	return true


static func kind_axis(code: int) -> Dictionary:
	if code > 127:
		code -= 256
	match code:
		63,67,66,68,70: return {"kind":"crevasse","axis":Vector2.RIGHT,"repaired":code==63}
		64,69: return {"kind":"crevasse","axis":Vector2.DOWN,"repaired":code==64}
		-116,-121: return {"kind":"lake","axis":Vector2.RIGHT,"repaired":code==-121}
		114,-117: return {"kind":"lake","axis":Vector2.DOWN,"repaired":code==-117}
	return {}


static func target_ports(view, cell: Vector2i, code: int) -> Array[Vector2]:
	var state := kind_axis(code)
	if state.is_empty():
		return []
	var center := Vector2(cell) + Vector2.ONE / 2.0
	return [view._world_to_screen(center-state.axis/2.0),view._world_to_screen(center+state.axis/2.0)]


func registration(view, cell: Vector2i, code: int) -> Transform2D:
	var frame: Dictionary = frames[code]
	var source_start := _point(frame.rail_ports[0])
	var source_end := _point(frame.rail_ports[1])
	var source_axis := (source_end-source_start).normalized()
	var targets := target_ports(view,cell,code)
	var axis := (targets[1]-targets[0]).normalized()
	var along := targets[0].distance_to(targets[1])/source_start.distance_to(source_end)
	var across: float = RAIL_GAUGE*view._effective_zoom()/float(frame.rail_gauge)
	var source_basis := Transform2D(source_axis,source_axis.orthogonal(),source_start)
	return Transform2D(axis*along,axis.orthogonal()*across,targets[0])*source_basis.affine_inverse()


func handles_rail(code: int) -> bool:
	return frames.has(code) # Atlas includes measured rail ends, broken or repaired.


func draw_tile(view, cell: Vector2i, code: int) -> bool:
	var state := kind_axis(code)
	if state.is_empty():
		return false
	if frames.has(code):
		var frame: Dictionary = frames[code]
		var region := Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		view.draw_set_transform_matrix(registration(view,cell,code))
		view.draw_texture_rect_region(atlas,Rect2(Vector2.ZERO,region.size),region)
		view.draw_set_transform_matrix(Transform2D.IDENTITY)
		return true
	var texture: Texture2D = fallback.get(state.kind)
	if texture == null:
		return false
	# Isolated terrain only: fallback never paints rails across an unrepaired gap.
	var origin: Vector2 = view._world_to_screen(Vector2(cell))
	var end: Vector2 = view._world_to_screen(Vector2(cell)+Vector2.ONE)
	var extent := end-origin
	view.draw_set_transform((origin+end)/2.0, state.axis.angle())
	view.draw_texture_rect(texture,Rect2(-extent/2.0,extent),false)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


static func _point(value: Array) -> Vector2:
	return Vector2(value[0],value[1])


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))
