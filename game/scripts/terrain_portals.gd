extends RefCounted

# MIT. Source dotted alignments and newly authored open arches.
# Source: underground-rendering.md; measured artwork underground-mouths.json.
const Visual = preload("res://scripts/underground_visual.gd")
const Rails = preload("res://scripts/rail_glyphs.gd")
const GAUGE := 20.0 # source: rail_art.gd TRACK_GAUGE, shared authored scale.
const DOTTED := Color("#657b87") # source: existing TravelWorld steel palette.
var frames: Dictionary = {}
var textures: Dictionary = {}


func load_art() -> void:
	var path := "res://assets/travel/terrain/underground-mouths.json"
	if not FileAccess.file_exists(path): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	path = "res://assets/travel/terrain/"+str(data.file)
	var master: Texture2D
	if ResourceLoader.exists(path):
		master = load(path) as Texture2D # Exported builds retain Godot's imported texture.
	else:
		# Raw source permits the authorized pre-import native comparison.
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image.is_empty(): return
		master = ImageTexture.create_from_image(image)
	for frame in data.frames:
		frames[int(frame.code)] = frame
		var texture := AtlasTexture.new()
		texture.atlas = master
		texture.region = _region(frame)
		textures[int(frame.code)] = texture


func handles_rail(code: int) -> bool:
	return Visual.is_underground(code) or textures.has(code)


func draw_tile(view, cell: Vector2i, code: int) -> bool:
	if Visual.is_underground(code):
		var center: Vector2 = view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5)
		for port in Rails.ports_for_code(code):
			_dotted(view,center,view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5+port))
		return true
	if not textures.has(code): return false
	var frame: Dictionary = frames[code]
	view.draw_set_transform_matrix(registration(view,cell,code))
	view.draw_texture_rect(textures[code],Rect2(Vector2.ZERO,_region(frame).size),false)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


func registration(view, cell: Vector2i, code: int) -> Transform2D:
	var frame: Dictionary = frames[code]
	var anchor := _point(frame.mouth_anchor)
	var endpoint := _point(frame.rail_endpoint)
	var direction := Visual.mouth_direction(code)
	var screen_axis: Vector2 = view._world_to_screen(Vector2(cell)+direction)-view._world_to_screen(Vector2(cell))
	var rotation := screen_axis.angle()-(endpoint-anchor).angle()
	var scale: float = GAUGE*view._effective_zoom()/float(frame.rail_gauge)
	var target: Vector2 = view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5+direction*0.5)
	var basis := Transform2D(Vector2.RIGHT.rotated(rotation)*scale,Vector2.DOWN.rotated(rotation)*scale,Vector2.ZERO)
	return Transform2D(basis.x,basis.y,target-basis.basis_xform(endpoint))


func _dotted(view, first: Vector2, last: Vector2) -> void:
	# Authored stipple spacing/width derives from shared gauge. The source manual
	# establishes dotted appearance, not a pixel-perfect ECS reproduction.
	var pitch: float = GAUGE*view._effective_zoom()
	var delta: Vector2 = last-first
	var direction := delta.normalized()
	var cursor := 0.0
	while cursor < delta.length():
		view.draw_line(first+direction*cursor,first+direction*minf(cursor+pitch*0.5,delta.length()),DOTTED,pitch*0.2)
		cursor += pitch


static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))


static func _region(frame: Dictionary) -> Rect2:
	return Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
