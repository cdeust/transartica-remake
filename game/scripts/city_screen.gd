extends Control

# City scene driven by the glieu.co menu (tasks/evidence/city-scripts.md §2).
# Rules live in city_trade.gd; this panel only mirrors the original flow:
# menu -> transaction (+1 / -1 / validate / exit) -> menu, or departure;
# cities 10..16 open the workshop instead (wagon purchase, glieu 0x1d64).
# The original reads choices 50..53 from main+0x1c, whose writer is not decoded:
# the button roles (buy/sell, validate, -, +, exit) are inferred from their effects.
# The wording of labels and refusals is the remake's own, not texte2k text.
const Backdrop = preload("res://scripts/city_backdrop.gd")
const CityTrade = preload("res://scripts/city_trade.gd")
var list_icons = preload("res://scripts/city_list_icons.gd").new()

signal depart_requested
signal cargo_changed
signal town_message_requested(id: int)

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
var _trade_box: Control
var _transaction_controls: HBoxContainer
var _quantity_label: Label
var backdrop
var _list: ItemList
var _detail: Label


func _init() -> void:
	backdrop = Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(backdrop)
	_title = _label(self, 30)
	_subtitle = _label(self, 15)
	_subtitle.hide()
	_funds = _label(self, 15)
	_funds.hide() # Resource values belong to the shared lower HUD.
	_trade_box = Control.new()
	add_child(_trade_box)
	_list = ItemList.new()
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	list_icons.load_goods()
	_list.max_columns = 5 # glieu comp26: five columns; workshop comp105 also five.
	_list.same_column_width = true
	_list.max_text_lines = 2
	_list.item_selected.connect(_select_goods)
	_trade_box.add_child(_list)
	_detail = _label(_trade_box, 17)
	_transaction_controls = HBoxContainer.new()
	_transaction_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_transaction_controls)
	# source: glieu composite23 order OK, minus, quantity, plus, EXIT.
	_button(_transaction_controls, "OK", validate)
	_button(_transaction_controls, "−", decrement)
	_quantity_label = _label(_transaction_controls, 17)
	_button(_transaction_controls, "+", increment)
	_button(_transaction_controls, "EXIT", leave_transaction)
	_trade_box.visibility_changed.connect(_transaction_visibility)
	_notice = _label(self, 15)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu = HBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_menu)
	resized.connect(_layout)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout()


func _has_point(point: Vector2) -> bool:
	return backdrop.screen_rect(Rect2(0, 0, 320, 149)).has_point(point)


func _layout() -> void:
	if not is_instance_valid(backdrop):
		return
	backdrop.size = size
	var scale_factor: float = backdrop.frame_rect().size.x / 320.0
	theme = Backdrop.interface_theme(maxi(7, roundi(6.0 * scale_factor)))
	_place(_title, Rect2(7, 2, 306, 17))
	_title.add_theme_font_size_override("font_size", maxi(8, roundi(8.0 * scale_factor)))
	_place(_menu, Rect2(20, 23, 280, 14))
	_place(_transaction_controls, Rect2(20, 23, 280, 14))
	_place(_trade_box, Backdrop.PICTURE)
	_list.position = Vector2(4, 3) * scale_factor
	_list.size = Vector2(312, 62) * scale_factor
	# Godot4.5 ItemList::_recompute_rects: panel margins and a horizontal
	# separation per cell consume width. Reserve the scrollbar as well so
	# commercial lists retain GLIEU's five columns when scrolling.
	var panel_size := _list.get_theme_stylebox("panel").get_minimum_size()
	var column_budget := _list.size.x-panel_size.x-_list.get_v_scroll_bar().get_minimum_size().x
	_list.fixed_column_width = maxi(1, floori(column_budget/_list.max_columns)-maxi(0,_list.get_theme_constant("h_separation")))
	# Source-width icon footprint; list scrolling and detail placement are UI adaptation.
	_list.fixed_icon_size = Vector2i(list_icons.FOOTPRINT * scale_factor)
	_list.add_theme_font_size_override("font_size", maxi(7, roundi(5.0 * scale_factor)))
	_fit_list_font()
	# Paris33126: native three-line detail occupied116..145 while refusal125..147
	# overlapped it. Reserve106..135 for detail and139..147 for the single-line
	# notices, measured at1440x900/1280x800 by test_city_refusal_layout.gd.
	_detail.position = Vector2(4, 67) * scale_factor
	_detail.size = Vector2(312, 29) * scale_factor
	_place(_notice, Rect2(7, 139, 306, 8))
	for label in [_detail, _notice, _quantity_label]:
		label.add_theme_font_size_override("font_size", maxi(7, roundi(5.0 * scale_factor)))
	_quantity_label.custom_minimum_size.x = 18.0 * scale_factor
	for row in [_menu, _transaction_controls]:
		row.add_theme_constant_override("separation", maxi(2, roundi(4.0 * scale_factor)))
		for child in row.get_children():
			if child is Button:
				child.custom_minimum_size = Vector2(34, 13) * scale_factor


