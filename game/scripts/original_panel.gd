extends Control

# source: tasks/evidence/panel-layout.md; yoda.alis form table 0x6bd0.
# This is a presentation layer: the owner handles the original command codes.
const LOGICAL_SIZE := Vector2(320, 200)
const STRIP := Rect2(0, 149, 320, 51)
# source: measured authored-asset alignment. Remove the surplus separator
# between wagon and map icons so each illustrated group meets the ECS hit boxes.
const ART_SLICES := [
	[Rect2(0, 184, 992, 402), Rect2(0, 149, 160, 51)],
	[Rect2(1058, 184, 480, 402), Rect2(160, 149, 70, 51)],
	[Rect2(1538, 184, 445, 402), Rect2(230, 149, 90, 51)],
]
const ART_PATH := "res://assets/interface/original-panel-v2.png"
const ICON_ATLAS_PATH := "res://assets/interface/panel-icons.png"
const LAUNCHER_ICON_PATH := "res://assets/interface/panel-launcher.png"
const COMMON := {
	2: Rect2(5, 164, 38, 29),
	6: Rect2(80, 161, 33, 15),
	8: Rect2(118, 162, 27, 14),
	7: Rect2(79, 180, 35, 14),
	9: Rect2(118, 179, 29, 17),
}
const MAP_COMMANDS := {
	4: Rect2(162, 160, 32, 19),
	1: Rect2(197, 160, 32, 19),
	3: Rect2(162, 180, 32, 19),
	5: Rect2(197, 180, 32, 19),
}
const WAGON_COMMANDS := {1: Rect2(161, 160, 33, 19)}
const LABELS := {1: "Map", 2: "Accelerate time", 3: "Reverse direction", 4: "Detailed map",
	5: "Brake", 6: "Engine", 7: "General Quarters", 8: "Boudoir", 9: "Missile launcher"}
# source: authored brass readouts for the new illustration, not historical pixels.
const READOUT_COLOR := Color("#ffe1a0")
const ICON_INK := Color("#342317") # source: authored dark ink on the brass/white plate.
# source: inner black-window bounds measured on original-panel.png and checked
# in tasks/validation/boudoir-quarters.png; excludes icon, rounded edge and rivets.
const READOUT_INNERS := [Rect2(1775, 299, 167, 54), Rect2(1775, 401, 167, 54), Rect2(1775, 505, 167, 54)]
const CLOCK_CENTER := Vector2(24, 180) # Source ECS hotspot; reference branch only.
# Measured cardinal stud center/interior on the unchanged v2 plate; validation/clock-quality.
const CLOCK_ART_CENTER := Vector2(160,410)
const CLOCK_ART_FACE := Rect2(60,320,200,180)
const CLOCK_ROMAN := ["XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"]

signal requested(code: int)

var reference_pixels := OS.get_environment("TRANSARTICA_REFERENCE_UI") == "1"
var ecs_art = preload("res://scripts/ecs_panel_art.gd").new()
var map_context := false
var overview_context := false
var app
var _texture: Texture2D
var _icon_atlas: Texture2D
var _launcher_icon: Texture2D
var _launcher_bounds := Rect2()
var _last_state: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ecs_art.load_private()
	if ResourceLoader.exists(ART_PATH):
		_texture = load(ART_PATH) as Texture2D
	if ResourceLoader.exists(ICON_ATLAS_PATH):
		_icon_atlas = load(ICON_ATLAS_PATH) as Texture2D
	if ResourceLoader.exists(LAUNCHER_ICON_PATH):
		_launcher_icon = load(LAUNCHER_ICON_PATH) as Texture2D
		var pixels := _launcher_icon.get_image()
		if pixels.is_compressed(): pixels.decompress()
		_launcher_bounds = Rect2(pixels.get_used_rect())
	mouse_exited.connect(_clear_hover)
	resized.connect(queue_redraw)


func bind(value) -> void:
	app = value
	refresh()


func frame_rect() -> Rect2:
	var scale_factor := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	var fitted := LOGICAL_SIZE * scale_factor
	return Rect2((size - fitted) / 2.0, fitted)


