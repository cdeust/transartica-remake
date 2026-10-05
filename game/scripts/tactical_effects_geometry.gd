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
	# Source: combat_setup.player_roster WDECOR0614..0652 reserves companion25;
	# enemy_composition WDECOR0723..072d puts real tender8 in slot1.
	# Keep the authored engine scale; only the player reserves a companion slot.
	# An enemy's real tender occupies the next slot, so the engine extends forward.
	var span := width
	if car.class == scene.state.Setup.LOCOMOTIVE:
		var has_companion: bool = index+1 < scene.state.trains[side].size() and scene.state.trains[side][index+1].class == scene.state.Setup.LOCOMOTIVE_COMPANION
		if not has_companion: span = 64.0
	return {"texture":texture,"used":used,"factor":factor,"rect":Rect2(Vector2(x-span,baseline-extent.y),extent)}

static func event_point(scene, event: Dictionary) -> Vector2:
	if event.has("x"): return scene._field_point(event.x,event.y)
	var rect: Rect2 = wagon(scene,event.side,event.wagon).rect
	return rect.position+Vector2(rect.size.x/2,0)

# Topmost opaque texel per column of each wagon sprite (presentation only).
static var _profiles := {}
# source: authored median window; rejects narrow chimneys/domes under actor feet.
const SURFACE_WINDOW := 3.0

static func _profile(texture: Texture2D, used: Rect2) -> PackedFloat32Array:
	var key := "%s/%s" % [texture.get_rid().get_id(),used]
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

# The drawn roof under x: the topmost opaque texel of that column of the wagon
# sprite (no median window), so feet placed on it touch the picture exactly.
static func drawn_y(scene, side: int, index: int, x: float) -> float:
	var geometry := wagon(scene,side,index)
	var rect: Rect2 = geometry.rect
	var car: Dictionary = scene.state.trains[side][index]
	var tops: PackedFloat32Array = _profile(geometry.texture,geometry.used) if car.health >= 3 else scene.materials.support_profile(geometry.texture,side,index,car.health,geometry.used)
	var column := clampi(int((clampf(x,rect.position.x,rect.end.x)-rect.position.x)/geometry.factor),0,tops.size()-1)
	return rect.position.y+(tops[column]-geometry.used.position.y)*geometry.factor

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
	return roof_point_at(scene,side,slot)

# Fractional slot for actors gliding between roof cells (presentation only).
static func roof_point_at(scene, side: int, slot: float) -> Vector2:
	var point: Vector2 = scene._roof_point(side,0)-Vector2(slot*16,0)
	var index := wagon_at(scene,side,point.x)
	if index < 0: return point
	var rect: Rect2 = wagon(scene,side,index).rect
	return Vector2(point.x,surface_y(scene,side,index,clampf(point.x,rect.position.x,rect.end.x)))

# Roof surface point under a screen x (clamped to its wagon), logical px.
static func roof_point_x(scene, side: int, x: float) -> Vector2:
	return roof_point_at(scene,side,(scene._roof_point(side,0).x-x)/16.0)

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
