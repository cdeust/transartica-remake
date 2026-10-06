extends SceneTree

# MIT. CARTE0x27ae..27ce rejects travelling/used spies before image238/form2.
const Session = preload("res://scripts/campaign_session.gd")
var failures: Array[String] = []

class Surface extends RefCounted:
	var calls := 0
	func hide() -> void: calls += 1
	func leave() -> void: calls += 1

class MotionEngine extends RefCounted:
	var brake := false
	var speed := 7 # Test sentinel: rejected prompts must preserve any nonzero speed.

class Clock extends RefCounted:
	var factor := 3 # Test sentinel distinct from the scene prelude's factor1.

class Simulation extends RefCounted:
	var paused := false

class App extends RefCounted:
	var engine = MotionEngine.new()
	var calendar = Clock.new()
	var session = Simulation.new()
	var _boudoir_session = Surface.new()
	var _modal = Surface.new()
	var instruments = Surface.new()
	var panel := ""
	func _open_panel(value: String) -> void: panel = value

class Probe extends Session:
	var shown := 0
	var audio := 0
	func _show_page() -> void: shown += 1
	func _play_scene_audio(_scene: String) -> void: audio += 1

func _init() -> void:
	for case in [[3, 100, false], [3, 123, false], [2, 0, false], [3, 99, true], [3, 0, true]]:
		var probe = Probe.new()
		var app = App.new()
		probe.app = app
		probe.state.spies[0][0] = case[0]
		probe.state.spies[0][13] = case[1]
		probe.state.pending = {"scene": "sabotage_confirm", "spy": 0, "messages": []}
		probe.present(probe.state.pending)
		var allowed: bool = case[2]
		_check(probe.shown == int(allowed), "confirmation eligibility %s" % [case])
		_check(probe.audio == int(allowed), "audio follows eligibility %s" % [case])
		_check(app.session.paused == allowed and app.engine.brake == allowed, "rejection preserves simulation %s" % [case])
		_check(app.engine.speed == (0 if allowed else 7) and app.calendar.factor == (1 if allowed else 3), "rejection preserves motion and clock %s" % [case])
		_check(app._boudoir_session.calls == int(allowed) and app._modal.calls == int(allowed) and app.instruments.calls == int(allowed), "rejection skips scene transition %s" % [case])
		_check(probe.state.pending.is_empty() == not allowed, "rejected pending event cleared %s" % [case])
		_check(app.panel == ("" if allowed else "quarters"), "rejected selection returns to quarters %s" % [case])
		_check(probe.state.spies[0][13] == case[1], "prompt does not consume or replenish charge %s" % [case])
	for failure in failures: push_error(failure)
	print("PASS: 40 spy sabotage prompt checks" if failures.is_empty() else "FAIL: %d spy sabotage prompt checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
