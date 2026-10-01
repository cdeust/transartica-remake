extends RefCounted
# MIT. Newly authored rendering of the original INCOMPLETE static plan.
# Private semantic vectors: tools/export_overview_geometry.py, audit evidence.
const FIELD := Color("#b1c4c9") # authored terrain snow palette.
const INK := Color("#173641") # authored rail_glyphs chart ink.
const BLUE := Color("#426e82") # authored terrain water palette, chart blue ink.
const PATH := "res://private-data/overview-geometry.json"
var frame: Texture2D
var material: Texture2D
var geometry: Dictionary = {}

func load_art() -> void:
	frame=load("res://assets/interface/world-chart-frame.png") as Texture2D
	material=load("res://assets/travel/terrain/ice-master.png") as Texture2D
	var path:=PATH if FileAccess.file_exists(PATH) else "res://../reference-private/overview-geometry.json"
	load_geometry(path)

func load_geometry(path:String)->bool:
	geometry.clear()
	if not FileAccess.file_exists(path):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version")!=1 or parsed.get("width")!=320 or parsed.get("height")!=149:return false
	for key in ["routes","compartments","towns","dots","symbols","sites"]:
		if not parsed.get(key) is Array:return false
		for item in parsed[key]:
			if not item is Array or item.size()!=(2 if key=="dots" else 4):return false
			for value in item:
				if not (value is int or value is float) or not is_finite(value) or value!=floor(value):return false
	geometry=parsed
	return true

func available()->bool:return not geometry.is_empty()

func draw(canvas:CanvasItem)->void:
	canvas.draw_rect(Rect2(0,0,320,149),FIELD)
	if material!=null:canvas.draw_texture_rect(material,Rect2(0,0,320,149),false,Color(FIELD,0.22))
	for line in geometry.compartments:
		canvas.draw_line(Vector2(line[0],line[1]),Vector2(line[2],line[3]),Color(INK,0.16),0.5)
	for line in geometry.routes:
		var a:=Vector2(line[0],line[1])
		var b:=Vector2(line[2],line[3])
		canvas.draw_line(a,b,Color("#d7e1dd"),1.5)
		canvas.draw_line(a,b,INK,0.6)
	for dot in geometry.dots:canvas.draw_circle(Vector2(dot[0],dot[1]),0.4,BLUE)
	for town in geometry.towns:
		var box:=Rect2(town[0],town[1],town[2],town[3])
		canvas.draw_rect(box,BLUE)
		canvas.draw_line(box.position,box.position+Vector2(box.size.x,0),Color("#d7e1dd"),0.6)
	for key in ["symbols","sites"]:
		for symbol in geometry[key]:
			var box:=Rect2(symbol[0],symbol[1],symbol[2],symbol[3])
			canvas.draw_rect(box,BLUE if key=="symbols" else INK,false,0.5)
	_draw_frame(canvas)
	# Original700Km scale placement, measured source cartouche41,136,26,11.
	canvas.draw_line(Vector2(42,145),Vector2(66,145),INK,1)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(43,142),"700 Km",HORIZONTAL_ALIGNMENT_LEFT,-1,5,INK)

func _draw_frame(canvas:CanvasItem)->void:
	if frame==null:return
	# Measured master straight bars, recomposed into the source3px plan border.
	# Avoid masking static towns/route edges with the master's thick ornamental rim.
	canvas.draw_texture_rect_region(frame,Rect2(0,0,320,3),Rect2(240,28,1320,49))
	canvas.draw_texture_rect_region(frame,Rect2(0,146,320,3),Rect2(240,796,1320,66))
	canvas.draw_texture_rect_region(frame,Rect2(0,3,3,143),Rect2(10,206,45,402))
	canvas.draw_texture_rect_region(frame,Rect2(317,3,3,143),Rect2(1715,206,49,402))
	# The original compass occupied exactly this measured private-plan rectangle.
	canvas.draw_texture_rect_region(frame,Rect2(291,104,29,27),Rect2(1558,631,216,256))
