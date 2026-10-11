extends "res://tests/native_play_console.gd"
# MIT. Exercise the actual capture branch without launching a scene or renderer.
var captures: Array[String] = []
func _initialize() -> void:
	for command in [{}, {"label":"move"}, {"label":"observe-state"}, {"capture":false}, {"capture":"true"}, {"capture":1}]:
		assert(not _capture_requested(command))
		_capture_frame("ignored", _capture_requested(command))
	assert(captures.is_empty(), "Default and observer commands must not write screenshots")
	_capture_frame("requested-action", _capture_requested({"label":"move","capture":true}))
	_capture_frame("requested-observer", _capture_requested({"label":"observe-state","capture":true}))
	_capture_frame("boot", true)
	assert(captures == ["requested-action","requested-observer","boot"])
	print("PASS: native screenshot branch is explicit; observers may request capture; boot retains one")
	quit()
func _write_capture(prefix: String) -> void:
	captures.append(prefix)
