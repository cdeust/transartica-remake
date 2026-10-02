extends SceneTree
# requires-native-renderer
# MIT. Native review frames of staged mammoth actions with the model frozen. Three
# phases of 8 s, each walking a group three cells, stopping, taking melee reports
# and dying: A bare player mammoth (the deploy case, count 1); B enemy mounted
# mammoth (count 5) whose riders step onto the player's roof (0x123a) before it is
# worn down to a bare beast and killed; C player mammoth carrying merged infantry
# (merge limit 31, 0x31f9). Fixture only: cells and melee reports are placed
# directly, at the source pace of one cell per scan (1.12 s for a player mammoth).
const OUT := "res://../.cache/mammoth/actions"
const PHASE := 400 # frames per phase, 50 Hz
const WALK_FIRST := 10 # frame of the first one-cell step
const CELL_FRAMES := 56 # source: scan period 14 ticks of 0.08 s (tactical_combat.gd STEP_SECONDS)
const WALK_CELLS := 3

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
	var stop := 0 # field column where the mammoth halts: its roof slot is 4, above the player's second wagon
	for x in model.columns:
		if model.roof_cell(0,x) == 4: stop = x
	scene.camera = float((stop-1)*16-model.center_offset()-160) # source: _field_point; the walk is centred on screen
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var group = null
	var foe = null
	var step := 1
	for frame in PHASE*3:
		var local := frame%PHASE
		var phase := frame/PHASE
		if local == 0:
			model.actors.clear()
			scene.actor_motion.clear()
			step = -1 if phase == 1 else 1
			var side := 1 if phase == 1 else 0
			group = model.add_actor(side,stop-step*WALK_CELLS,5,[1,5,4][phase],true,-1,6 if step < 0 else 2)
			foe = null
		var walked := clampi((local-WALK_FIRST)/CELL_FRAMES+1 if local >= WALK_FIRST else 0,0,WALK_CELLS)
		group.x = stop-step*(WALK_CELLS-walked)
		if local == 178: # standing: the attacker closes from the mammoth's front
			foe = model.add_actor(1-group.side,stop+step*2,5,3,false,-1,6 if step > 0 else 2)
		if phase == 0:
			if local == 210: scene.actor_motion.melee({"kind":"melee","x":foe.x,"y":foe.y}) # the beast is struck, survives
			if local == 330: model.actors.erase(group)
		if phase == 1:
			if local == 200: # riders step off onto the player's roof, a new enemy roof group
				model.add_actor(1,model.roof_cell(0,group.x),-1,2,false,0,2)
				group.count -= 2
			if local == 250: _strike(scene,foe,group,2)
			if local == 300: _strike(scene,foe,group,2)
			if local == 350: model.actors.erase(group)
		if phase == 2:
			if local == 220: _strike(scene,foe,group,1)
			if local == 280: _strike(scene,foe,group,2)
			if local == 340: model.actors.erase(group)
		scene._advance_visual(0.02)
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"/%04d.png" % frame))
		if local%50 == 0 and is_instance_valid(group): print("f%d phase %d group at %s" % [frame,phase,scene.actor_motion.point(scene,group)])
	print("PASS: staged mammoth action frames written")
	quit()

# One melee report: the foe strikes, the group loses `lost` men (riders, never the beast).
func _strike(scene, foe: Dictionary, group: Dictionary, lost: int) -> void:
	group.count = maxi(1,group.count-lost)
	scene.actor_motion.melee({"kind":"melee","x":foe.x,"y":foe.y})
