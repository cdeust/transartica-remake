extends SceneTree
# MIT. PREPARED artwork fixtures from earned composition, never campaign gameplay.
# Root alone launches this native comparison. No save files or source map writes.
const Saves = preload("res://scripts/session_saves.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
const Glyphs = preload("res://scripts/rail_glyphs.gd")
var app
func _initialize()->void:
	# Like test_ecs_panel: changed-frame-only rendering can strand post-draw waits.
	OS.low_processor_usage_mode=false
	_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless" or args.size()!=2:
		push_error("Native renderer, earned save and output directory required; PREPARED fixtures only")
		quit(1)
		return
	var save_digest:=FileAccess.get_sha256(args[0])
	if save_digest.is_empty():
		_fail("Earned save is unreadable")
		return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1440,900) # source: owner native inspection viewport.
	app=load("res://main.tscn").instantiate()
	app.play_startup_intro=false
	app.save_path_override=args[0]
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	if not Saves.restore(app,args[0]).ok:
		_fail("Earned save restore failed")
		return
	if app._city_panel.visible:
		_fail("Earned save opens a city modal; supply an earned map save without changing UI state")
		return
	app._open_panel("map")
	await process_frame
	await process_frame
	if not _capture_ready():return
	app.world_view.set_process(false)
	app.game_audio.set_process(false)
	app.game_audio.reset()
	assert(app.world_view.cover.portal!=null and app.world_view.cover.canopies.size()==3)
	assert(DirAccess.make_dir_recursive_absolute(args[1])==OK)
	var network_before:PackedInt32Array=app.network._tiles.duplicate()
	var sites:Array[Dictionary]=[]
	for cell in app.world_view.cover.MOUTHS:
		var code:int=app.world_view.cover.MOUTHS[cell]
		var surface:=preload("res://scripts/underground_visual.gd").mouth_direction(code)
		var heading:int=Rails.DELTAS.find_key(-Vector2i(surface))
		sites.append({"name":"mouth-%d-%d-%d" % [code,cell.x,cell.y],"cell":cell,"heading":heading,"mouth":true})
	# Pick an actual source canopy with opaque pixels on its neighboring rail center.
	app.world_view.camera_world=Vector2(80,36)
	app.world_view.zoom=0.01 # authored whole-map search, never gameplay camera change.
	for entry in app.world_view.cover.canopy_plan(app.world_view):
		var image:Image=app.world_view.cover.canopies[entry.variant].get_image()
		var pixel:Vector2=(Vector2(entry.rail)+Vector2.ONE*0.5-entry.rect.position)/entry.rect.size*Vector2(image.get_size())
		if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height() or image.get_pixel(int(pixel.x),int(pixel.y)).a==0:continue
		var ports:Array[Vector2]=Glyphs.ports_for_code(app.network.tile(entry.rail))
		for heading in Rails.DELTAS:
			if -Vector2(Rails.DELTAS[heading])*0.5 in ports and Vector2(Rails.DELTAS[heading])*0.5 in ports:
				if _source_history(app.network,entry.rail,heading,app.world_view.consist.length_world()+2,{}).is_empty():continue
				sites.append({"name":"forest-%d-%d" % [entry.cell.x,entry.cell.y],"cell":entry.rail,"heading":heading,"mouth":false})
				break
		if sites.size()>6:break
	assert(sites.size()==7,"Prepared forest fixture must use a real opaque crown over a source rail")
	var report:Array[Dictionary]=[]
	for site in sites:
		var fixture=Journey.new()
		fixture.network=app.network
		assert(fixture.restore({"version":1,"position":[site.cell.x,site.cell.y],"heading":site.heading,"distance_ticks":0,"phase":0,"blocked":false}))
		_seed_source_history(fixture,app.world_view.consist.length_world()+2)
		# Move only the fixture cursor slightly under the existing mouth; source route unchanged.
		var penetration:=0.5 # source: source-cell center for prepared forest comparison.
		if site.mouth:
			var frame:Dictionary=app.world_view.terrain.portals.frames[app.network.tile(site.cell)]
			var anchor:=Vector2(frame.mouth_anchor[0],frame.mouth_anchor[1])
			var endpoint:=Vector2(frame.rail_endpoint[0],frame.rail_endpoint[1])
			penetration=(endpoint-anchor).length()*app.world_view.cover.GAUGE/float(frame.rail_gauge)/app.world_view.CELL_PIXELS+app.world_view.cover.GAUGE/app.world_view.CELL_PIXELS
		fixture._render_cursor=fixture._render_path.length-1+penetration
		fixture._render_origin=fixture._render_cursor
		app.journey=fixture
		app.world_view.journey=fixture
		app.world_view._snap_visual_position(fixture.sample_behind(0).position)
		app.world_view.camera_world=Vector2(site.cell)+Vector2.ONE*0.5
		app.world_view.offset=Vector2.ZERO
		app.world_view.zoom=1.0 # authored close-up, same across off/on capture.
		app.world_view.train_renderer.underground_alpha=0.75 # owner-selected4Oct presentation.
		var poses:Array=app.world_view.train_renderer.poses(app.world_view,fixture,app.world_view.consist,0.0)
		assert(poses.size()==app.world_view.consist.vehicles.size())
		var before:Dictionary=Saves.snapshot(app)
		var captures:Array[Image]=[]
		for enabled in [false,true]:
			if not _capture_ready():return
			print("PREPARED capture ",site.name," ","on" if enabled else "off")
			app.world_view.cover.foreground_enabled=enabled
			app.world_view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if not _capture_ready():return
			var capture:Image=root.get_texture().get_image()
			assert(not capture.is_empty())
			assert(capture.save_png(args[1]+"/%s-%s.png" % [site.name,"on" if enabled else "off"])==OK)
			captures.append(capture)
			assert(Saves.snapshot(app)==before,"Prepared overlay cannot advance simulation")
			assert(app.world_view.train_renderer.poses(app.world_view,fixture,app.world_view.consist,0.0)==poses,"Overlay cannot alter rigid train poses")
			assert(app.network._tiles==network_before,"Prepared review cannot alter source network")
			assert(FileAccess.get_sha256(args[0])==save_digest,"Prepared review cannot write the earned save")
		var bounds:Rect2=app.world_view.train_renderer.screen_bounds(app.world_view,fixture,app.world_view.consist,0.0)
		bounds.position+=app.world_view.global_position
		var changed:=_changed_pixels(captures[0],captures[1],bounds)
		var changed_train:=_changed_train_pixels(captures[0],captures[1],app.world_view,poses)
		print("PREPARED ",site.name," changed train-bounds pixels=",changed," actual alpha-covered train pixels=",changed_train)
		report.append({"name":site.name,"changed_train_bounds_pixels":changed,"changed_alpha_covered_train_pixels":changed_train,"state_unchanged":true,"poses_unchanged":true,"network_unchanged":true})
		_write_report(args[1],report)
		if not _positive_occlusion(changed_train):
			_fail("PREPARED %s has zero changed pixels beneath train alpha; this is not occlusion proof" % site.name)
			return
	app.queue_free()
	await process_frame
	print("PASS: PREPARED world foreground comparisons; positive train-alpha changes at all seven sites; root image review still required")
	quit()
