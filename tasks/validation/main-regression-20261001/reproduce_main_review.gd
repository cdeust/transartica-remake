extends SceneTree
var scene
func _initialize():
 OS.low_processor_usage_mode=false
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 var wagons=load("res://scripts/train_wagons.gd").new()
 wagons.wagons.append([11,0,0,0])
 wagons.wagons.append([12,0,0,0])
 var rng=RandomNumberGenerator.new()
 rng.seed=420
 var model=load("res://scripts/tactical_combat.gd").new()
 model.begin(wagons,47,rng)
 model.offsets=[448,448]
 scene=load("res://scripts/tactical_scene.gd").new()
 scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(scene)
 scene.open_battle(model)
 scene.set_physics_process(false)
 scene.pace=1.0
 await process_frame
 model.actors.clear()
 scene.camera=448
 model.velocities[0]=4
 model.remainder=model.STEP_SECONDS*0.5
 var mismatch=false
 var geometry=load("res://scripts/tactical_effects_geometry.gd")
 for index in model.trains[0].size():
  if model.trains[0][index].class==model.Setup.LOCOMOTIVE_COMPANION: continue
  var car=geometry.wagon(scene,0,index)
  var point=Vector2(car.rect.end.x-0.5,car.rect.get_center().y)
  if not car.rect.has_point(point) or point.y<38 or point.y>=64: continue
  var old_index=clampi(int((320+model.offsets[0]-scene.camera-point.x)/64),0,model.trains[0].size()-1)
  if old_index==index: continue
  var input=InputEventMouseButton.new()
  input.button_index=MOUSE_BUTTON_LEFT
  input.pressed=true
  var bounds=scene.canvas_rect()
  input.position=bounds.position+point*bounds.size/Vector2(320,200)
  scene._gui_input(input)
  print("OBSERVED moving click: displayed wagon=",index," selected=",scene.selected_wagon," logical=",point)
  mismatch=scene.selected_wagon!=index
  break
 model.remainder=0
 model.velocities[0]=0
 var actor=model.add_actor(0,29,-1,5,false,1,8)
 assert(model.plant(actor.id,1))
 for sweep in 5:
  model.scan_side=0
  model.scan=model.columns*7-1
  scene._physics_process(model.STEP_SECONDS)
 assert(model.trains[1][7].health==0)
 var wreck=geometry.wagon(scene,1,7)
 var cached=scene.materials.texture_for(wreck.texture,1,7,0)
 var original=geometry.wagon(scene,1,7,true)
 print("OBSERVED destroyed crop: cached size=",cached.get_size()," chosen wreck source=",wreck.texture.get_size()," original source=",original.texture.get_size()," crop=",wreck.used)
 var cache_mismatch=cached.get_size()!=wreck.texture.get_size()
 scene.camera=0
 scene.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.cache/main-review-reproduction.png"))
 scene.queue_free()
 await process_frame
 print("REPRODUCED: moving-click=",mismatch," destruction-cache=",cache_mismatch)
 quit(1 if mismatch or cache_mismatch else 0)
