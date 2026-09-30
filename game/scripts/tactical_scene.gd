extends "res://scripts/original_screen.gd"
# MIT. Dedicated side-view scene: WDECOR0x2b82 mouse bands and four roof slots.
signal completed
signal save_requested
signal options_requested
var state
var selected_actor := -1
var selected_wagon := -1
var group_size := 1
var camera := 0.0
var paused := false
var textures := {}
var effects: Array = []
var edge_scroll := 0
var materials = preload("res://scripts/tactical_materials.gd").new()
var wagon_bounds := {}
var lights: Array = []

func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hide()
	for name in ["background", "actors-kit-00", "actors-kit-01", "actors-kit-04", "actors-kit-05", "actors-kit-08", "actors-kit-09", "effects-kit-04", "effects-kit-05", "effects-kit-06", "effects-kit-07", "effects-kit-08"]:
		textures[name] = load("res://assets/combat/" + name + ".png")
	for kind in range(1,26):
		textures["wagon-%02d" % kind] = load("res://assets/combat/wagon-%02d.png" % kind)

func open_battle(value) -> void:
	state = value
	show()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not visible or state == null or paused:
		return
	var before: int = state.ticks
	camera += edge_scroll * delta * 64
	state.advance(delta)
	if state.ticks != before:
		for event in state.events:
			effects.append({"event":event.duplicate(), "born":state.ticks})
			_impact_light(event)
		effects = effects.filter(func(effect): return state.ticks - effect.born < 23)
	for entry in lights:
		entry.node.energy = maxf(0.0,1.0-float(state.ticks-entry.born)/23.0)
		if entry.node.energy <= 0: entry.node.queue_free()
	lights = lights.filter(func(entry): return state.ticks-entry.born < 23)
	if state.outcome != 0:
		hide()
		completed.emit()
	queue_redraw()

func _draw() -> void:
	if state == null:
		return
	frame()
	begin_canvas()
	draw_texture_rect(textures.background,Rect2(0,14,320,164),false)
	_train(0, 63)
	_train(1, 192)
	for actor in state.actors:
		_actor(actor)
	for charge in state.charges:
		var point := _roof_point(charge.side,charge.slot)
		text_at(point,"●%d" % charge.fuse,5)
	for effect in effects:
		_effect(effect)
	centered(9,"TRAIN COMBAT" + (" · PAUSED" if paused else ""),6)
	text_at(Vector2(3,197),"← → CONVOY  ·  P PAUSE  ·  F5 SAVE  ·  F6 OPTIONS",5)
	if selected_actor >= 0:
		text_at(Vector2(3,183),"ARROWS: MOVE  SPACE: STOP  +/-: %d  S: SPLIT  Q/E: DYNAMITE" % group_size,5)
	elif selected_wagon >= 0:
		var car: Dictionary = state.trains[0][selected_wagon]
		text_at(Vector2(3,183),"WAGON %d · HULL %d/3 · %d ABOARD · GROUP %d · ENTER DEPLOY/FIRE" % [selected_wagon + 1,car.health,car.quantity,group_size],5)
	draw_set_transform(Vector2.ZERO)

func _train(side: int, baseline: float) -> void:
	var source_index := 0
	for index in state.trains[side].size():
		var car: Dictionary = state.trains[side][index]
		if car.class == state.Setup.LOCOMOTIVE_COMPANION:
			continue
		var kind: int = state.original[source_index][0] if side == 0 else _enemy_type(car.class)
		if side == 0:
			source_index += 1
		var texture: Texture2D = textures["wagon-%02d" % (kind if car.health > 0 else 25)]
		var width := 128.0 if car.class == state.Setup.LOCOMOTIVE else 64.0
		var factor := minf(width/texture.get_width(),26.0/texture.get_height())
		var extent := texture.get_size()*factor
		var x: float = 320 + state.offsets[side] - index*64 - camera
		var rect := Rect2(x-width,baseline-extent.y,extent.x,extent.y)
		var original_texture: Texture2D = texture
		texture = materials.texture_for(texture,side,index,car.health)
		wagon_bounds["%d/%d" % [side,index]] = rect
		draw_texture_rect(texture,rect,false,Color(1,0.77,0.66) if side == 1 else Color.WHITE)
		if car.health <= 0:
			materials.texture_for(original_texture,side,index,1)
		if side == 0:
			text_at(Vector2(rect.position.x+2,32),"%d:%d" % [source_index,car.health],4)

func _enemy_type(kind: int) -> int:
	var classes := {1:23,2:11,3:12,4:7,5:1,6:17,7:25,8:21}
	return classes.get(kind,25)

func _actor(actor: Dictionary) -> void:
	var point := _roof_point(actor.roof,actor.x) if actor.roof >= 0 else _field_point(actor.x,actor.y)
	var name := ("actors-kit-09" if actor.count > 1 else "actors-kit-08") if actor.mammoth else ("actors-kit-00" if actor.side == 0 else "actors-kit-04")
	if actor.direction != 8 and not actor.mammoth:
		name = "actors-kit-01" if actor.side == 0 else "actors-kit-05"
	var texture: Texture2D = textures[name]
	var extent := Vector2(28,28) if actor.mammoth else Vector2(12,17)
	var factor := minf(extent.x/texture.get_width(),extent.y/texture.get_height())
	extent = texture.get_size()*factor
	draw_texture_rect(texture,Rect2(point-Vector2(extent.x/2,extent.y),extent),false)
	text_at(point+Vector2(-4,4),str(actor.count),4)
	if actor.id == selected_actor:
		draw_line(point+Vector2(-6,6),point+Vector2(6,6),GOLD,1)

