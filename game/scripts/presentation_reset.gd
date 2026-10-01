extends RefCounted

# MIT. Transient authored effects never belong to a loaded or new session.
# Source: native restart/restore regression in review_engine_travel_effects.gd.
static func clear(app) -> void:
	var room = app.get("room_art")
	if room != null:
		room.living = preload("res://scripts/engine_living_effects.gd").new()
		room.queue_redraw()
	var view = app.get("world_view")
	if view != null and view.get("living") != null:
		view.living = preload("res://scripts/travel_living_effects.gd").new()
		view.queue_redraw()
	var boudoir = app.get("_boudoir_session")
	if boudoir != null and boudoir.launcher.scene != null:
		boudoir.launcher.scene.living = preload("res://scripts/rocket_living_effects.gd").new()
		boudoir.launcher.scene.queue_redraw()
