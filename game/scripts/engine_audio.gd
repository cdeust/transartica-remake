extends RefCounted

# MIT. TRAINc3d/d1f: each shovel pose waits5-2*rate original50Hz ticks.
# TRAINc78/d5a andc9e/d7f play shovel pickup/deposit at poses1 and4.
var app
var audio
var remainder := 0.0
var active := false
var poses := [0,0]
var waits := [0,0]

func reset() -> void:
	active = false
	remainder = 0.0
	poses = [0,0]
	waits = [0,0]

func attach(owner, playback) -> void:
	for property in owner.get_property_list():
		if property.name == "engine":
			app = owner
			audio = playback
			return

func advance(delta: float) -> void:
	if app == null:
		return
	var booting: bool = app._boot.intro != null and app._boot.intro.visible
	var shown: bool = not app._modal.visible and not app._city_panel.visible and not app.campaign.screen.visible and not app.works_dialog.visible and not app._world_session.blocks_simulation() and not app._boudoir_session.blocks_simulation() and not app.encounters.manual_scene.visible and not app.encounters.report.visible and app._boudoir_session.last_room == "room" and not booting
	if not shown:
		active = false
		remainder = 0.0
		return
	if not active:
		active = true
		poses = [0,0]
		waits = [0,0]
		# TRAINd3..128 ECS engine entry. Sound preference is owned by GameAudio.
		audio.stop_effects()
		if app.engine.speed > 0:
			audio.son(8)
		elif app.engine.pressure_reserve >= 1500:
			audio.son(2,int((app.engine.speed-1)/60))
	# Original ALIS source ticks, independent of display or train simulation speed.
	remainder += delta
	while remainder >= 1.0/50 or is_equal_approx(remainder,1.0/50):
		remainder = maxf(0.0,remainder-1.0/50)
		_tick()

func _tick() -> void:
	for side in 2:
		var rate: int = app.engine.lignite_rate if side == 0 else app.engine.anthracite_rate
		var fuel: int = app.engine.lignite if side == 0 else app.engine.anthracite
		if rate == 0 or fuel == 0:
			poses[side] = 0
			waits[side] = 0
			continue
		if waits[side] > 0:
			waits[side] -= 1
			if waits[side] > 0:
				continue
		if poses[side] == 0:
			audio.effect("train",0x10cf)
		elif poses[side] == 3:
			audio.effect("train",0x10e3)
		poses[side] = (poses[side]+1)%8 # TRAIN forward1..4, then reverse3..0.
		waits[side] = 5-2*rate
