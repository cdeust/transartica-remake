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
	var x: float = 320+scene.shown_offset(side)-index*64-scene.camera
	var baseline := 63.0 if side == 0 else 192.0
	return {"texture":texture,"used":used,"factor":factor,"rect":Rect2(Vector2(x-width,baseline-extent.y),extent)}

static func event_point(scene, event: Dictionary) -> Vector2:
	if event.has("x"): return scene._field_point(event.x,event.y)
	var rect: Rect2 = wagon(scene,event.side,event.wagon).rect
	return rect.position+Vector2(rect.size.x/2,0)

# Topmost opaque texel per column of each wagon sprite (presentation only).
static var _profiles := {}
# source: authored median window; rejects narrow chimneys/domes under actor feet.
const SURFACE_WINDOW := 3.0

static func _profile(texture: Texture2D, used: Rect2) -> PackedFloat32Array:
	var key := texture.get_rid().get_id()
	if _profiles.has(key): return _profiles[key]
	var image := texture.get_image()
	var tops := PackedFloat32Array()
	for x in range(int(used.position.x),int(used.end.x)):
		var top := used.end.y
		for y in range(int(used.position.y),int(used.end.y)):
			if image.get_pixel(x,y).a >= 0.5:
				top = y
				break
		tops.append(top)
	_profiles[key] = tops
	return tops

static func surface_y(scene, side: int, index: int, x: float) -> float:
	var geometry := wagon(scene,side,index)
	var rect: Rect2 = geometry.rect
	var factor: float = geometry.factor
	# The damaged hull is what bears weight: holes and torn roofs lower the surface.
	var car: Dictionary = scene.state.trains[side][index]
	var tops: PackedFloat32Array
	if car.health >= 3: tops = _profile(geometry.texture,geometry.used)
	else: tops = scene.materials.support_profile(geometry.texture,side,index,car.health,geometry.used)
	var samples: Array[float] = []
	var first := int((clampf(x-SURFACE_WINDOW,rect.position.x,rect.end.x)-rect.position.x)/factor)
	var last := int((clampf(x+SURFACE_WINDOW,rect.position.x,rect.end.x)-rect.position.x)/factor)
	for column in range(clampi(first,0,tops.size()-1),clampi(last,0,tops.size()-1)+1):
		samples.append(tops[column])
	samples.sort()
	var top: float = samples[samples.size()/2]
	return rect.position.y+(top-geometry.used.position.y)*factor

# Wagon whose drawn body covers x; nearest body for coupler gaps.
static func wagon_at(scene, side: int, x: float) -> int:
	var best := -1
	var distance := INF
	for index in scene.state.trains[side].size():
		if scene.state.trains[side][index].class == scene.state.Setup.LOCOMOTIVE_COMPANION: continue
		var rect: Rect2 = wagon(scene,side,index).rect
		var gap := maxf(rect.position.x-x,x-rect.end.x)
		if gap < distance:
			distance = gap
			best = index
	return best

# Actor feet rest on the drawn roof; source slot x and rules stay unchanged.
static func roof_point(scene, side: int, slot: int) -> Vector2:
	var point: Vector2 = scene._roof_point(side,slot)
	var index := wagon_at(scene,side,point.x)
	if index < 0: return point
	var rect: Rect2 = wagon(scene,side,index).rect
	return Vector2(point.x,surface_y(scene,side,index,clampf(point.x,rect.position.x,rect.end.x)))

# One mount for drawing, flash and tracer origin. Oblique projection authored:
# side0 aims toward the viewer (muzzle face), side1 away (breech visible).
static func mount(scene, side: int, index: int, recoil := 0.0, reach := 0.0, resting := INF) -> Dictionary:
	var rect: Rect2 = wagon(scene,side,index).rect
	var x := rect.position.x+rect.size.x/2
	# source: authored ring depth, measured kind11/12 ring rim→centre ≈1.8 logical px.
	var base := Vector2(x,resting if is_finite(resting) else surface_y(scene,side,index,x)+1.8)
	var direction := Vector2(0,1 if side == 0 else -1)
	var body := base-direction*recoil
	return {"base":base,"body":body,"muzzle":body+direction*reach,"direction":direction}
