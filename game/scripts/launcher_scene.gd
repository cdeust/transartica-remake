extends "res://scripts/original_screen.gd"

# MIT. BERTA form8 exact logical hitboxes, decoded from its separate form table.
const HOTSPOTS := {101:Rect2(245,15,7,7),102:Rect2(245,31,7,7),103:Rect2(261,17,6,14),104:Rect2(269,17,6,14),105:Rect2(277,17,6,14),106:Rect2(285,17,6,14),107:Rect2(261,40,15,15),108:Rect2(285,40,15,14)}
const Geometry = preload("res://scripts/launcher_geometry.gd")
const Glyphs = preload("res://scripts/rail_glyphs.gd")
# source: rocket body21 z anchors in BERTA composites54..68, relative to145.
const LAUNCH_OFFSETS := [0,1,2,4,6,8,10,13,16,19,22,25,28,32,36,40]
var session
var terrain = preload("res://scripts/travel_terrain.gd").new()
var background: Texture2D
var rocket: Texture2D
var world_data
var living = preload("res://scripts/rocket_living_effects.gd").new()
var ignition_canvas = preload("res://scripts/rocket_ignition_canvas.gd").new()
# Measured solid silhouette of authored launcher-rocket.png, excluding its glow.
const ROCKET_BODY := Rect2(398,29,228,1402)
# Presented body offset: a smooth, ever-accelerating curve through the BERTA
# poses (source cursor untouched). Source increments have plateaus and a +2 dip
# at launch→ascent; presentation pools them into non-decreasing speed.
const SOURCE_STEP := 3.0/50.0
static var _curve := PackedFloat32Array()
var _shown := 0.0


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	add_child(ignition_canvas)
	session.app.resized.connect(_layout)
	_layout()
	terrain.load_art()
	world_data = session.app.world_view.world_data
	for pair in [["background","res://assets/interface/launcher.png"],["rocket","res://assets/interface/launcher-rocket.png"]]:
		if ResourceLoader.exists(pair[1]):
			set(pair[0],load(pair[1]))
	hide()


func canvas_rect() -> Rect2:
	# Source scene occupies top149 rows while the shared command panel owns51.
	var parent_size: Vector2 = session.app.size
	var factor := minf(parent_size.x/320.0,parent_size.y/200.0)
	var extent := Vector2(320,200)*factor
	return Rect2((parent_size-extent)*0.5,extent)


func _layout() -> void:
	var bounds := canvas_rect()
	offset_bottom = bounds.position.y+bounds.size.y*149.0/200.0-session.app.size.y


func _physics_process(delta: float) -> void:
	if visible:
		session.advance(delta)
		if session.model != null and not session.paused:
			living.observe(session.model,delta,_exhaust_point(session.model),flight_point(session.model) if session.model.phase == "flight" else Vector2.INF)
			queue_redraw()


func _source_offset(model) -> int:
	# Source composites54..68 shift the body z146..185 (39 pixels).
	if model.phase == "launch": return LAUNCH_OFFSETS[mini(model.cursor,15)]
	if model.phase == "ascent": return 42+model.ascent # BERTA moving body z187 vs initial145.
	return 0


static func _source_poses() -> PackedFloat32Array:
	# Same rules as launcher_model.step(): table, then ascent += step (+1 past11).
	var poses := PackedFloat32Array(LAUNCH_OFFSETS)
	var ascent := 0
	var increment := 4
	poses.append(42)
	while ascent <= 205:
		ascent += increment
		if ascent > 11: increment += 1
		poses.append(42+ascent)
	return poses


static func curve() -> PackedFloat32Array:
	if not _curve.is_empty(): return _curve
	var poses := _source_poses()
	var deltas: Array = []
	for index in poses.size()-1: deltas.append([poses[index+1]-poses[index],1])
	# Pool adjacent violators: speed never decreases.
	var pooled: Array = []
	for block in deltas:
		pooled.append(block.duplicate())
		while pooled.size() > 1 and pooled[-2][0]/pooled[-2][1] > pooled[-1][0]/pooled[-1][1]:
			var last: Array = pooled.pop_back()
			pooled[-1][0] += last[0]
			pooled[-1][1] += last[1]
	var speed: Array = []
	for block in pooled:
		for count in block[1]: speed.append(block[0]/block[1])
	# Five-tap average removes plateaus while keeping speed monotone.
	var smooth: Array = []
	for index in speed.size():
		var total := 0.0
		for tap in range(-2,3): total += speed[clampi(index+tap,0,speed.size()-1)]
		smooth.append(total/5.0)
	var scale: float = (poses[-1]-poses[0])/smooth.reduce(func(a,b):return a+b,0.0)
	_curve.append(poses[0])
	for value in smooth: _curve.append(_curve[-1]+value*scale)
	return _curve


