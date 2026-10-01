extends SceneTree
# MIT. Native actual-size review of all six isolated authored silhouettes.
const Art=preload("res://scripts/tactical_actor_art.gd")
class Review extends Control:
	var art=Art.new()
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*4.5)
		draw_rect(Rect2(0,0,320,200),Color("#d2e9f2"))
		for foot in [38,171]:
			draw_line(Vector2(0,foot),Vector2(320,foot),Color("#34414b"),1)
		for index in 6:
			var actor={"mammoth":index>=4,"count":2 if index==5 else 1,"side":1 if index in [2,3] else 0,"direction":0 if index in [1,3] else 8}
			for foot in [38,171]:
				art.draw_actor(self,actor,Vector2(26+index*53,foot))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var art=Art.new()
	var master: Image=Art.MASTER.get_image()
	assert(master.get_size()==Vector2i(1448,1086))
	var expected={0:Rect2i(75,99,272,289),1:Rect2i(426,109,273,282),4:Rect2i(69,459,278,288),5:Rect2i(428,464,274,285),8:Rect2i(12,777,408,293),9:Rect2i(433,747,391,323)}
	for pose in expected:
		var bounds: Rect2i=Art.BOUNDS[pose]
		assert(bounds.encloses(expected[pose]))
		var occupied := Rect2i()
		for region in art.regions_for(pose):
			var image=master.get_region(Rect2i(region))
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x,y).a<128.0/255.0:image.set_pixel(x,y,Color.TRANSPARENT)
			var used: Rect2i=image.get_used_rect()
			assert(used.has_area())
			var absolute := Rect2i(used.position+Vector2i(region.position),used.size)
			occupied=absolute if not occupied.has_area() else occupied.merge(absolute)
		print("ISOLATED ",pose," ",occupied)
		assert(occupied==expected[pose])
	# Explicit exclusion of the neighbour's boot while retaining driver helmet.
	assert(not Art.RIDER_REGIONS[0].has_point(Vector2(617,748)))
	assert(Art.RIDER_REGIONS[0].has_point(Vector2(519,748)))
	if DisplayServer.get_name()=="headless":
		print("PASS: all six measured silhouette regions, complete mammoth trunk and isolated rider helmet")
		quit();return
	root.size=Vector2i(1440,900)
	root.add_child(Review.new())
	await process_frame
	await create_timer(0.25).timeout
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/tactical-actors-native-20260930.png"))==OK)
	print("PASS: native six-pose actual-game-scale roof38/171 capture")
	quit()