func screen_rect(logical: Rect2) -> Rect2:
	var frame := frame_rect()
	var scale_factor := frame.size.x / LOGICAL_SIZE.x
	return Rect2(frame.position + logical.position * scale_factor, logical.size * scale_factor)


func panel_rect() -> Rect2:
	return screen_rect(STRIP)


func logical_point(point: Vector2) -> Vector2:
	var frame := frame_rect()
	if frame.size.x <= 0.0:
		return Vector2(-1, -1)
	return (point - frame.position) * LOGICAL_SIZE.x / frame.size.x


func hotspot_at(point: Vector2) -> int:
	var logical := logical_point(point)
	for code in COMMON:
		if COMMON[code].has_point(logical):
			return code
	var contextual: Dictionary = contextual_commands()
	for code in contextual:
		if contextual[code].has_point(logical):
			return code
	return 0


func _has_point(point: Vector2) -> bool:
	# The full-size control must not intercept clicks on the scene above the strip.
	return panel_rect().has_point(point)


func activate(code: int) -> void:
	var contextual: Dictionary = contextual_commands()
	if COMMON.has(code) or contextual.has(code):
		requested.emit(code)


func contextual_commands() -> Dictionary:
	# Source: tasks/validation/common-map-access-20261004.md, owner room access.
	if map_context:
		return MAP_COMMANDS
	return WAGON_COMMANDS if reference_pixels else {4: MAP_COMMANDS[4], 1: MAP_COMMANDS[1]}


func _gui_input(event: InputEvent) -> void:
	# Original works question/report owns input while visible (Main blocking).
	# Keep the panel painted; its commands resume when that screen is dismissed.
	if app != null and app.get("works_dialog") != null and app.works_dialog.visible:
		_clear_hover()
		accept_event()
		return
	if event is InputEventMouseMotion:
		var code := hotspot_at(event.position)
		tooltip_text = LABELS.get(code, "")
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if code != 0 else CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ecs_art.scroll(self, logical_point(event.position)):
			accept_event()
			return
		var code := hotspot_at(event.position)
		if code != 0:
			activate(code)
			accept_event()


func _clear_hover() -> void:
	tooltip_text = ""
	mouse_default_cursor_shape = CURSOR_ARROW


func refresh() -> void:
	var state: Array = [map_context, overview_context]
	if app != null:
		state.append_array([app.engine.lignite, app.engine.anthracite, app.engine.speed, app.engine.cycles,
			app.calendar.hour, app.calendar.minute, app.calendar.factor, app.engine.brake, app.journey.reverse, app.journey.heading, app.journey.blocked, app.wagons.snapshot()])
	if state != _last_state:
		_last_state = state
		queue_redraw()


func _draw() -> void:
	if reference_pixels and ecs_art.available:
		ecs_art.draw(self)
		if app != null:
			_draw_readouts()
		return
	if _texture == null:
		return
	for slice in ART_SLICES:
		draw_texture_rect_region(_texture, screen_rect(slice[1]), slice[0])
	var frame := frame_rect()
	var scale_factor := frame.size.x / LOGICAL_SIZE.x
	draw_set_transform(frame.position, 0.0, Vector2.ONE * scale_factor)
	if not map_context:
		# Cover controls inactive in wagon context with the authored blank plate.
		for code in [3, 5]:
			draw_texture_rect_region(_texture, MAP_COMMANDS[code], Rect2(758, 434, 207, 120))
	draw_set_transform(Vector2.ZERO)
	if app != null:
		_draw_clock()
		_draw_map_commands()
		if map_context:
			_draw_driving_states()
		_draw_readouts()
		_draw_composition()
		_draw_launcher()


func driving_states() -> Dictionary:
	if app == null:
		return {}
	return {"brake": "ON" if app.engine.brake else "OFF",
		"direction": "REV" if app.journey.reverse else "FWD",
		"heading": app.journey.heading_name()}


