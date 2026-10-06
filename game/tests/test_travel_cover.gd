extends SceneTree
# MIT. Source: six decoded mouths and forest resources; new imported overlays.
const Cover = preload("res://scripts/travel_cover.gd")
const World = preload("res://scripts/world_data.gd")
const Network = preload("res://scripts/rail_network.gd")
const Terrain = preload("res://scripts/travel_terrain.gd")
const Rails = preload("res://scripts/rail_glyphs.gd")
class Recorder:
	extends RefCounted
	const WorldDataScript = World
	const CELL_PIXELS = 205.91260281974 # source: TravelWorld sqrt(180²+100²).
	var world_data
	var network
	var terrain = Terrain.new()
	var commands: Array[Dictionary] = []
	var matrix := Transform2D.IDENTITY
	var camera := Vector2.ZERO
	func _tile_code(x:int,y:int)->int: return network.tile(Vector2i(x,y))
	func _world_to_screen(point:Vector2)->Vector2: return (point-camera)*CELL_PIXELS*0.5
	func _effective_zoom()->float: return 0.5
	func _cell_is_visible(_x:int,_y:int)->bool: return true
	func _visible_world_bounds()->Rect2i: return Rect2i(0,0,World.MAP_WIDTH,World.MAP_HEIGHT)
	func draw_set_transform_matrix(value:Transform2D)->void: matrix=value
	func draw_texture_rect_region(_texture:Texture2D,destination:Rect2,source:Rect2)->void:
		commands.append({"matrix":matrix,"destination":destination,"source":source})
	func draw_texture_rect(_texture:Texture2D,destination:Rect2,_tile:bool)->void:
		commands.append({"matrix":matrix,"destination":destination})
var failures:Array[String]=[]
var checks:=0
func _initialize()->void: call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value: failures.append(label)
func run()->void:
	var view=Recorder.new()
	view.world_data=World.new()
	check(view.world_data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")),"actual private geography loads")
	view.network=Network.new()
	view.network.load_bytes(view.world_data.map_bytes)
	view.terrain.portals.load_art()
	var cover=Cover.new()
	check(cover.load_art(),"actual imported foreground resources load")
	check(cover.portal!=null and cover.canopies.size()==3,"all imported v2 canopy and portal resources exist")
	if cover.portal==null or cover.canopies.size()!=3:
		finish()
		return
	var original:PackedInt32Array=view.network._tiles.duplicate()
	_mouths(cover,view)
	_forests(cover,view)
	_layers()
	cover.draw_floor(view)
	check(view.commands.size()==6,"floor draws exactly six source mouths")
	view.commands.clear()
	cover.draw(view)
	check(view.matrix==Transform2D.IDENTITY,"foreground restores canvas transform")
	check(view.network._tiles==original,"all foreground drawing leaves live network unchanged")
	finish()
func finish()->void:
	if failures.is_empty():
		print("PASS: ",checks," imported cover checks: six registered mouths, foreground lip, source forest neighbors, clickable clearance, layers and unchanged network")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _mouths(cover,view)->void:
	var actual:=0
	for x in World.MAP_WIDTH:
		for y in World.MAP_HEIGHT:
			var cell:=Vector2i(x,y)
			var code:int=view._tile_code(x,y)
			if code in [53,54,58]:
				actual+=1
				check(cover.handles_mouth(cell,code),"each actual source mouth is whitelisted")
			else:
				check(not cover.handles_mouth(cell,code),"no invented mouth covers other source cells")
	check(actual==6 and Cover.MOUTHS.size()==6,"source contains exactly six replacement mouths")
	for cell in Cover.MOUTHS:
		view.camera=Vector2(cell)
		var code:int=Cover.MOUTHS[cell]
		var registration:Transform2D=cover.mouth_registration(view,cell,code)
		var frame:Dictionary=view.terrain.portals.frames[code]
		var old_anchor:=Vector2(frame.mouth_anchor[0],frame.mouth_anchor[1])
		check((registration*Cover.MOUTH_ANCHOR).distance_to(view.terrain.portals.registration(view,cell,code)*old_anchor)<0.0001,"new dark opening retains existing measured mouth anchor")
		check(is_equal_approx(registration.basis_xform(Vector2(Cover.MOUTH_GAUGE,0)).length(),Cover.GAUGE*view._effective_zoom()),"v2 rail gauge matches existing rail gauge")
		var section:Vector2=cover.mouth_section(view,cell,code)
		var endpoint:Vector2=view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5+Vector2(preload("res://scripts/underground_visual.gd").mouth_direction(code))*0.5)
		check((registration*section).distance_to(endpoint)<0.0001,"external section lands at unchanged source port")
		check(section.y>Cover.LIP_HEIGHT and section.y<=cover.portal.get_height(),"floor includes dark opening and clips external stub inside artwork")
	view.camera=Vector2.ZERO
	check(Cover.LIP_HEIGHT==Cover.MOUTH_ANCHOR.y,"foreground ends at measured opening boundary")
	var missing=Cover.new()
	check(not missing.handles_mouth(Vector2i(61,51),53),"missing overlay retains old portal fallback")
