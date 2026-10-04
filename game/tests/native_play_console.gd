extends SceneTree
# MIT. Validation console: normal scene, live cadence, viewport player inputs.
# source: owner3Oct continuous-game correction and recorded native actions.
const DIRECTORY := "res://../.cache/native-play/"
const EVIDENCE := "res://../tasks/validation/continuous-play-20261003/"
var app
var busy := false
var last_id := -1
var started := Time.get_ticks_msec()
var pointer_trace: Array = []

func _initialize() -> void:
	var old_command = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"command.json")) if FileAccess.file_exists(DIRECTORY+"command.json") else {}
	last_id = int(old_command.get("id",-1))+1 if old_command is Dictionary else 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	call_deferred("_start")

func _start() -> void:
	app = load("res://main.tscn").instantiate()
	app.save_path_override = ProjectSettings.globalize_path(DIRECTORY + "save.json")
	root.add_child(app)
	app.world_view.gui_input.connect(_trace_pointer)
	await process_frame
	await process_frame
	await _record(last_id, "normal-scene-boot")
	process_frame.connect(_poll)

func _poll() -> void:
	if busy or app == null: return
	var path := DIRECTORY + "command.json"
	if not FileAccess.file_exists(path): return
	var command = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not command is Dictionary or int(command.get("id", -1)) <= last_id: return
	last_id = int(command.id)
	busy = true
	call_deferred("_command", command)

func _command(command: Dictionary) -> void:
	pointer_trace.clear()
	for action in command.get("inputs", []):
		if action.has("text"):
			for character in String(action.text):
				await _key(OS.find_keycode_from_string(character.to_upper()),character.unicode_at(0))
		elif action.has("key"):
			await _key(OS.find_keycode_from_string(action.key))
		elif action.has("wheel"):
			# Real viewport wheel input; inspection never edits camera/model state.
			var event := InputEventMouseButton.new()
			event.position = Vector2(action.point[0],action.point[1])
			event.button_index = MOUSE_BUTTON_WHEEL_UP if action.wheel == "up" else MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = true
			root.push_input(event,true)
			await process_frame
			event.pressed = false
			root.push_input(event,true)
		elif action.has("click"):
			var point := Vector2(action.click[0], action.click[1])
			var before: Vector2 = app.world_view._screen_to_world(point-app.world_view.global_position)
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			root.push_input(event, true)
			await process_frame
			var after: Vector2 = app.world_view._screen_to_world(point-app.world_view.global_position)
			pointer_trace.append({"point":str(point),"world_before":str(before),"world_release":str(after),"held":app.world_view._left_held})
			event.pressed = false
			root.push_input(event, true)
		await process_frame
	await _record(int(command.id), command.get("label", "observe"))
	busy = false
	if command.get("quit", false): quit()

func _trace_pointer(event: InputEvent) -> void:
	if not event is InputEventMouse: return
	pointer_trace.append({"event":event.get_class(),"local":str(event.position),
		"world":str(app.world_view._screen_to_world(event.position)),
		"dragging":app.world_view._dragging,"held":app.world_view._left_held})

func _key(code: int, unicode := 0) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func _record(id: int, label: String) -> void:
	await process_frame
	var prefix := EVIDENCE + "%03d" % id
	# Observations poll live state; player actions retain rendered evidence.
	if not label.begins_with("observe-"):
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(prefix + ".png")
	var controls: Array = []
	_visible_controls(app, controls)
	var lag: float = maxf(0.0,app.journey.distance_travelled()-app.world_view._visual_arc)
	var rendered_poses: Array = app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,lag)
	var rendered: int = rendered_poses.size()
	# Read-only contact evidence for the owner-approved reverse obstacle stop.
	var contacts: Array = []
	for pose in app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0):
		contacts.append({"kind":pose.kind,"front":[pose.front.x,pose.front.y],"rear":[pose.rear.x,pose.rear.y]})
	_capture_zero(prefix,id,rendered)
	var state := {"id":id,"label":label,"process_id":OS.get_process_id(),"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"release":not OS.is_debug_build(),"audio":app.game_audio.snapshot(),"music_playing":app.game_audio.music.playing,
		"position":str(app.journey.position),"heading":app.journey.heading,"reverse":app.journey.reverse,
		"blocked":app.journey.blocked,"cycles":app.engine.cycles,"paused":app.session.paused,
		"combat_paused":app.encounters.manual_scene.paused,
		"speed":app.engine.speed,"regulator":app.engine.regulator,"brake":app.engine.brake,
		"heat":app.engine.heat,"steam":app.engine.pressure_reserve,"lignite":app.engine.lignite,
		"screen":_screen(),"intro_tick":app._boot.intro.tick if app._boot.intro != null else -1,
		"anthracite":app.engine.anthracite,"lignite_rate":app.engine.lignite_rate,
		"anthracite_rate":app.engine.anthracite_rate,"event":app.engine.event_message,
		"rendered_vehicles":rendered,"rendered_head":str(app.journey.fractional_position()),
		"logical_head":str(app.journey._logical_fractional_position()),
		"phase":app.journey.phase,"distance_ticks":app.journey.distance_ticks,
		"vehicle_contacts":contacts,
		"vehicle_frames":_frame_diagnostics(rendered_poses),
		"render_lag":lag,"visual_arc":app.world_view._visual_arc,
		"obstacle_cell":str(app.journey.obstacle_cell()) if app.journey.has_method("obstacle_cell") else str(app.journey.next_cell()),
		"view_rect":str(app.world_view.get_global_rect()),"zoom":app.world_view.zoom,
		"following_train":app.world_view.following_train,"inspecting_map":app.world_view.inspecting_map,
		"calendar":app.calendar.snapshot(),"vehicles":app.world_view.train_renderer.poses(
			app.world_view,app.journey,app.world_view.consist,0.0).size(),
		"switches":_visible_switches(),
		"pointer_trace":pointer_trace,
		"controls":controls}
	var file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "\t"))
	var latest := FileAccess.open(DIRECTORY + "state.tmp", FileAccess.WRITE)
	latest.store_string(JSON.stringify(state, "\t"))
	latest.close()
	DirAccess.rename_absolute(DIRECTORY+"state.tmp",DIRECTORY+"state.json")
	print("NATIVE_PLAY ", id, " ", label, " ", state.position, " cycles=", state.cycles)

