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
var texture_bounds := {}
var actor_art = preload("res://scripts/tactical_actor_art.gd").new()
var wagon_art = preload("res://scripts/tactical_wagon_art.gd").new()
var effects: Array = []
var edge_scroll := 0
var materials = preload("res://scripts/tactical_materials.gd").new()
var wagon_bounds := {}
var lights: Array = []
var audio
var living = preload("res://scripts/living_effects.gd").new()
var weapon_motion = preload("res://scripts/tactical_weapon_motion.gd").new()
var actor_motion = preload("res://scripts/tactical_actor_motion.gd").new()
var _visual_frame := false
var _visual_delta := 0.0
var _visual_cursor := 0.0
var _visual_boundary := 0.0
var light_layer := Node2D.new() # Additive halos: flashes, tracers, hot sparks.
const EffectGeometry = preload("res://scripts/tactical_effects_geometry.gd")
# Owner decision1October2026: combat no longer runs at ECS real-time pace; the
# active pause suffices. Each source tick and its rules/RNG are unchanged, only
# its real-time duration is divided. Visual effects keep real time.
const PACE := 2.0
var pace := PACE
var _clock_fraction := -1.0 # tick fraction pinned while source/visual steps emit
var _steps_since_tick := 0
var world_transform := Transform2D() # current logical→control transform while drawing

func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hide()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light_layer.material = additive
	light_layer.draw.connect(_draw_light)
	add_child(light_layer)
	living.separate_light = true
	for name in ["background", "actors-kit-00", "actors-kit-01", "actors-kit-04", "actors-kit-05", "actors-kit-08", "actors-kit-09", "effects-kit-04", "effects-kit-05", "effects-kit-06", "effects-kit-07", "effects-kit-08"]:
		textures[name] = load("res://assets/combat/" + name + ".png")
	for kind in range(1,26):
		var name := "wagon-%02d" % kind
		textures[name] = wagon_art.texture_for(kind)
		texture_bounds[name] = Rect2(textures[name].get_image().get_used_rect())

func open_battle(value) -> void:
	if state != value:
		if state != null and state.audio_cue_requested.is_connected(_source_audio):
			state.audio_cue_requested.disconnect(_source_audio)
		if state != null and state.presentation_event_requested.is_connected(_presentation_event):
			state.presentation_event_requested.disconnect(_presentation_event)
		if state != null and state.presentation_tick_started.is_connected(_presentation_tick):
			state.presentation_tick_started.disconnect(_presentation_tick)
		value.audio_cue_requested.connect(_source_audio)
		value.presentation_event_requested.connect(_presentation_event)
		value.presentation_tick_started.connect(_presentation_tick)
		if audio != null:
			audio.stop_effects()
			audio.effect("wdecor",0x6121) # WDECOR127→6114, ECS25918>1 ambient.
		materials.instances.clear()
		effects.clear()
		wagon_bounds.clear()
		for entry in lights:entry.node.queue_free()
		lights.clear()
		living.clear()
		weapon_motion.clear()
		actor_motion.clear()
	state = value
	show()
	queue_redraw()


func _source_audio(offset: int) -> void:
	if audio != null:
		audio.effect("wdecor",offset)


func _presentation_event(event: Dictionary) -> void:
	var point: Vector2 = EffectGeometry.event_point(self,event)
	var direction := Vector2(0,1 if event.get("side",0) == 0 else -1)
	if event.kind == "melee":
		actor_motion.melee(event)
	if event.kind in ["machinegun","cannon"]:
		weapon_motion.fire(event.side,event.wagon,event.kind)
		point = weapon_motion.mount(self,event.side,event.wagon,event.kind == "machinegun").muzzle
	living.add(event.kind,point+Vector2(camera,0),direction)
	if event.kind in ["impact","destroy"]:
		_impact_fragments(event,point+Vector2(camera,0))
	_impact_light(event)


func _presentation_tick(seconds: float) -> void:
	if not _visual_frame: return
	var boundary: float = clampf(_visual_boundary,0,_visual_delta)
	_advance_visual(maxf(0,boundary-_visual_cursor))
	_visual_cursor = boundary
	_visual_boundary += seconds/pace
	_steps_since_tick = 0
	_clock_fraction = 0.0 # events of this tick are born exactly at its boundary


