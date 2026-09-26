extends RefCounted

# City transactions ported from glieu.co (tasks/evidence/city-scripts.md §2).
# Prices and stock formulas are private derived data loaded at run time.
# Money is main+0x2fb6, the lignite stock (engine.lignite); anthracite is main+0x2fc8.
const Wagons = preload("res://scripts/train_wagons.gd")

const BUY := 50 # main+0x1c selection codes copied into L0x12
const SELL := 51
# abs(VILLE.FIC field 2), glieu 0x1ef.
const TOWN := 1
const COMMERCIAL := 2
const GARRISON := 4
const MAMMOTH_FAIR := 5
const SLAVE_MARKET := 6
const FIRST_TRADING_CITY := 24 # main+0x6160 rows are city index - 24
const TRADING_CITIES := 22
const GOODS_KINDS := 16
const LIST_SLOTS := 16 # Lw[0x44], 5x4 grid
const SPY_SLOTS := 20 # main[0x5d84][k][0]
const MONEY_CAP := 31000 # glieu 0x565, after a sale
const TENDER_TYPE := 21
const SCRAP_STATE := 3
const COAL_PER_TENDER := 5000 # glieu 0x697..0x6d2
const NOMAD_CITY := 45
# Refusals, texte2k message numbers (glieu 0x344, 0x39a, 0x658, 0x681, 0x6f5).
const NO_ROOM := 51
const NOTHING_TO_SELL := 18
const NO_MONEY := 50
const NOT_ENOUGH_LOAD := 52
const NO_COAL_ROOM := 54
const STOCK_LIMIT := 1 # glieu 0x63c: silent refusal (cstop), not a message.
# Workshop of cities 10..16 (glieu 0x1d64..0x21e7, city-scripts evidence §2.4).
const WAGONS_FULL := 17 # texte2k message, glieu 0x2137: count + quantity > 99
const WORKSHOP_WAGON_LIMIT := 99
const TENDER_LIMIT := 2 # glieu 0x2158: silent refusal, no message.
const MAX_INTACT_TENDERS := 6
const PRIVATE_NAME := "commerce.json"

var data: Dictionary = {}
var stock: Array = [] # 22 x 16, -1 = not sold here
var spy_slots: Array = []


func load_from_project(project_root: String) -> bool:
	var path := "res://private-data/" + PRIVATE_NAME
	if not FileAccess.file_exists(path):
		path = project_root.path_join("../reference-private/" + PRIVATE_NAME)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("stock_init") or parsed.goods_names.size() != GOODS_KINDS \
			or not parsed.has("workshop") or parsed.get("wagon_names", []).size() != 25:
		return false
	data = parsed
	return true


func reset(rng: RandomNumberGenerator) -> void:
	stock = []
	for row in data.stock_init:
		var cells: Array = []
		for cell in row:
			cells.append(int(cell[0]) + _rnd(rng, int(cell[1])) if int(cell[0]) >= 0 else -1)
		stock.append(cells)
	spy_slots = []
	spy_slots.resize(SPY_SLOTS)
	spy_slots.fill(0)


# ornd (opernames.c): the high word of n * seed, hence 0..n-1.
func _rnd(rng: RandomNumberGenerator, n: int) -> int:
	return rng.randi_range(0, n - 1) if n > 0 else 0


# glieu 0x1588: the nomads' antiques stock is redrawn at each visit.
func visit(city: int, rng: RandomNumberGenerator) -> void:
	if city == NOMAD_CITY:
		stock[NOMAD_CITY - FIRST_TRADING_CITY][3] = 5 + _rnd(rng, 40)


func goods_name(goods: int) -> String:
	return String(data.goods_names[goods - 1])


# glieu 0x100..0x143: spies are offered only in cities 8 and 9 with a free file.
func offers_spies(city: int) -> bool:
	return (city == 8 or city == 9) and spy_slots.has(0)


# glieu 0xcd1, 0xd23, 0xd5f, 0xdd2: accepted wagons, capacities and prices.
func offer(city: int, kind: int, mode: int, goods := 0) -> Dictionary:
	var table := ""
	match kind:
		MAMMOTH_FAIR: table = "mammoths"
		SLAVE_MARKET: table = "slaves"
		GARRISON: table = "soldiers" if mode == BUY else "spies"
	var source: Dictionary
	if kind == COMMERCIAL:
		if goods < 1 or goods > GOODS_KINDS or not data.goods.has(str(city)):
			return {}
		source = data.goods[str(city)][goods - 1]
	elif table != "" and data[table].has(str(city)):
		source = data[table][str(city)]
	else:
		return {}
	var result := source.duplicate()
	result.city = city
	result.kind = kind
	# glieu 0x28d: both garrison choices run the purchase path; 51 marks spy files.
	result.mode = BUY if kind == GARRISON else mode
	result.spy = kind == GARRISON and mode == SELL
	result.goods = goods if kind == COMMERCIAL else 0
	return result


