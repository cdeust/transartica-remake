extends RefCounted

# MIT. Original MAIN boot precedes OPTION; programmatic fixtures opt out.
const Intro = preload("res://scripts/startup_intro.gd")
var intro
var _processing := true


func restore_after_layout(app) -> void:
	await app.get_tree().process_frame
	app.world_view.fit_discovered()
	app._restore_view()
	app._update_status()
	if not app.play_startup_intro:
		return
	app.session.paused = true
	_processing = app.is_processing()
	app.set_process(false) # Clock/event dispatch waits for the original boot owner.
	intro = Intro.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.z_index = 100 # Source boot is exclusive; artwork covers restored scene.
	app.add_child(intro)
	intro.completed.connect(_complete.bind(app))
	intro.start(app.game_audio)


func _complete(app) -> void:
	app._open_panel("options")
	app.move_child(app._boudoir_session.reception, app.get_child_count() - 1)
	app.session.paused = true
	app.set_process(_processing)
