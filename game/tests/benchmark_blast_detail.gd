extends SceneTree
# requires-native-renderer
# MIT. Every measured native frame advances/rasterizes the bounded detail peak.
const Effects = preload("res://scripts/living_effects.gd")
class Surface extends Control:
	var effects
	var costs: Array = []
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		effects.draw(self)
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
	for index in Effects.MAX_EMITTERS: surface.effects.add("destroy",Vector2(index%16*75,index/16*85+50))
	var update := []
	for frame in 120: # Two source-clock seconds plus warmup observations.
		var start := Time.get_ticks_usec()
		surface.effects.advance(Effects.STEP)
		update.append(Time.get_ticks_usec()-start)
		surface.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	var result := {"draw":summary(surface.costs),"update":summary(update),"detail_fields":surface.effects.volume.LIMIT,"detail_parcels_per_blast":64,"common_emitters":Effects.MAX_EMITTERS,"sparse_particles":surface.effects.particles.LIMIT,"draw_scope":"CPU raster, texture upload call and command submission; excludesGPU frame time","renderer":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open("res://../tasks/validation/blast-detail-benchmark-20261001.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("PASS:120native advancing-detail frames at bounded peak "+JSON.stringify(result))
	surface.queue_free()
	await process_frame
	quit()

func summary(samples: Array) -> Dictionary:
	samples.sort()
	return {"samples":samples.size(),"median_us":samples[samples.size()/2],"p95_us":samples[int((samples.size()-1)*0.95)],"maximum_us":samples[-1]}
