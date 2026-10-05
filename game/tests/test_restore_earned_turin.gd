extends SceneTree
# MIT. Real F5 snapshot11591; no state repair or reconstructed fixture.
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var saved=JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/turin11591-earned.json"))
	var app=preload("res://scripts/main.gd").new()
	app.game_audio.effects_enabled=false
	app.game_audio.music_enabled=false
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app.world_view.set_process(false)
	var saves=preload("res://scripts/session_saves.gd")
	var path=ProjectSettings.globalize_path("res://../reference-private/validation/turin11591-earned.json")
	check(saves.restore(app,path).ok,"actual earned Turin city restores through Main staging")
	check(app.journey.position==Vector2i(32,37) and app._city_panel.visible,"actual city location and menu are restored")
	check(app.journey._render_cursor<=app.journey._render_path.length,"restored cursor lies on the recomputed path")
	var before=app.journey.snapshot()
	var invalid: Dictionary=saved.journey.duplicate(true)
	invalid.render_cursor+=Vector2(invalid.render_path[-2][0],invalid.render_path[-2][1]).distance_to(Vector2(invalid.render_path[-1][0],invalid.render_path[-1][1]))
	check(not app.journey.restore(invalid),"cursor beyond another actual rail segment is rejected")
	check(app.journey.snapshot()==before,"rejected malformed save leaves current journey unchanged")
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("PASS: earned Turin save restores and invalid cursor remains atomic" if failures.is_empty() else "FAIL: earned Turin restore")
	quit(0 if failures.is_empty() else 1)
