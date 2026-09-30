extends "res://scripts/world_event_screen.gd"

# Question and result screens of YODA 0x2390 for a blocked obstacle cell. After either
# answer the brake stays on; the player releases it (YODA 0x18e3 never does).
# Rules: track_works.gd; texts: TEXTEK switch 0x84 in private data (tools/claude/export_textek.py).
const TrackWorks = preload("res://scripts/track_works.gd")
const PRIVATE_NAME := "textek.json"
# TEXTEK 0x454d / 0x4588: suffix lines appended to the lack message.
const LACK_RAILS := ["BUT YOU DON'T HAVE", "ENOUGH RAILS TO REPAIR"]
const LACK_SLAVES := ["BUT YOU DON'T HAVE ENOUGH", "SLAVES TO WORK ON IT"]

signal finished(repaired: bool)

var journey
var wagons
var rng: RandomNumberGenerator
var texts: Dictionary = {}
var kind := ""
var _lines: Label
var _yes: Button
var _no: Button
var _ok: Button
var _ok_result := false
var _pending_cell := Vector2i(-1, -1)
var _pending_code := 0
var countdown := 0
var _result_lines: Array = []


func _ready() -> void:
	super._ready()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines = Label.new()
	_lines.hide() # source: text is painted in the decoded scene banner.
	add_child(_lines)
	# TEXTEK resource 11: NO on the left, OK on the right (YODA 0x2d6b click zones).
	_no = _button("NO", _decline)
	_yes = _button("OK", _accept)
	_ok = _button("OK", func(): _close(_ok_result))
	resized.connect(_layout_buttons)
	_layout_buttons()
	hide()


func load_texts(project_root: String) -> bool:
	var path := "res://private-data/" + PRIVATE_NAME
	if not FileAccess.file_exists(path):
		path = project_root.path_join("../reference-private/" + PRIVATE_NAME)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("messages") is Dictionary:
		return false
	texts = parsed.messages
	return true


func ask(network) -> bool:
	kind = TrackWorks.kind_for(network.tile(journey.next_cell()))
	if kind.is_empty():
		return false
	_pending_cell = Vector2i(-1, -1)
	_ok_result = false
	_show(_message(TrackWorks.WORKS[kind].question), true)
	countdown = 0
	return true


# A TEXTEK message closed by OK, for event handlers without a question.
func inform(id: int) -> void:
	kind = ""
	_ok_result = false
	_show(_message(id), false)


func _accept() -> void:
	# An accepted screen can be resumed from disk; never charge twice.
	if _ok_result or kind.is_empty():
		return
	var missing := TrackWorks.shortage(kind, wagons)
	if not missing.is_empty():
		var lines := _message(TrackWorks.WORKS[kind].lack)
		lines.append_array(LACK_RAILS if missing == "rails" else LACK_SLAVES)
		_ok_result = false
		_show(lines, false)
		return
	var used := TrackWorks.consume_rails(wagons, TrackWorks.rails_needed(kind, rng))
	_pending_cell = journey.next_cell()
	_pending_code = journey.network.tile(_pending_cell)
	var report := TrackWorks.work_report(kind, wagons)
	countdown = int(report.ticks)
	# YODA 0x25c2 waits for TEXTEK's dismissal before 0x25ce writes the map.
	# TEXTEK 0x41d6..0x4406 spends rails and draws labour before that click.
	_ok_result = true
	_result_lines = ["%d RAILS" % used, "%d SLAVE(S)" % report.slaves,
		"%d MAMMOTH(S)" % report.mammoths, "%d CRANE(S)" % report.cranes]
	_show(_result_lines, false)


func _decline() -> void:
	_close(false)


func _close(repaired: bool) -> void:
	if repaired and _ok_result and journey.network.tile(_pending_cell) == _pending_code:
		journey.network.repair(_pending_cell)
		journey.resume_after_works()
	_pending_cell = Vector2i(-1, -1)
	_ok_result = false
	hide()
	finished.emit(repaired)


# TEXTEK 0x45e6..0x462d: expiry only restores normal clock; click alone exits.
func textek_tick() -> bool:
	if not visible or not _ok_result or countdown <= 0:
		return false
	countdown -= 1
	return countdown == 0


func snapshot() -> Dictionary:
	return {"visible": visible, "kind": kind, "accepted": _ok_result, "question": _yes.visible,
		"cell": [_pending_cell.x, _pending_cell.y], "code": _pending_code,
		"countdown": countdown, "lines": _lines.text, "result_lines": _result_lines.duplicate()}


static func validate_snapshot(value: Variant, network) -> bool:
	if not value is Dictionary or not value.get("visible") is bool or not value.get("accepted") is bool or not value.get("question") is bool:
		return false
	if not value.get("kind") is String or not (value.kind.is_empty() or TrackWorks.WORKS.has(value.kind)):
		return false
	if not value.get("cell") is Array or value.cell.size() != 2 or not value.get("lines") is String:
		return false
	for coordinate in value.cell:
		if not _whole_number(coordinate):
			return false
	if not value.get("result_lines") is Array or not _whole_number(value.get("countdown")) or not _whole_number(value.get("code")):
		return false
	for line in value.result_lines:
		if not line is String:
			return false
	# source: TEXTEK L0x16b signed byte; ALIS opernames.c:114.
	if value.countdown < -128 or value.countdown > 127:
		return false
	var cell := Vector2i(int(value.cell[0]), int(value.cell[1]))
	if value.accepted and (not value.visible or not network.in_bounds(cell) or network.tile(cell) != int(value.code) or TrackWorks.kind_for(int(value.code)) != value.kind):
		return false
	return true


static func _whole_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value))


func restore(value: Variant) -> bool:
	if not validate_snapshot(value, journey.network):
		return false
	var cell := Vector2i(int(value.cell[0]), int(value.cell[1]))
	kind = value.kind
	_pending_cell = cell
	_pending_code = int(value.get("code", 0))
	countdown = int(value.countdown)
	_ok_result = value.accepted
	_result_lines = value.result_lines.duplicate()
	_show(value.lines.split("\n"), value.question)
	visible = value.visible
	return true


func _show(lines: Array, question: bool) -> void:
	_lines.text = "\n".join(lines)
	_yes.visible = question
	_no.visible = question
	_ok.visible = not question
	open_works(kind, lines, question)
	_layout_buttons()


func _message(id: int) -> Array:
	var lines: Array = texts.get(str(id), [])
	return lines.duplicate() if not lines.is_empty() else ["TEXTEK %d" % id]


func _button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.tooltip_text = label
	button.flat = true
	button.pressed.connect(action)
	add_child(button)
	return button


func _layout_buttons() -> void:
	if not is_instance_valid(_no):
		return
	var bounds := canvas_rect()
	var scale_factor := bounds.size.x / 320
	_no.position = bounds.position + Vector2(120,124) * scale_factor
	_yes.position = bounds.position + Vector2(170,124) * scale_factor
	_ok.position = _yes.position
	for button in [_no,_yes,_ok]:
		button.size = Vector2(32,14) * scale_factor
