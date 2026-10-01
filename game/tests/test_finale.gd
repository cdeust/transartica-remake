extends SceneTree

# requires-native-renderer
# Source: this fixture starts the source WAV; native audio avoids Dummy backend
# teardown retaining a WAV playback after the node has been freed.

const Sequence = preload("res://scripts/finale_sequence.gd")
const Screen = preload("res://scripts/campaign_screen.gd")
var errors: Array[String] = []


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)


func run() -> void:
	var sequence = Sequence.new()
	sequence.start(123)
	check(sequence.shot() == 36, "original initial station overlay36")
	sequence.advance(30.0 / 50)
	check(sequence.shot() == 37, "blast begins after30 source waits")
	sequence.advance(90.0 / 50)
	check(sequence.tick == 120 and sequence.shot() == 2, "intro completes120 source waits")
	sequence.advance(36.0 / 50)
	check(sequence.clouds() == PackedInt32Array([-4, -3, -2, -1]), "source cloud speeds after35")
	var saved: Dictionary = sequence.snapshot()
	check(Sequence.valid(JSON.parse_string(JSON.stringify(saved))), "movie cursor survives actual JSON save serialization")
	var resumed = Sequence.new()
	resumed.restore(saved)
	check(resumed.palette() == sequence.palette(), "restored RNG palette sequence")
	check(not Sequence.valid({"tick": -1, "seed": 1, "remainder": 0.0}), "reject negative playback cursor")
	var slow = Sequence.new()
	var fast = Sequence.new()
	slow.start(123)
	fast.start(123)
	for _frame in 180:
		slow.advance(1.0 / 30)
	for _frame in 864:
		fast.advance(1.0 / 144)
	check(abs(slow.tick - fast.tick) <= 1 and slow.palette() == fast.palette(), "display-independent source cadence")
	sequence.advance(100)
	check(sequence.tick == Sequence.LAST, "source exit counter>240")
	var screen = Screen.new()
	root.add_child(screen)
	screen.size = Vector2(1280, 800)
	screen.start_movie()
	screen.set_process(false)
	var alpha_image: Image = screen._finale_art.effects.get_image()
	check(alpha_image.get_pixel(0, 0).a < 0.1, "VFX atlas has genuine transparent background")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	var continued := [false]
	screen.continued.connect(func(): continued[0] = true)
	screen.handle_key(event)
	check(not continued[0], "cinematic cannot dismiss before completion")
	screen.finale.restore(saved)
	check(screen.finale.tick == saved.tick, "screen restores interrupted source scene")
	screen.stop_movie()
	if screen._finale_audio != null:
		screen._finale_audio.stream = null
	screen.open_menu(["SEND SPY", "DYNAMITE", "EXIT"])
	check(screen.menu == ["SEND SPY", "DYNAMITE", "EXIT"], "native untyped crew menu literals remain callable")
	screen.queue_free()
	await process_frame
	if errors.is_empty():
		print("PASS: source finale choreography, timing, save/resume, alpha and input guards")
	else:
		for message in errors:
			push_error(message)
	quit(0 if errors.is_empty() else 1)