func _draw_driving_states() -> void:
	# Owner3Oct: expose effective state inside the existing ECS command slots.
	var states := driving_states()
	var scale_factor := frame_rect().size.x/LOGICAL_SIZE.x
	for code in [3,5]:
		var slot := screen_rect(MAP_COMMANDS[code].grow(-1))
		var active: bool = app.journey.reverse if code == 3 else app.engine.brake
		draw_rect(slot, READOUT_COLOR if active else ICON_INK, false, scale_factor)
		var caption: String = "%s %s" % [states.direction,states.heading] if code == 3 else "BRAKE " + states.brake
		var font := ThemeDB.fallback_font
		var font_size := maxi(1,roundi(4*scale_factor)) # source: authored16px at native4x.
		while font_size > 1 and font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > slot.size.x-2*scale_factor:
			font_size -= 1
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var band := Rect2(slot.position.x,slot.end.y-6*scale_factor,slot.size.x,6*scale_factor)
		draw_rect(band,ICON_INK)
		draw_string(font,Vector2(band.get_center().x-width/2,band.end.y-scale_factor),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,READOUT_COLOR)
		if code == 5:
			var pivot := Vector2(slot.get_center().x,slot.position.y+8*scale_factor)
			var handle := pivot + (Vector2(-6,-5) if active else Vector2(6,-5))*scale_factor
			draw_line(pivot,handle,ICON_INK,3*scale_factor,true)
			draw_line(pivot,handle,READOUT_COLOR,scale_factor,true)
			draw_circle(handle,1.5*scale_factor,READOUT_COLOR)


func clock_face() -> Rect2:
	var source: Rect2 = ART_SLICES[0][0]
	var target: Rect2 = ART_SLICES[0][1]
	var ratio := target.size/source.size
	return screen_rect(Rect2(target.position+(CLOCK_ART_FACE.position-source.position)*ratio,CLOCK_ART_FACE.size*ratio))


func clock_center() -> Vector2:
	var source: Rect2 = ART_SLICES[0][0]
	var target: Rect2 = ART_SLICES[0][1]
	return screen_rect(Rect2(target.position+(CLOCK_ART_CENTER-source.position)*target.size/source.size,Vector2.ZERO)).position


func clock_layout(hour: int, minute: int) -> Dictionary:
	# Source12-hour calendar, same9/6 logical lengths as the accepted panel.
	var center := clock_center()
	var factor := frame_rect().size.x/LOGICAL_SIZE.x
	var face := clock_face()
	var font := ThemeDB.fallback_font
	var font_size := maxi(1,roundi(7.0*factor)) # Existing panel readout scale ceiling.
	var numerals: Array[Dictionary] = []
	while font_size > 0:
		numerals = _clock_numerals(font,font_size,face.grow(-1.0))
		if numerals.size()==CLOCK_ROMAN.size(): break
		font_size-=1
	var glyph_extent := Vector2.ZERO
	for numeral in numerals: glyph_extent=glyph_extent.max(numeral.bounds.size)
	var hand_radius := face.size/2.0-glyph_extent
	var minutes := float(minute)/60.0
	var hours := (float(hour%12)+minutes)/12.0
	return {"center":center,"face":face,"font_size":font_size,"numerals":numerals,
		"minute_end":center+Vector2.UP.rotated(minutes*TAU)*hand_radius,
		"hour_end":center+Vector2.UP.rotated(hours*TAU)*hand_radius*(6.0/9.0),
		"stroke":factor,"hub_radius":1.5*factor,"hour_radius":hand_radius*(6.0/9.0)}


