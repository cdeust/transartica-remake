extends RefCounted

# source: tasks/evidence/locomotive-rules.md, TABLE and TIME original bytecode.
# Each step is one original locomotive update, not one rendered frame.
# Manual stepping deliberately leaves the original wall-clock cadence unresolved.
var lignite := 2000
var anthracite := 500
var lignite_rate := 0
var anthracite_rate := 0
var regulator := 0
var speed := 0
var heat := 0
var temperature := 0
var pressure_reserve := 0
var brake := false
var event_pending := false
var event_message := ""
var cycles := 0
var train_mass := 1266 # TABLE 0x699..0x6f4, TIME 0x2a77..0x2bd6: six original wagons.
# Cargo changes it; main.gd sets it from train_wagons.gd::mass() (TIME 0x2a77/0x2b4a).
# Remake adaptation approved by the owner on 26 September 2026 (FIDELITE.md).
# ECS TIME 0x2e4..0x2fa zeroes speed when the lever is set; the remake instead
# lowers it by the original regulator step (TIME 0x280..0x2e3) on every cycle.
const SERVICE_BRAKE_STEP := 5


func cycle_lignite() -> void:
	lignite_rate = (lignite_rate + 1) % 3


func cycle_anthracite() -> void:
	anthracite_rate = (anthracite_rate + 1) % 3


func set_regulator(value: float) -> void:
	regulator = clampi(int(value), 0, 300)


func toggle_brake() -> void:
	brake = not brake


func step_cycle() -> void:
	if event_pending or train_mass <= 0:
		return
	cycles += 1
	heat += 10 * lignite_rate + 30 * anthracite_rate
	if heat > 5000:
		_suspend_event("Boiler overload")
		return
	lignite = maxi(0, lignite - lignite_rate)
	anthracite = maxi(0, anthracite - anthracite_rate)
	if lignite == 0 and anthracite == 0 and (lignite_rate != 0 or anthracite_rate != 0):
		_suspend_event("No coal remaining")
		return
	_heat_boiler()
	_drive()


func _heat_boiler() -> void:
	var transfer := 0
	if heat != 0:
		transfer = heat / 100 + 1
		heat = maxi(0, heat - transfer)
	temperature = mini(heat, 600)
	if temperature > 100:
		pressure_reserve = mini(32000, pressure_reserve + 100 * transfer)


func _drive() -> void:
	var mass_factor: int = train_mass / 100
	var resistance: int = (train_mass + mass_factor * mass_factor) / 2
	var divisor: int = 32000 / resistance
	var consumption: int = (speed + speed * (speed / 10)) / divisor
	pressure_reserve -= consumption
	if brake:
		# Progressive service brake: overrides the regulator target, never adds to
		# the exhausted-reserve decrease, and leaves regulator and stokers unchanged.
		pressure_reserve = maxi(pressure_reserve, 0)
		speed = maxi(speed - SERVICE_BRAKE_STEP, 0)
		return
	if pressure_reserve <= 0:
		pressure_reserve = 0
		speed -= 5
	elif pressure_reserve > 1500 or speed > 0:
		speed = move_toward(speed, regulator, 5)
	speed = maxi(speed, 0)


func _suspend_event(reason: String) -> void:
	# Port boundary: original event handler is not connected yet.
	event_pending = true
	event_message = reason


# source: tasks/evidence/locomotive-rules.md; captures every mutable model field.
func snapshot() -> Dictionary:
	return {
		"lignite": lignite,
		"anthracite": anthracite,
		"lignite_rate": lignite_rate,
		"anthracite_rate": anthracite_rate,
		"regulator": regulator,
		"speed": speed,
		"heat": heat,
		"temperature": temperature,
		"pressure_reserve": pressure_reserve,
		"brake": brake,
		"event_pending": event_pending,
		"event_message": event_message,
		"cycles": cycles,
		"train_mass": train_mass,
	}


func restore(data: Variant) -> bool:
	if not data is Dictionary or not _has_snapshot_fields(data):
		return false
	if not _snapshot_values_valid(data):
		return false
	_apply_snapshot(data)
	return true


func _has_snapshot_fields(data: Dictionary) -> bool:
	for field in ["lignite", "anthracite", "lignite_rate", "anthracite_rate", "regulator", "speed", "heat", "temperature", "pressure_reserve", "brake", "event_pending", "event_message", "cycles", "train_mass"]:
		if not data.has(field):
			return false
	return true


# source: tasks/evidence/locomotive-rules.md; 16-bit memory, TRAIN ranges and TIME clamps.
func _snapshot_values_valid(data: Dictionary) -> bool:
	return _is_int_in_range(data.lignite, 0, 32767) \
		and _is_int_in_range(data.anthracite, 0, 32767) \
		and _is_int_in_range(data.lignite_rate, 0, 2) \
		and _is_int_in_range(data.anthracite_rate, 0, 2) \
		and _is_int_in_range(data.regulator, 0, 300) \
		and _is_int_in_range(data.speed, 0, 300) \
		and _is_int_in_range(data.heat, 0, 32767) \
		and _is_int_in_range(data.temperature, 0, 600) \
		and _is_int_in_range(data.pressure_reserve, 0, 32000) \
		and _is_int_in_range(data.cycles, 0, 2147483647) \
		and _is_int_in_range(data.train_mass, 1, 32767) \
		and typeof(data.brake) == TYPE_BOOL \
		and typeof(data.event_pending) == TYPE_BOOL \
		and typeof(data.event_message) == TYPE_STRING


func _is_int_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	var numeric := typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
	return numeric and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


func _apply_snapshot(data: Dictionary) -> void:
	lignite = data.lignite
	anthracite = data.anthracite
	lignite_rate = data.lignite_rate
	anthracite_rate = data.anthracite_rate
	regulator = data.regulator
	speed = data.speed
	heat = data.heat
	temperature = data.temperature
	pressure_reserve = data.pressure_reserve
	brake = data.brake
	event_pending = data.event_pending
	event_message = data.event_message
	cycles = data.cycles
	train_mass = data.train_mass
