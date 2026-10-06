extends SceneTree
# MIT. CARTE160x73 and CARTE1ece marker transform are registration oracles.
const Artwork = preload("res://scripts/world_artwork.gd")
const Travel = preload("res://scripts/travel_world.gd")
const Terrain = preload("res://scripts/travel_terrain.gd")
var failures: Array[String] = []
var checks := 0

class Recorder extends RefCounted:
	var draws: Array = []
	var discovery_enabled := false
	var bounds := Rect2i(0,0,2,2)
	var known := [Vector2i(1,0)]
	var cover
	func _world_to_screen(point: Vector2) -> Vector2: return point*10
	func _visible_world_bounds() -> Rect2i: return bounds
	func _cell_is_visible(x: int,y: int) -> bool: return Vector2i(x,y) in known
	func draw_texture_rect(_texture,rect: Rect2,_tile: bool) -> void: draws.append({"rect":rect})
	func draw_texture_rect_region(_texture,rect: Rect2,source: Rect2) -> void: draws.append({"rect":rect,"source":source})

class MouthDelegate extends RefCounted:
	func handles_mouth(_cell: Vector2i,_code: int) -> bool: return true

class NodeView extends Control:
	var discovery_enabled := false
	var bounds := Rect2i(0,0,2,2)
	func _world_to_screen(point: Vector2) -> Vector2: return point*10+Vector2(13,-7)
	func _visible_world_bounds() -> Rect2i: return bounds

class Delegate extends RefCounted:
	var calls := 0
	var handled := false
	func draw_tile(_view,_cell,_code,_bounds = null) -> bool:
		calls += 1
		return handled

func _initialize() -> void: _run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	_registration()
	_layers()
	_regions()
	_imported()
	await _nodes()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: ",checks," finite artwork registration, shared overview transform, fallback, discovery and retained terrain delegates")
	quit(0 if failures.is_empty() else 1)

func _imported() -> void:
	var artwork = Artwork.new()
	check(artwork.load_art(),"Actual imported master is loadable by ResourceLoader")
	check(artwork.regions.size() == 8,"All eight actual imported detailed regions are loadable")
	for index in artwork.regions.size():
		var region: Dictionary = artwork.regions[index]
		var image: Image = region.texture.get_image()
		check(image != null and not image.is_empty(),"Imported regional texture exposes actual pixels")
		check(region.texture.get_size() == Vector2(1312,1199),"Actual texture has documented v2 delivery resolution")
		check(region.world == Artwork.region_rect(index),"Actual imported region registered to original finite bounds")
		check(not region.mask.is_empty(),"Actual imported pixel hash matches measured art-only dark mask")
	var document = JSON.parse_string(FileAccess.get_file_as_string(Artwork.REGISTRATION_PATH))
	if artwork.regions.size() == 8:
		var region: Dictionary = artwork.regions[0]
		check(Artwork._registered_mask(null,0,region.texture).is_empty(),"Unknown registration never suppresses legacy relief")
		var stale: Dictionary = document.duplicate(true)
		stale.regions[0].rgba_sha256 = "stale"
		check(Artwork._registered_mask(stale,0,region.texture).is_empty(),"Stale artwork hash never suppresses legacy relief")
		stale = document.duplicate(true)
		stale.regions[0].dark_mask = "bad"
		check(Artwork._registered_mask(stale,0,region.texture).is_empty(),"Malformed registration mask rejected")
		stale = document.duplicate(true)
		stale.regions[0].relief_iou = stale.regions[0].chance
		check(Artwork._registered_mask(stale,0,region.texture).is_empty(),"Unmeasured chance-level relief rejected")
		check(not artwork.covers_relief(Vector2i(40,36),86),"Partial seam cell36 retains original relief")
		check(not artwork.covers_relief(Vector2i(0,1),86),"Feather border retains original relief")
		check(not artwork.covers_relief(Vector2i(10,10),106),"Dark classification never removes dynamic water")
	check(artwork.load_art(false) and artwork.regions.is_empty(),"Actual overview loads master without detailed texture overlays")

