extends SceneTree
# requires-native-renderer
# MIT. Native review frames of staged trooper actions with the model frozen:
# a group wiped out man by man, a dynamite plant on the top train, a boarding
# climb onto it. Fixture only; groups and the melee report are placed directly.
const OUT := "res://../.cache/rig/actions"
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
	var scene = preload("res://scripts/tactical_scene.gd").new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.open_battle(model)
	scene.set_physics_process(false)
	var centre: int = (model.center_offset()+160)/16 # field column under screen centre
	var doomed = model.add_actor(0,centre-4,3,4,false,-1,2)
	var victor = model.add_actor(1,centre-2,3,5,false,-1,6)
	var planter = model.add_actor(0,model.roof_cell(0,centre+2),-1,3,false,0,8)
	var boarder = model.add_actor(0,centre+6,6,2,false,-1,8)
	var lone_back = model.add_actor(0,centre-9,5,1,false,-1,2) # isolated deaths, one of each fall
	var lone_forward = model.add_actor(0,centre-7,1,1,false,-1,6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var clashes := 0
	for frame in 50*6: # source: six seconds at the shared50Hz step
		if frame == 25: # melee: the doomed group is wiped out
			model.actors.erase(doomed)
			scene.actor_motion.melee({"kind":"melee","x":victor.x,"y":victor.y})
		if frame == 40: model.plant(planter.id,1)
		if frame == 120 or frame == 170: # isolated man struck down; the fall is pinned to show both
			var victim = lone_back if frame == 120 else lone_forward
			model.actors.erase(victim)
			scene.actor_motion.melee({"kind":"melee","x":victor.x,"y":victor.y})
			scene._advance_visual(0.02)
			scene.actor_motion.bodies[-1].kind = 0 if frame == 120 else 1
		if frame == 60:
			boarder.roof = 0
			boarder.x = model.roof_cell(0,boarder.x)
			boarder.y = -1
		scene._advance_visual(0.02)
		clashes += scene.layout_clashes()
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"/%04d.png" % frame))
	print("label clashes over the fixture: %d" % clashes)
	print("PASS: staged trooper action frames written")
	quit()
