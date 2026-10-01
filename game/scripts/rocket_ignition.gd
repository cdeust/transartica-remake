extends RefCounted

# MIT. Authored ignition clock, not BERTA movement or engine physics.
# Visual50Hz matches the existing ALIS presentation clock.
const STEP := 1.0/50.0
var tick := 0
var remainder := 0.0
var nozzle := Vector2.ZERO
var active := false

func clear() -> void:
	tick = 0
	remainder = 0
	nozzle = Vector2.ZERO
	active = false

func observe(seconds: float, point: Vector2, burning: bool) -> void:
	nozzle = point
	active = burning
	if not burning or not is_finite(seconds) or seconds <= 0: return
	remainder += seconds
	while remainder >= STEP or is_equal_approx(remainder,STEP):
		remainder = maxf(0,remainder-STEP)
		tick += 1
