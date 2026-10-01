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
var explosions: Array[Texture2D] = []
var world_data
# Measured solid silhouette of authored launcher-rocket.png, excluding its glow.
const ROCKET_BODY := Rect2(398,29,228,1402)


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	session.app.resized.connect(_layout)
	_layout()
	terrain.load_art()
	world_data = session.app.world_view.world_data
	for pair in [["background","res://assets/interface/launcher.png"],["rocket","res://assets/interface/launcher-rocket.png"]]:
		if ResourceLoader.exists(pair[1]):
			set(pair[0],load(pair[1]))
	for frame in range(4,8):
		explosions.append(load("res://assets/combat/effects-kit-%02d.png" % frame))
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
	var offset := 0
	if model.phase == "launch":
		# Source composites54..68 shift the body z146..185 (39 pixels).
		offset = LAUNCH_OFFSETS[mini(model.cursor,15)]
	elif model.phase == "ascent":
		offset = 42+model.ascent # BERTA moving body z187 vs initial145.
	var width := 96.0 * ROCKET_BODY.size.x / ROCKET_BODY.size.y
	if model.phase in ["launch","ascent"]:
		# Authored flame artwork; source continuation controls when ignition exists.
		draw_texture_rect(explosions[model.cursor%explosions.size()],Rect2(132,94-offset,18,25),false)
	draw_texture_rect_region(rocket,Rect2(141-width/2,7-offset,width,96),ROCKET_BODY)
	if model.phase in ["arming","armed","disarming"] and background != null:
		# Authored gantry beam measured in launcher.png. Source has four linkage poses.
		var pose: float = 1.0 if model.phase == "armed" else model.cursor/4.0
		if model.phase == "disarming": pose = 1.0-pose
		var length: float = 10.0+37.0*pose # Native composition: tower188, missile center141.
		for y in [55,91]:
			draw_texture_rect_region(background,Rect2(188-length,y,length,3),Rect2(751,72,340,35))


func _world_to_screen(point: Vector2) -> Vector2:
	return Vector2(0,0)+(point-Vector2(session.model.camera))*16


func _map() -> void:
	var model = session.model
	draw_rect(Rect2(0,0,320,149),Color("#b1c4c9")) # authored snow palette.
	var bounds := Rect2i(model.camera,Vector2i(20,10)).intersection(Rect2i(0,0,160,72))
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
	var point := Vector2(Geometry.screen(model.geometry,model.camera,maxi(0,model.cursor-1),final))
	if rocket != null and model.phase == "flight":
		var frame := canvas_rect()
		var factor := frame.size.x/320.0 # source: BERTA/CARTE320px logical canvas.
		draw_set_transform(frame.position+point*factor,deg_to_rad(-Geometry.angle(model.bearing)+90),Vector2.ONE*factor)
		var width := 12.0 * ROCKET_BODY.size.x / ROCKET_BODY.size.y
		draw_texture_rect_region(rocket,Rect2(-width/2,-6,width,12),ROCKET_BODY)
		begin_canvas()
	if model.phase == "impact":
		# CARTE0x1c50..74 draws two miss or four hit poses, then erases sprite7.
		var texture: Texture2D = explosions[mini(model.cursor,explosions.size()-1)]
		draw_texture_rect(texture,Rect2(point-Vector2(12,12),Vector2(24,24)),false)
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
