extends "test_contact_and_occupancy.gd"
## Contract matrix for unit.state transitions.
## Each block drives one transition through the real order / cancel / death
## entry points and asserts the invariants other domains rely on. The goal is a
## written contract, not a generic FSM: only the fields each transition owns are
## checked.

const ActionClock = preload("res://simulation/movement/action_clock.gd")
const TickTimers = preload("res://simulation/movement/tick_timers.gd")
const ResourceState = preload("res://simulation/economy/resource_state.gd")
const Balance = preload("res://simulation/definitions/balance_rules.gd")

func run() -> void:
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true)
	leader_template=scene.selected[0].duplicate(true);metadata=scene.map_data.units.duplicate(true)
	scene.scene.ready_to_save=false;scene.free()
	attack_to_move()
	gather_to_order()
	gather_deliver_retarget()
	wood_retry()
	board_to_unload()
	move_to_idle()
	any_to_death()
	order_progress_restore()
	sim.free();done=true
	print("UNIT STATE TRANSITIONS PASS attack->move / gather->order / board->unload / move->idle / any->death / progress restore")
	quit()

func gather_deliver_retarget() -> void:
	blank()
	var worker := make(1, 3, 30, Vector2i(10, 9))
	worker.vision = 3.0
	var depot := make(2, 3, 10, Vector2i(6, 10))
	depot.is_building = true
	depot.occupied_cells = [Vector2i(6, 10)]
	install([worker, depot])
	_decor([[10, 10, 2], [12, 10, 2]])
	var source: Dictionary = sim.decor_cells["10_10"]
	var next: Dictionary = sim.decor_cells["12_10"]
	var harvest := Balance.harvest()
	var amount := float(harvest.extractAmount)
	var stock := float(source.stock)
	var capacity: float = sim.world.harvest_orders._food_capacity(3)
	assert(capacity > 0)
	sim.food = capacity
	sim.world.harvest_orders._begin_gather(worker, source, [])
	for tick in range(int(harvest.periodTicks)): sim.world.unit_actions._step_unit_inner(worker, sim.SIM_DT)
	assert(worker.state == "deliver" and worker.carry == amount and worker.carry_kind == "food")
	assert(source.stock == stock - amount and not source.alive and sim.food == capacity)
	assert(worker.gather_ticks == 0 and worker.pi == 0 and worker.path.is_empty())

	for tick in range(900):
		sim.world.unit_actions._step_unit_inner(worker, sim.SIM_DT)
		if worker.repath > 0.0 and sim.world.interaction_paths._deposit_ready(worker, depot): break
	assert(worker.state == "deliver" and worker.repath > 0.0)
	assert(is_same(worker.gather_obj, source) and worker.carry == amount and sim.food == capacity)
	assert(Vector2(worker.ax, worker.ay).distance_to(Vector2(next.ax, next.ay)) > worker.vision * sim.tile_w)
	sim.food = capacity - amount
	for tick in range(120):
		sim.world.unit_actions._step_unit_inner(worker, sim.SIM_DT)
		if worker.state == "gather": break
	assert(worker.state == "gather" and is_same(worker.gather_obj, next))
	assert(worker.carry == 0.0 and worker.carry_kind.is_empty() and sim.food == capacity)
	for tick in range(900):
		sim.world.unit_actions._step_unit_inner(worker, sim.SIM_DT)
		if worker.state == "deliver": break
	assert(worker.carry == amount and worker.carry_kind == "food" and not next.alive)
	assert(sim.food == capacity, "The first load was deposited exactly once")
	print("HARVEST TRANSITIONS PASS extract / full depot / one deposit / disconnected crop")

