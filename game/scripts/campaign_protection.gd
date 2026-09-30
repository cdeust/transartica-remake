extends "res://scripts/campaign_crew.gd"

# MIT. YODA0xe80/ec8 city controls; SCENE4d5→3b5 control before CODE.
const Quiz = preload("res://scripts/manual_quiz.gd")

func before_city(index: int) -> bool:
	var name := "soleil" if index > 4 and index < 10 else "viking" if index == 12 else ""
	if name.is_empty() or state.protection_seen[name]:
		return false
	if name == "soleil":
		state.protection_seen[name] = true # YODAe9d sets6519 before loading.
	begin_quiz(name, {"city": index})
	return true


func begin_quiz(name: String, resume: Dictionary) -> void:
	state.pending = Quiz.create(name, app._trade_rng, resume)
	call("present", state.pending)


func submit_quiz(text: String) -> void:
	var name: String = state.pending.quiz
	var result: Dictionary = Quiz.submit(state.pending, text, state.data, app._trade_rng)
	if result.get("exit", false):
		app.get_tree().quit() # Three failed attempts: original cunload0 / exit.
	elif result.get("accepted", false):
		state.dismiss()
		if result.resume.has("city"):
			state.protection_seen[name] = true # YODAef6 sets651a after VIKING.
			screen.hide()
			app._open_city(int(result.resume.city))
		else:
			state.pending = result.resume
			call("present", state.pending)
	else:
		screen.present("manual_quiz", Quiz.lines(state.pending, state.data), true)