func price(o: Dictionary) -> int:
	return int(o.buy) if o.mode == BUY else int(o.sell)


# glieu 0x7a9: L0x28 = quantity x unit price.
func total(o: Dictionary, quantity: int) -> int:
	return quantity * price(o)


# glieu 0x157c: buy lists the city's stock, sell sums goods carried in wagons 14, 15, 17, 18, 19.
func goods_list(city: int, mode: int, wagons) -> Array:
	var result: Array = []
	if mode == BUY:
		var row: Array = stock[city - FIRST_TRADING_CITY]
		for goods in GOODS_KINDS:
			if row[goods] > -1:
				result.append([goods + 1, row[goods]])
		return result
	for wagon in wagons.wagons:
		if not wagon[Wagons.TYPE] in [14, 15, 17, 18, 19] or wagon[Wagons.GOODS] == 0 or wagon[Wagons.QUANTITY] == 0:
			continue
		var found := false
		for entry in result:
			if entry[0] == wagon[Wagons.GOODS]:
				entry[1] += wagon[Wagons.QUANTITY]
				found = true
				break
		if not found and result.size() < LIST_SLOTS:
			result.append([wagon[Wagons.GOODS], wagon[Wagons.QUANTITY]])
	return result


func _accepts(o: Dictionary, wagon: Array, wagon_type: int) -> bool:
	return wagon[Wagons.TYPE] == wagon_type and (o.goods == 0 or wagon[Wagons.GOODS] == 0 or wagon[Wagons.GOODS] == o.goods)


# glieu 0x90a: free room (L0x2a) and carried quantity (L0x2c) in accepted wagons.
func capacity(o: Dictionary, wagons) -> Vector2i:
	var room := 0
	var loaded := 0
	for wagon in wagons.wagons:
		if _accepts(o, wagon, o.wagon_a):
			room += int(o.cap_a) - wagon[Wagons.QUANTITY]
			loaded += wagon[Wagons.QUANTITY]
		elif _accepts(o, wagon, o.wagon_b):
			room += int(o.cap_b) - wagon[Wagons.QUANTITY]
			loaded += wagon[Wagons.QUANTITY]
	return Vector2i(room, loaded)


# glieu 0x31a..0x3ae: entry refusal for mammoths, slaves, soldiers and spies.
func entry_refusal(o: Dictionary, wagons) -> int:
	if o.goods != 0:
		return 0
	var room := capacity(o, wagons)
	if room.x == 0 and o.mode == BUY:
		return NO_ROOM
	if room.y == 0 and o.mode == SELL:
		return NOTHING_TO_SELL
	return 0


func _coal_room(wagons, engine) -> int:
	var room := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] == TENDER_TYPE and wagon[Wagons.STATE] != SCRAP_STATE:
			room += COAL_PER_TENDER
	return room - (engine.lignite + engine.anthracite)


# glieu 0x5db..0x701: refusal of "+1" at the current quantity, 0 when accepted.
func increment_refusal(o: Dictionary, quantity: int, wagons, engine) -> int:
	var room := capacity(o, wagons)
	if o.mode == BUY:
		if room.x < quantity + 1:
			return NO_ROOM
		if o.goods != 0 and quantity + 1 > stock[o.city - FIRST_TRADING_CITY][o.goods - 1]:
			return STOCK_LIMIT
		if engine.lignite < total(o, quantity) + int(o.buy):
			return NO_MONEY
		return 0
	if quantity + 1 > room.y:
		return NOT_ENOUGH_LOAD
	if (quantity + 1) * int(o.sell) > _coal_room(wagons, engine):
		return NO_COAL_ROOM
	return 0


# glieu 0x549..0x583 then 0x9ec (buy) or 0xbd0 (sell).
func commit(o: Dictionary, quantity: int, wagons, engine) -> void:
	if quantity <= 0:
		return
	if o.mode == BUY:
		engine.lignite -= total(o, quantity)
	else:
		# glieu 0x55f..0x57c: only the credit path is clamped (the debit jumps to 0x583).
		engine.lignite += total(o, quantity)
		if engine.lignite < 0 or engine.lignite > MONEY_CAP:
			engine.lignite = MONEY_CAP
	if o.mode == BUY:
		_load(o, quantity, wagons)
	else:
		_unload(o, quantity, wagons)


