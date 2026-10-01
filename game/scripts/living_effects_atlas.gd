extends RefCounted

# MIT. Measured authored regions; never historical effect pixels.
const PATH := "res://assets/effects/living-atlas.json"
var loaded := false
var texture: Texture2D
var regions := {}


func load_art() -> bool:
	if not FileAccess.file_exists(PATH): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or not parsed.get("frames") is Array: return false
	var source: String = "res://assets/effects/"+str(parsed.get("file",""))
	if not ResourceLoader.exists(source): return false
	var candidate = load(source) as Texture2D
	if candidate == null: return false
	var staged := {}
	for frame in parsed.frames:
		if not frame is Dictionary or not frame.get("name") is String or not frame.get("region") is Array: return false
		if frame.region.size() != 4 or staged.has(frame.name): return false
		for value in frame.region:
			if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value): return false
		var rect := Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		if not rect.has_area() or not Rect2(Vector2.ZERO,candidate.get_size()).encloses(rect): return false
		staged[frame.name] = rect
	for group in ["flame","smoke","muzzle","rocket"]:
		for index in 4:
			if not staged.has("%s-%d" % [group,index]): return false
	for name in ["debris-0","ember-0","projectile-0","shock-0","steam-0","snow-0","dust-0","spark-0"]:
		if not staged.has(name): return false
	texture = candidate
	regions = staged
	loaded = true
	return true


func draw(canvas: CanvasItem, name: String, point: Vector2, extent: Vector2, color: Color, angle := 0.0) -> void:
	if texture == null or not regions.has(name):
		# Temporary authored glyph until the generated atlas is installed.
		canvas.draw_rect(Rect2(point-extent/2,extent),Color(color,color.a*0.25))
		return
	var source: Rect2 = regions[name]
	var factor := minf(extent.x/source.size.x,extent.y/source.size.y)
	var size := (source.size*factor).round()
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for corner in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
		points.append((point+((corner-Vector2.ONE/2)*size).rotated(angle)).round())
		uv.append((source.position+corner*source.size)/texture.get_size())
	canvas.draw_polygon(points,PackedColorArray([color]),uv,texture)
