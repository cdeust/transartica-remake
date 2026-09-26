extends PanelContainer

# City scene driven by the glieu.co menu (tasks/evidence/city-scripts.md §2).
# Rules live in city_trade.gd; this panel only mirrors the original flow:
# menu -> transaction (+1 / -1 / validate / exit) -> menu, or departure;
# cities 10..16 open the workshop instead (wagon purchase, glieu 0x1d64).
# The original reads choices 50..53 from main+0x1c, whose writer is not decoded:
# the button roles (buy/sell, validate, -, +, exit) are inferred from their effects.
# The wording of labels and refusals is the remake's own, not texte2k text.
const CityTrade = preload("res://scripts/city_trade.gd")

signal depart_requested
signal cargo_changed

const REFUSALS := {
	CityTrade.NO_ROOM: "No room left in suitable wagons.",
	CityTrade.NOTHING_TO_SELL: "Nothing of this kind aboard.",
	CityTrade.NO_MONEY: "Not enough lignite to pay.",
	CityTrade.NOT_ENOUGH_LOAD: "You do not carry that many.",
	CityTrade.NO_COAL_ROOM: "The tenders cannot hold that much more coal.",
	CityTrade.WAGONS_FULL: "The train cannot take more wagons.",
}
const WORKSHOP_CITIES := [10, 11, 12, 13, 14, 15, 16] # glieu 0x4a: usine + workshop 0x1d64
const AUTO_DEPART_CITIES := [5, 6, 7] # glieu 0x790

var trade
var wagons
var engine
var city := -1
var city_name := ""
var kind := 0
var _mode := 0
var _offer: Dictionary = {}
var _quantity := 0
var _direct := false
var _arriving := false
var _depart_after_notice := false
var _rows: Array = []
var _workshop := false
var _entry: Array = [] # workshop selection [type, price]; empty = L0x3e -1

var _title: Label
var _subtitle: Label
var _funds: Label
var _notice: Label
var _menu: HBoxContainer
var _trade_box: VBoxContainer
var _list: ItemList
var _detail: Label


func _init() -> void:
	custom_minimum_size = Vector2(620, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0d1b23")
	style.border_color = Color("#c79a4a")
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	_title = _label(body, 30)
	_subtitle = _label(body, 15)
	_funds = _label(body, 15)
	_trade_box = VBoxContainer.new()
	_trade_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_trade_box)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 150)
	_list.max_columns = 2
	_list.same_column_width = true
	_list.item_selected.connect(_select_goods)
	_trade_box.add_child(_list)
	_detail = _label(_trade_box, 17)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_trade_box.add_child(controls)
	_button(controls, "−  (key -)", decrement)
	_button(controls, "+  (key +)", increment)
	_button(controls, "Validate · Enter", validate)
	_button(controls, "Back · Esc", leave_transaction)
	_notice = _label(body, 15)
	_notice.add_theme_color_override("font_color", Color("#e7c27d"))
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu = HBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_menu)


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func open(index: int, name: String, city_kind: int, type_label: String) -> void:
	city = index
	city_name = name
	kind = city_kind
	_title.text = name
	_subtitle.text = type_label
	_notice.text = ""
	_arriving = true
	_direct = false
	show()
	_show_menu()
	_arriving = false


func in_transaction() -> bool:
	return _trade_box.visible


# glieu 0xc7..0x1ef, 0x100..0x189: the choices offered by each kind of city.
func _show_menu() -> void:
	_trade_box.hide()
	_offer = {}
	_workshop = false
	_depart_after_notice = false
	for child in _menu.get_children():
		child.queue_free()
	if city in WORKSHOP_CITIES:
		# glieu 0x1d64..0x1d98: the workshop menu replaces trade (50 buy, 52 depart).
		_button(_menu, "Buy wagons", start_workshop)
	else:
		match kind:
			CityTrade.COMMERCIAL:
				_button(_menu, "Buy goods", start.bind(CityTrade.BUY))
				_button(_menu, "Sell goods", start.bind(CityTrade.SELL))
			CityTrade.MAMMOTH_FAIR:
				_button(_menu, "Buy mammoths", start.bind(CityTrade.BUY))
				_button(_menu, "Sell mammoths", start.bind(CityTrade.SELL))
			CityTrade.SLAVE_MARKET:
				_button(_menu, "Buy slaves", start.bind(CityTrade.BUY))
				_button(_menu, "Sell slaves", start.bind(CityTrade.SELL))
			CityTrade.GARRISON:
				# glieu 0x16e..0x189: without a spy offer, enrolment starts at once.
				# The original re-enters it after each transaction in cities 8-9; the
				# remake does so only on arrival and then shows the menu (adaptation).
				if not trade.offers_spies(city) and _arriving:
					_arriving = false
					_direct = true
					start(CityTrade.BUY)
					return
				_button(_menu, "Enlist soldiers", start.bind(CityTrade.BUY))
				if trade.offers_spies(city):
					_button(_menu, "Recruit spies", start.bind(CityTrade.SELL))
			CityTrade.TOWN:
				_notice.text = "Town story pages (texte2k 1..14) are not ported yet."
	_button(_menu, "Leave the city · Enter", func(): depart_requested.emit())
	_menu.show()
	_refresh()