func _advance_visual(seconds: float) -> void:
	living.advance(seconds,_visual_step)


# Rotary rounds share the particle step; presentation only, no model access beyond reads.
func _visual_step() -> void:
	# Fraction from the50Hz visual clock, so emitters never see display-rate remainders.
	_steps_since_tick += 1
	_clock_fraction = clampf(_steps_since_tick*living.STEP*pace/state.STEP_SECONDS,0.0,1.0)
	actor_motion.step(self)
	for landing in weapon_motion.settle(self): # dust and grit where a fallen gun lands
		var base: Vector2 = weapon_motion.mount(self,landing.side,landing.wagon,true).base
		living.add("dust",base+Vector2(camera,0),Vector2.UP,clampf(landing.speed/3.0,0.4,1.0))
		living.add("sparks",base+Vector2(camera,0),Vector2.UP,0.5)
	for shot in weapon_motion.step():
		var mount: Dictionary = weapon_motion.mount(self,shot.side,shot.wagon,true)
		var muzzle: Vector2 = mount.muzzle
		var far: int = 1-shot.side
		var target := EffectGeometry.wagon_at(self,far,muzzle.x)
		var armour := false
		var arrival := 190.0 if far == 1 else 61.0 # source: rail band beneath each train baseline.
		var body: Rect2 = EffectGeometry.wagon(self,far,maxi(0,target)).rect
		if target >= 0 and muzzle.x >= body.position.x and muzzle.x <= body.end.x:
			armour = true
			var surface := EffectGeometry.surface_y(self,far,target,muzzle.x)
			arrival = surface+2+float(shot.round%5)*1.5 # source: authored spread over the armour face.
		var floor_y := EffectGeometry.surface_y(self,shot.side,shot.wagon,muzzle.x+6)
		var world := Vector2(camera,0)
		living.fire_round(muzzle+world,mount.direction,shot.round,shot.heat,floor_y,absf(arrival-muzzle.y),armour,mount.breech+world)


func _advance_battle(seconds: float) -> void:
	# Tick callbacks timestamp births while preserving one unchanged model call.
	_visual_frame = true
	_visual_delta = seconds
	_visual_cursor = 0
	_visual_boundary = (state.STEP_SECONDS-state.remainder)/pace
	state.advance(seconds*pace)
	_advance_visual(maxf(0,seconds-_visual_cursor))
	_visual_frame = false
	_clock_fraction = -1.0


func _impact_fragments(event: Dictionary, point: Vector2) -> void:
	var car: Dictionary = state.trains[event.side][event.wagon]
	var texture: Texture2D = EffectGeometry.wagon(self,event.side,event.wagon,true).texture
	materials.texture_for(texture,event.side,event.wagon,car.health)
	var key := "%d/%d/%d" % [event.side,event.wagon,car.health]
	living.fragments(point,materials.fragment_colors(key))

func _physics_process(delta: float) -> void:
	if not visible or state == null or paused:
		return
	camera += edge_scroll * delta * 64
	_advance_battle(delta)
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
	# Presentation jolt on heavy blasts; UI text below is drawn without it.
	var jolt: Vector2 = living.shake_offset()
	var bounds := canvas_rect()
	var factor := bounds.size.x/CANVAS.x
	world_transform = Transform2D(0,Vector2.ONE*factor,0,bounds.position+jolt*factor)
	draw_set_transform_matrix(world_transform)
	for entry in lights:
		entry.node.position = world_transform*(entry.point-Vector2(camera,0))
	_draw_ground()
	_train(0, 63)
	_train(1, 192)
	actor_motion.draw(self,actor_art) # live groups plus fading removals
	for actor in state.actors:
		_actor(actor)
	for charge in state.charges:
		var point := EffectGeometry.roof_point(self,charge.side,charge.slot)
		_label(point+Vector2(0,-9),"●%d" % charge.fuse,5) # above the drawn box
	for effect in effects:
		_effect(effect)
	# World-position effects remain registered while the combat camera scrolls.
	living.draw(self,Vector2(-camera,0))
	begin_canvas()
	light_layer.queue_redraw()
	centered(9,"TRAIN COMBAT" + (" · PAUSED" if paused else ""),6)
	text_at(Vector2(3,18),"← → CONVOY  ·  P PAUSE  ·  F5 SAVE  ·  F6 OPTIONS",5)
	if selected_actor >= 0:
		_status("ARROWS: MOVE  SPACE: STOP  +/-: %d  S: SPLIT  Q/E: DYNAMITE" % group_size)
	elif selected_wagon >= 0:
		var car: Dictionary = state.trains[0][selected_wagon]
		_status("WAGON %d · HULL %d/3 · %d ABOARD · GROUP %d · ENTER DEPLOY/FIRE" % [selected_wagon + 1,car.health,car.quantity,group_size])
	draw_set_transform(Vector2.ZERO)

