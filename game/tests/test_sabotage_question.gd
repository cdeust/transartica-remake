extends SceneTree

# MIT. Prepared presentation regression, not native campaign acceptance.
# Source: CARTE0x27f9..281d image238/form2 confirms action33; no TEXTEK text.
const Session = preload("res://scripts/campaign_session.gd")
const Screen = preload("res://scripts/campaign_screen.gd")


func _initialize() -> void:
	var session = Session.new()
	var screen = Screen.new()
	session.screen = screen
	var event: Dictionary = session.state._event("sabotage_confirm", [], {"spy":0})
	var before: Dictionary = session.state.snapshot()
	session._show_page()
	assert(screen.lines == ["ORDER THIS SPY TO USE DYNAMITE HERE?"], "Empty source-ID list must still explain this confirmation")
	assert(screen.question and not screen.entering_code, "Existing NO/OK confirmation remains active")
	assert(screen.is_quarters_scene(), "Preserve crew scene and shared train strip")
	assert(session.state.snapshot() == before and event.messages.is_empty(), "Clarification must leave pending spy/action/save state unchanged")
	var legacy: Dictionary = session.snapshot().duplicate(true)
	legacy.presentation.lines = []
	assert(Session.validate_snapshot(legacy), "Previous empty presentation stays valid")
	assert(session.restore(legacy), "Old opened sabotage save restores")
	var upgraded: Dictionary = session.snapshot()
	assert(not upgraded.presentation.lines.is_empty(), "Restoring old save repairs the blank question immediately")
	upgraded.presentation.lines = []
	assert(upgraded == legacy, "Upgrade changes only empty presentation lines")
	var preserved: Dictionary = session.snapshot().duplicate(true)
	preserved.presentation.lines = ["ALREADY SAVED QUESTION"]
	assert(session.restore(preserved) and session.snapshot() == preserved, "Nonempty saved presentation remains untouched")
	screen.free()
	print("PASS: sabotage confirmation explains existing dynamite action without changing campaign state")
	quit()