# Cubic Hermite between curve points: continuous velocity at50Hz and above.
func _present(model, _delta := 0.0) -> void:
	if not model.phase in ["launch","ascent"]:
		_shown = _source_offset(model)
		return
	var points := curve()
	var index: int = model.cursor if model.phase == "launch" else 16+model.cursor
	index = clampi(index,0,points.size()-2)
	var fraction := clampf(model.accumulator/SOURCE_STEP,0.0,1.0)
	var start: float = points[index]
	var span: float = points[index+1]-start
	var before: float = points[index]-points[maxi(0,index-1)] if index > 0 else 0.0
	var after: float = points[mini(points.size()-1,index+2)]-points[index+1]
	var v0 := (before+span)/2.0
	var v1 := (span+after)/2.0
	var f := fraction
	_shown = start+(f*f*f-2*f*f+f)*v0+(-2*f*f*f+3*f*f)*span+(f*f*f-f*f)*v1


func _exhaust_point(model) -> Vector2:
	_present(model)
	return Vector2(141,103-_shown) # source: rocket drawn y7,height96; base y103.


func render_ignition(ignition) -> void:
	ignition_canvas.configure(ignition,canvas_rect())


func _draw() -> void:
	if session.model == null:
		return
	begin_canvas()
	var model = session.model
	if model.phase in ["flight","impact","report"]:
		_map()
	else:
		if background != null:
			draw_texture_rect(background,Rect2(0,0,320,149),false)
		_draw_rocket(model)
		living.draw(self,model.camera)
		_controls(model)
	text_at(Vector2(5,146),"P: PAUSE   F5: SAVE   F6: OPTIONS   ESC: EXIT",5)
	if session.paused:
		centered(76,"PAUSED")
	draw_set_transform(Vector2.ZERO)


func _controls(model) -> void:
	# Source BERTA form8 supplies each rectangle; labels are keyboard adaptation.
	draw_rect(Rect2(211,7,100,64),Color("#172b34"))
	if _frame != null:
		draw_texture_rect(_frame,Rect2(211,7,100,64),false)
	text_at(Vector2(216,28),"%03d°" % Geometry.angle(model.bearing),7)
	for code in HOTSPOTS:
		var bounds: Rect2 = HOTSPOTS[code]
		draw_rect(bounds,Color("#344753"))
		draw_rect(bounds,GOLD,false,0.5)
		if code in [101,102]:
			var point := bounds.get_center()
			var direction := -1 if code == 101 else 1
			draw_colored_polygon(PackedVector2Array([point+Vector2(-2,-direction),point+Vector2(2,-direction),point+Vector2(0,2*direction)]),GOLD)
		elif code <= 106:
			text_at(bounds.position+Vector2(1,9),str(model.digits[code-103]),5)
		else:
			text_at(bounds.position+Vector2(1,9),"ARM" if code == 107 else "FIRE",4)
	if model.phase in ["armed","arming"]:
		draw_rect(HOTSPOTS[107],Color("#ffe1a0"),false,1)
	text_at(Vector2(216,65),model.phase.to_upper(),5)


func _draw_rocket(model) -> void:
	if rocket == null:
		return
	_present(model)
	var offset := _shown
	var width := 96.0 * ROCKET_BODY.size.x / ROCKET_BODY.size.y
	draw_texture_rect_region(rocket,Rect2(141-width/2,7-offset,width,96),ROCKET_BODY)
	if model.phase in ["arming","armed","disarming"] and background != null:
		# Authored gantry beam measured in launcher.png. Source has four linkage poses.
		var pose: float = 1.0 if model.phase == "armed" else model.cursor/4.0
		if model.phase == "disarming": pose = 1.0-pose
		var length: float = 10.0+37.0*pose # Native composition: tower188, missile center141.
		for y in [55,91]:
			draw_texture_rect_region(background,Rect2(188-length,y,length,3),Rect2(751,72,340,35))


