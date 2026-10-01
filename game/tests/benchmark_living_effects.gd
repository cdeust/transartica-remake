extends SceneTree
# requires-native-renderer
# MIT. Native A/B CPU submission cost at the authored peak working-set budget.
const Effects = preload("res://scripts/living_effects.gd")
class Surface extends Control:
	var effects
	var enabled := false
	var costs: Array = []
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		if enabled: effects.draw(self)
		costs.append(Time.get_ticks_usec()-start)


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280,800)
	var surface := Surface.new()
	surface.size = Vector2(1280,800)
	surface.effects = Effects.new()
	root.add_child(surface)
	assert(surface.effects.atlas.load_art())
	for index in Effects.MAX_EMITTERS:
		surface.effects.add("destroy",Vector2(index%16*75,index/16*85+50))
	assert(surface.effects.particles.items.size() == surface.effects.particles.LIMIT)
	await process_frame
	var timings := {}
	for mode in ["baseline","peak"]:
		surface.enabled = mode == "peak"
		surface.costs.clear()
		for frame in 60:
			surface.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
		timings[mode] = summary(surface.costs)
	var update: Array = []
	for tick in 120:
		var start := Time.get_ticks_usec()
		surface.effects.advance(Effects.STEP)
		update.append(Time.get_ticks_usec()-start)
	timings.update = summary(update)
	timings.emitters_budget = Effects.MAX_EMITTERS
	timings.particles_budget = surface.effects.particles.LIMIT
	timings.native_renderer = RenderingServer.get_video_adapter_name()
	timings.draw_measures = "CPU draw command submission, not GPU frame time"
	var file := FileAccess.open("res://../tasks/validation/living-effects-benchmark-20261001.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(timings,"\t")+"\n")
	file.close()
	print("PASS: native A/B living effects CPU microseconds "+JSON.stringify(timings))
	surface.queue_free()
	await process_frame
	quit()


func summary(samples: Array) -> Dictionary:
	samples.sort()
	return {"samples":samples.size(),"median_us":samples[samples.size()/2],"p95_us":samples[int((samples.size()-1)*0.95)],"maximum_us":samples[-1]}