func _place(control: Control, logical: Rect2) -> void:
	var rect: Rect2 = backdrop.screen_rect(logical)
	control.position = rect.position
	control.size = rect.size


func _fit_list_font() -> void:
	# Owner4Oct Turin11592: preserve whole name and whole quantity on separate
	# lines. Measure actual theme font/column and spacing, never split digits.
	var font := _list.get_theme_font("font")
	var pixels := _list.get_theme_font_size("font_size")
	var available := maxi(1,_list.fixed_column_width-2*_list.get_theme_constant("h_separation"))
	var labels: Array = []
	if trade != null and not trade.data.is_empty():
		labels.append_array(trade.data.goods_names)
		labels.append_array(trade.data.wagon_names)
	for index in _list.item_count:
		labels.append_array(_list.get_item_text(index).split("\n"))
	for label in labels:
		while pixels > 1 and font.get_string_size(str(label),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x > available:
			pixels -= 1 # Same measured fitting approach as OriginalPanel readouts.
	if _workshop and _list.item_count > 0:
		# NewPeking45797: the icon and both text lines must fit every workshop
		# row above the reserved detail band. Match ItemList's shaped text and
		# row spacing (Godot4.5 item_list.cpp1594..1639), not an estimated font.
		var rows := ceili(float(_list.item_count)/_list.max_columns)
		var height := _list.size.y-_list.get_theme_stylebox("panel").get_minimum_size().y
		while pixels > 1 and _workshop_row_height(font,pixels)*rows > height:
			pixels -= 1
	_list.add_theme_font_size_override("font_size",pixels)


func _workshop_row_height(font: Font, pixels: int) -> float:
	var text_height := 0.0
	for index in _list.item_count:
		var paragraph := TextParagraph.new()
		paragraph.add_string(_list.get_item_text(index),font,pixels)
		paragraph.width = _list.fixed_column_width
		paragraph.break_flags = TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_GRAPHEME_BOUND|TextServer.BREAK_TRIM_START_EDGE_SPACES|TextServer.BREAK_TRIM_END_EDGE_SPACES
		paragraph.max_lines_visible = _list.max_text_lines
		text_height = maxf(text_height,paragraph.get_size().y)
	return _list.fixed_icon_size.y*_list.icon_scale+_list.get_theme_constant("icon_margin")+text_height+_list.get_theme_constant("line_separation")*_list.max_text_lines+maxi(0,_list.get_theme_constant("v_separation"))


func _transaction_visibility() -> void:
	_transaction_controls.visible = _trade_box.visible
	backdrop.trading = _trade_box.visible
	backdrop.queue_redraw()


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.tooltip_text = text
	button.text = "BUY" if text.begins_with("Buy") else "SELL" if text.begins_with("Sell") else "EXIT" if text.begins_with("Leave") else "ENLIST" if text.begins_with("Enlist") else "SPY" if text.begins_with("Recruit") else text
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
	backdrop.set_city(kind, city in WORKSHOP_CITIES)
	show()
	_show_menu()
	_layout()
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
		_menu.remove_child(child)
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
				# GLIEU0x20e: both locals have a city-specific TEXTE2K message.
				_button(_menu, "INFORMATION", town_information.bind(50))
				_button(_menu, "RUMOURS", town_information.bind(51))
	_button(_menu, "Leave the city · Enter", func(): depart_requested.emit())
	_menu.show()
	_refresh()
	_layout()


func town_information(choice: int) -> void:
	if kind != CityTrade.TOWN or not choice in [50, 51] or city < 17 or city > 23:
		return
	town_message_requested.emit((city - 17) * 2 + choice - 49)


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
		_list.add_item("%s\n%d" % [trade.wagon_name(row[0]), row[1]],list_icons.wagon_for(row[0]))
	_fit_list_font()
	_menu.hide()
	_list.show()
	_trade_box.show()
	_refresh()


func _show_depart_only() -> void:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	_button(_menu, "Leave the city · Enter", func(): depart_requested.emit())
	_menu.show()


func _fill_list() -> void:
	var previous: int = _offer.get("goods", 0)
	_rows = trade.goods_list(city, _mode, wagons)
	_list.clear()
	for row in _rows:
		_list.add_item("%s\n%d" % [trade.goods_name(row[0]), row[1]],list_icons.goods_for(row[0]))
		if row[0] == previous:
			_list.select(_list.item_count - 1)
	_fit_list_font()


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
	_quantity_label.text = str(_quantity)
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
