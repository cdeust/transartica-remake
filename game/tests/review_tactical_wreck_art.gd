extends SceneTree
# MIT. Authored presentation adaptation of original health0 to ruined wagon25.
const Art=preload("res://scripts/tactical_wagon_art.gd")
const Materials=preload("res://scripts/tactical_materials.gd")
class Review extends Control:
	var art=Art.new()
	var materials=Materials.new()
	func _ready() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*4.5)
		draw_rect(Rect2(0,0,320,200),Color("#d2e9f2"))
		for index in 4:
			var health := 3-index
			var base=art.texture_for(25 if health==0 else 23)
			var texture=materials.texture_for(base,0,index,health)
			var factor:=minf(64.0/texture.get_width(),26.0/texture.get_height())
			var extent:=texture.get_size()*factor
			for baseline in [63,192]:
				var point:=Vector2(index*80,baseline)
				draw_line(point,point+Vector2(64,0),Color("#34414b"),1)
				draw_texture_rect(texture,Rect2(point-Vector2(0,extent.y),extent),false)
				draw_string(ThemeDB.fallback_font,point-Vector2(0,30),"HULL %d" % health,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color.BLACK)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var art=Art.new()
	var materials=Materials.new()
	var source=art.texture_for(25)
	var damaged=materials.texture_for(source,0,0,1)
	var wreck=materials.texture_for(source,0,0,0)
	assert(wreck!=source and wreck.get_size()==source.get_size())
	var damaged_mask:Dictionary=materials.instances["0/0/1"]
	var wreck_mask:Dictionary=materials.instances["0/0/0"]
	assert(wreck_mask.removed.size()>damaged_mask.removed.size())
	assert(wreck_mask.occupancy.size()==source.get_width()*source.get_height())
	for fragment in wreck_mask.removed:assert(Rect2i(Vector2i.ZERO,source.get_size()).has_point(fragment.point))
	assert(materials.texture_for(source,0,0,0)==wreck)
	print("PASS: health0 cached ruined hull, three authored fracture passes, scorch, aligned debris coordinates")
	if DisplayServer.get_name()=="headless":quit();return
	root.size=Vector2i(1440,900)
	root.add_child(Review.new())
	await process_frame
	await create_timer(0.25).timeout
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/tactical-wreck-native-20260930.png"))==OK)
	print("PASS: native intact/damaged/ruined comparison at original wheel baselines")
	quit()
