extends SceneTree
# MIT. Measured unchanged v2 art anchor and source12-hour clock semantics.
const PanelScript=preload("res://scripts/original_panel.gd")
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var panel=PanelScript.new()
	root.add_child(panel)
	for size in [Vector2(320,200),Vector2(600,1000),Vector2(1280,800),Vector2(1440,900)]:
		panel.size=size
		# Independent direct first-slice anchor mapping; sourcex160 inside x0..992.
		var center: Vector2=panel.screen_rect(Rect2(Vector2(160.0/992*160,149+(410.0-184)/402*51),Vector2.ZERO)).position
		for time in [Vector2i(0,0),Vector2i(3,0),Vector2i(6,30),Vector2i(23,59)]:
			var layout: Dictionary=panel.clock_layout(time.x,time.y)
			if "--legacy-layout" in OS.get_cmdline_user_args():
				layout.center=panel.screen_rect(Rect2(Vector2(24,180),Vector2.ZERO)).position
				layout.numerals=[]
			if not layout.center.is_equal_approx(center): failures.append("Clock pivot misses measured source dial%s" % size)
			if layout.numerals.size()!=12: failures.append("Clock Romanhours missing%s" % size)
			for numeral in layout.numerals:
				if not layout.face.encloses(numeral.bounds): failures.append("Numeral outside dial")
				for corner in [numeral.bounds.position,numeral.bounds.end]:
					if ((corner-layout.face.get_center())/(layout.face.size/2.0)).length_squared()>1: failures.append("Numeral outside ellipse")
				for other in layout.numerals:
					if other.text!=numeral.text and other.bounds.intersects(numeral.bounds): failures.append("Numerals overlap")
			if not layout.face.has_point(layout.minute_end) or not layout.face.has_point(layout.hour_end): failures.append("Hand outside clock face")
			var direction: Vector2=(layout.minute_end-center)/((layout.face.size/2.0)-_maximum(layout.numerals))
			if not direction.is_equal_approx(Vector2.UP.rotated(float(time.y)/60*TAU)): failures.append("Minute semantics changed")
			direction=(layout.hour_end-center)/((layout.face.size/2.0)-_maximum(layout.numerals))/(6.0/9.0)
			if not direction.is_equal_approx(Vector2.UP.rotated((float(time.x%12)+float(time.y)/60)/12*TAU)): failures.append("Hour semantics changed")
			if layout.font_size<=0: failures.append("Romanhours font empty")
		for cycles in [0,6322,2147483647]:
			var counter: Array=panel.clock_counter_layout(cycles)
			if counter.is_empty() or counter[-1].text!=str(cycles): failures.append("Actual cycle counter missing")
			if size.x>=600 and counter.size()!=2: failures.append("Cycle caption missing at modern frame size")
			for line in counter:
				if not line.window.encloses(line.bounds): failures.append("Cycle value exceeds central plate")
				for numeral in panel.clock_layout(0,0).numerals:
					if numeral.bounds.intersects(line.window): failures.append("Cycle plate covers numeral")
			if size.x>=600 and counter.size()==2:
				for hour in 12:
					for minute in [0,15,30,45]:
						var hands: Dictionary=panel.clock_layout(hour,minute)
						if counter[0].window.has_point(hands.hour_end): failures.append("Cycle plate hides hour hand %s cycles%d at%d:%d" % [size,cycles,hour,minute])
						if counter[0].window.has_point(hands.minute_end): failures.append("Cycle plate hides minute hand")
		print("CLOCK FONT ",size," ",panel.clock_layout(0,0).font_size)

	var engine=preload("res://scripts/engine_state.gd").new()
	panel.app={"engine":engine,"calendar":preload("res://scripts/game_calendar.gd").new(),
		"journey":preload("res://scripts/train_journey.gd").new(),"wagons":preload("res://scripts/train_wagons.gd").new()}
	panel.refresh()
	var previous: Array=panel._last_state.duplicate(true)
	engine.cycles+=1
	panel.refresh()
	if panel._last_state==previous: failures.append("Stationary cycle counter does not refresh")
	panel.app=null
	panel.queue_free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: measured clock pivot,12 Romanhours, contained hands/numerals/cyclecount, calendar angles across four frame sizes")
	quit(0 if failures.is_empty() else 1)

func _maximum(numerals: Array) -> Vector2:
	var extent:=Vector2.ZERO
	for numeral in numerals: extent=extent.max(numeral.bounds.size)
	return extent
