extends RefCounted
# MIT. Newly authored world-landmarks-kit; measured isolated sprite regions.
# Source roles: city_backdrop.SCENES, world-terrain.md resources65/71..79/133.
const REGIONS := [Rect2(11,75,360,325),Rect2(377,128,345,274),
	Rect2(731,8,340,386),Rect2(1078,128,370,275),Rect2(0,402,372,305),
	Rect2(377,407,350,308),Rect2(730,400,348,314),Rect2(1090,425,358,294)]
const CITY_ART := {1:0,2:1,3:2,4:4,5:3,6:5}
var master: Texture2D

func load_art() -> void:
	master = load("res://assets/travel/terrain/landmarks-master.png") as Texture2D

func draw_tile(view, cell: Vector2i, resource: int, bounds: Rect2) -> bool:
	var index := -1
	if resource in [78,79]:
		index = 7
	elif resource == 65:
		index = 6
	elif resource == 133:
		index = 2
	elif resource == 71:
		index = _town(view,cell)
		bounds.size *= Vector2(3,2)
	elif resource >= 72 and resource <= 76:
		return true # Other pieces belong to the same3x2 source town painting.
	if index < 0 or master == null:
		return false
	var source: Rect2 = REGIONS[index]
	var factor := minf(bounds.size.x/source.size.x,bounds.size.y/source.size.y)
	var extent := source.size*factor
	var destination := Rect2(bounds.get_center()-extent/2,extent)
	# Depleted mine visual state, source CARTE78→79; no gameplay mutation.
	var tint := Color("#718594") if resource == 79 else Color.WHITE
	view.draw_texture_rect_region(master,destination,source,tint)
	return true

func _town(view, cell: Vector2i) -> int:
	# CARTE towns: top row71/72/73, bottom74/75/76; decoded record
	# anchors the lower-right piece. Verified Istanbul(62..64,41..42).
	for city in view.world_data.cities:
		if cell + Vector2i(2,1) == Vector2i(int(city.x),int(city.y)):
			return CITY_ART.get(absi(int(city.kind)),0)
	return 0 # Neutral authored town when the source painting has no city record.