func wood_retry() -> void:
	for cancel in [false, true]:
		blank()
		var worker := make(1, 3, 30, Vector2i(10, 10))
		install([worker])
		_decor([[15, 10, 0]])
		var source: Dictionary = sim.decor_cells["15_10"]
		assert(sim.world.harvest_orders._order_gather(source, [worker], 3) == 1)
		var approaches: Array = sim.world.interaction_paths._edge_neighbors(source)
		for cell in approaches: sim.nav.block(cell)
		for tick in range(120):
			sim.world.unit_actions._step_unit_inner(worker, sim.SIM_DT)
			if worker.path.is_empty() and worker.repath > 0.0: break
		assert(worker.state == "gather" and worker.repath > 0.0 and is_same(worker.gather_obj, source))
		if cancel:
			var point: Vector2 = sim.nav.anchor_of(8, 10)
			assert(sim.world.world_orders._move_autonomous(worker, point))
			assert(worker.gather_obj == null)
		for cell in approaches: sim.nav.unblock(cell)
		for tick in range(480):
			sim.world.unit_actions._step_unit_inner(worker, sim.SIM_DT)
			if worker.state == "deliver": break
		if cancel:
			assert(worker.state == "idle" and worker.carry == 0.0 and source.alive and worker.gather_obj == null)
		else:
			assert(worker.state == "deliver" and worker.carry_kind == "wood" and not source.alive)
	print("WOOD TRANSITIONS PASS retry after reopening / replacement order cancels retry")

func _decor(cells: Array) -> void:
	sim.map_data.decor = cells
	sim.world.harvest_orders._build_decor_targets()

## Attack -> Move: switching to a move order drops the attack target and resets
## the attack clock before the route is installed.
func attack_to_move() -> void:
	blank()
	var a:=make(1,3,32,Vector2i(10,10));var b:=make(2,2,32,Vector2i(10,14))
	install([a,b])
	assert(sim.world.world_orders._attack_units([a],b,3)==1)
	assert(a.state=="attack" and a.target!=null and int(a.target.uid)==int(b.uid))
	var goal: Vector2=sim.nav.anchor_of(16,10)
	assert(sim.world.world_orders._move_autonomous(a,goal),"Move order accepted")
	assert(a.target==null,"Move drops the stale attack target")
	assert(a.state=="move" and not (a.path as Array).is_empty(),"Move installs a route")
	assert(int(a.action_wait)==0 and not bool(a.action_started),"Move resets the attack clock")
	var start:=Vector2(a.ax,a.ay)
	for tick in range(8):sim.world.unit_actions._step_unit_inner(a,sim.SIM_DT)
	assert(Vector2(a.ax,a.ay)!=start,"Move advances the unit")

## Gather -> another order: cancelling the in-flight gather clears the resource
## reference, the carry timer and the route. A worker cannot attack, so the
## second order is modelled with the same cancel transaction a team command uses.
func gather_to_order() -> void:
	blank()
	var worker:=make(1,3,30,Vector2i(10,10));var depot:=make(2,3,10,Vector2i(12,10));depot.is_building=true
	var decor:=make(3,0,24,Vector2i(14,10));decor.is_building=true;decor.decor=true
	install([worker,depot,decor])
	worker.state="gather";worker.path=[Vector2(depot.ax,depot.ay)];worker.pi=1;worker.gather_t=7
	ResourceState.set_gather_obj(worker,decor)
	assert(worker.gather_obj!=null,"Gather reference installed")
	sim.world.command_groups._cancel_unit_command(worker)
	assert(worker.gather_obj==null,"Cancel clears the gather reference")
	assert(worker.state=="idle" and (worker.path as Array).is_empty() and int(worker.pi)==0,"Cancel clears the route")

## Board -> Unload: the passenger leaves the ship, regains a floor cell and the
## ship's cargo counter returns to zero.
func board_to_unload() -> void:
	blank()
	var passenger:=make(1,3,32,Vector2i(20,20));var ship:=make(2,3,47,Vector2i(22,20))
	install([passenger,ship])
	assert(sim.world.transport_orders._attach_to_ship(passenger,ship),"Boarding transition")
	assert(bool(passenger.attached) and int(ship.carry_n)==1)
	assert(sim.world.transport_orders._order_unload(ship)==1,"Unload order accepted")
	for tick in range(4):sim.world.unit_actions._step_unit(ship,sim.SIM_DT)
	assert(not bool(passenger.attached),"Unload detaches the passenger")
	assert(int(ship.carry_n)==0,"Unload empties the cargo counter")
	var landed: Vector2i=sim.nav.cell_of_px(passenger.ax,passenger.ay)
	assert(landed!=sim.nav.cell_of_px(ship.ax,ship.ay),"Passenger does not stay on the ship cell")
	assert(not sim.world.spatial_index._cell_unit(landed,-1,0).is_empty(),"Passenger is reindexed on the floor")