func _frame_diagnostics(poses: Array) -> Array:
	# Observe the same frame selection, registration and tint as Renderer.draw.
	# This records availability and geometry; pose counts do not prove pixels.
	var result: Array = []
	var view = app.world_view
	var renderer = view.train_renderer
	for pose in poses:
		var frame: Dictionary = renderer.frame_for(pose.kind)
		var item := {"pose_kind":pose.kind,"frame_available":not frame.is_empty(),
			"front_screen":str(view._world_to_screen(pose.front + Vector2(0.5,0.5))),
			"rear_screen":str(view._world_to_screen(pose.rear + Vector2(0.5,0.5))),
			"texel_scale":renderer.texel_scale(view)}
		if not frame.is_empty():
			var texture: Texture2D = frame.get("texture")
			item["frame_kind"] = pose.kind
			item["texture_available"] = texture != null
			if texture != null:
				item["texture_class"] = texture.get_class()
				item["texture_size"] = str(texture.get_size())
				item["texture_path"] = texture.resource_path
				if texture is AtlasTexture:
					item["atlas_region"] = str(texture.region)
					item["atlas_available"] = texture.atlas != null
					if texture.atlas != null:
						item["atlas_path"] = texture.atlas.resource_path
						item["atlas_size"] = str(texture.atlas.get_size())
			item["draw_rect"] = str(frame.get("draw_rect",frame.get("bounds")))
			item["frame_front"] = str(frame.get("front"))
			item["frame_rear"] = str(frame.get("rear"))
			var cell := Vector2i(Vector2(pose.rail_midpoint).round())
			var code: int = view._tile_code(cell.x,cell.y)
			item["tint_tile"] = code
			item["tint"] = str(preload("res://scripts/underground_visual.gd").train_tint(code,renderer.underground_alpha))
		result.append(item)
	return result

func _capture_zero(prefix: String, id: int, rendered: int) -> void:
	if rendered != 0 or _screen() != "map": return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(prefix+".png")
	var snapshot := FileAccess.open(DIRECTORY+"zero-poses-%d.json" % id,FileAccess.WRITE)
	snapshot.store_string(JSON.stringify({"journey":app.journey.snapshot(),"network":app.network.snapshot()},"\t"))

func _screen() -> String:
	if app._boot.intro != null and app._boot.intro.visible: return "intro"
	if app.get_node("KeyboardSettings").visible: return "keyboard"
	var reception = app._boudoir_session.reception
	if reception.visible: return "load-book" if reception.loader.visible else "options"
	if app.encounters.manual_scene.visible: return "combat"
	if app.encounters.report.visible: return "combat-report"
	if app.campaign.screen.visible: return "campaign-" + app.campaign.screen.scene
	# Native8650: a nomad question pauses and hides the map, but is not the engine.
	if app._world_session.roamer_screen.visible: return "world-" + app.roamers.pending
	if app._world_session.mine_screen.visible: return "world-mine"
	if app._world_session.workshop.visible: return "world-workshop"
	if app.works_dialog.visible: return "works"
	if app._city_panel.visible: return "city-trade" if app._city_panel._trade_box.visible else "city"
	if app._boudoir_session.overview.visible: return "overview"
	if app._modal.visible: return "map"
	if app._boudoir_session.view.visible: return "boudoir"
	return "engine"

func _visible_switches() -> Array:
	var result: Array = []
	if not app._modal.visible: return result
	var view = app.world_view
	for x in app.network.WIDTH:
		for y in app.network.HEIGHT:
			var cell := Vector2i(x,y)
			if not app.network.is_switch(cell): continue
			var point: Vector2 = view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5)
			if Rect2(Vector2.ZERO,view.size).has_point(point):
				point += view.global_position
				result.append({"cell":[x,y],"tile":app.network.tile(cell),"click":[point.x,point.y]})
	return result

func _visible_controls(node: Node, result: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		if node is Button or node is Label or node is LineEdit:
			result.append({"path":str(node.get_path()),"text":node.text,
				"rect":str(node.get_global_rect())})
	for child in node.get_children(): _visible_controls(child, result)
