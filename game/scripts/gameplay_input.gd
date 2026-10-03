extends RefCounted

# MIT. Host keyboard routing; original commands remain in their owning modules.
# source: tasks/evidence/boudoir-layout.md, panel-layout.md and combat.md.

static func _unhandled_key_input(app, event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var mapped: InputEventKey = app.get_node("KeyboardSettings").bindings.canonical(event)
	# Function-key saves can interrupt dialogs. A letter/Enter binding respects
	# original text entry and confirmation before becoming a gameplay command.
	if mapped.physical_keycode == KEY_F5 and event.physical_keycode >= KEY_F2 and event.physical_keycode <= KEY_F12:
		app._save_view()
		app.get_viewport().set_input_as_handled()
		return
	# Visible OPTIONS owns input even when a loaded story scene remains beneath it.
	if app._boudoir_session.reception.visible:
		app._boudoir_session.reception.handle_key(event)
		app.get_viewport().set_input_as_handled()
		return
	if app.encounters.manual_scene.visible:
		app.encounters.manual_scene.handle_key(_tactical_key(event,mapped))
		return
	if app.campaign.handle_key(event) or app._world_session.handle_key(event):
		app.get_viewport().set_input_as_handled()
		return
	if app.encounters.report.visible:
		app.encounters.report.handle_key(event)
		return
	# LineEdit handles Unicode in unhandled_key_input too (Godot 4.5 line_edit.cpp).
	if app.get_viewport().gui_get_focus_owner() is LineEdit and event.physical_keycode not in [KEY_ESCAPE, KEY_F1]:
		return
	if app._boudoir_session.handle_key(event,mapped):
		app.get_viewport().set_input_as_handled()
		return
	# GRANADA native play1375: commerce owns Escape before the general map close.
	if app._city_panel.visible:
		# Layout keycode: the - and + keys differ between QWERTY and AZERTY.
		if app._city_panel.handle_key(event.keycode):
			app.get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE:
		app._modal.hide()
		app.room_controls.show_help = false
		app.room_controls.show_instruments = false
		app.instruments.hide()
		app.get_viewport().set_input_as_handled()
		return
	match mapped.physical_keycode:
		KEY_L: app.room_controls.activate("lignite")
		KEY_A: app.room_controls.activate("anthracite")
		KEY_B: app.room_controls.activate("brake")
		KEY_SPACE: app.room_controls.activate("pause")
		KEY_H: app.room_controls.activate("help")
		KEY_M: app._open_panel("map")
		KEY_J: app._open_panel("journal")
		KEY_LEFT: app.engine.set_regulator(app.engine.regulator - (1 if event.shift_pressed else 15))
		KEY_RIGHT: app.engine.set_regulator(app.engine.regulator + (1 if event.shift_pressed else 15))
		KEY_F5: app._save_view()
		KEY_F6: app._open_panel("options")
		KEY_R: app._restart_engine()
		_: return
	app.get_viewport().set_input_as_handled()


static func _tactical_key(event: InputEventKey, mapped: InputEventKey) -> InputEventKey:
	# Source: tactical_scene.handle_key owns these context commands. Configurable
	# SAVE/OPTIONS may use an otherwise unused key, but cannot steal actor actions.
	var context := [KEY_P,KEY_EQUAL,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT,KEY_ENTER,
		KEY_Q,KEY_E,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_S]
	if event.physical_keycode in context:
		return event
	if mapped.physical_keycode in [KEY_F5,KEY_F6] or event.physical_keycode in [KEY_F5,KEY_F6]:
		return mapped
	return event