## Move -> Idle: cancelling a move clears the route and cursor and leaves the
## unit actionable next tick.
func move_to_idle() -> void:
	blank()
	var unit:=make(1,3,32,Vector2i(10,10))
	install([unit])
	assert(sim.world.world_orders._move_autonomous(unit,sim.nav.anchor_of(18,10)))
	sim.world.command_groups._cancel_unit_command(unit)
	assert(unit.state=="idle" and (unit.path as Array).is_empty() and int(unit.pi)==0)
	assert(int(unit.action_wait)==0 and not bool(unit.action_started))
	var before:=Vector2(unit.ax,unit.ay)
	sim.world.unit_actions._step_unit_inner(unit,sim.SIM_DT)
	assert(Vector2(unit.ax,unit.ay)==before,"Idle unit does not drift")

## Any -> Death: a killed unit frees its cell; a killed leader also leaves the
## selection and every control group that referenced it.
func any_to_death() -> void:
	blank()
	var soldier:=make(1,3,32,Vector2i(10,10))
	install([soldier])
	var cell: Vector2i=sim.nav.cell_of_px(soldier.ax,soldier.ay)
	assert(sim.world.spatial_index._cell_unit(cell,-1,0).uid==soldier.uid)
	sim.world.combat._kill(soldier)
	assert(float(soldier.die_t)>=0.0,"Kill starts the death sequence")
	assert(sim.world.spatial_index._cell_unit(cell,-1,0).is_empty(),"Death frees the floor cell immediately")
	sim.world.battle_simulation._finish_death(soldier)
	assert(not bool(soldier.alive),"Death completes through the simulation finish hook")
	blank()
	var leader:=leader_template.duplicate(true);leader.uid=11;leader.owner=3
	var point: Vector2=sim.nav.anchor_of(8,10);leader.ax=point.x;leader.ay=point.y;leader.A=8;leader.B=10
	var member:=make(12,3,32,Vector2i(9,10));member.group_officer=int(leader.officer.index)
	install([leader,member])
	var state = sim.world.battle_simulation.battle
	state.selected=[leader]
	state.control_groups={1:[11,12],2:[12]}
	sim.world.battle_simulation._finish_death(leader)
	assert(not bool(leader.alive),"Leader marked dead")
	assert(not (state.selected as Array).has(leader),"Selection forgets the dead leader")
	for slot in state.control_groups.keys():
		assert(not (state.control_groups[slot] as Array).has(11),"Control group %s still references the dead leader" % str(slot))

## Save -> Restore: order progress (action clock, status timers, rest counter)
## survives a schema round-trip. The save service uses the same restore calls.
func order_progress_restore() -> void:
	blank()
	var unit:=make(1,3,32,Vector2i(10,10))
	install([unit])
	ActionClock.reset(unit)
	unit.action_wait=13;unit.action_started=true;unit.rest_t=2;unit.confused_t=3
	var saved: Dictionary={}
	for key in ActionClock.FIELDS: saved[key]=unit.get(key)
	for key in TickTimers.STATUS_KEYS + TickTimers.ELAPSED_KEYS: saved[key]=unit.get(key)
	ActionClock.reset(unit)
	for key in TickTimers.STATUS_KEYS + TickTimers.ELAPSED_KEYS: unit[key]=0
	TickTimers.restore(saved,unit)
	ActionClock.restore(saved,unit)
	assert(int(unit.action_wait)==13 and bool(unit.action_started),"Action clock survives restore")
	assert(int(unit.rest_t)==2 and int(unit.confused_t)==3,"Status timers survive restore")
