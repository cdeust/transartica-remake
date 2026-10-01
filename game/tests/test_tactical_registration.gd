extends SceneTree
# requires-native-renderer
# MIT. Regression evidence: tasks/validation/main-regression-20261001.md.
# Actual input, source charge destruction and rendered pixels are the oracles.
const Scene = preload("res://scripts/tactical_scene.gd")
const Geometry = preload("res://scripts/tactical_effects_geometry.gd")
# Opaque native probes expose the transform left by real train/label drawing.
# Nearest texture sampling can choose adjacent texels at fractional source rows;
# solid geometry and glyph positions provide an exact registration oracle.
class RegistrationScene extends Scene:
	func _draw_ground() -> void:
		super._draw_ground()
		# Isolate actual additive light on a solid surface from texture resampling.
		draw_rect(Rect2(250,68,60,23),Color.BLACK)
	func _train(side: int, baseline: float) -> void:
		super._train(side,baseline)
		draw_rect(Rect2(16,70 if side == 0 else 180,3,3),Color.MAGENTA if side == 0 else Color.GREEN)
	func _draw_light() -> void:
		super._draw_light()
		# Exact probe after the actual light draw, using its retained transform.
		light_layer.draw_rect(Rect2(254,70,3,3),Color.CYAN)
var scene
var failures: Array[String] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func capture() -> Image:
	scene.queue_redraw()
	await process_frame
	await process_frame # child additive draw is queued by the parent draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var bounds: Rect2 = scene.canvas_rect()
	event.position = bounds.position+(point+scene.living.shake_offset())*bounds.size/Vector2(320,200)
	scene._gui_input(event)

func run() -> void:
	root.size = Vector2i(1280,800) # source: native regression reproduction viewport
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: existing tactical fixture
	var model = preload("res://scripts/tactical_combat.gd").new()
	model.begin(wagons,47,rng)
	model.offsets = [448,448]
	scene = RegistrationScene.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.open_battle(model)
	scene.set_physics_process(false)
	scene.pace = 1.0
	await process_frame
	model.actors.clear()
	scene.camera = 448
	model.velocities[0] = 4
	model.remainder = model.STEP_SECONDS*0.5
	for jolt in [0.0,1.5]: # source: existing LivingEffects maximum jolt
		scene.living.shake = jolt
		for index in model.trains[0].size():
			if model.trains[0][index].class == model.Setup.LOCOMOTIVE_COMPANION: continue
			var body: Rect2 = Geometry.wagon(scene,0,index).rect
			var point := Vector2(body.end.x-0.5,body.get_center().y)
			if point.x < 0 or point.x > 320 or point.y < 38: continue
			click(point)
			check(scene.selected_wagon == index,"displayed wagon %d selected during interpolation/jolt %s" % [index,jolt])
	model.remainder = 0
	model.velocities[0] = 0
	var actor = model.add_actor(0,29,-1,5,false,1,8)
	check(model.plant(actor.id,1),"real charge planted")
	for sweep in 5: # source: reproduction's source charge countdown
		model.scan_side = 0
		model.scan = model.columns*7-1
		scene._physics_process(model.STEP_SECONDS)
	check(model.trains[1][7].health == 0,"source charge actually destroyed enemy wagon7")
	var wreck: Dictionary = Geometry.wagon(scene,1,7)
	var texture: Texture2D = scene.materials.texture_for(wreck.texture,1,7,0)
	check(texture.get_size() == wreck.texture.get_size(),"wreck material agrees with authored crop after fragment creation")
	var front: Texture2D = scene.materials.front_for(1,7,0)
	check(front.get_size() == wreck.texture.get_size(),"front wall uses wreck source")
	var original: Dictionary = Geometry.wagon(scene,1,7,true)
	var original_damage: Texture2D = scene.materials.texture_for(original.texture,1,7,0)
	check(original_damage.get_size() == original.texture.get_size(),"original debris retains original source")
	check(not scene.materials.fragment_colors("1/7/0").is_empty(),"removed material colors available")
	var full: PackedFloat32Array = scene.materials.support_profile(wreck.texture,1,7,0,wreck.used)
	var crop: Rect2 = wreck.used
	crop.size.x /= 2
	var partial: PackedFloat32Array = scene.materials.support_profile(wreck.texture,1,7,0,crop)
	check(full.size() == int(wreck.used.size.x) and partial.size() == int(crop.size.x),"bearing profiles respect source and crop")
	# Render the same paused world with and without Opus' existing jolt.
	# Exact probes and real glyph interiors verify the retained draw transforms.
	model.actors.clear()
	model.charges.clear()
	scene.camera = 448
	scene.living.clear()
	scene.living.add("cannon",Vector2(280+scene.camera,80),Vector2.DOWN)
	scene.living.clock = 0
	scene.living.shake = 0
	var snapshot := JSON.stringify(model.snapshot())
	var still := await capture()
	scene.living.shake = 1.5
	var shifted := await capture()
	check(still.save_png(ProjectSettings.globalize_path("res://../.cache/tactical-registration-still.png")) == OK,"native baseline capture saved")
	check(shifted.save_png(ProjectSettings.globalize_path("res://../.cache/tactical-registration-shaken.png")) == OK,"native shaken capture saved")
	var delta := Vector2i(scene.living.shake_offset()*4)
	var different := 0
	# Pixel-perfect probes after each real train's labels and the actual light
	# draw. The halo texture also has fractional-source nearest sampling: the
	# earlier capture differed only on native rows288/351,91 pixels each.
	# Opaque geometry tests registration without byte-comparing those texels.
	# No error tolerance is introduced.
	for region in [Rect2i(15*4,69*4,5*4,5*4),Rect2i(15*4,179*4,5*4,5*4),Rect2i(253*4,69*4,5*4,5*4)]:
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				if still.get_pixel(x,y) != shifted.get_pixel(x+delta.x,y+delta.y): different += 1
	check(different == 0,"native world/additive draw probes translate together; differing pixels=%d" % different)
	check(still.get_pixel(255*4,71*4) == Color.CYAN,"actual additive draw probe visible")
	var glyph_pixels := 0
	for y in range(27*4,33*4): # source: _train label baseline32, font_size4
		for x in range(320*4):
			if still.get_pixel(x,y) == Scene.GOLD:
				glyph_pixels += 1
				check(shifted.get_pixel(x+delta.x,y+delta.y) == Scene.GOLD,"world glyph pixel follows jolt")
	check(glyph_pixels > 0,"actual world glyph interiors present in native capture")
	check(JSON.stringify(model.snapshot()) == snapshot,"jolt/input/capture leave source state unchanged")
	scene.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: interpolated/shaken clicks, actual destroyed wreck cache/front/debris/crops, native world-label-light translation and source invariance")
	quit(0 if failures.is_empty() else 1)
