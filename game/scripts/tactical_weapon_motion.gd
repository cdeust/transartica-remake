extends RefCounted
# MIT. Authored rotary-barrel/recoil presentation, driven by actual source bursts.
# Owner1October2026 permits modern continuous visual timing, not source-rule edits.
# Source bursts (every2 ticks, reload13) only open a firing window; the visual
# rounds between them are authored presentation and never touch combat state.
const Geometry = preload("res://scripts/tactical_effects_geometry.gd")
const STEP := 1.0/50.0 # Shared presentation cadence, independent combat clock.
const SPIN := 42.0 # source: authored barrel-ring speed, rad/s at full spin.
const WINDOW := 12 # source: authored0.24s; bridges the8-step source burst gap.
const STEEL := Color("#2a343e")
const DARK := Color("#11171d")
const BORE := Color("#05080b")
const LIGHT := Color("#8796a2")
const BRASS := Color("#b8873a")
const BRASS_LIGHT := Color("#e8bd68")
const SNOW := Color("#e8f0f5")
# Authored original sheet (output/imagegen/gatling-20261001/manifest.json):
# measured opaque cell bounds; cells differ slightly, cycling reads as rotation.
const SHEET := preload("res://assets/weapons/gatling.png")
const CELLS := [Rect2(52,39,417,693),Rect2(570,20,417,706),Rect2(1089,33,417,681),Rect2(1607,25,417,688)]
const GUN_HEIGHT := 13.0 # source: authored, logical px; fits the14px turret ring.
const SCALE := GUN_HEIGHT/693.0
const CAP := Rect2(145,0,125,78) # six-bore muzzle cap, cell-relative
const BASE_TOP := 310.0 # trunnion/yoke start, cell-relative
const HUB := Vector2(208,480) # trunnion hub, cell-relative
const ENEMY_TINT := Color(1,0.77,0.66) # same modulate as the side1 wagon sprite
var rigs := {}
var resting := {} # side/wagon → fall state of the gun on the (damaged) hull
const GRAVITY := 0.12 # source: authored logical px per50Hz step², ≈300px/s².


func fire(side: int, wagon: int, kind: String) -> void:
	var key := "%d/%d" % [side,wagon]
	var rig: Dictionary = rigs.get(key,{"side":side,"wagon":wagon,"kind":kind,"phase":0.0,"speed":0.0,"recoil":0.0,"heat":0.0,"window":0,"age":0,"rounds":0})
	rig.kind = kind
	if kind == "machinegun":
		rig.window = WINDOW
	else:
		rig.recoil = 2.5 # source: authored cannon recoil, logical px.
		rig.heat = minf(1.0,rig.heat+0.3)
	rigs[key] = rig


# One50Hz visual step; returns the rounds the scene must emit this step.
func step() -> Array:
	var rounds := []
	for key in rigs.keys():
		var rig: Dictionary = rigs[key]
		rig.age += 1
		var target := SPIN if rig.window > 0 else 0.0
		rig.speed += (target-rig.speed)*(0.25 if rig.window > 0 else 0.06)
		rig.phase = fmod(rig.phase+rig.speed*STEP,TAU)
		rig.recoil *= 0.55 if rig.kind == "machinegun" else 0.82
		rig.heat *= 0.993
		if rig.window > 0:
			rig.window -= 1
			if rig.speed > SPIN*0.6 and rig.age%2 == 0:
				rig.rounds += 1
				rig.recoil = 0.6 # source: authored per-round kick, logical px.
				rig.heat = minf(1.0,rig.heat+0.035)
				rounds.append({"side":rig.side,"wagon":rig.wagon,"round":rig.rounds,"heat":rig.heat})
		if rig.window == 0 and rig.speed < 0.05 and rig.heat < 0.02 and rig.recoil < 0.01:
			rigs.erase(key)
	return rounds


func state_for(side: int, wagon: int) -> Dictionary:
	return rigs.get("%d/%d" % [side,wagon],{"phase":0.0,"speed":0.0,"recoil":0.0,"heat":0.0,"window":0})


# Muzzle distance along the aim; side0 aims at the viewer, so its bore face sits
# above the foot (negative reach). Shared by drawing, flashes and tracers.
func reach(side: int, machine_gun: bool) -> float:
	if machine_gun: return -(CELLS[0].size.y-HUB.y)*SCALE if side == 0 else GUN_HEIGHT
	return -2.5 if side == 0 else 8.5


