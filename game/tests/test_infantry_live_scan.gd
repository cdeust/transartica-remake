extends SceneTree
# MIT. Native deployment4965 followed by Down stayed at y6 through tick62.
# Regression fixture only; source WDECOR1390..13b3,1417,150a,173e..1773.

func _initialize() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../reference-private/validation/infantry-stationary-earned-deployment.json"))
	assert(saved is Dictionary and saved.encounters.manual != null)
	var state = preload("res://scripts/tactical_combat.gd").new()
	assert(state.restore(saved.encounters.manual))
	var infantry: Array = state.actors.filter(func(actor): return actor.side == 0)
	assert(infantry.size() == 1 and infantry[0].count == 10)
	var actor: Dictionary = infantry[0]
	var initial_y: int = actor.y
	assert(state.command(actor.id,0)) # TacticalScene's actual Down command.
	# Four complete source scans cover both movement counters:8548/8549.
	var ticks: int = state.columns*7*4/maxi(state.columns/4,40)
	for tick in ticks: state.step()
	if actor.y >= initial_y and actor.roof < 0:
		push_error("Native infantry order remains stationary through full field scans")
		quit(1)
		return
	print("PASS: recorded infantry moves through full combat scans: ",initial_y," -> ",actor.y)
	quit()