func _registration() -> void:
	var view = Travel.new()
	view.size = Vector2(1440,700) # Existing native travel fixture viewport.
	var overview = preload("res://scripts/ecs_overview.gd").new()
	for camera in [Vector2.ZERO,Vector2(80,36.5),Vector2(159,72)]:
		view.camera_world = camera
		for zoom in [0.01,0.65,2.0]: # Existing whole-world, terrain-review and maximum zoom fixtures.
			view.zoom = zoom
			view.offset = Vector2(17,-11) # Nonzero pan fixture tests both axes.
			var rect := Artwork.travel_rect(view)
			check(rect.position.is_equal_approx(view._world_to_screen(Vector2.ZERO)),"Artwork world origin registered")
			check(rect.end.is_equal_approx(view._world_to_screen(Artwork.extent())),"Artwork covers finite source bounds")
			for cell in [Vector2(12.5,62.5),Vector2(64,42),Vector2(152,66)]:
				var painted: Vector2 = rect.position+(cell/Artwork.extent())*rect.size
				check(painted.is_equal_approx(view._world_to_screen(cell)),"Interior artwork point aligned with unchanged travel transform")
	var chart := Artwork.overview_rect()
	check(chart == Rect2(2,3,320,146),"Original overview extent retains its intentional edge clipping")
	for cell in [Vector2.ZERO,Vector2(12,62),Vector2(64,42),Vector2(159,72)]:
		check((chart.position+cell/Artwork.extent()*chart.size).is_equal_approx(overview.map_point(cell)),"Shared artwork agrees with original overview markers")
	view.free()
	overview.free()

func _layers() -> void:
	var artwork = Artwork.new()
	var recorder := Recorder.new()
	check(not artwork.draw_travel(recorder) and not artwork.draw_overview(recorder) and recorder.draws.is_empty(),"Missing artwork leaves fallback untouched")
	var image := Image.create(160,73,false,Image.FORMAT_RGBA8) # One synthetic pixel per source cell.
	image.fill(Color.WHITE)
	artwork.texture = ImageTexture.create_from_image(image)
	check(artwork.draw_travel(recorder) and recorder.draws.size() == 1,"Available artwork draws once across finite world")
	check(recorder.draws[0].rect == Rect2(0,0,1600,730),"Recorder receives full world rectangle")
	recorder.draws.clear()
	recorder.discovery_enabled = true
	check(artwork.draw_travel(recorder) and recorder.draws.size() == 1,"Optional discovery paints only known cells")
	check(recorder.draws[0].rect == Rect2(10,0,10,10) and recorder.draws[0].source == Rect2(1,0,1,1),"Known cell samples its exact master coordinates")
	recorder.draws.clear()
	check(artwork.draw_overview(recorder) and recorder.draws[0].rect == Artwork.overview_rect(),"Overview uses same master with original transform")
	var terrain = Terrain.new()
	terrain.artwork = artwork
	terrain.portals = Delegate.new()
	terrain.obstacles = Delegate.new()
	terrain.landmarks = Delegate.new()
	terrain.textures = {86:artwork.texture,116:artwork.texture,106:artwork.texture}
	artwork.regions.append({"texture":artwork.texture,"world":Artwork.region_rect(0),"index":0,"mask":"1".repeat(40*36)})
	recorder.draws.clear()
	for resource in [86,105,116,132,142,146,-114]:
		check(terrain.draw_tile(recorder,Vector2i(10,10),resource),"Measured coarse relief cell handled including signed146")
	check(recorder.draws.is_empty(),"Old generic relief does not repaint finite artwork")
	check(terrain.draw_tile(recorder,Vector2i.ZERO,86) and recorder.draws.size() == 1,"Unknown border cell retains old terrain despite available painting")
	recorder.draws.clear()
	terrain.artwork.texture = null
	check(terrain.draw_tile(recorder,Vector2i.ZERO,86) and recorder.draws.size() == 1,"Missing artwork restores old terrain draw")
	terrain.artwork.texture = ImageTexture.create_from_image(image)
	var before := recorder.draws.size()
	check(terrain.draw_tile(recorder,Vector2i.ZERO,106) and recorder.draws.size() == before+1,"Exact water tile remains drawn over artwork")
	for delegate in [terrain.portals,terrain.obstacles,terrain.landmarks]:
		delegate.handled = true
		before = recorder.draws.size()
		check(terrain.draw_tile(recorder,Vector2i.ZERO,86) and recorder.draws.size() == before,"Special terrain delegate keeps priority over generic relief")
		delegate.handled = false
	terrain.portals.handled = true
	var portal_calls: int = terrain.portals.calls
	recorder.cover = MouthDelegate.new()
	check(terrain.draw_tile(recorder,Vector2i(61,51),53) and terrain.portals.calls == portal_calls,"Loaded source mouth replacement prevents duplicate old portal")
	recorder.cover = null
	check(terrain.draw_tile(recorder,Vector2i(61,51),53) and terrain.portals.calls == portal_calls+1,"Unavailable replacement retains original mouth fallback")