# Guns obey gravity: when the roof under them is torn away they drop onto
# whatever hull remains, with a small bounce. Presentation only (50Hz step).
func settle(scene) -> Array:
	var landings := []
	for side in 2:
		for wagon in scene.state.trains[side].size():
			var car: Dictionary = scene.state.trains[side][wagon]
			if not car.class in [scene.state.Setup.CANNON,scene.state.Setup.MACHINE_GUN]: continue
			var key := "%d/%d" % [side,wagon]
			var target: float = Geometry.mount(scene,side,wagon).base.y
			if not resting.has(key):
				resting[key] = {"y":target,"v":0.0}
				continue
			var fall: Dictionary = resting[key]
			if target < fall.y:
				fall.y = target
				fall.v = 0.0
			elif target > fall.y+0.01 or fall.v != 0.0:
				fall.v += GRAVITY
				fall.y += fall.v
				if fall.y >= target:
					fall.y = target
					if fall.v > 0.8:
						landings.append({"side":side,"wagon":wagon,"speed":fall.v})
						fall.v = -fall.v*0.25
					else:
						fall.v = 0.0
	return landings


func mount(scene, side: int, wagon: int, machine_gun: bool) -> Dictionary:
	var rig := state_for(side,wagon)
	var key := "%d/%d" % [side,wagon]
	var rest: float = resting[key].y if resting.has(key) else INF
	var result: Dictionary = Geometry.mount(scene,side,wagon,rig.recoil,reach(side,machine_gun),rest)
	# Spent brass leaves the receiver's right side.
	result.breech = result.body+Vector2(2.5,-(3.5 if side == 0 else 2.0))
	return result


# Persistent weapon: drawn idle on every armed wagon, animated by its rig.
func draw(canvas: CanvasItem, scene, side: int, wagon: int, machine_gun: bool) -> void:
	var rig := state_for(side,wagon)
	var at := mount(scene,side,wagon,machine_gun)
	var tint := ENEMY_TINT if side == 1 else Color.WHITE
	if scene.state.trains[side][wagon].health <= 0: tint = tint*Color(0.45,0.4,0.38) # burnt in the wreck
	if machine_gun:
		if side == 0: _gatling_front(canvas,at,rig,tint)
		else: _gatling_rear(canvas,at,rig,tint)
	elif side == 0: _cannon_front(canvas,at,rig,tint)
	else: _cannon_rear(canvas,at,rig,tint)


func _cell(rig: Dictionary) -> Rect2:
	# Spinning barrels step through the sheet's poses; idle keeps pose0.
	if rig.speed < 4.0: return CELLS[0]
	return CELLS[int(rig.phase/TAU*12.0)%4]


func _gatling_rear(canvas: CanvasItem, at: Dictionary, rig: Dictionary, tint: Color) -> void:
	var cell := _cell(rig)
	var size := cell.size*SCALE
	var foot: Vector2 = at.body
	var rect := Rect2(_snap(foot-Vector2(size.x/2,size.y)),size)
	canvas.draw_texture_rect_region(SHEET,rect,cell,tint)
	_barrel_heat(canvas,Rect2(foot.x-1.25,foot.y-size.y+0.5,2.5,size.y*0.5),rig.heat)


func _gatling_front(canvas: CanvasItem, at: Dictionary, rig: Dictionary, tint: Color) -> void:
	# Yoke and pedestal from the sheet; the barrel cluster faces the viewer.
	var cell := _cell(rig)
	var foot: Vector2 = at.body
	var base := Rect2(cell.position+Vector2(0,BASE_TOP),Vector2(cell.size.x,cell.size.y-BASE_TOP))
	var size := base.size*SCALE
	canvas.draw_texture_rect_region(SHEET,Rect2(_snap(foot-Vector2(size.x/2,size.y)),size),base,tint)
	var face: Vector2 = at.muzzle
	var cap := Rect2(cell.position+CAP.position,CAP.size)
	var cap_size := CAP.size*SCALE*2.0 # nearer the viewer than the yoke
	canvas.draw_texture_rect_region(SHEET,Rect2(_snap(face-cap_size/2),cap_size),cap,tint)
	if rig.heat > 0.15:
		canvas.draw_circle(face,cap_size.x*0.45,Color(1,0.4,0.12,(rig.heat-0.15)*0.45))


func _barrel_heat(canvas: CanvasItem, rect: Rect2, heat: float) -> void:
	if heat <= 0.15: return
	var bands := 4
	for band in bands: # hottest at the muzzle
		var part := Rect2(rect.position+Vector2(0,rect.size.y*band/bands),Vector2(rect.size.x,rect.size.y/bands))
		canvas.draw_rect(part,Color(1,0.38,0.1,(heat-0.15)*0.5*(1.0-float(band)/bands)))


func _plate(canvas: CanvasItem, centre: Vector2, half: Vector2, fill: Color, rim: Color) -> void:
	var points := PackedVector2Array()
	for index in 16: points.append(centre+Vector2(cos(TAU*index/16)*half.x,sin(TAU*index/16)*half.y))
	canvas.draw_colored_polygon(points,fill)
	points.append(points[0])
	canvas.draw_polyline(points,rim,0.25)


