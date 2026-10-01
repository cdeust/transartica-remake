extends RefCounted
# MIT. Actual cropped wagon draw registration for body-attached effects.
# Source: TacticalScene._train, measured TacticalWagonArt regions.

static func wagon(scene, side: int, index: int, original := false) -> Dictionary:
	var car: Dictionary = scene.state.trains[side][index]
	var kind: int = scene._enemy_type(car.class)
	if side == 0:
		var source_index := -1
		for slot in index+1:
			if scene.state.trains[0][slot].class != scene.state.Setup.LOCOMOTIVE_COMPANION: source_index += 1
		kind = scene.state.original[maxi(0,source_index)][0]
	var name := "wagon-%02d" % (kind if original or car.health > 0 else 25)
	var texture: Texture2D = scene.textures[name]
	var used: Rect2 = scene.texture_bounds[name]
	var width := 128.0 if car.class == scene.state.Setup.LOCOMOTIVE else 64.0
	var factor := minf(width/used.size.x,26.0/used.size.y)
	var extent := used.size*factor
	var x: float = 320+scene.state.offsets[side]-index*64-scene.camera
	var baseline := 63.0 if side == 0 else 192.0
	return {"texture":texture,"used":used,"factor":factor,"rect":Rect2(Vector2(x-width,baseline-extent.y),extent)}

static func event_point(scene, event: Dictionary) -> Vector2:
	if event.has("x"): return scene._field_point(event.x,event.y)
	var rect: Rect2 = wagon(scene,event.side,event.wagon).rect
	return rect.position+Vector2(rect.size.x/2,0)
