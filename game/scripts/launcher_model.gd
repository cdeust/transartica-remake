extends RefCounted

# MIT. BERTA aiming/arming/launch and CARTE missile continuation.
const Geometry = preload("res://scripts/launcher_geometry.gd")
var bearing := 0
var digits := [0,0,5,0]
var phase := "aim"
var cursor := 0
var ascent := 0
var ascent_step := 4
var geometry: Dictionary = {}
var camera := Vector2i.ZERO
var scroll := Vector2i.ZERO
var scroll_left := 0
var status := 1
var removed := false
var accumulator := 0.0


func distance() -> int:
	return digits[0]*1000+digits[1]*100+digits[2]*10+digits[3]


func action(code: int, origin: Vector2i, enemies) -> bool:
	if phase == "aim":
		if code in [101,102]:
			bearing = posmod(bearing+(-1 if code == 101 else 1),32)
		elif code in [103,104,105,106]:
			var index := code-103
			digits[index] = (digits[index]+1)%10
			if distance() < 50:
				digits[2] = 5
		elif code == 107:
			phase = "arming"
			cursor = 0
		else:
			return false
	elif phase == "armed":
		if code == 107:
			phase = "disarming"
			cursor = 0
		elif code == 108:
			var candidate := Geometry.calculate(bearing,distance(),origin,enemies)
			if candidate.is_empty():
				return false
			geometry = candidate
			camera = Vector2i(clampi(origin.x-10,0,140),clampi(origin.y-4,0,63))
			phase = "launch"
			cursor = 0
		else:
			return false
	else:
		return false
	return true


func advance(delta: float) -> void:
	if phase in ["aim","armed","report"]:
		return
	accumulator += delta
	# BERTA and CARTE ECS sloc[-2]=3; canonical PAL scheduler50Hz.
	while accumulator >= 3.0/50.0 and phase != "report":
		accumulator -= 3.0/50.0
		step()
	if phase == "report":
		accumulator = fmod(accumulator,3.0/50.0)


func step() -> void:
	match phase:
		"arming","disarming":
			cursor += 1 # flash plus four linkage poses.
			if cursor == 5:
				phase = "armed" if phase == "arming" else "aim"
				cursor = 0
		"launch":
			cursor += 1
			if cursor == 16: # flash and original frames54..68.
				phase = "ascent"
				cursor = 0
		"ascent":
			ascent += ascent_step
			if ascent > 11:
				ascent_step += 1
			cursor += 1
			if ascent > 205:
				phase = "flight"
				cursor = 0
		"flight": _flight_step()
		"impact":
			cursor += 1
			if cursor >= (2 if status == 1 else 4):
				phase = "report"
				cursor = 0


func _flight_step() -> void:
	if scroll_left > 0:
		camera.x = clampi(camera.x+scroll.x,0,140)
		camera.y = clampi(camera.y+scroll.y,0,63)
		scroll_left -= 1
		if scroll_left == 0:
			cursor += 1
		return
	if cursor > geometry.count:
		_finish_flight()
		return
	var point := Geometry.screen(geometry,camera,maxi(0,cursor-1))
	if cursor > 0 and _scroll_or_exit(point):
		return
	cursor += 1


func _scroll_or_exit(point: Vector2i) -> bool:
	# CARTE checks the previous drawn position, then scrolls18 cells/8 rows.
	if point.x < 7 or point.x > 303:
		if (point.x < 7 and camera.x == 0) or (point.x > 303 and camera.x == 140):
			status = 0
			_finish_flight()
		else:
			scroll = Vector2i(-1 if point.x < 7 else 1,0)
			scroll_left = 18
		return true
	if point.y < 16 or point.y > 142:
		if (point.y < 16 and camera.y == 0) or (point.y > 142 and camera.y == 63):
			status = 0
			_finish_flight()
		else:
			scroll = Vector2i(0,-1 if point.y < 16 else 1)
			scroll_left = 8
		return true
	return false


func _finish_flight() -> void:
	if status != 0:
		status = 2 if geometry.target >= 0 else 1
	phase = "report" if status == 0 else "impact"
	cursor = 0


func snapshot() -> Dictionary:
	return {"bearing":bearing,"digits":digits.duplicate(),"phase":phase,"cursor":cursor,"ascent":ascent,"ascent_step":ascent_step,"geometry":geometry.duplicate(true),"camera":[camera.x,camera.y],"scroll":[scroll.x,scroll.y],"scroll_left":scroll_left,"status":status,"removed":removed,"accumulator":maxf(0,accumulator)}


func restore(data: Dictionary) -> void:
	for key in ["bearing","phase","cursor","ascent","ascent_step","geometry","scroll_left","status","removed","accumulator"]:
		set(key,data[key])
	digits = data.digits.duplicate()
	for index in digits.size():
		digits[index] = int(digits[index])
	camera = Vector2i(data.camera[0],data.camera[1])
	scroll = Vector2i(data.scroll[0],data.scroll[1])
