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
	ease_labels()
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
	actor_motion.draw(self) # live groups plus fading removals
	var layout := layout_labels()
	for actor in state.actors: _actor(actor)
	for label in layout.charges+layout.counts: _label(label.shown,label.text,label.size,label.anchor)
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

# Where this frame's labels go. Each is the first spot of a short preference list
# whose backing rectangle covers no soldier, wagon body, wagon tag or label placed
# before it; none free: the least covered. A label keeps its spot while that stays
# clear and moves only when it clashes, easing there (ease_labels) so it never
# jumps. Charge counters first (beside the box, away from the man kneeling at it,
# then the other side, then a smaller font, then up to LABEL_REACH above it, never
# farther), then each group's count (below its feet, else beside or above the group).
# Returns each label's "point" (where it settles) and "shown" (where it is drawn).
const LABEL_GAP := 0.75 # source: authored, logical px kept clear around a label.
const LABEL_REACH := 16.0 # source: authored, logical px; highest a charge counter goes above its box.
const LABEL_EASE := 1.0 # source: authored, logical px a label may move per visual step.
var _kept := {} # label key -> {"offset","size","anchor"}: the spot it keeps while clear
var _shown := {} # label key -> offset from its base where it is drawn
func layout_labels() -> Dictionary:
	var avoid := wagon_tag_rects()+actor_motion.soldier_rects(self)+wagon_body_rects()
	var layout := {"charges":[],"counts":[]}
	for charge in state.charges:
		var home := EffectGeometry.roof_point(self,charge.side,charge.slot)
		var left_first := actor_motion.planter_facing(charge) < 0
		var options := []
		for lift in [-9.0,-LABEL_REACH]: # 9 clears a kneeling man, 16 a standing one
			for size in [5,4]:
				for turn in 2:
					var left := (turn == 0) == left_first
					var offset := Vector2(-2.0 if left else 0.0,lift)
					options.append({"point":home+offset,"offset":offset,"text":"●%d" % charge.fuse,"anchor":1.0 if left else 0.0,"size":size})
		layout.charges.append(_settle("c%d/%d" % [charge.side,charge.slot],home,options,avoid))
	for actor in state.actors:
		if actor_motion.label_hidden(actor): continue
		var feet := actor_motion.point(self,actor)
		var offsets := [Vector2(-4,4),Vector2(2,4),Vector2(-6,-4),Vector2(7,-4),Vector2(-12,-4),Vector2(13,-4),Vector2(-4,11),Vector2(2,11),Vector2(-12,11),Vector2(13,11)] # below, then beside, then farther below (a second group at the same feet)
		for lift in [-16.0,-22.0,-28.0,-34.0]: # then above the heads, sliding sideways
			for slide in [-3.0,4.0,-10.0,11.0,-17.0,18.0]: offsets.append(Vector2(slide,lift))
		var options := []
		for offset in offsets:
			var left: bool = offset.x == -6 or offset.x == -12 # beside, growing leftwards
			options.append({"point":feet+offset,"offset":offset,"text":str(actor.count),"anchor":1.0 if left else 0.0,"size":4})
		layout.counts.append(_settle("a%d" % actor.id,feet,options,avoid))
	return layout

# The spot a label settles on: its kept one while still clear, else the first free.
func _settle(key: String, base: Vector2, options: Array, avoid: Array) -> Dictionary:
	var spot: Dictionary = {}
	if _kept.has(key):
		var kept: Dictionary = _kept[key]
		var same: Dictionary = options[0].duplicate()
		same.offset = kept.offset
		same.point = base+kept.offset
		same.anchor = kept.anchor
		same.size = kept.size
		if _cover(same,avoid) == 0.0: spot = same
	if spot.is_empty(): spot = _free_spot(options,avoid)
	_kept[key] = {"offset":spot.offset,"size":spot.size,"anchor":spot.anchor}
	avoid.append(label_rect(spot.point,spot.text,spot.size,spot.anchor))
	spot = spot.duplicate()
	spot.key = key
	spot.base = base
	spot.shown = base+_shown.get(key,spot.offset)
	return spot

# One visual step of the labels: settle them, then move each drawn label at most
# LABEL_EASE toward its spot, taking the step (toward it, up, down, sideways or
# staying) that covers the least and then gets closest, so it slides around the
# soldiers instead of across them.
func ease_labels() -> void:
	var layout := layout_labels()
	var avoid := wagon_tag_rects()+actor_motion.soldier_rects(self)+wagon_body_rects()
	var shown := {}
	for label in layout.charges+layout.counts:
		var here: Vector2 = _shown.get(label.key,label.offset)
		var steps := [here.move_toward(label.offset,LABEL_EASE),here,here+Vector2(0,-LABEL_EASE),here+Vector2(0,LABEL_EASE),here+Vector2(-LABEL_EASE,0),here+Vector2(LABEL_EASE,0)]
		var best: Vector2 = steps[0]
		var cost := INF
		for step in steps:
			var option := {"point":label.base+step,"text":label.text,"anchor":label.anchor,"size":label.size}
			var value: float = _cover(option,avoid)*1000.0+step.distance_to(label.offset)
			if value < cost:
				cost = value
				best = step
		shown[label.key] = best
		avoid.append(label_rect(label.base+best,label.text,label.size,label.anchor))
	_shown = shown