func _forests(cover,view)->void:
	var plan:Array[Dictionary]=cover.canopy_plan(view)
	check(not plan.is_empty(),"source forest edges produce foreground crowns")
	var opaque_rail_centers:=0
	for entry in plan:
		var cell:Vector2i=entry.cell
		var resource:int=Terrain.resource_code(view._tile_code(cell.x,cell.y))
		check(resource>=116 and resource<=132,"every crown is anchored to a real source forest cell")
		var rail:Vector2i=entry.rail
		check((rail-cell).length()==1 and not Rails.ports_for_code(view._tile_code(rail.x,rail.y)).is_empty(),"every crown borders actual source track cardinally")
		check(not cover.protected_overlap(view,entry.rect),"no crown obscures switch, station or city click targets")
		var image:Image=cover.canopies[entry.variant].get_image()
		var pixel:Vector2=(Vector2(rail)+Vector2.ONE*0.5-entry.rect.position)/entry.rect.size*Vector2(image.get_size())
		if pixel.x>=0 and pixel.y>=0 and pixel.x<image.get_width() and pixel.y<image.get_height() and image.get_pixel(int(pixel.x),int(pixel.y)).a>0:
			opaque_rail_centers+=1
	check(opaque_rail_centers>0,"actual opaque crown pixels cover source track centers where wagons pass")
	print("Source forest plan: ",plan.size()," clumps; ",opaque_rail_centers," opaque rail-center overlaps")
	var switch_cell:=Vector2i(54,67)
	check(cover.protected_overlap(view,Rect2(Vector2(switch_cell),Vector2.ONE)),"source switch cell explicitly protected")
	var city:Dictionary=view.world_data.cities[0]
	var city_origin:=Vector2(city.x,city.y)-Vector2(2,1)
	check(cover.protected_overlap(view,Rect2(city_origin,Vector2.ONE)),"city painting north-west origin is protected")
	check(cover.protected_overlap(view,Rect2(Vector2(city.x,city.y),Vector2.ONE)),"source city anchor click cell is protected")
	for code in range(18,38):
		var scratch=Network.new()
		scratch.load_bytes(view.world_data.map_bytes)
		scratch._tiles[20*World.MAP_HEIGHT+20]=code
		var original=view.network
		view.network=scratch
		check(cover.protected_overlap(view,Rect2(Vector2(20,20),Vector2.ONE)),"all interaction rail codes18..37 protected")
		view.network=original
func _layers()->void:
	var source:=FileAccess.get_file_as_string("res://scripts/travel_world.gd")
	var start:int=source.find("func _draw()")
	var end:int=source.find("func _draw_rails()",start)
	var draw:=source.substr(start,end-start)
	check(draw.find("cover.draw_floor(self)")<draw.find("_draw_train()"),"new portal floor stays below actual train draw")
	check(draw.find("cover.draw(self)")>draw.find("_draw_train()") and draw.find("cover.draw(self)")>draw.find("living.draw(self)"),"crowns and portal lip draw above train and plumes")
	check(draw.find("cover.draw(self)")<draw.find("map_entities._draw_cities(self)") and draw.find("cover.draw(self)")<draw.find("map_entities.draw_player_heading(self)"),"city click markers and heading stay above foreground")
	check(not FileAccess.get_file_as_string("res://scripts/travel_cover.gd").contains("Control.new"),"foreground creates no controls or hit boxes")
