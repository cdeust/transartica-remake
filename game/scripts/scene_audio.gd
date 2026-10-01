extends RefCounted

# MIT. SCENE4 second header task3d4 runs at the original50Hz callback cadence.
# Its selector1 guard and rnd10==0 gate belong to Oslo, never selector2 moles.
var app
var audio
var remainder := 0.0

func reset() -> void:
	remainder = 0.0

func attach(owner, playback) -> void:
	for property in owner.get_property_list():
		if property.name == "campaign":
			app = owner
			audio = playback
			return

func advance(delta: float) -> void:
	if app == null:
		return
	if not app.campaign.screen.visible or app.campaign.screen.scene != "oslo":
		remainder = 0.0
		return
	remainder += delta
	while remainder >= 1.0/50 or is_equal_approx(remainder,1.0/50):
		remainder = maxf(0.0,remainder-1.0/50)
		if randi_range(0,9) == 0:
			audio.effect("scene4",0x3ed)
