extends SceneTree
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
const Contract = preload("res://simulation/definitions/rule_contract.gd")
const Roles = preload("res://simulation/definitions/unit_roles.gd")
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Technology = preload("res://simulation/definitions/technology_rules.gd")
const State = preload("res://simulation/systems/technology_state.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	_contracts()
	for id in range(61):
		assert(Roles.is_hero(id) == (id in [29,31,33,35,52]))
		assert(Roles.is_naval(id) == (id in [46,47,48,49,52]))
		assert(Roles.is_worker(id) == (id in [30,27,28]))
		assert(Roles.is_transport(id) == (id == 47))
		assert(Roles.uses_channel_b(id) == (id in [18,19,33,34,39,42,44,45,46,48,49,52]))
	assert(not Roles.is_naval_technology(Roles.transport_id()) and Roles.is_naval_technology(52))
	assert(Technology.table().size() == 23 and Technology.ticks() == 200)
	for index in range(23):
		var value := State.initial()
		var completion: Dictionary = Technology.table()[index].completion
		assert(State.complete(value,index) == not completion.is_empty())
		assert(not State.complete(value,index), "Repeated completion is idempotent")
	assert(Technology.building_lines(2) == ["weapon","armor"])
	assert(Technology.lines().bow.has(3) and Roles.ids("naval").has(47), "JSON IDs must retain integer membership")
	var table := Technology.table(); var naval := Roles.ids("naval")
	for frame in range(1000): assert(is_same(table,Technology.table()) and is_same(naval,Roles.ids("naval")))
	_population()
	print("RULE CONSTANTS PASS validated catalogs / integer membership / classification boundaries / monotonic completion / cached frozen values / population and reservations")
	quit()

func _contracts() -> void:
	for name in ["tech.json","unit_roles.json","balance.json"]:
		assert(Contract.valid(name,Catalog.get_catalog(name)) and Catalog.get_catalog(name).is_read_only())
	var bad: Dictionary = Catalog.get_catalog("tech.json").duplicate(true)
	bad.rows[0].v.pop_back(); assert(not Contract.valid("tech.json",bad))
	bad = Catalog.get_catalog("tech.json").duplicate(true)
	bad.lines.bow[0] = 999; assert(not Contract.valid("tech.json",bad))
	bad = Catalog.get_catalog("tech.json").duplicate(true)
	bad.rows[3].completion = {"bow":3}; assert(not Contract.valid("tech.json",bad))
	bad = Catalog.get_catalog("unit_roles.json").duplicate(true)
	bad.navalTechnology.append(Roles.transport_id()); assert(not Contract.valid("unit_roles.json",bad))
	bad = Catalog.get_catalog("unit_roles.json").duplicate(true)
	bad.workers.append(bad.workers[0]); assert(not Contract.valid("unit_roles.json",bad))
	bad = Catalog.get_catalog("balance.json").duplicate(true)
	bad.armyCap = 0; assert(not Contract.valid("balance.json",bad))
	var documents := {}
	for name in Contract.FILES: documents[name] = Catalog.get_catalog(name).duplicate(true)
	documents["unit_roles.json"].heroes.append(999)
	assert(not Contract.errors(documents).is_empty(), "Unknown unit references cannot be published")
	var identity = preload("res://app/saves/rules_identity.gd")
	var role: Dictionary = Catalog.get_catalog("unit_roles.json").duplicate(true)
	var projection: Dictionary = identity.rule_projection("unit_roles.json",role)
	role.naval.reverse(); role.technologyCategories[0].reverse()
	assert(identity.rule_projection("unit_roles.json",role) == projection,"Set ordering is not a simulation rule")
	role.naval.erase(52)
	assert(identity.rule_projection("unit_roles.json",role) != projection)

func _population() -> void:
	var game: Node = root.get_node("Game"); game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate(); root.add_child(battle); battle.set_process(false)
	var original: Array = battle.units.duplicate()
	var leader: Dictionary = battle.selected[0]
	var worker: Dictionary = battle.units.filter(func(u): return int(u.owner) == battle.player_owner and Roles.is_worker(int(u.unit)))[0]
	var headquarters: Dictionary = battle.units.filter(func(u): return int(u.owner) == battle.player_owner and int(u.unit) in [0,1])[0]
	battle.gold=100000.;battle.wood=100000.;battle.stone=100000.;battle.food=100000.
	var production: Object = battle.world.production
	var construction: Object = battle.world.construction_orders
	while production._army_count(battle.player_owner) < Balance.army_cap():
		var filler: Dictionary = worker.duplicate(true)
		filler.uid = 10000+battle.units.size(); filler.unit = 0; filler.is_building = true; filler.group_officer = -1
		battle.units.append(filler)
	var point := Vector2(leader.ax,leader.ay)
	var opt: Dictionary = battle.build_types[0]
	assert(construction.build_placement_at(point,opt).reason == "已达%d单位上限" % Balance.army_cap())
	var before: float = battle.gold
	assert(not production._queue_train(battle.player_owner,headquarters,30) and battle.gold == before)
	assert(not battle.world.entity_factory._spawn_unit(32,battle.player_owner,point.x,point.y))
	assert(not battle.world.officer_teams._form_hero_unit(worker,0))
	# A corpse, an enemy, and a fading unit do not occupy a live entity slot.
	var last: Dictionary = battle.units.back(); last.alive = false
	assert(production._army_count(battle.player_owner) == Balance.army_cap()-1)
	last.alive=true;last.die_t=0.;assert(production._army_count(battle.player_owner) == Balance.army_cap()-1)
	last.die_t=-1.;last.owner=0;assert(production._army_count(battle.player_owner) == Balance.army_cap()-1)
	# Queued units reserve slots even before a unit is born.
	battle.trainings = [{"owner":battle.player_owner,"b":{"uid":-1,"owner":battle.player_owner},"unit":30}]
	assert(not production._queue_train(battle.player_owner,headquarters,30))
	battle.trainings.clear()
	assert(production._queue_train(battle.player_owner,headquarters,30))
	battle.trainings.clear(); battle.units = original
	while production._commander_count(battle.player_owner) < Balance.commander_cap():
		var commander: Dictionary = leader.duplicate(true)
		commander.uid = 20000+battle.units.size(); commander.officer.index = 1000+battle.units.size()
		battle.units.append(commander)
	assert(production._army_count(battle.player_owner) < Balance.army_cap())
	assert(not battle.world.officer_teams._form_hero_unit(worker,0), "Commander quota is independent of entity quota")
	# Remove synthetic commanders before disposing the real scene.
	while int(battle.units.back().uid) >= 20000: battle.units.pop_back()
	production=null;construction=null;battle.scene.ready_to_save=false;battle.free()
