extends SceneTree

# MIT. Owner4Oct presentation regression: original clickable regions unchanged.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var screen = preload("res://scripts/campaign_screen.gd").new()
	root.add_child(screen)
	screen.size = Vector2(320,200)
	var selected: Array = []
	screen.menu_selected.connect(func(index): selected.append(index))
	screen.open_menu(["SEND SPY","DYNAMITE","EXIT"])
	for index in range(3):
		click(screen,Vector2(1,44+index*25)) # wide original bands, outside authored cards.
	assert(selected == [0,1,2])
	var answers: Array = []
	screen.answered.connect(func(value): answers.append(value))
	screen.present("sabotage_confirm",["ORDER THIS SPY TO USE DYNAMITE HERE?"],false,true)
	click(screen,Vector2(159,20))
	click(screen,Vector2(160,20))
	assert(answers == [false,true])
	var reception = preload("res://scripts/reception_screen.gd").new()
	root.add_child(reception)
	reception.size = Vector2(320,200)
	var actions: Array = []
	reception.level_requested.connect(func(): actions.append("level"))
	reception.combat_requested.connect(func(): actions.append("combat"))
	reception.music_requested.connect(func(): actions.append("music"))
	for action in ["level","combat","music"]:
		click(reception,reception.PLAQUES[action].position+Vector2.ONE)
	assert(actions == ["level","combat","music"])
	assert(preload("res://scripts/keyboard_settings_button.gd").BADGE == Rect2(130,128,59,17))
	print("PASS: menu bands, NO/OK partition, option plaque actions and KEYS hitbox retained")
	quit()


func click(view, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	view._gui_input(event)