func _clock_numerals(font: Font, font_size: int, face: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var height := font.get_ascent(font_size)+font.get_descent(font_size)
	var maximum := Vector2.ZERO
	for roman in CLOCK_ROMAN:
		maximum = maximum.max(Vector2(font.get_string_size(roman,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,height))
	if maximum.x>=face.size.x or maximum.y>=face.size.y: return []
	for index in CLOCK_ROMAN.size():
		var text: String=CLOCK_ROMAN[index]
		var extent := Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,height)
		var direction := Vector2.UP.rotated(float(index)/CLOCK_ROMAN.size()*TAU)
		var radius := 1.0
		# Analytic rectangle-in-ellipse bound: |direction*t+corner|²<=1.
		# Solve its quadratic for the outer positive root, for all four corners.
		for sign_pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var corner: Vector2=sign_pair*extent/face.size
			var along := direction.dot(corner)
			var discriminant := along*along+1.0-corner.length_squared()
			if discriminant<0: return []
			radius=minf(radius,-along+sqrt(discriminant))
		var center := face.get_center()+direction*(face.size/2.0)*radius
		var bounds := Rect2(center-extent/2.0,extent)
		if not face.encloses(bounds): return []
		for corner in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
			var squared: float=((corner-face.get_center())/(face.size/2.0)).length_squared()
			if squared>1.0 and not is_equal_approx(squared,1.0): return []
		for previous in result:
			if previous.bounds.intersects(bounds): return []
		result.append({"text":text,"bounds":bounds,"baseline":bounds.position+Vector2(0,font.get_ascent(font_size))})
	return result


func clock_counter_layout(cycles: int) -> Array[Dictionary]:
	# Actual engine cycles, already named CYCLE in engine_panel.gd209.
	# A centered half-face rectangle is contained in the measured ellipse.
	var face := clock_face()
	# Rectangle inscribed in the shorter hand ellipse: its normalized corner
	# has coordinates(1/sqrt(2),1/sqrt(2)). One existing screen-pixel inset
	# leaves every hour hand tip visible beyond the central plate.
	var clock := clock_layout(0,0)
	var extent: Vector2 = clock.hour_radius/sqrt(2.0)
	var window := Rect2(face.get_center()-extent,extent*2.0).grow(-1.0)
	var font := ThemeDB.fallback_font
	var result: Array[Dictionary]=[]
	var label_height := window.size.y*(1.0-6.0/9.0)
	var minimum_height := font.get_ascent(1)+font.get_descent(1)
	var lines := [str(cycles)] if minimum_height>label_height else ["CYCLES",str(cycles)]
	for line in lines:
		var slot := Rect2(window.position,Vector2(window.size.x,label_height)) if result.is_empty() else Rect2(window.position+Vector2(0,label_height),Vector2(window.size.x,window.size.y-label_height))
		if lines.size()==1: slot=window
		var size := maxi(1,mini(roundi(slot.size.y),clock_layout(0,0).font_size))
		while size>0:
			var glyph := Vector2(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,font.get_ascent(size)+font.get_descent(size))
			if glyph.x<=slot.size.x and glyph.y<=slot.size.y:
				var bounds := Rect2(slot.get_center()-glyph/2.0,glyph)
				result.append({"text":line,"font_size":size,"bounds":bounds,"window":window,
					"baseline":bounds.position+Vector2(0,font.get_ascent(size))})
				break
			size-=1
	# Stack the actual glyph heights, keeping the center plate compact enough
	# to leave both clock hands visible outside it at every dial direction.
	var total_height := 0.0
	for line in result: total_height+=line.bounds.size.y
	var top := face.get_center().y-total_height/2.0
	var plate := Rect2()
	for line in result:
		line.bounds.position.y=top
		line.baseline.y=top+font.get_ascent(line.font_size)
		top+=line.bounds.size.y
		plate=line.bounds if plate.size==Vector2.ZERO else plate.merge(line.bounds)
	# Place the compact readout below the ivory dial, on its lower brass rim.
	# The measured face end is the boundary; the existing stroke leaves clearance.
	var offset: float = face.end.y+clock.stroke-plate.position.y
	for line in result:
		line.bounds.position.y += offset
		line.baseline.y += offset
		line.window = Rect2(plate.position+Vector2(0,offset),plate.size).grow(1.0)

	return result


func _draw_clock() -> void:
	var layout := clock_layout(app.calendar.hour,app.calendar.minute)
	var font := ThemeDB.fallback_font
	for numeral in layout.numerals:
		draw_string(font,numeral.baseline,numeral.text,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.font_size,ICON_INK)
	_draw_clock_hand(layout.center, layout.hour_end, layout.hub_radius, layout.stroke)
	_draw_clock_hand(layout.center, layout.minute_end, layout.stroke, layout.stroke)
	# Turned brass cap, with the same dark rim and warm bevel as the panel.
	draw_circle(layout.center, layout.hub_radius, ICON_INK)
	draw_circle(layout.center, layout.stroke, READOUT_COLOR.darkened(0.3))
	draw_arc(layout.center, layout.stroke, PI, TAU, 12, READOUT_COLOR, 1.0, true)
	draw_circle(layout.center, 1.0, ICON_INK)
	var counter := clock_counter_layout(app.engine.cycles)
	if not counter.is_empty():
		draw_rect(counter[0].window,ICON_INK)
		draw_rect(counter[0].window,READOUT_COLOR,false,1.0)
		for line in counter:
			draw_string(font,line.baseline,line.text,HORIZONTAL_ALIGNMENT_LEFT,-1,line.font_size,READOUT_COLOR)


func _draw_clock_hand(center: Vector2, tip: Vector2, half_width: float, bevel: float) -> void:
	# Presentation adaptation requested5Oct: machined lancet, using the existing
	# hand endpoint, dial stroke/hub dimensions and authored brass/ink palette.
	var axis := (tip-center).normalized()
	var side := axis.orthogonal()
	var shoulder := tip-axis*half_width
	var base := center-axis*half_width
	var left := center+side*half_width
	var right := center-side*half_width
	var outline := PackedVector2Array([base,left,shoulder+side*bevel,tip,shoulder-side*bevel,right])
	draw_colored_polygon(outline,ICON_INK)
	draw_colored_polygon(PackedVector2Array([center,left,tip]),READOUT_COLOR.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([center,tip,right]),READOUT_COLOR.darkened(0.5))
	draw_line(center+side*bevel,shoulder,READOUT_COLOR,1.0,true)


func _draw_readouts() -> void:
	_readout(str(app.engine.lignite), 0)
	_readout(str(app.engine.anthracite), 1)
	# TIME's refused entry stops displacement without rewriting the engine's
	# stored speed; display the stationary train truthfully during that scene.
	_readout(str(0 if app.journey.blocked else app.engine.speed), 2)


func readout_window(index: int) -> Rect2:
	if reference_pixels and ecs_art.available:
		# Original YODA coal icons at z32/20/8, adjacent numeric wells.
		return screen_rect(Rect2(278, 162 + 12 * index, 40, 11))
	var source: Rect2 = READOUT_INNERS[index]
	var source_slice: Rect2 = ART_SLICES[2][0]
	var logical_slice: Rect2 = ART_SLICES[2][1]
	var ratio := logical_slice.size / source_slice.size
	return screen_rect(Rect2(logical_slice.position + (source.position - source_slice.position) * ratio, source.size * ratio))


func readout_layout(value: String, index: int) -> Dictionary:
	# Account for the full font ascent/descent and the shadow, not only advance
	# width. One additional screen pixel guards the sampled inner window boundary.
	var window := readout_window(index).grow(-1.0)
	if window.size.x <= 1.0 or window.size.y <= 1.0:
		return {}
	var font := ThemeDB.fallback_font
	var font_size := maxi(1, roundi(7.0 * frame_rect().size.x / LOGICAL_SIZE.x))
	while font_size > 0:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ascent := font.get_ascent(font_size)
		var height := ascent + font.get_descent(font_size)
		var baseline := Vector2(floorf(window.end.x - width - 1.0), window.get_center().y - (height + 1.0) / 2.0 + ascent)
		var bounds := Rect2(baseline - Vector2(0, ascent), Vector2(width + 1.0, height + 1.0))
		if window.encloses(bounds):
			return {"font_size": font_size, "baseline": baseline, "bounds": bounds}
		font_size -= 1
	return {}


func _readout(value: String, index: int) -> void:
	var layout := readout_layout(value, index)
	if layout.is_empty():
		return
	var font := ThemeDB.fallback_font
	# source: authored one-screen-pixel shadow, included in readout_layout bounds.
	draw_string(font, layout.baseline + Vector2.ONE, value, HORIZONTAL_ALIGNMENT_LEFT, -1, layout.font_size, ICON_INK)
	draw_string(font, layout.baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1, layout.font_size, READOUT_COLOR)


func _draw_map_commands() -> void:
	if _icon_atlas == null:
		return
	# source: authored 1536x1024 atlas, six 512-square cells. Original ECS03/07
	# supplies the roles: overall map / return, reverser, STOP. The detailed-map
	# image remains baked into the plate. Preserve atlas aspect ratio in each slot.
	_draw_command_icon(4 if overview_context else 1, MAP_COMMANDS[1])


func _draw_command_icon(index: int, slot: Rect2) -> void:
	# source: one logical pixel inset leaves the illustrated brass frame visible;
	# square cell bounds retain the authored transparent padding and shadow.
	var available := slot.grow(-1.0)
	var side := minf(available.size.x, available.size.y)
	var destination := Rect2(available.get_center() - Vector2.ONE * side / 2.0, Vector2.ONE * side)
	var source := Rect2((index % 3) * 512, (index / 3) * 512, 512, 512)
	# Native city32034: _draw resets its transform before these HUD commands.
	draw_texture_rect_region(_icon_atlas, screen_rect(destination), source)


# Source: ECS scroll bounds x14/x304, composition startx300,y153.5;
# panel-layout.md. Keep complete authored thumbnails inside the arrow interval.
func composition_window() -> Rect2:
	return screen_rect(Rect2(14,149,300-14,158-149))


func composition_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if app == null: return result
	var renderer = app.world_view.train_renderer
	var right := 300
	var factor := frame_rect().size.x / LOGICAL_SIZE.x
	var window := composition_window()
	for index in range(ecs_art.first_wagon, app.wagons.count()):
		var wagon: Array = app.wagons.wagons[index]
		var kind: String = preload("res://scripts/train_consist.gd").TYPE_TO_KIND[int(wagon[0])]
		var vehicle: Dictionary = renderer.frame_for(kind)
		var width: int = ecs_art.wagon_width(wagon)
		if not vehicle.is_empty():
			var extent: Vector2 = vehicle.bounds.size
			var scale := minf((width - 2.0) / extent.y, 5.0 / extent.x) * factor
			var center := screen_rect(Rect2(right - width / 2.0, 153.5, 0, 0)).position
			var transform: Transform2D = renderer.registration(vehicle,center,-PI/2,scale)
			var bounds: Rect2 = transform * vehicle.bounds
			# The old post-draw stop painted a partial wagon over the left arrow.
			# Registration can offset alpha bounds from contact-anchor centers,
			# so contain the actual transformed drawing, not only nominal width.
			if not window.encloses(bounds): break
			result.append({"vehicle":vehicle,"transform":transform,"bounds":bounds,
				"color":Color("#7d6551") if int(wagon[1])==3 else Color.WHITE})
		right -= width
		if right < 14: break
	return result


func _draw_composition() -> void:
	for item in composition_layout():
		draw_set_transform_matrix(item.transform)
		app.world_view.train_renderer.draw_frame(self,item.vehicle,item.color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func launcher_icon_rect() -> Rect2:
	# Alpha-fit the side-elevation artwork uniformly into the same ECS slot.
	var source: Rect2 = ART_SLICES[0][0]
	var target: Rect2 = ART_SLICES[0][1]
	# Measured blank train-button interior on the unchanged v2 raster.
	var interior := Rect2(750,430,226,130)
	var ratio := target.size/source.size
	var slot := screen_rect(Rect2(target.position+(interior.position-source.position)*ratio,interior.size*ratio))
	if _launcher_bounds.size == Vector2.ZERO: return Rect2()
	var factor := minf(slot.size.x/_launcher_bounds.size.x,slot.size.y/_launcher_bounds.size.y)
	var extent := _launcher_bounds.size*factor
	return Rect2(slot.get_center()-extent/2.0,extent)


func _draw_launcher() -> void:
	# YODA0x7a4: icon exposed only after wagon13 is bought; command9 unchanged.
	if not app.wagons.wagons.any(func(w): return int(w[0]) == 13): return
	if _launcher_icon == null: return
	draw_texture_rect_region(_launcher_icon,launcher_icon_rect(),_launcher_bounds)