func _capture_ready()->bool:
	var problem:=_view_problem(app._city_panel.visible,app.world_view.is_visible_in_tree(),app.world_view.size,app._map_panel.visible)
	if problem.is_empty() and (app.encounters.report.visible or app.encounters.manual_scene.visible or app.room_controls.show_help):
		problem="World is covered by another modal"
	if problem.is_empty():return true
	_fail(problem)
	return false
static func _view_problem(city_visible:bool,world_visible:bool,world_size:Vector2,map_visible:bool)->String:
	if city_visible:return "World is covered by a city modal"
	if not map_visible or not world_visible or world_size.x<=0 or world_size.y<=0:return "World map is hidden or has no drawable area"
	return ""
static func _positive_occlusion(changed_train:int)->bool:
	return changed_train>0
func _write_report(directory:String,report:Array[Dictionary])->void:
	var file:=FileAccess.open(directory+"/prepared-report.json",FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
func _fail(message:String)->void:
	push_error(message)
	if is_instance_valid(app):app.queue_free()
	quit(1)
static func _seed_source_history(fixture, length_needed:float)->void:
	var result:=_source_history(fixture.network,fixture.position,fixture.heading,length_needed,{})
	assert(not result.is_empty(),"Prepared consist requires nonlooping connected source history")
	for record in result.records:fixture._render_path.append_tile(record[0],record[1],record[2])
	fixture._render_end_cell=fixture.position
	fixture._render_end_heading=fixture.heading
static func _source_history(network, cell:Vector2i, outgoing:int, needed:float, visited:Dictionary)->Dictionary:
	if needed<=0:return {"records":[]}
	var ports:Array[Vector2]=Glyphs.ports_for_code(network.tile(cell))
	if not Vector2(Rails.DELTAS[outgoing])*0.5 in ports:return {}
	var choices:Array[int]=[]
	for incoming in Rails.DELTAS:
		if incoming+outgoing==10:continue # Source through-route needs two distinct ports.
		if not -Vector2(Rails.DELTAS[incoming])*0.5 in ports:continue
		if network.turn(cell,incoming)!=outgoing:
			if not network.is_switch(cell):continue
			# Historical switch setting may differ; verify the other original state on a clone.
			var alternate=Rails.new()
			alternate._initial=network._initial.duplicate()
			alternate._tiles=network._tiles.duplicate()
			assert(alternate.toggle_switch(cell))
			if alternate.turn(cell,incoming)!=outgoing:continue
		var previous:Vector2i=cell-Rails.DELTAS[incoming]
		if Vector2(Rails.DELTAS[incoming])*0.5 in Glyphs.ports_for_code(network.tile(previous)):choices.append(incoming)
	if outgoing in choices:
		choices.erase(outgoing)
		choices.push_front(outgoing)
	for incoming in choices:
		var key:=Vector3i(cell.x,cell.y,incoming)
		if visited.has(key):continue
		visited[key]=true
		var distance:float=Vector2(Rails.DELTAS[incoming]).length()*0.5+Vector2(Rails.DELTAS[outgoing]).length()*0.5
		var result:=_source_history(network,cell-Rails.DELTAS[incoming],incoming,needed-distance,visited)
		visited.erase(key)
		if not result.is_empty():
			result.records.append([cell,incoming,outgoing])
			return result
	return {}
func _changed_pixels(first:Image,last:Image,bounds:Rect2)->int:
	var rect:=Rect2i(Vector2i(bounds.position.floor()),Vector2i(bounds.end.ceil()-bounds.position.floor())).intersection(Rect2i(Vector2i.ZERO,first.get_size()))
	var changed:=0
	for x in range(rect.position.x,rect.end.x):
		for y in range(rect.position.y,rect.end.y):
			if first.get_pixel(x,y)!=last.get_pixel(x,y):changed+=1
	return changed

func _changed_train_pixels(first:Image,last:Image,view,poses:Array)->int:
	var counted:=PackedByteArray()
	counted.resize(first.get_width()*first.get_height())
	var changed:=0
	for vehicle in poses:
		var frame:Dictionary=view.train_renderer.frame_for(vehicle.kind)
		var image:Image=frame.texture.get_image()
		var front:Vector2=view._world_to_screen(vehicle.front+Vector2.ONE*0.5)
		var rear:Vector2=view._world_to_screen(vehicle.rear+Vector2.ONE*0.5)
		var rotation:float=(front-rear).angle()-PI*0.5
		var registration:Transform2D=view.train_renderer.registration(frame,(front+rear)*0.5,rotation,view.train_renderer.texel_scale(view))
		registration.origin+=view.global_position
		var rectangle:Rect2=frame.get("draw_rect",Rect2(Vector2.ZERO,Vector2(image.get_size())))
		var bounds:=Rect2(registration*rectangle.position,Vector2.ZERO)
		for point in [rectangle.position,rectangle.end,Vector2(rectangle.position.x,rectangle.end.y),Vector2(rectangle.end.x,rectangle.position.y)]:bounds=bounds.expand(registration*point)
		var pixels:=Rect2i(Vector2i(bounds.position.floor()),Vector2i(bounds.end.ceil()-bounds.position.floor())).intersection(Rect2i(Vector2i.ZERO,first.get_size()))
		var inverse:=registration.affine_inverse()
		for x in range(pixels.position.x,pixels.end.x):
			for y in range(pixels.position.y,pixels.end.y):
				var index:int=y*first.get_width()+x
				if counted[index]!=0 or first.get_pixel(x,y)==last.get_pixel(x,y):continue
				var local:Vector2=inverse*(Vector2(x,y)+Vector2.ONE*0.5) # Pixel-center alpha sample.
				if not rectangle.has_point(local):continue
				var texel:Vector2=(local-rectangle.position)/rectangle.size*Vector2(image.get_size())
				if image.get_pixel(int(texel.x),int(texel.y)).a>0:
					counted[index]=1
					changed+=1
	return changed
