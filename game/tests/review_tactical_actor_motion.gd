extends SceneTree
# requires-native-renderer
# MIT. Native review frames of actor presentation motion at the shared50Hz step.
# Fixture only: groups are placed directly to show walking, melee, crouch and fade.
const OUT := "res://../.cache/actor-motion-frames"
func _initialize() -> void:
	OS.low_processor_usage_mode = false
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,800)
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: existing tactical fixture
	var model = preload("res://scripts/tactical_combat.gd").new()
	model.begin(wagons,47,rng)
	model.actors.clear()
	var centre: int = (model.center_offset()+160)/16 # field column under screen centre
	model.add_actor(0,centre-6,3,5,false,-1,2)
	model.add_actor(0,centre+6,2,5,false,-1,6)
	model.add_actor(0,centre-1,4,3,false,-1,8)
	model.add_actor(1,centre+1,4,6,false,-1,6)
	model.add_actor(0,centre-4,1,2,true,-1,2)
	var scene = preload("res://scripts/tactical_scene.gd").new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.open_battle(model)
	scene.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var planter = null
	for frame in 50*8: # source: eight seconds at the shared50Hz step
		if frame == 150:
			planter = model.add_actor(0,model.roof_cell(1,centre)+1,-1,4,false,1,8)
		if frame == 160 and planter != null: model.plant(planter.id,1)
		scene._physics_process(0.02)
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"/%04d.png" % frame))
	print("PASS: native actor motion frames written")
	quit()