func _field_point(x: int,y: int) -> Vector2:
	return Vector2(x*16-state.center_offset()-camera+8,61+96-y*16+16)

func _roof_point(side: int,slot: int) -> Vector2:
	return Vector2(304+state.offsets[side]-slot*16-camera,38 if side==0 else 171)

func _effect(effect: Dictionary) -> void:
	var event: Dictionary = effect.event
	var age: int = state.ticks-effect.born
	var point: Vector2 = _field_point(event.x,event.y) if event.has("x") else _roof_point(event.side,event.wagon*4+2)
	# Authored keyposes: impact→flame→embers→smoke; visual clock never changes rules.
	var frame_index := mini(age/5,3)+4
	var texture: Texture2D = textures["effects-kit-%02d" % frame_index]
	var extent := Vector2(40,40) if event.kind=="destroy" else Vector2(18,18)
	draw_texture_rect(texture,Rect2(point-extent/2,extent),false,Color(1,1,1,1.0-float(age)/23))
	if event.has("wagon"):
		var prefix := "%d/%d" % [event.side,event.wagon]
		var health: int = maxi(1,state.trains[event.side][event.wagon].health)
		if wagon_bounds.has(prefix): materials.draw_debris(self,prefix+"/%d" % health,wagon_bounds[prefix],age)

func _gui_input(event: InputEvent) -> void:
	if state != null and event is InputEventMouseMotion:
		var point := logical_point(event.position)
		edge_scroll = -1 if point.x < 8 else (1 if point.x > 312 else 0)
		return
	if state == null or not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:
		return
	var point := logical_point(event.position)
	for actor in state.actors:
		if actor.side != 0:
			continue
		var actor_point := _roof_point(actor.roof,actor.x) if actor.roof>=0 else _field_point(actor.x,actor.y)
		if Rect2(actor_point-Vector2(12,22),Vector2(24,28)).has_point(point):
			selected_actor = actor.id
			selected_wagon = -1
			group_size = mini(actor.count,30)
			accept_event()
			queue_redraw()
			return
	if point.y >= 27 and point.y < 38:
		var index := clampi(int(point.x / 320 * state.trains[0].size()),0,state.trains[0].size()-1)
		camera = 128 + state.offsets[0] - index * 64
	elif point.y>=38 and point.y<64:
		selected_wagon = int((320+state.offsets[0]-camera-point.x)/64)
		selected_wagon = clampi(selected_wagon,0,state.trains[0].size()-1)
		selected_actor = -1
		group_size = mini(30,state.trains[0][selected_wagon].quantity)
	elif selected_actor>=0 and point.y>=64 and point.y<171:
		for actor in state.actors:
			if actor.id == selected_actor:
				var target := _field_point(actor.x,actor.y)
				var vector := Vector2i(signi(roundi(point.x-target.x)), -signi(roundi(point.y-target.y)))
				state.command(selected_actor,state.DIRECTIONS.find(vector))
	accept_event()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		handle_key(event)
		get_viewport().set_input_as_handled()

func handle_key(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_P: paused = not paused
		KEY_F5: save_requested.emit()
		KEY_F6: paused=true; options_requested.emit()
		KEY_EQUAL,KEY_KP_ADD: group_size=mini(30,group_size+1)
		KEY_MINUS,KEY_KP_SUBTRACT: group_size=maxi(1,group_size-1)
		KEY_ENTER: _activate_wagon()
		KEY_Q: state.plant(selected_actor,-1)
		KEY_E: state.plant(selected_actor,1)
		KEY_SPACE:
			if selected_actor>=0: state.command(selected_actor,8)
			else: state.velocities[0]=0
		KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN: _direction(event.physical_keycode,event.shift_pressed)
		KEY_S:
			for actor in state.actors:
				if actor.id==selected_actor: state.command(selected_actor,actor.direction,group_size)
	queue_redraw()

func _activate_wagon() -> void:
	if selected_wagon<0:
		return
	var car: Dictionary = state.trains[0][selected_wagon]
	if car.class in [state.Setup.CANNON,state.Setup.MACHINE_GUN]:
		state.fire(selected_wagon)
	else:
		state.deploy(0,selected_wagon,group_size)

func _direction(key: int, diagonal: bool) -> void:
	if selected_actor<0:
		if key in [KEY_LEFT,KEY_RIGHT]:
			state.velocities[0]=-1 if key==KEY_LEFT else 1
		return
	var direction: int = {KEY_UP:4,KEY_RIGHT:2,KEY_DOWN:0,KEY_LEFT:6}[key]
	if diagonal:
		direction=(direction+1)%8
	state.command(selected_actor,direction)

func _impact_light(event: Dictionary) -> void:
	if event.kind not in ["impact","destroy","shot"]:
		return
	var point: Vector2 = _field_point(event.x,event.y) if event.has("x") else _roof_point(event.side,event.wagon*4+2)
	var light := PointLight2D.new()
	# Pixel silhouette of the authored explosion supplies the light footprint.
	light.texture = textures["effects-kit-04"]
	light.color = Color("#ffbc66")
	var bounds := canvas_rect()
	var scale := bounds.size.x/CANVAS.x
	light.position = bounds.position+point*scale
	light.texture_scale = 40.0*scale/light.texture.get_width()
	add_child(light)
	lights.append({"node":light,"born":state.ticks})
