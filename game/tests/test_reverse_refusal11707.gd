extends SceneTree
# MIT. Unmodified earned11686 plus normal source pre-entry dispatch.
# Prepared Main replay only; no native gameplay claim.
var errors: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var app=preload("res://scripts/main.gd").new()
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/reverse-refusal-11707-20261004/unused.SAV")
	app.game_audio.effects_enabled=false
	app.game_audio.music_enabled=false
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app.world_view.set_process(false)
	var path=ProjectSettings.globalize_path("res://../reference-private/validation/reverse-refusal11686-earned.json")
	var loaded=preload("res://scripts/session_saves.gd").restore(app,path)
	check(loaded.ok,"actual Main restores unmodified earned pre-stop11686")
	if loaded.ok:
		app.game_audio.effects_enabled=false
		app.game_audio.music_enabled=false
		if "--before" in OS.get_cmdline_user_args():
			# Baseline copied verbatim except its local script class name and
			# Render preload; source game and saved state remain unchanged.
			var before=load("res://../.cache/reverse-refusal-11707-20261004/before-journey.gd").new()
			before.network=app.network
			var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
			check(before.restore(saved.journey),"baseline restores exact11686 without releasing fields")
			app.journey=before
			app.world_view.journey=before
		if "--before" in OS.get_cmdline_user_args():
			# Verbatim pre-fix command capture and parity mutation; production
			# visibility is checked before executing this baseline command.
			check(app.world_view._cell_is_visible(42,32),"actual command is visible")
			load("res://../.cache/reverse-refusal-11707-20261004/before-switch-contact.gd").capture(app.world_view,Vector2i(42,32))
			check(app.network.toggle_switch(Vector2i(42,32)),"baseline actual11687 parity mutation")
		else:
			check(app.world_view.toggle_switch_at(Vector2i(42,32)),"actual11687 command changes42,32 from19 to18 before continuation")
			check(app.journey.reverse_switches.get("42,32",0)==9,"real partial occupied switch command latches measuredNEbranch")
			var known=app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0)
			var saves=preload("res://scripts/session_saves.gd")
			check(saves.save(app,app.save_path_override).ok and saves.restore(app,app.save_path_override).ok,"partial command saves/reloads through production staging")
			check(app.journey.reverse_switches.get("42,32",0)==9 and app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0)==known,"partial reload retains proved branch and all15known contacts")
			app.game_audio.effects_enabled=false
			app.game_audio.music_enabled=false
		var seen: Dictionary={}
		var prepared: Array[Vector2i]=[]
		var reached:=false
		while not (reached and app.journey.position==Vector2i(34,32) and app.journey.phase>=1):
			var key=str([app.journey.position,app.journey.phase,app.journey.distance_ticks,app.network.changed_cells()])
			if seen.has(key): check(false,"source replay cannot cycle");break
			seen[key]=true
			preload("res://scripts/reverse_contact_stop.gd").advance(app.world_view,app.journey,130)
			if app.journey.blocked:
				var cell: Vector2i=app.journey.physical_obstacle
				if app.journey.stop_reason=="special site":
					prepared.append(cell)
					preload("res://scripts/journey_session.gd")._handle_boundary(app,false)
					if not app.campaign.state.pending.is_empty():
						check(false,"source event requires player continuation; do not bypass it")
						break
					reached=reached or cell==Vector2i(45,25)
				if app.journey.blocked: break
		var poses=app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0)
		print("earned11686 prepared=",prepared," stop=",app.journey.physical_obstacle," logical=",app.journey.position," phase=",app.journey.phase," count=",poses.size()," rear=",poses[-1].rear)
		check(reached and app.journey.position==Vector2i(34,32) and app.journey.phase>=1,"occupied branch survives the actual34,32 source turn after preparing45,25")
		check(not app.journey.blocked and app.network.tile(Vector2i(45,25))!=-115,"normal source dispatcher reveals and releases actual hidden contact")
		check(poses.size()==21,"production dispatch retains21earned contacts")
		check(not prepared.has(Vector2i(49,33)),"no reconstructed distant station is presented as physical contact")
	app.game_audio.reset()
	if FileAccess.file_exists(app.save_path_override): DirAccess.remove_absolute(app.save_path_override)
	app.queue_free()
	await process_frame
	for error in errors: push_error(error)
	print("PASS: unchanged earned11686 Main replay retains occupied prefix and dispatches hidden45,25" if errors.is_empty() else "FAIL: earned11686 reconstructed branch refusal")
	quit(0 if errors.is_empty() else 1)
