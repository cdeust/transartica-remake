extends RefCounted

# MIT. TIME0x1444 phase-one turning; TIME0x1a25 movement and0x21d5 bounce.
const Rails = preload("res://scripts/rail_network.gd")
const Hazards = preload("res://scripts/campaign_hazards.gd")
const OBSTACLES := [34,35,36,37,65,67,69,78,79,107,114,116,120]
const REVERSE := {1:9,2:8,3:7,4:6,5:5,6:4,7:3,8:2,9:1}

static func turn(cell: Vector2i, heading: int, phase: int, history: Array, network, rng: RandomNumberGenerator) -> int:
	if phase != 1:
		return heading
	var code: int = absi(network.tile(cell))
	var base: int = code - code % 2
	if not Rails.SWITCH_RULES.has(base):
		return network.turn(cell, heading)
	var rule: Array = Rails.SWITCH_RULES[base]
	if heading != rule[0]:
		return network.turn(cell, heading)
	var diverge: bool = network.switch_diverges(cell) if cell in history else rng.randi_range(0,1) == 1
	return int(rule[1]) if diverge else heading

static func step(cell: Vector2i, heading: int, bit: int, network, traps: Array = []) -> Dictionary:
	var candidate: Vector2i = cell + Rails.DELTAS[heading]
	if bit != 2:
		var trap: int = Hazards.TRAPS.find(candidate)
		var blocked: bool = bit == 16 and network.tile(candidate) < 0 and trap >= 0 and traps.size() == Hazards.TRAPS.size() and traps[trap] == -1
		# The signed -113 case at TIME228c is unreachable after abs; retain source behavior.
		if blocked or absi(network.tile(candidate)) in OBSTACLES:
			return {"cell":cell,"heading":REVERSE[heading]}
	return {"cell":candidate,"heading":heading}