func _load(o: Dictionary, quantity: int, wagons) -> void:
	if o.spy:
		# glieu 0xa04: one spy file per recruit; the original writes past slot 19
		# when none is free, which the offer condition prevents.
		for _recruit in quantity:
			var slot := spy_slots.find(0)
			if slot >= 0:
				spy_slots[slot] = 1
	var left := quantity
	for wagon in wagons.wagons:
		var limit := -1
		if _accepts(o, wagon, o.wagon_a):
			limit = int(o.cap_a)
		elif _accepts(o, wagon, o.wagon_b):
			limit = int(o.cap_b)
		while limit >= 0 and wagon[Wagons.QUANTITY] < limit and left > 0:
			wagon[Wagons.QUANTITY] += 1
			left -= 1
			if o.goods != 0:
				stock[o.city - FIRST_TRADING_CITY][o.goods - 1] -= 1
				wagon[Wagons.GOODS] = o.goods
		if left == 0:
			return


func _unload(o: Dictionary, quantity: int, wagons) -> void:
	var left := quantity
	for wagon in wagons.wagons:
		var accepted: bool = wagon[Wagons.TYPE] == o.wagon_a or wagon[Wagons.TYPE] == o.wagon_b
		if not accepted or (o.goods != 0 and wagon[Wagons.GOODS] != o.goods):
			continue
		while wagon[Wagons.QUANTITY] > 0 and left > 0:
			wagon[Wagons.QUANTITY] -= 1
			left -= 1
			if o.goods != 0:
				var row: Array = stock[o.city - FIRST_TRADING_CITY]
				# glieu 0xc49: goods sold where they are not traded are not stocked.
				# The cell is a signed byte (read with > -1): 127 + 1 wraps to -128.
				var cell: int = wagon[Wagons.GOODS] - 1
				if row[cell] > -1:
					row[cell] = row[cell] + 1 if row[cell] < 127 else -128
			if wagon[Wagons.QUANTITY] == 0:
				wagon[Wagons.GOODS] = 0
		if left == 0:
			return


# glieu 0x1905: [type, price] pairs offered by the workshop of city 10..16.
func workshop_list(city: int) -> Array:
	var result: Array = []
	if data.has("workshop"):
		for entry in data.workshop.get(str(city), []):
			result.append([int(entry[0]), int(entry[1])])
	return result


# textek 0x3172: names of wagon types 1..25.
func wagon_name(wagon_type: int) -> String:
	return String(data.wagon_names[wagon_type - 1])


# glieu 0x1f29..0x1f6b: tenders not in scrap state, recounted on every loop.
func intact_tenders(wagons) -> int:
	var count := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] == TENDER_TYPE and wagon[Wagons.STATE] != SCRAP_STATE:
			count += 1
	return count


# glieu 0x2137..0x21a0: refusal of "+1" for entry [type, price], 0 when accepted.
func workshop_refusal(entry: Array, quantity: int, wagons, engine) -> int:
	if quantity + wagons.count() > WORKSHOP_WAGON_LIMIT:
		return WAGONS_FULL
	if entry[0] == TENDER_TYPE and intact_tenders(wagons) + quantity >= MAX_INTACT_TENDERS:
		return TENDER_LIMIT
	if engine.lignite < quantity * int(entry[1]) + int(entry[1]):
		return NO_MONEY
	return 0


# glieu 0x2092..0x20ce: debit without clamp, then append quantity wagons. The
# original writes only field [0]; the slot's other fields keep their old bytes,
# which are zero until wagons can be destroyed (gare-atelier, not ported).
func buy_wagons(entry: Array, quantity: int, wagons, engine) -> void:
	if quantity <= 0:
		return
	engine.lignite -= quantity * int(entry[1])
	for _wagon in quantity:
		wagons.wagons.append([int(entry[0]), 0, 0, 0])


func snapshot() -> Dictionary:
	return {"stock": stock.duplicate(true), "spy_slots": spy_slots.duplicate()}


func restore(value: Variant) -> bool:
	if not value is Dictionary or not value.get("stock") is Array or not value.get("spy_slots") is Array:
		return false
	if value.stock.size() != TRADING_CITIES or value.spy_slots.size() != SPY_SLOTS:
		return false
	var parsed: Array = []
	for row in value.stock:
		if not row is Array or row.size() != GOODS_KINDS:
			return false
		var cells: Array = []
		for cell in row:
			# main+0x6160 holds signed bytes.
			if not (typeof(cell) == TYPE_INT or typeof(cell) == TYPE_FLOAT) or float(cell) != floor(float(cell)) or cell < -128 or cell > 127:
				return false
			cells.append(int(cell))
		parsed.append(cells)
	var slots: Array = []
	for slot in value.spy_slots:
		if not (typeof(slot) == TYPE_INT or typeof(slot) == TYPE_FLOAT) or not int(slot) in [0, 1]:
			return false
		slots.append(int(slot))
	stock = parsed
	spy_slots = slots
	return true