func _shield(canvas: CanvasItem, foot: Vector2, height: float, tint: Color) -> void:
	var top := foot.y-height
	var outline := PackedVector2Array([Vector2(foot.x-4.25,foot.y),Vector2(foot.x-3.5,top+1),Vector2(foot.x-2.5,top),Vector2(foot.x+2.5,top),Vector2(foot.x+3.5,top+1),Vector2(foot.x+4.25,foot.y)])
	canvas.draw_colored_polygon(outline,STEEL*tint)
	canvas.draw_line(Vector2(foot.x-4.0,foot.y-0.25),Vector2(foot.x-3.25,top+1),LIGHT*tint,0.5) # lit bevel
	canvas.draw_line(Vector2(foot.x-2.25,top+0.25),Vector2(foot.x+2.25,top+0.25),SNOW,0.5) # snow on the lip
	canvas.draw_line(Vector2(foot.x+3.75,foot.y),Vector2(foot.x+3.1,top+1.2),DARK,0.5)
	for x in [-3.0,-1.0,1.0,3.0]: # rivet row
		_box(canvas,Rect2(Vector2(foot.x+x-0.125,foot.y-1.0),Vector2(0.25,0.25)),BRASS_LIGHT*tint)


func _cannon_front(canvas: CanvasItem, at: Dictionary, rig: Dictionary, tint: Color) -> void:
	var foot: Vector2 = at.body
	_plate(canvas,foot+Vector2(0,0.5),Vector2(5,1.25),DARK*tint,BRASS*tint)
	_shield(canvas,foot,5.5,tint)
	var face: Vector2 = at.muzzle
	# Muzzle brake seen head-on: slotted block around a dark bore.
	_box(canvas,Rect2(face-Vector2(2,1.25),Vector2(4,2.5)),DARK*tint)
	_box(canvas,Rect2(face-Vector2(2,1.25),Vector2(4,0.5)),LIGHT*tint)
	canvas.draw_circle(face,1.25,STEEL*tint)
	canvas.draw_arc(face,1.25,PI*1.05,PI*1.7,6,BRASS_LIGHT*tint,0.5)
	canvas.draw_circle(face,0.75,BORE)
	if rig.heat > 0.1: canvas.draw_circle(face,0.75,Color(1,0.45,0.15,rig.heat*0.6))
	_box(canvas,Rect2(face+Vector2(-1.75,-0.25),Vector2(0.5,0.5)),BORE) # brake slots
	_box(canvas,Rect2(face+Vector2(1.25,-0.25),Vector2(0.5,0.5)),BORE)


func _cannon_rear(canvas: CanvasItem, at: Dictionary, rig: Dictionary, tint: Color) -> void:
	var foot: Vector2 = at.body
	var tip: Vector2 = at.muzzle
	var shield_top := foot.y-4.5
	_plate(canvas,foot+Vector2(0,0.5),Vector2(5,1.25),DARK*tint,BRASS*tint)
	# Barrel rises behind the shield toward the far train, tapering slightly.
	var barrel := PackedVector2Array([Vector2(foot.x-1.5,shield_top),Vector2(tip.x-1.1,tip.y+1),Vector2(tip.x+1.1,tip.y+1),Vector2(foot.x+1.5,shield_top)])
	canvas.draw_colored_polygon(barrel,STEEL*tint)
	canvas.draw_line(Vector2(foot.x-0.9,shield_top),Vector2(tip.x-0.6,tip.y+1),LIGHT*tint,0.5)
	canvas.draw_line(Vector2(foot.x+1.1,shield_top),Vector2(tip.x+0.8,tip.y+1),DARK*tint,0.5)
	_box(canvas,Rect2(Vector2(foot.x-1.5,lerpf(shield_top,tip.y,0.45)),Vector2(3,0.5)),BRASS*tint)
	_box(canvas,Rect2(tip+Vector2(-2,-0.25),Vector2(4,1.75)),DARK*tint) # muzzle brake
	_box(canvas,Rect2(tip+Vector2(-2,-0.25),Vector2(4,0.5)),LIGHT*tint)
	_box(canvas,Rect2(tip+Vector2(-1.5,0.75),Vector2(0.75,0.5)),BORE)
	_box(canvas,Rect2(tip+Vector2(0.75,0.75),Vector2(0.75,0.5)),BORE)
	_barrel_heat(canvas,Rect2(tip.x-1.25,tip.y,2.5,(shield_top-tip.y)*0.6),rig.heat)
	_shield(canvas,foot,4.5,tint)
	# Breech block toward the viewer, recoil cylinder above it.
	_box(canvas,Rect2(foot+Vector2(-1.75,-2),Vector2(3.5,2.5)),DARK*tint)
	_box(canvas,Rect2(foot+Vector2(-1.75,-2),Vector2(3.5,0.5)),STEEL*tint)
	_box(canvas,Rect2(foot+Vector2(-0.5,-1.25),Vector2(1,1)),BRASS_LIGHT*tint)


func _snap(point: Vector2) -> Vector2:
	return (point*4).round()/4


func _box(canvas: CanvasItem, rect: Rect2, fill: Color) -> void:
	canvas.draw_rect(Rect2((rect.position*4).round()/4,(rect.size*4).round()/4),fill)


func clear() -> void:
	rigs.clear()
	resting.clear()