# Presented missile position on the map (logical, before scroll glide).
func flight_point(model) -> Vector2:
	var final: bool = model.phase in ["impact","report"]
	var point := Vector2(Geometry.screen(model.geometry,model.camera,maxi(0,model.cursor-1),final))
	if model.phase == "flight" and model.scroll_left == 0 and model.cursor > 0 and model.cursor <= model.geometry.count:
		# Glide toward the next CARTE point unless that point triggers a scroll/exit.
		var next := Vector2(Geometry.screen(model.geometry,model.camera,model.cursor))
		if next.x >= 7 and next.x <= 303 and next.y >= 16 and next.y <= 142:
			point = point.lerp(next,clampf(model.accumulator/SOURCE_STEP,0.0,1.0))
	return point


func _world_to_screen(point: Vector2) -> Vector2:
	return Vector2(0,0)+(point-Vector2(session.model.camera))*16


func _map() -> void:
	var model = session.model
	draw_rect(Rect2(0,0,320,149),Color("#b1c4c9")) # authored snow palette.
	# CARTE scrolls one cell per step; presentation glides through each cell.
	var fraction := clampf(model.accumulator/SOURCE_STEP,0.0,1.0)
	var glide := Vector2(model.scroll)*fraction*16 if model.phase == "flight" and model.scroll_left > 0 else Vector2.ZERO
	var frame := canvas_rect()
	var factor := frame.size.x/320.0 # source: BERTA/CARTE320px logical canvas.
	draw_set_transform(frame.position-glide*factor,0,Vector2.ONE*factor)
	var bounds := Rect2i(model.camera-Vector2i.ONE,Vector2i(22,12)).intersection(Rect2i(0,0,160,72))
	terrain.water.begin_frame(bounds.get_area())
	for x in range(bounds.position.x,bounds.end.x):
		for y in range(bounds.position.y,bounds.end.y):
			var cell := Vector2i(x,y)
			var code: int = session.app.network.tile(cell)
			terrain.draw_tile(self,cell,code)
			Glyphs.draw_tile(self,code,_world_to_screen(Vector2(cell)),16)
	if model.geometry.target >= 0 and model.phase == "flight":
		_target_marker(model)
	var final: bool = model.phase in ["impact","report"]
	var point := flight_point(model)
	if rocket != null and model.phase == "flight":
		draw_set_transform(frame.position+(point-glide)*factor,deg_to_rad(-Geometry.angle(model.bearing)+90),Vector2.ONE*factor)
		var width := 12.0 * ROCKET_BODY.size.x / ROCKET_BODY.size.y
		draw_texture_rect_region(rocket,Rect2(-width/2,-6,width,12),ROCKET_BODY)
		draw_set_transform(frame.position-glide*factor,0,Vector2.ONE*factor)
	living.draw(self,model.camera)
	begin_canvas()
	if model.phase == "report":
		draw_rect(Rect2(0,102,320,47),Color("#172b34")) # authored panel ink.
		var lines: Array = session.app.works_dialog._message(60+model.status)
		for index in lines.size():
			centered(111+index*9,str(lines[index]),6)


func _target_marker(model) -> void:
	# CARTE0x1d24..3f redraws only the selected homing target during flight.
	var renderer = session.app.world_view.train_renderer
	var vehicle: Dictionary = renderer.frame_for("locomotive")
	if vehicle.is_empty():
		return
	var record: Array = model.geometry.record
	var cell := Vector2(record[1]+40,record[2])
	var bounds := canvas_rect()
	var factor := bounds.size.x/320.0
	var center := bounds.position+_world_to_screen(cell+Vector2(0.5,0.5))*factor
	var direction := Vector2(session.app.network.DELTAS.get(int(record[3]),Vector2i.DOWN))
	var scale := 12.0*factor/maxf(vehicle.bounds.size.x,vehicle.bounds.size.y)
	draw_set_transform_matrix(renderer.registration(vehicle,center,direction.angle()-PI/2,scale))
	draw_texture(vehicle.texture,Vector2.ZERO)
	begin_canvas()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if session.model == null:
		return
	if session.model.phase == "report":
		session.dismiss()
	else:
		var point := logical_point(event.position)
		for code in HOTSPOTS:
			if HOTSPOTS[code].has_point(point):
				session.action(code)
				break
	accept_event()


func _has_point(point: Vector2) -> bool:
	return logical_point(point).y < 149 # shared original command strip stays clickable.
