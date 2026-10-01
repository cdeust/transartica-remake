extends SceneTree
# MIT. Native presentation evidence using the source cannon hit function.
const Combat=preload("res://scripts/tactical_combat.gd")
const Weapons=preload("res://scripts/tactical_weapons.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var wagons=preload("res://scripts/train_wagons.gd").new()
	var rng=RandomNumberGenerator.new()
	rng.seed=420
	var state=Combat.new()
	state.begin(wagons,47,rng)
	var scene=preload("res://scripts/tactical_scene.gd").new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.open_battle(state)
	scene.set_physics_process(false)
	await process_frame
	# Original cannon alignment: relative32 at matching index targets enemy wagon.
	for index in [2,3]:
		for hit in (2 if index==2 else 1):
			Weapons._cannon(state,0,index)
	# Preserve real emitted impacts, with different ages for flame and smoke poses.
	state.ticks=16
	for event in state.events:
		scene.effects.append({"event":event.duplicate(),"born":state.ticks-(2 if event.wagon==2 else 16)})
		scene._impact_light(event)
	var pause=InputEventKey.new()
	pause.physical_keycode=KEY_P
	pause.pressed=true
	scene.handle_key(pause)
	assert(scene.paused)
	scene.queue_redraw()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	var path=ProjectSettings.globalize_path("res://../tasks/validation/tactical-impacts-native-20260930.png")
	assert(root.get_texture().get_image().save_png(path)==OK)
	print("PASS: native cannon health2/1 masks, authored impact/smoke/debris/light and pause input capture: "+path)
	quit()
