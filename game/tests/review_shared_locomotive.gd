extends SceneTree

# MIT. Native artwork acceptance fixture, not earned campaign progression.
# Source: owner 1 October locomotive consistency direction; source story screens.
var app

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	_run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1280,800)
	app=preload("res://scripts/main.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/hero-review-unused.SAV")
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	app.game_audio.set_process(false)
	app.game_audio.reset()
	app._open_panel("map")
	var renderer=app.world_view.train_renderer
	var hero:Dictionary=renderer.frame_for("locomotive")
	assert(hero.texture is AtlasTexture and hero.texture.atlas.resource_path.ends_with("locomotive-hero.png"))
	assert(is_equal_approx(hero.draw_rect.size.y,hero.front.distance_to(hero.rear)))
	await _capture("travel")
	app._boudoir_session.leave()
	app._modal.hide()
	for name in ["urga","slope","whale","sun-overcast","sun-restored","wolf","mole"]:
		app.campaign.screen.present(name,["LOCOMOTIVE ART REVIEW"])
		await _capture(name)
	app.campaign.screen.hide()
	var state=preload("res://scripts/tactical_combat.gd").new()
	var rng=RandomNumberGenerator.new()
	rng.seed=420 # source: repeatable tactical scene review fixture.
	state.begin(app.wagons,47,rng)
	var scene=app.encounters.manual_scene
	scene.open_battle(state)
	scene.paused=true
	# Native view places the source leading engine slots inside the viewport.
	scene.camera=state.offsets[0]+64
	scene.queue_redraw()
	await _capture("combat")
	scene.hide()
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	print("PASS: native shared locomotive travel, common panel, combat and seven story depictions")
	quit()

func _capture(name:String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	assert(image.get_pixel(image.get_width()/2,image.get_height()/2)!=image.get_pixel(0,0))
	assert(image.save_png(ProjectSettings.globalize_path("res://../tasks/validation/locomotive-%s-native.png" % name))==OK)