func _draw_light() -> void:
	if state == null: return
	light_layer.draw_set_transform_matrix(world_transform)
	living.draw_light(light_layer,Vector2(-camera,0))

func _draw_ground() -> void:
	# Source: measured authored background.png snow band170..650, track40..170.
	# Place rails beneath source wagon wheel baselines63/192, not above the roofs.
	var background: Texture2D = textures.background
	var width := float(background.get_width())
	# Fit the snow crop at its authored aspect ratio instead of stretching pixels.
	var snow_width := 480.0 * 320.0 / 186.0
	draw_texture_rect_region(background, Rect2(0,14,320,186), Rect2((width-snow_width)/2,170,snow_width,480))
	for baseline in [63,192]:
		draw_texture_rect_region(background, Rect2(0,baseline-9,320,16), Rect2(0,40,width,130))
	draw_rect(Rect2(0,14,320,8), Color(0.03,0.06,0.08,0.85))

func _status(value: String) -> void:
	# Authored translucent central banner leaves both roof/wagon bands unobscured.
	draw_rect(Rect2(0,94,320,10), Color(0.03,0.06,0.08,0.8))
	text_at(Vector2(3,101), value, 5)

func _label(point: Vector2, value: String, font_size: int) -> void:
	# Authored dark backing keeps health/count readouts legible on snow and smoke.
	var factor := canvas_rect().size.x / CANVAS.x
	var pixels := maxi(1, roundi(font_size * factor))
	var width := ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x / factor
	draw_rect(Rect2(point-Vector2(1,font_size+1),Vector2(width+2,font_size+3)),Color(0.03,0.06,0.08,0.9))
	# Keep output-pixel glyphs while restoring the shaken world transform.
	# OriginalScreen.text_at resets that transform after every world label.
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font,world_transform*point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,GOLD)
	draw_set_transform_matrix(world_transform)

func _train(side: int, _baseline: float) -> void:
	var source_index := 0
	for index in state.trains[side].size():
		var car: Dictionary = state.trains[side][index]
		if car.class == state.Setup.LOCOMOTIVE_COMPANION:
			continue
		if side == 0:
			source_index += 1
		var geometry: Dictionary = EffectGeometry.wagon(self,side,index)
		var texture: Texture2D = geometry.texture
		var used: Rect2 = geometry.used
		var factor: float = geometry.factor
		var rect: Rect2 = geometry.rect
		texture = materials.texture_for(texture,side,index,car.health)
		# Debris uses the same isolated sprite coordinates as material occupancy.
		wagon_bounds["%d/%d" % [side,index]] = Rect2(rect.position-used.position*factor,texture.get_size()*factor)
		draw_texture_rect_region(texture,rect,used,Color(1,0.77,0.66) if side == 1 else Color.WHITE)
		if car.class in [state.Setup.CANNON,state.Setup.MACHINE_GUN]:
			weapon_motion.draw(self,self,side,index,car.class == state.Setup.MACHINE_GUN)
			# A gun that fell into the breach sits behind the remaining front wall.
			var front: Texture2D = materials.front_for(side,index,car.health) if car.health < 3 else null
			if front != null: draw_texture_rect_region(front,rect,used,Color(1,0.77,0.66) if side == 1 else Color.WHITE)
		if side == 0:
			_label(Vector2(rect.position.x+2,32),"%d:%d" % [source_index,car.health],4)