# Overlaps among this frame's labels and the soldiers, wagon tags and wagon
# bodies (a charge counter may not touch a soldier; a count label may meet
# boots), plus charge counters farther than LABEL_REACH from their box. 0 is clean.
func layout_clashes() -> int:
	var layout := layout_labels()
	var rects := []
	for label in layout.charges+layout.counts: rects.append(label_rect(label.point,label.text,label.size,label.anchor))
	var clashes := 0
	for index in rects.size():
		for other in rects.slice(index+1)+wagon_tag_rects()+wagon_body_rects():
			if rects[index].grow(LABEL_GAP).intersects(other): clashes += 1
	for index in layout.charges.size():
		for other in actor_motion.soldier_rects(self):
			if rects[index].grow(LABEL_GAP).intersects(other): clashes += 1
		var home := EffectGeometry.roof_point(self,state.charges[index].side,state.charges[index].slot)
		if home.y-layout.charges[index].point.y > LABEL_REACH+0.01 or absf(layout.charges[index].point.x-home.x) > LABEL_REACH: clashes += 1
	return clashes

func _free_spot(options: Array, avoid: Array) -> Dictionary:
	var best: Dictionary = options[0]
	var least := INF
	for option in options:
		var covered := _cover(option,avoid)
		if covered < least:
			least = covered
			best = option
		if covered == 0.0: break
	return best

# How much of the obstacles a label's backing rectangle (with its gap) covers;
# 1000 and up when it leaves the canvas below the HUD bar.
func _cover(option: Dictionary, avoid: Array) -> float:
	var rect := label_rect(option.point,option.text,option.size,option.anchor).grow(LABEL_GAP)
	var covered := 0.0 if Rect2(Vector2(0,22),Vector2(320,178)).encloses(rect.grow(-LABEL_GAP)) else 1000.0 # source: canvas below the HUD bar (88 px at x4).
	for other in avoid:
		if rect.intersects(other): covered += rect.intersection(other).get_area()
	return covered

# The wagons' bodies below their roof line (logical px), where no label fits.
func wagon_body_rects() -> Array:
	var rects := []
	for side in 2:
		for index in state.trains[side].size():
			if state.trains[side][index].class == state.Setup.LOCOMOTIVE_COMPANION: continue
			var rect: Rect2 = EffectGeometry.wagon(self,side,index).rect
			var roof := EffectGeometry.surface_y(self,side,index,rect.get_center().x)
			rects.append(Rect2(rect.position.x,roof,rect.size.x,rect.end.y-roof))
	return rects

# Wagon tags drawn over the player's train (logical px).
func wagon_tag_rects() -> Array:
	var rects := []
	var source_index := 0
	for index in state.trains[0].size():
		if state.trains[0][index].class == state.Setup.LOCOMOTIVE_COMPANION: continue
		source_index += 1
		rects.append(label_rect(Vector2(EffectGeometry.wagon(self,0,index).rect.position.x+2,32),"%d:%d" % [source_index,state.trains[0][index].health],4))
	return rects

# Backing rectangle of a label (logical px); anchor 0 starts the text at point,
# 1 ends it there, so a charge's counter can sit away from the man kneeling at it.
func label_rect(point: Vector2, value: String, font_size: int, anchor := 0.0) -> Rect2:
	var factor := canvas_rect().size.x / CANVAS.x
	var pixels := maxi(1, roundi(font_size * factor))
	var width := ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x / factor
	return Rect2(point-Vector2(1+anchor*width,font_size+1),Vector2(width+2,font_size+3))

func _label(point: Vector2, value: String, font_size: int, anchor := 0.0) -> void:
	# Authored dark backing keeps health/count readouts legible on snow and smoke.
	var factor := canvas_rect().size.x / CANVAS.x
	var pixels := maxi(1, roundi(font_size * factor))
	var rect := label_rect(point,value,font_size,anchor)
	draw_rect(rect,Color(0.03,0.06,0.08,0.9))
	# Keep output-pixel glyphs while restoring the shaken world transform.
	# OriginalScreen.text_at resets that transform after every world label.
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font,world_transform*Vector2(rect.position.x+1,point.y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,GOLD)
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
