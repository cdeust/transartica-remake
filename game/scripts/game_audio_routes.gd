extends RefCounted
# MIT. Scene requests only at source transitions, never on rendering refresh.
# Sources: campaign-audio-source-20261001.md; ecs-audio-independent.md.
const Extensions=preload("res://scripts/session_save_extensions.gd")

static func available(app)->bool:
	return Extensions.has_component(app,"game_audio")

static func journey(app)->void:
	# YODA0xb54/0xd04: original preference gates NEW scene score selection.
	if available(app) and app.game_audio.music_enabled:
		app.game_audio.play_journey()

static func city(app,index:int)->void:
	if available(app) and app.game_audio.music_enabled:
		# Preserve signed TABLE field2; selector checks are not abs(kind).
		var kind:int=app.world_data.cities[index].kind
		# GLIEU0x33 negates visited kind before YODA0x1070 compares signed1/2.
		if index in app.world.visited_cities:kind=-absi(kind)
		app.game_audio.play_city(kind,index)

static func departure(app)->void:
	if available(app):
		app.game_audio.son(1) # YODA18c7/18cc before source departure18e3.
	journey(app)

static func worksite(app)->void:
	if available(app) and app.game_audio.music_enabled:
		app.game_audio.play_worksite() # YODA0x126a workshop,0x165b accepted mine.

static func new_game(app)->void:
	if available(app):
		app.game_audio.new_game_reset() # START retains OPTION25912 preference.
		journey(app)

static func toggle_music(app,reception)->void:
	if available(app):
		reception.music_enabled=app.game_audio.toggle_original_music()
		reception.queue_redraw() # OPTION action3 writes flag/overlay; no cdelmusic.

static func sync_options(app,reception)->void:
	if available(app):
		reception.music_enabled=app.game_audio.music_enabled
		reception.queue_redraw()
