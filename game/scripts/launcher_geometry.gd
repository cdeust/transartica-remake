extends RefCounted

# MIT. Exact BERTA0x460..4c3 and CARTE0x15b0..1a69 integer tables.
# CARTE uses hand-authored coefficients, including its asymmetric entries.
const ANGLES := [0,11,23,34,45,57,68,79,90,101,112,124,135,146,158,169,180,192,203,214,225,237,248,259,270,281,292,304,315,326,337,349]
const VECTORS := [[100,0],[98,19],[92,39],[83,56],[71,71],[54,84],[37,93],[19,98],[0,100],[-19,98],[-37,93],[-56,83],[-71,71],[-83,56],[-93,38],[-98,19],[-100,0],[-98,-21],[-92,-39],[-83,-56],[-71,-71],[-54,-84],[-37,-93],[-19,-98],[0,-100],[19,-98],[37,-93],[56,-83],[71,-71],[83,-56],[92,-39],[98,-19]]
const GROUPS := [0,0,0,1,1,1,2,2,2,2,2,3,3,3,4,4,4,4,4,5,5,5,6,6,6,6,6,7,7,7,0,0]


static func angle(bearing: int) -> int:
	var base: int = bearing * 113 / 10
	if bearing >= 17:
		base -= 1
	return posmod(90 - base,360)


static func calculate(bearing: int, distance: int, origin: Vector2i, enemies) -> Dictionary:
	var index := ANGLES.find(angle(bearing))
	var length: int = distance * 16 / 7 if distance < 2000 else distance / 7 * 16
	var vector: Array = VECTORS[index]
	var dx: int = vector[0] * length / 100 if length < 300 else length / 100 * vector[0]
	var dy: int = vector[1] * length / 100 if length < 300 else length / 100 * vector[1]
	var nominal := origin + Vector2i(dx / 16,-dy / 16)
	var radius: int = absi(length) / 96
	var target := -1
	for slot in 30: # CARTE0x1958: first strict-square match, STATE!=2 (not is_active).
		var point: Vector2i = enemies.cell(slot)
		if point.x < nominal.x+radius and point.x > nominal.x-radius and point.y < nominal.y+radius and point.y > nominal.y-radius and enemies.slots[slot][0] != 2:
			target = slot
			dx = (point.x-origin.x)*16
			dy = -(point.y-origin.y)*16
			break
	var divisor: int = length / 8
	var sx: int = dx / divisor
	var sy: int = dy / divisor
	# Canonical ALIS odiv has no zero guard. Refuse undefined source arithmetic.
	if sx == 0 and sy == 0:
		return {}
	var count: int = absi(dx / sx) if absi(sx) > absi(sy) else absi(dy / sy)
	return {"origin":[origin.x,origin.y],"delta":[dx,dy],"step":[sx,sy],"count":count,"target":target,"group":GROUPS[index],"record":enemies.slots[target].duplicate() if target >= 0 else []}


static func screen(geometry: Dictionary, camera: Vector2i, tick: int, final := false) -> Vector2i:
	var offset: Array = geometry.delta if final else [geometry.step[0]*tick,geometry.step[1]*tick]
	# CARTE0x1cfe z becomes logical y=199-z.
	return Vector2i(offset[0]+(geometry.origin[0]-camera.x)*16+7,7+(geometry.origin[1]-camera.y)*16-offset[1])