func start(mode: int) -> void:
	_mode = mode
	_quantity = 0
	_notice.text = ""
	if kind == CityTrade.COMMERCIAL:
		_offer = {}
		_fill_list()
	else:
		_offer = trade.offer(city, kind, mode)
		if _offer.is_empty():
			_notice.text = "No price is recorded for this city."
			return
		var refusal: int = trade.entry_refusal(_offer, wagons)
		if refusal != 0:
			_notice.text = REFUSALS[refusal]
			# glieu 0x358..0x377: a direct enrolment without room ends with departure.
			if _direct:
				_depart_after_notice = true
				_show_depart_only()
			return
	_menu.hide()
	_list.visible = kind == CityTrade.COMMERCIAL
	_trade_box.show()
	_refresh()


# glieu 0x1dd7..0x1efc: list of the city's wagons and prices, no selection.
func start_workshop() -> void:
	_workshop = true
	_entry = []
	_quantity = 0
	_notice.text = ""
	_rows = trade.workshop_list(city)
	_list.clear()
	for row in _rows:
		_list.add_item("%s  %d" % [trade.wagon_name(row[0]), row[1]])
	_menu.hide()
	_list.show()
	_trade_box.show()
	_refresh()


func _show_depart_only() -> void:
	for child in _menu.get_children():
		child.queue_free()
	_button(_menu, "Leave the city · Enter", func(): depart_requested.emit())
	_menu.show()


func _fill_list() -> void:
	var previous: int = _offer.get("goods", 0)
	_rows = trade.goods_list(city, _mode, wagons)
	_list.clear()
	for row in _rows:
		_list.add_item("%s  %d" % [trade.goods_name(row[0]), row[1]])
		if row[0] == previous:
			_list.select(_list.item_count - 1)


# glieu 0x464..0x4a9: picking goods loads its prices and restarts at zero.
func _select_goods(index: int) -> void:
	if _workshop:
		# glieu 0x1fdf..0x2059: select a wagon, quantity restarts at zero.
		_entry = _rows[index]
		_quantity = 0
		_notice.text = ""
		_refresh()
		return
	_offer = trade.offer(city, kind, _mode, _rows[index][0])
	_quantity = 0
	_notice.text = "" if not _offer.is_empty() else "No price is recorded for these goods."
	_refresh()


func increment() -> void:
	var refusal := 0
	if _workshop:
		if _entry.is_empty():
			return
		refusal = trade.workshop_refusal(_entry, _quantity, wagons, engine)
	elif _offer.is_empty():
		return
	else:
		refusal = trade.increment_refusal(_offer, _quantity, wagons, engine)
	if refusal == 0:
		_quantity += 1
		_notice.text = ""
	elif REFUSALS.has(refusal):
		_notice.text = REFUSALS[refusal]
	_refresh()


func decrement() -> void:
	if _quantity > 0:
		_quantity -= 1
	_refresh()


# glieu 0x529..0x5ad: pay or cash in, load or unload, then continue.
func validate() -> void:
	if _workshop:
		# glieu 0x2085..0x20f4: buy, then clear quantity and selection; stay in the list.
		if _quantity > 0:
			trade.buy_wagons(_entry, _quantity, wagons, engine)
			cargo_changed.emit()
		_quantity = 0
		_entry = []
		_list.deselect_all()
		_refresh()
		return
	if _offer.is_empty():
		return
	if _quantity > 0:
		trade.commit(_offer, _quantity, wagons, engine)
		cargo_changed.emit()
	_quantity = 0
	if kind == CityTrade.COMMERCIAL:
		_fill_list()
		_refresh()
		return
	_finish()


func leave_transaction() -> void:
	if _workshop:
		# glieu 0x21a9..0x21d8: exit returns to the workshop menu, not departure.
		_show_menu()
		return
	_finish()


func _finish() -> void:
	_direct = false
	if city in AUTO_DEPART_CITIES:
		depart_requested.emit()
		return
	_show_menu()


func _refresh() -> void:
	_funds.text = "Lignite %d  ·  Anthracite %d" % [engine.lignite, engine.anthracite]
	if not _trade_box.visible:
		return
	if _workshop:
		if _entry.is_empty():
			_detail.text = "Choose a wagon in the list.\nWagons %d" % wagons.count()
		else:
			_detail.text = "Buy %s · %d each\nQuantity %d · total %d lignite\nWagons %d" % [trade.wagon_name(_entry[0]), _entry[1], _quantity, _quantity * int(_entry[1]), wagons.count()]
		return
	if _offer.is_empty():
		_detail.text = "Choose goods in the list."
		return
	var room: Vector2i = trade.capacity(_offer, wagons)
	var verb := "Buy" if _offer.mode == CityTrade.BUY else "Sell"
	var what := _what()
	_detail.text = "%s %s · %d each\nQuantity %d · total %d lignite\nRoom %d · aboard %d" % [verb, what, trade.price(_offer), _quantity, trade.total(_offer, _quantity), room.x, room.y]


func _what() -> String:
	if _offer.goods != 0:
		return trade.goods_name(_offer.goods)
	match kind:
		CityTrade.MAMMOTH_FAIR: return "mammoths"
		CityTrade.SLAVE_MARKET: return "slaves"
	return "spies" if _offer.spy else "soldiers"


func handle_key(keycode: int) -> bool:
	if in_transaction():
		match keycode:
			KEY_ENTER, KEY_KP_ENTER: validate()
			KEY_ESCAPE: leave_transaction()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: increment()
			KEY_MINUS, KEY_KP_SUBTRACT: decrement()
			_: return false
		return true
	if keycode in [KEY_ENTER, KEY_KP_ENTER]:
		depart_requested.emit()
		return true
	return false
