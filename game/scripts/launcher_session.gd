extends RefCounted

# MIT. YODA0x672 gates; CARTE0x1b91 removal,0x1c97 delayed missile debit.
const Model = preload("res://scripts/launcher_model.gd")
const Snapshot = preload("res://scripts/launcher_snapshot.gd")
const Scene = preload("res://scripts/launcher_scene.gd")
var app
var scene
var model
var paused := false


func attach(owner) -> void:
	app = owner
	scene = Scene.new()
	scene.session = self
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(scene)
	scene.hide()


func open() -> bool:
	if model != null:
		resume_pending()
		return true
	var bought: bool = app.wagons.wagons.any(func(w): return w[0] == 13)
	var missiles := 0
	for wagon in app.wagons.wagons:
		if wagon[2] == 2:
			missiles += wagon[3]
	var gate := preload("res://scripts/panel_hotspots.gd").launcher_action(bought,missiles)
	if gate.is_empty():
		return false
	if gate.kind == "textek":
		app.works_dialog.inform(gate.id)
		return false
	app._open_panel("room")
	model = Model.new()
	paused = false
	resume_pending()
	return true


func action(code: int) -> bool:
	if model == null or paused:
		return false
	var changed: bool = model.action(code,app.journey.position,app.encounters.enemies)
	if changed:
		if code == 108:
			app.engine.speed = 0 # manual: train stops while firing.
			app.game_audio.effect("berta",0x574)
		elif code == 107:
			app.game_audio.effect("berta",0x596)
		else:
			app.game_audio.effect("berta",0x568)
		scene.queue_redraw()
	return changed


func advance(delta: float) -> void:
	if model == null or paused or not scene.visible:
		return
	var before: String = model.phase
	model.advance(delta)
	if model.phase in ["impact","report"] and not model.removed and model.geometry.target >= 0:
		app.encounters.enemies.remove(model.geometry.target)
		model.removed = true
		app.world_view.queue_redraw()
	if not before in ["impact","report"] and model.phase in ["impact","report"] and model.status != 0:
		app.game_audio.son(5)
	scene.queue_redraw()


func dismiss() -> void:
	if model == null:
		return
	if model.phase == "report":
		for wagon in app.wagons.wagons:
			if wagon[2] == 2 and wagon[3] > 0:
				wagon[3] -= 1
				break
		app._on_cargo_changed()
	elif not model.phase in ["aim","armed","arming","disarming"]:
		return # source continuation must finish; options/save suspend it instead.
	reset()
	app._open_panel("room")


func reset() -> void:
	model = null
	paused = false
	if scene != null:
		scene.hide()


func resume_pending() -> void:
	if model != null:
		scene.show()
		scene.queue_redraw()


func blocks_simulation() -> bool:
	return model != null


func handle_key(input: InputEventKey) -> bool:
	if model == null or not scene.visible:
		return false
	match input.physical_keycode:
		KEY_P:
			paused = not paused
		KEY_F6:
			paused = true
			scene.hide()
			app._open_panel("options")
		KEY_F5: app.save_view()
		KEY_ESCAPE,KEY_ENTER,KEY_SPACE: dismiss()
		_: return false
	scene.queue_redraw()
	return true


func snapshot() -> Dictionary:
	return {"version":1,"active":model != null,"visible":scene.visible if model != null else false,"paused":paused,"state":model.snapshot() if model != null else {}}


static func validate_snapshot(value: Variant, wagons, enemies, origin: Vector2i) -> bool:
	return Snapshot.validate(value,wagons,enemies,origin)


func restore(value: Dictionary) -> void:
	reset()
	if value.active:
		model = Model.new()
		model.restore(Snapshot.normalized(value.state))
		paused = value.paused
		scene.visible = value.visible
		scene.queue_redraw()
