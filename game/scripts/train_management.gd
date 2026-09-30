extends RefCounted

# MIT. GLIEU station workshop0x21ea..2b10, verified private ALIS listing.
const Wagons = preload("res://scripts/train_wagons.gd")
# source: GLIEU0x2a48 switch, one base repair price per wagon type1..25.
const REPAIR_PRICES := [100,80,50,80,10,15,20,60,30,50,50,40,80,30,30,60,10,15,40,30,10,60,15,20,80]
# source: TEXTE2K messages used by GLIEU0x2546,0x256a,0x2637,0x25c1.
const REFUSED_SCRAP := 87
const UNDAMAGED := 35
const PROTECTED := 88
const NO_MONEY := 50

var wagons
var engine


func attach(active_wagons, active_engine) -> void:
	wagons = active_wagons
	engine = active_engine


func station_name(cell: Vector2i) -> String:
	# GLIEU0x2202..22c5 uses the train x/y, not station city metadata.
	if cell.x < 30:
		return "LEEDS STATION"
	if cell.x < 70:
		return "AOUDJILA STATION"
	if cell.x < 100:
		return "NOVOMOSKOVSK STATION"
	return "BALKHACH STATION" if cell.y < 50 else "OMAN STATION"


func repair_price(index: int) -> int:
	if index < 0 or index >= wagons.count():
		return 0
	var wagon: Array = wagons.wagons[index]
	return REPAIR_PRICES[int(wagon[Wagons.TYPE]) - 1] * int(wagon[Wagons.STATE])


func repair_refusal(index: int) -> int:
	if index < 0 or index >= wagons.count():
		return PROTECTED
	var state: int = wagons.wagons[index][Wagons.STATE]
	if state == 3:
		return REFUSED_SCRAP
	if state == 0:
		return UNDAMAGED
	return NO_MONEY if engine.lignite < repair_price(index) else 0


func repair(index: int, confirm: bool) -> bool:
	if not confirm or repair_refusal(index) != 0:
		return false
	engine.lignite -= repair_price(index)
	wagons.wagons[index][Wagons.STATE] = 0
	return true


func remove_refusal(index: int) -> int:
	if index < 0 or index >= wagons.count():
		return PROTECTED
	var wagon: Array = wagons.wagons[index]
	# Exact GLIEU0x2604 condition is QUANTITY!=3 for a tender, not STATE.
	return PROTECTED if wagon[Wagons.TYPE] < 4 or (wagon[Wagons.TYPE] == 21 and wagon[Wagons.QUANTITY] != 3) else 0


func remove(index: int, confirm: bool) -> bool:
	if not confirm or remove_refusal(index) != 0:
		return false
	wagons.wagons.remove_at(index)
	return true


# GLIEU0x242c saves four fields, removes source, then inserts at the clicked
# destination's unchanged numeric index. This is an insertion, not a swap.
func move(from_index: int, to_index: int) -> bool:
	if from_index < 0 or to_index < 0 or from_index >= wagons.count() or to_index >= wagons.count():
		return false
	var wagon: Array = wagons.wagons[from_index]
	wagons.wagons.remove_at(from_index)
	wagons.wagons.insert(to_index, wagon)
	return true


func equipment_flags() -> Dictionary:
	# GLIEU0x27c3 skips STATE>=3 and finds types4/10/13; these drive instruments
	# and missile access in YODA, recomputed after removing any wagon.
	var instruments := 0
	var launcher := false
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] >= 3:
			continue
		if wagon[Wagons.TYPE] == 4:
			instruments = 2
		elif wagon[Wagons.TYPE] == 10:
			instruments = maxi(instruments, 1)
		elif wagon[Wagons.TYPE] == 13:
			launcher = true
	return {"instruments": instruments, "launcher": launcher}
