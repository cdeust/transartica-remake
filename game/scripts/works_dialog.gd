extends PanelContainer

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


func _ready() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_lines = Label.new()
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lines)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	# TEXTEK resource 11: NO on the left, OK on the right (YODA 0x2d6b click zones).
	_no = _button(row, "NO", _decline)
	_yes = _button(row, "OK", _accept)
	_ok = _button(row, "OK", func(): _close(_ok_result))
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
	_show(_message(TrackWorks.WORKS[kind].question), true)
	return true


func _accept() -> void:
	var missing := TrackWorks.shortage(kind, wagons)
	if not missing.is_empty():
		var lines := _message(TrackWorks.WORKS[kind].lack)
		lines.append_array(LACK_RAILS if missing == "rails" else LACK_SLAVES)
		_ok_result = false
		_show(lines, false)
		return
	var used := TrackWorks.consume_rails(wagons, TrackWorks.rails_needed(kind, rng))
	var network = journey.network
	network.repair(journey.next_cell())
	journey.resume_after_works()
	# TEXTEK 74..76 is a computed work screen; its layout is not decoded, only its items.
	_ok_result = true
	_show(["%d RAILS" % used, "%d SLAVE(S)" % TrackWorks.slaves_carried(wagons)], false)


func _decline() -> void:
	_close(false)


func _close(repaired: bool) -> void:
	hide()
	finished.emit(repaired)


func _show(lines: Array, question: bool) -> void:
	_lines.text = "\n".join(lines)
	_yes.visible = question
	_no.visible = question
	_ok.visible = not question
	show()


func _message(id: int) -> Array:
	var lines: Array = texts.get(str(id), [])
	return lines.duplicate() if not lines.is_empty() else ["TEXTEK %d" % id]


func _button(row: HBoxContainer, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(120, 40)
	button.pressed.connect(action)
	row.add_child(button)
	return button
