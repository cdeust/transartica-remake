extends SceneTree
const Combat=preload("res://scripts/tactical_combat.gd")
const Actors=preload("res://scripts/tactical_actors.gd")
const Weapons=preload("res://scripts/tactical_weapons.gd")
const Result=preload("res://scripts/tactical_result.gd")
const Wagons=preload("res://scripts/train_wagons.gd")
const EngineState=preload("res://scripts/engine_state.gd")
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
func check(value: bool,label: String) -> void:
	if not value: failures.append(label)
func fresh():
	var state=Combat.new()
	var rng=RandomNumberGenerator.new()
	rng.seed=420
	var wagons=Wagons.new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	state.begin(wagons,47,rng)
	return state
func run() -> void:
	_weapons()
	_actors()
	_results()
	_resume()
	_scene()
	if failures.is_empty():
		print("PASS: tactical combat weapons, actors, dynamite, defeat/victory, exactly-once result, JSON resume,30/60/144 cadence, native scene inputs")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _weapons() -> void:
	var state=fresh()
	state.offsets=[448,448]
	state.trains[0][7].reload=23
	var initial: int=state.trains[1][7].health
	Weapons.run(state)
	check(state.trains[1][7].health==initial,"cannon23 is muzzle flash only")
	Weapons.run(state)
	check(state.trains[1][7].health==initial-1,"cannon22 damages facing wagon exactly1")
	state.trains[0][7].reload=22
	Weapons.run(state)
	state.trains[0][7].reload=22
	Weapons.run(state)
	check(state.trains[1][7].health==0,"three hits destroy wagon")
	var x: int=state.train_cell(0,8)
	var friendly=state.add_actor(0,x,6,30,false)
	var enemy=state.add_actor(1,x,5,30,false)
	state.trains[0][8].reload=12
	Weapons.run(state)
	check(friendly.count<30 and enemy.count==30,"column targeting preserves first-unit friendly fire")
func _actors() -> void:
	var state=fresh()
	check(state.deploy(0,6,5),"barracks deploy group from source wagon")
	var actor=state.actors[-1]
	check(actor.count==5 and actor.y==6 and state.trains[0][6].quantity==5,"deployment debits barracks and starts upper row6")
	check(state.command(actor.id,2,2),"split2 into adjacent field cell")
	check(actor.count==3,"split preserves actor counts")
	var split=state.actors[-1]
	check(state.command(split.id,6,2),"merge into friendly group")
	check(actor.count==5 and split.count==0,"merge conserves headcount")
	state.actors=state.actors.filter(func(a):return a.count>0)
	actor.x=state.train_cell(1,2)
	actor.y=0
	actor.direction=0
	Actors.update(state,actor)
	check(actor.roof==1,"cross lower edge boards enemy roof")
	actor.x=9
	check(state.plant(actor.id,1),"roof actor plants adjacent dynamite")
	state.scan_side=0
	for sweep in 4: Actors.roof_sweep(state)
	check(state.trains[1][2].health==3,"dynamite survives four roof sweeps")
	Actors.roof_sweep(state)
	check(state.trains[1][2].health==0,"fifth roof sweep destroys target wagon")
	var target=state.add_actor(1,12,-1,5,false,1,6)
	state.charges=[{"side":1,"slot":13,"fuse":5,"owner":0}]
	Actors.roof_sweep(state)
	check(state.charges.is_empty(),"opposing actor defuses by walking onto charge")
func _results() -> void:
	var state=fresh()
	Weapons.destroy(state,0,3)
	state.check_end()
	check(state.outcome==2,"GQ destruction defeats player despite troops")
	var win=fresh()
	for car in win.trains[1]:
		if car.class!=Combat.Setup.MERCHANDISE: car.health=0;car.quantity=0
	win.actors=[]
	win.check_end()
	check(win.outcome==1,"enemy weapons/troops eliminated gives victory")
	var wagons=Wagons.new()
	wagons.wagons=win.original.duplicate(true)
	var engine=EngineState.new()
	var result=Result.commit(win,wagons,engine)
	check(result.won and win.settled,"victory committed")
	var after: Array=wagons.wagons.duplicate(true)
	var coal: int=engine.lignite
	check(Result.commit(win,wagons,engine).is_empty() and wagons.wagons==after and engine.lignite==coal,"second commit cannot repeat booty")
func _resume() -> void:
	var state=fresh()
	state.deploy(0,6,5)
	state.command(state.actors[-1].id,0)
	for tick in 19: state.step()
	var resumed=Combat.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(state.snapshot()))),"JSON interrupted combat restores")
	for tick in 150:
		state.step();resumed.step()
	check(JSON.stringify(state.snapshot())==JSON.stringify(resumed.snapshot()),"restored actors, AI, weapons and RNG produce same outcome")
	var bad=state.snapshot()
	bad.actors=[{"side":9}]
	var before: String=JSON.stringify(resumed.snapshot())
	check(not resumed.restore(bad) and JSON.stringify(resumed.snapshot())==before,"invalid snapshot rejected transactionally")
	var snapshots: Array=[]
	for rate in [30,60,144]:
		var run=fresh()
		for frame in rate*12: run.advance(1.0/rate)
		var snapshot: Dictionary=run.snapshot()
		snapshot.erase("remainder")
		snapshots.append(JSON.stringify(snapshot))
	check(snapshots[0]==snapshots[1] and snapshots[1]==snapshots[2],"same12 simulated seconds at30/60/144Hz")
func _scene() -> void:
	var scene=load("res://scripts/tactical_scene.gd").new()
	root.add_child(scene)
	var state=fresh()
	scene.open_battle(state)
	scene.selected_wagon=6
	scene.group_size=3
	var key=InputEventKey.new()
	key.physical_keycode=KEY_ENTER
	scene.handle_key(key)
	check(state.trains[0][6].quantity==7,"native scene Enter deploys selected barracks")
	scene.selected_actor=state.actors[-1].id
	key.physical_keycode=KEY_UP
	scene.handle_key(key)
	check(state.actors[-1].direction==4,"native scene arrow sets original grid direction")
	scene.free()
