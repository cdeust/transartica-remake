extends SceneTree
# MIT. Full-silhouette and material-coordinate review of all25 authored wagons.
const Art=preload("res://scripts/tactical_wagon_art.gd")
const Materials=preload("res://scripts/tactical_materials.gd")
class Review extends Control:
	var art=Art.new()
	func _ready() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*4.5)
		draw_rect(Rect2(0,0,320,200),Color("#d2e9f2"))
		for kind in range(1,26):
			var slot:int=0 if kind==1 else kind
			var point:=Vector2(slot%5*64,30+int(slot/5)*30)
			var texture=art.texture_for(kind)
			var limit:=128.0 if kind==1 else 64.0
			var factor:=minf(limit/texture.get_width(),26.0/texture.get_height())
			var extent:=texture.get_size()*factor
			draw_line(point,point+Vector2(limit,0),Color("#34414b"),1)
			draw_texture_rect(texture,Rect2(point-Vector2(0,extent.y),extent),false)
			draw_string(ThemeDB.fallback_font,point+Vector2(1,5),str(kind),HORIZONTAL_ALIGNMENT_LEFT,-1,5,Color.BLACK)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var art=Art.new()
	var materials=Materials.new()
	for kind in range(1,26):
		var texture=art.texture_for(kind)
		var image=texture.get_image().duplicate()
		var spec:Array=Art.REGIONS[kind]
		var region:Rect2i=spec[1].grow(1)
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a<128.0/255.0:image.set_pixel(x,y,Color.TRANSPARENT)
		assert(image.get_used_rect()==Rect2i(spec[1].position-region.position,spec[1].size))
		for health in [2,1]:
			var damaged=materials.texture_for(texture,0,kind,health)
			assert(damaged.get_size()==texture.get_size())
			var material:Dictionary=materials.instances["0/%d/%d" % [kind,health]]
			assert(material.occupancy.size()==texture.get_width()*texture.get_height())
			for removed in material.removed:assert(Rect2i(Vector2i.ZERO,texture.get_size()).has_point(removed.point))
	# Master metadata recovers the original tower, full wheels and wider carriages.
	assert(Art.REGIONS[4][1].size.y==334)
	assert(Art.REGIONS[6][1].end.y==687 and Art.REGIONS[7][1].end.y==687)
	assert(Art.REGIONS[18][1].position.x<768)
	print("PASS:25 isolated full silhouettes and aligned health2/1 material occupancy/debris")
	if DisplayServer.get_name()=="headless":quit();return
	root.size=Vector2i(1440,900)
	root.add_child(Review.new())
	await process_frame
	await create_timer(0.25).timeout
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/tactical-wagons-native-20260930.png"))==OK)
	print("PASS: native25-wagon actual-game-scale montage")
	quit()
