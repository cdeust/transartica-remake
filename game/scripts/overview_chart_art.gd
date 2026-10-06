extends RefCounted
# MIT. Newly authored rendering of the original INCOMPLETE static plan.
# Private semantic vectors: tools/export_overview_geometry.py, audit evidence.
const FIELD := Color("#eee9d7") # Existing authored chart/clock paper palette.
const INK := Color("#342317") # Existing modern panel ink.
const BLUE := Color("#ad8b52") # Existing authored brass chart accent.
const PATH := "res://private-data/overview-geometry.json"
var frame: Texture2D
var material: Texture2D
var town_art: Texture2D
var artwork = preload("res://scripts/world_artwork.gd").new()
const TownArt = preload("res://scripts/terrain_landmarks.gd")
const PAPER_FACE := Rect2(60,320,200,180) # Measured clock face; clock-quality20261003.
var geometry: Dictionary = {}

func load_art() -> void:
	artwork.load_art(false) # Overview uses the finite master only.
	frame=load("res://assets/interface/world-chart-frame.png") as Texture2D
	var paper := AtlasTexture.new()
	paper.atlas=load("res://assets/interface/original-panel-v2.png")
	paper.region=paper_region()
	material=paper
	town_art=load("res://assets/travel/terrain/landmarks-master.png")
	var path:=PATH if FileAccess.file_exists(PATH) else "res://../reference-private/overview-geometry.json"
	load_geometry(path)


static func paper_region() -> Rect2:
	# Native7222 showed bezel at the rectangular face crop's corners. Inscribe
	# a rectangle in the measured ellipse: normalized corner (1/sqrt2,1/sqrt2).
	# Round inward to full source pixels so texture sampling stays inside paper.
	var half := (PAPER_FACE.size/(2.0*sqrt(2.0))).floor()
	return Rect2(PAPER_FACE.get_center()-half,half*2.0)

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
	if not artwork.draw_overview(canvas) and material!=null:
		canvas.draw_texture_rect(material,Rect2(0,0,320,149),false,Color.WHITE)
	for line in geometry.compartments:
		canvas.draw_line(Vector2(line[0],line[1]),Vector2(line[2],line[3]),Color(BLUE,0.16),0.5)
	for line in geometry.routes:
		var a:=Vector2(line[0],line[1])
		var b:=Vector2(line[2],line[3])
		canvas.draw_line(a,b,INK,1.5)
		canvas.draw_line(a,b,BLUE,0.6)
	for dot in geometry.dots:canvas.draw_circle(Vector2(dot[0],dot[1]),0.4,BLUE)
	for marker in town_markers():
		if town_art!=null:
			canvas.draw_texture_rect_region(town_art,marker.destination,marker.source)
		else:
			canvas.draw_circle(marker.bounds.get_center(),marker.bounds.size.y/2.0,INK)
	for key in ["symbols","sites"]:
		for symbol in geometry[key]:
			var box:=Rect2(symbol[0],symbol[1],symbol[2],symbol[3])
			# Undecoded marks retain their measured location, without assigning
			# towns/mines/depots/quests or copying original ambiguous glyphs.
			var radius := minf(box.size.x,box.size.y)/2.0
			canvas.draw_circle(box.get_center(),radius,INK)
			canvas.draw_circle(box.get_center(),radius/2.0,BLUE)
	_draw_frame(canvas)
	# Original700Km scale placement, measured source cartouche41,136,26,11.
	canvas.draw_line(Vector2(42,145),Vector2(66,145),INK,1)


func town_markers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not available(): return result
	var source: Rect2 = TownArt.REGIONS[0] # Neutral authored town; no guessed function.
	for town in geometry.towns:
		var bounds := Rect2(town[0],town[1],town[2],town[3])
		var factor := minf(bounds.size.x/source.size.x,bounds.size.y/source.size.y)
		var extent := source.size*factor
		result.append({"bounds":bounds,"source":source,"destination":Rect2(bounds.get_center()-extent/2.0,extent)})
	return result


func draw_labels(canvas: CanvasItem, scale: Vector2) -> void:
	# Same measured original scale cartouche; screen-space font avoids magnified
	# tiny fallback glyphs. No names inferred from nearby detailed-map cities.
	var font_size := maxi(1,roundi(5.0*scale.y))
	canvas.draw_string(ThemeDB.fallback_font,Vector2(43,142)*scale,"700 Km",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,INK)

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
