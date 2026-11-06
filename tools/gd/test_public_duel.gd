extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.get_node("Game").current_map="chibil1"
	var b:Node=load("res://main.tscn").instantiate();root.add_child(b);b.set_process(false);b.cli_mode=true;b.ai=null
	var a:Dictionary=b.selected[0]
	var e:Dictionary=b.units.filter(func(u):return u.owner!=b.player_owner and not u.get("officer",{}).is_empty())[0]
	a.officer.might=100;a.officer.level=9;a.officer.tier=1;a.vision=20
	e.officer.might=1;e.officer.level=0;e.officer.tier=4;e.ax=a.ax+88;e.ay=a.ay
	b.visibility.update(b.units,b.player_owner)
	var hp:float=e.hp
	b.commands.military._duel_begin();b.commands.military._duel_at(Vector2(e.ax,e.ay-e.h*0.5))
	assert(not paused and not b.duel_pending and e.hp<hp)
	print("PUBLIC DUEL PASS no original video / accepted duel settles once without pause")
	b.free();quit()