func _enemy_type(kind: int) -> int:
	var classes := {1:23,2:11,3:12,4:7,5:1,6:17,7:25,8:21}
	return classes.get(kind,25)

func _actor(actor: Dictionary) -> void:
	var point: Vector2 = actor_motion.point(self,actor)
	_label(point+Vector2(-4,4),str(actor.count),4)
	if actor.id == selected_actor:
		draw_line(point+Vector2(-6,6),point+Vector2(6,6),GOLD,1)

func _field_point(x: float,y: float) -> Vector2:
	return Vector2(x*16-state.center_offset()-camera+8,61+96-y*16+16)

func _roof_point(side: int,slot: int) -> Vector2:
	return Vector2(304+shown_offset(side)-slot*16-camera,38 if side==0 else 171)


# Train offset glides between source ticks: next tick adds the current velocity
# (move_trains applies velocities before the AI changes them). Display only.
func shown_offset(side: int) -> float:
	var fraction: float = _clock_fraction if _clock_fraction >= 0 else clampf(state.remainder/state.STEP_SECONDS,0.0,1.0)
	var low: int = state.trains[side].size()*64-320-state.center_offset()
	var high: int = state.columns*16-320-state.center_offset()
	return clampf(state.offsets[side]+state.velocities[side]*fraction,mini(low,state.offsets[side]),maxi(high,state.offsets[side]))

func _effect(effect: Dictionary) -> void:
	var event: Dictionary = effect.event
	var age: int = state.ticks-effect.born
	var point: Vector2 = EffectGeometry.event_point(self,event)
	# Authored keyposes: impact→flame→embers→smoke; visual clock never changes rules.
	var frame_index := mini(age/5,3)+4
	var texture: Texture2D = textures["effects-kit-%02d" % frame_index]
	var extent := Vector2(40,40) if event.kind=="destroy" else Vector2(18,18)
	draw_texture_rect(texture,Rect2(point-extent/2,extent),false,Color(1,0.9,0.7,1.0-float(age)/23))
	if event.has("wagon"):
		var prefix := "%d/%d" % [event.side,event.wagon]
		var health: int = maxi(0,state.trains[event.side][event.wagon].health)
		if wagon_bounds.has(prefix): materials.draw_debris(self,prefix+"/%d" % health,wagon_bounds[prefix],age)

func _gui_input(event: InputEvent) -> void:
	if state != null and event is InputEventMouseMotion:
		var point := logical_point(event.position)
		edge_scroll = -1 if point.x < 8 else (1 if point.x > 312 else 0)
		return
	if state == null or not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:
		return
	var point := logical_point(event.position)-living.shake_offset()
	for actor in state.actors:
		if actor.side != 0:
			continue
		var actor_point: Vector2 = actor_motion.point(self,actor)
		if Rect2(actor_point-Vector2(12,22),Vector2(24,28)).has_point(point):
			selected_actor = actor.id
			selected_wagon = -1
			group_size = mini(actor.count,30)
			accept_event()
			queue_redraw()
			return
	if point.y >= 27 and point.y < 38:
		var index := clampi(int(point.x / 320 * state.trains[0].size()),0,state.trains[0].size()-1)
		camera = 128 + shown_offset(0) - index * 64
	elif point.y>=38 and point.y<64:
		selected_wagon = EffectGeometry.wagon_at(self,0,point.x)
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
	var point: Vector2 = EffectGeometry.event_point(self,event)
	var light := PointLight2D.new()
	# Pixel silhouette of the authored explosion supplies the light footprint.
	light.texture = textures["effects-kit-04"]
	light.color = Color("#ffbc66")
	var bounds := canvas_rect()
	var scale := bounds.size.x/CANVAS.x
	light.position = bounds.position+point*scale
	light.texture_scale = 40.0*scale/light.texture.get_width()
	add_child(light)
	lights.append({"node":light,"born":state.ticks,"point":point+Vector2(camera,0)})
