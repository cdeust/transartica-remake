extends SceneTree
# MIT. Prepared source arithmetic fixtures, not native campaign evidence.
const Extraction = preload("res://scripts/mine_extraction.gd")
var errors: Array[String] = []
func _initialize() -> void:
	var wagons: Array = [[21,0,0,0],[5,3,0,24],[7,0,0,2],[16,3,0,0],[16,2,0,0]]
	var crew := Extraction.resources(wagons)
	check(crew == {"slaves":24,"mammoths":2,"cranes":1},"crew selection preserves source state guards")
	# Work234; integer234/5=46; wealth40 =>41*47=1927.
	check(Extraction.calculate(wagons,crew,40,494,0) == 1927,"source work and wealth multiplication")
	check(Extraction.calculate(wagons,crew,40,4900,0) == 100,"remaining combined coal capacity bounds credit")
	check(Extraction.calculate(wagons,crew,-1,0,0) == 47,"negative wealth uses zero")
	check(Extraction.calculate(wagons,crew,40,5100,0) == -100,"source negative free space is retained")
	check(Extraction.credited_total(5100,-100) == 5000,"negative grant source subtraction")
	check(Extraction.credited_total(31000,1000) == 31000,"source coal upper cap")
	check(Extraction.credited_total(32000,1000) == 31000,"source word overflow cap")
	var capacity: Array = []
	for index in 7: capacity.append([21,0,0,0])
	check(Extraction.calculate(capacity,{"slaves":0,"mammoths":0,"cranes":0},40,31990,0) == 10,"negative capacity overflow uses32000")
	var large := {"slaves":10000,"mammoths":0,"cranes":0}
	# 41*2001=82041 wraps to16505, before capacity bound.
	check(Extraction.calculate(capacity,large,40,0,0) == 16505,"positive quantity word overflow retained")
	check(Extraction.calculate(capacity,{"slaves":4000,"mammoths":0,"cranes":0},40,0,0) == 30000,"negative quantity word overflow replaces30000")
	for error in errors: push_error(error)
	if errors.is_empty(): print("PASS: source mine crew, capacity, word overflow, quantity and coal caps")
	quit(0 if errors.is_empty() else 1)
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)
