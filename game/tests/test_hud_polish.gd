extends SceneTree
# MIT. Owner5Oct visual correction: painted train plate and uncovered clock spindle.
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var panel=preload('res://scripts/original_panel.gd').new()
 root.add_child(panel)
 var failures: Array[String]=[]
 for viewport in [Vector2(320,200),Vector2(1280,800),Vector2(1440,900)]:
  panel.size=viewport
  var rect: Rect2=panel.launcher_icon_rect()
  var aspect: float=panel._launcher_bounds.size.x/panel._launcher_bounds.size.y
  if not is_equal_approx(rect.size.x/rect.size.y,aspect): failures.append('Launcher stretched')
  if not panel.panel_rect().encloses(rect): failures.append('Launcher leaves HUD')
  if panel.hotspot_at(panel.screen_rect(panel.COMMON[9]).get_center())!=9: failures.append('Launcher command moved')
  var clock: Dictionary=panel.clock_layout(10,10)
  for count in [0,42519,2147483647]:
   for line in panel.clock_counter_layout(count):
    if line.window.has_point(clock.center): failures.append('Counter hides spindle')
    if not panel.panel_rect().encloses(line.window): failures.append('Counter leaves painted panel')
    for numeral in clock.numerals:
     if numeral.bounds.intersects(line.window): failures.append('Counter covers numeral')
 panel.queue_free()
 for failure in failures: push_error(failure)
 if failures.is_empty(): print('PASS: launcher uniform alpha-fit, original command9, readable lower-rim counter and uncovered spindle')
 quit(0 if failures.is_empty() else 1)
