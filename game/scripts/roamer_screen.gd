extends "res://scripts/world_event_screen.gd"

# MIT. Authored art; TEXTEK23/27 question composition and73/83 hunt plaques.
func _load_scene() -> void:
	var name := "nomads" if mode == "nomads" else "mammoth-hunt"
	var path := "res://assets/world-events/%s.png" % name
	_scene = load(path) as Texture2D if ResourceLoader.exists(path) else null


func scene_bounds(box: Rect2) -> Rect2:
	# Authored composition: preserve the complete scene and its original aspect.
	# Source: Texture2D.get_size; uniform contain scale, no gameplay change.
	var dimensions := _scene.get_size()
	var scale := minf(box.size.x / dimensions.x, box.size.y / dimensions.y)
	var size := dimensions * scale
	return Rect2(box.position + (box.size - size) / 2, size)


func _draw_scene(box: Rect2) -> void:
	draw_texture_rect(_scene, scene_bounds(box), false)