func _nodes() -> void:
	var artwork = Artwork.new()
	var image := Image.create(160,73,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	artwork.texture = ImageTexture.create_from_image(image)
	for index in 8: artwork.regions.append({"texture":artwork.texture,"world":Artwork.region_rect(index)})
	var view := NodeView.new()
	var ground := Control.new()
	ground.name = "WorldGround"
	ground.show_behind_parent = true
	view.add_child(ground)
	root.add_child(view)
	check(artwork.draw_travel(view),"Real CanvasItem schedules dedicated background")
	await process_frame
	check(artwork.layer.get_parent() == view and artwork.layer.show_behind_parent,"Artwork layer draws behind parent rails and landmarks")
	check(artwork.layer.get_index() == ground.get_index()+1,"Artwork follows existing WorldGround")
	check(artwork.master_rect.position == Vector2(13,-7) and artwork.master_rect.size == Vector2(1600,730),"Master child registration includes pan")
	check(artwork.master_rect.material == null and view.material == null and ground.material == null,"Feather never changes master or shared view materials")
	check(artwork.regional_rects[0].visible and not artwork.regional_rects[1].visible,"Only visible regional child enabled")
	check(artwork.regional_rects[0].size == Vector2(400,365),"Regional child matches authored world span")
	check(artwork.regional_rects[0].material != artwork.regional_rects[1].material,"Each regional image has a dedicated material")
	check(artwork.regional_rects[0].material.get_shader_parameter("feather_pixels") == 16.0,"Authored edge feather is16texturepixels")
	check(artwork.regional_rects[0].material.get_shader_parameter("image_size") == Vector2(160,73),"Feather accounts for actual texture resolution")
	view.bounds = Rect2i(81,40,2,2)
	artwork.draw_travel(view)
	check(not artwork.regional_rects[0].visible and artwork.regional_rects[6].visible,"Camera movement updates visible regions")
	view.free()
	await process_frame

func _regions() -> void:
	var artwork = Artwork.new()
	var image := Image.create(160,73,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	artwork.texture = ImageTexture.create_from_image(image)
	for index in 8: # Owner's authored four-column/two-row regional grid.
		var world := Artwork.region_rect(index)
		check(world == Rect2((index%4)*40,(index/4)*36.5,40,36.5),"Regional source rectangle matches generation guide")
		check(Rect2(Vector2.ZERO,Artwork.extent()).encloses(world),"Region lies within finite world")
		artwork.regions.append({"texture":artwork.texture,"world":world})
	var recorder := Recorder.new()
	check(artwork.draw_travel(recorder) and recorder.draws.size() == 2,"Only visible region drawn over master")
	check(recorder.draws[1].rect == Rect2(0,0,400,365),"Detailed region uses exact world rectangle")
	recorder.draws.clear()
	check(artwork.draw_overview(recorder) and recorder.draws.size() == 1,"Overview draws master without regional overlays")
	recorder.draws.clear()
	recorder.discovery_enabled = true
	recorder.bounds = Rect2i(39,36,3,2)
	recorder.known = [Vector2i(40,36)]
	check(artwork.draw_travel(recorder) and recorder.draws.size() == 3,"Known cell crossing regional seam samples both half-cell images")
	check(recorder.draws[1].rect == Rect2(400,360,10,5) and recorder.draws[2].rect == Rect2(400,365,10,5),"Regional seam is exactly36.5cells without gap or overlap")
	check(recorder.draws[1].source.end.y == 73 and recorder.draws[2].source.position.y == 0,"Regional seam samples each image boundary")
	artwork.regions.clear()
	recorder.discovery_enabled = false
	recorder.draws.clear()
	check(artwork.draw_travel(recorder) and recorder.draws.size() == 1,"Missing detailed regions retain full master fallback")
