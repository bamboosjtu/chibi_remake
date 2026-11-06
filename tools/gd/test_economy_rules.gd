extends SceneTree
var done := false
var b: Node2D
func _initialize() -> void:
 create_timer(75).timeout.connect(func():
  if not done: quit(1))
 run.call_deferred()
func open_battle(id := "chibil1") -> void:
 root.get_node("Game").current_map = id
 b = load("res://main.tscn").instantiate()
 root.add_child(b); b.set_process(false); b.cli_mode = true; b.ai = null
func depot(uid: int, owner: int = -1, site := false) -> Dictionary:
 if owner < 0: owner = b.player_owner
 var base: Dictionary = b.units.filter(func(u): return int(u.unit) in [0,1] and int(u.owner)==b.player_owner)[0]
 var d: Dictionary = {}
 for dy in [0,200,-200,400,-400,600,-600]:
  for dx in [0,300,-300,600,-600,900,-900]:
   d = b.commands._place_building(owner, uid, Vector2(base.ax+dx,base.ay+dy), site)
   if not d.is_empty(): break
  if not d.is_empty(): break
 assert(not d.is_empty(), "fixture warehouse placement")
 return d
func snapshot() -> Dictionary:
 var game := root.get_node("Game")
 assert(game.save_game(b.units, b.commands._resources(), b.commands._save_extra()))
 return game.load_save()
func run() -> void:
 open_battle()
 for source in b.units:
  if int(source.unit)==22:assert(source.stock==50000)
  if int(source.unit) in [24,25]:assert(source.stock==500)
 var initial: Dictionary = b.commands._resources()
 for i in range(120): b.commands._sim_step(b.SIM_DT)
 assert(b.commands._resources() == initial, "no player passive income")
 var workers: Array = b.units.filter(func(u): return int(u.unit) == 30 and int(u.owner)==b.player_owner)
 var w: Dictionary = workers[0]
 var trees: Array = b.decor_targets.filter(func(t): return int(t.unit) == 100 and t.alive)
 var target: Dictionary = trees[0]
 var tep: Vector2 = b.commands._edge_point(target, Vector2(workers[0].ax, workers[0].ay))
 for worker in workers:
  worker.ax = tep.x; worker.ay = tep.y
  b.commands._begin_gather(worker, target, [Vector2(worker.ax,worker.ay)])
 for tick in range(99):
  for worker in workers: b.commands._step_unit(worker,b.SIM_DT)
 assert(workers.all(func(worker): return worker.carry == 0))
 for worker in workers: b.commands._step_unit(worker,b.SIM_DT)
 var total := 0.0
 for worker in workers: total += float(worker.carry)
 assert(total == 200 and target.stock == 0 and not target.alive and target.phase == 1, "shared cell extracts exactly 200 once and leaves stump")
 assert(workers.any(func(worker): return worker.gather_obj != target and worker.gather_obj != null and int(worker.gather_obj.unit) == 100), "depleted cell retargets same kind")
 var carrier: Dictionary = workers.filter(func(worker): return worker.carry > 0)[0]
 # 大本营是通用卸货点；此时只有 HQ，没有木材场，也应能作为 wood 的交付点。
 var wood_deps: Array = b.commands._deposits_for(carrier,"wood")
 assert(wood_deps.any(func(depot): return int(depot.unit) in [0,1] and int(depot.owner) == b.player_owner))
 assert(not b.commands._deposit_carry(carrier) and carrier.carry == 200)
 var enemy := depot(4, b.player_owner+1)
 assert(not b.commands._deposits_for(carrier,"wood").any(func(depot): return int(depot.owner) != b.player_owner), "enemy warehouse rejected")
 var unfinished := depot(4,-1,true)
 assert(not b.commands._deposits_for(carrier,"wood").any(func(depot): return bool(depot.get("site",false))), "unfinished warehouse rejected")
 unfinished.site = false; unfinished.hp = unfinished.maxhp
 var uep: Vector2 = b.commands._edge_point(unfinished, Vector2(carrier.ax, carrier.ay), b.DEPOSIT_EDGE_PX)
 carrier.ax = uep.x; carrier.ay = uep.y
 carrier.state = "deliver"; carrier.delivery_ticks = 0
 for tick in range(3): b.commands._step_unit(carrier,b.SIM_DT)
 assert(carrier.carry == 200)
 b.commands._step_unit(carrier,b.SIM_DT)
 assert(carrier.carry == 0 and b.wood == initial.wood+200, "correct depot credits once on fourth poll")
 # 再验一次：工人直接站在大本营旁，wood 也应入账（早期关卡只有 HQ）。
 var hq2: Dictionary = b.units.filter(func(u): return u.alive and int(u.owner) == b.player_owner and int(u.unit) in [0,1])[0]
 var hep: Vector2 = b.commands._edge_point(hq2, Vector2(carrier.ax, carrier.ay), b.DEPOSIT_EDGE_PX)
 carrier.ax = hep.x; carrier.ay = hep.y; carrier.path = []; carrier.carry = 200; carrier.carry_kind = "wood"
 var wood_before_hq: float = b.wood
 assert(b.commands._deposit_carry(carrier) and b.wood == wood_before_hq + 200, "HQ accepts wood as universal drop-off")
 var saved := snapshot()
 var cell: String = target.cell
 assert(b.saver.apply_snapshot(saved))
 assert(not b.decor_cells[cell].alive and b.decor_cells[cell].phase == 1 and b.decor_cells[cell].stock == 0)
 var invalid: Dictionary = saved.duplicate(true)
 invalid.simulation.decorResources[cell].stock = 201
 assert(not b.saver.apply_snapshot(invalid))
 assert(b.decor_cells[cell].stock == 0, "invalid snapshot is atomic")
 w = b.units.filter(func(u): return int(u.owner)==b.player_owner and int(u.unit)==30)[0]
 var grain := depot(10)
 var gep: Vector2 = b.commands._edge_point(grain, Vector2(w.ax, w.ay), b.DEPOSIT_EDGE_PX)
 w.ax=gep.x; w.ay=gep.y; w.carry=200; w.carry_kind="food"
 b.food=b.commands._food_capacity(b.player_owner)
 assert(not b.commands._deposit_carry(w) and w.carry==200)
 b.food-=200
 assert(b.commands._deposit_carry(w) and w.carry==0)
 grain.die_t=0
 assert(not b.commands._deposits_for(w,"food").any(func(depot): return depot == grain), "destroyed depot rejected immediately")
 for u in b.units:
  if int(u.owner)==b.player_owner and int(u.unit) in [0,1,10,11]: u.die_t=0
 w.carry=200; w.carry_kind="food";b.food=0
 assert(b.commands._food_capacity(b.player_owner)==0 and not b.commands._deposit_carry(w) and w.carry==200)
 # 民居三次装载严格为200+200+100，最后一次立即进入消失流程。
 var house:Dictionary=b.units.filter(func(u):return int(u.unit) in [24,25])[0]
 var money_before:float=b.gold
 var gold_depot:Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit) in [0,1])[0]
 gold_depot.die_t=-1
 w.carry=0;w.carry_kind=""
 for amount in [200,200,100]:
  w.gather_ticks=0
  for tick in range(100): b.harvesting.extract(w,house)
  assert(w.carry==amount)
  if amount==100:
   w.gather_obj=house
   var worker_uid:int=w.uid
   b.commands._free_unit_at(b.units.find(house))
   var spent_save:=snapshot()
   assert(b.saver.apply_snapshot(spent_save))
   w=b.units.filter(func(u):return u.uid==worker_uid)[0]
   assert(w.carry==100 and w.gather_obj is Dictionary and not w.gather_obj.alive and int(w.gather_obj.unit) in [24,25],"depleted source context survives pruning and save")
   gold_depot=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit) in [0,1])[0]
  var gep2: Vector2 = b.commands._edge_point(gold_depot, Vector2(w.ax, w.ay), b.DEPOSIT_EDGE_PX)
  w.ax=gep2.x;w.ay=gep2.y
  assert(b.commands._deposit_carry(w))
 assert(house.stock==0 and house.die_t>=0 and b.gold==money_before+500)
 print("ECONOMY HARVEST PASS finite200 / remnant / retarget / no duplication / strict depot / cap0 / save")
 b.free()
 for map_id in ["chibil1","chibic1"]:
  open_battle(map_id)
  var variant := 0 if map_id=="chibil1" else 1
  assert(b.build_types.size()==12)
  var confirmed:Dictionary={30:[400,50,50,0],32:[600,0,100,100],36:[800,100,200,100],45:[500,100,100,50],38:[1200,0,200,200],37:[1600,200,400,200],39:[1000,200,200,100]}
  for uid in confirmed:
   var c:Array=confirmed[uid]
   assert(b.commands.ai_unit_cost(uid)=={"gold":float(c[0]),"wood":float(c[1]),"food":float(c[2]),"stone":float(c[3])},"user confirmed production cost")
  for locked in [6,12,14,18]: assert(b.commands.building_block_reason(locked+variant)!="")
  var granary := depot(10+variant,-1,true)
  assert(b.commands.building_block_reason(12+variant)!="")
  granary.site=false;granary.hp=granary.maxhp
  assert(b.commands.building_block_reason(12+variant)=="")
  var lumber := depot(4+variant)
  assert(b.commands.building_block_reason(14+variant)=="" and b.commands.building_block_reason(18+variant)=="")
  var armory := depot(2+variant)
  assert(b.commands.building_block_reason(6+variant)=="")
  armory.die_t=0
  assert(b.commands.building_block_reason(6+variant)=="","cavalry needs granary AND lumber, not armory")
  lumber.die_t=0
  assert(b.commands.building_block_reason(6+variant)!="")
  lumber.die_t=-1
  for kind in [8+variant,20]: assert(b.commands.building_block_reason(kind)=="")
  assert(b.commands.building_block_reason(21)!="")
  for kind in [6,12,14]:
   b.player_tech.level=0
   assert(b.commands.train_types_for(kind+variant).size()==1)
   b.player_tech.level=1
   var roster: Array=b.commands.train_types_for(kind+variant)
   assert(roster.size()==2 and b.map_data.units[str(roster[1].unit)].hp==200)
  b.player_tech.level=0
  b.gold=10000;b.wood=10000;b.food=10000;b.stone=10000
  var hq: Dictionary=b.units.filter(func(u): return int(u.owner)==b.player_owner and int(u.unit) in [0,1])[0]
  var cash: Dictionary=b.commands._resources()
  assert(not b.commands._queue_train(b.player_owner,hq,38) and b.commands._resources()==cash)
  assert(b.commands._queue_train(b.player_owner,hq,30))
  var paid: Dictionary=b.commands._resources()
  assert(not b.commands._queue_train(b.player_owner,hq,30) and b.commands._resources()==paid)
  for tick in range(99):b.commands._process_trainings(b.SIM_DT)
  assert(b.trainings.size()==1 and b.trainings[0].t==1)
  var training_save:=snapshot()
  assert(b.saver.apply_snapshot(training_save) and b.trainings[0].t==1)
  hq=b.trainings[0].b
  assert(b.commands._cancel_training(hq) and not b.commands._cancel_training(hq))
  assert(b.gold==cash.gold-100 and b.wood==cash.wood-13 and b.food==cash.food-13)
  var trained_before:int=b.units.size()
  assert(b.commands._queue_train(b.player_owner,hq,30))
  for tick in range(100):b.commands._process_trainings(b.SIM_DT)
  assert(b.trainings.is_empty() and b.units.size()==trained_before+1 and b.units.back().officer.is_empty() and int(b.units.back().group_officer)==-1,"new production does not silently assign an officer")
  var barracks:=depot(12+variant)
  paid=b.commands._resources()
  assert(b.commands._queue_train(b.player_owner,barracks,32))
  assert(b.gold==paid.gold-600 and b.wood==paid.wood and b.food==paid.food-100 and b.stone==paid.stone-100)
  assert(b.commands._cancel_training(barracks))
  assert(b.gold==paid.gold-150 and b.wood==paid.wood and b.food==paid.food-25 and b.stone==paid.stone-25)
  var site:=depot(10+variant,-1,true)
  site.build_cost={"gold":200,"wood":100,"food":0,"stone":100}
  site.hp=0
  var site_uid:int=site.uid
  var zero_save:=snapshot()
  assert(b.saver.apply_snapshot(zero_save))
  site=b.units.filter(func(u):return u.uid==site_uid)[0]
  assert(site.alive and site.site and site.hp==0,"zero HP site survives save/load")
  paid=b.commands._resources()
  assert(b.commands._cancel_site(site) and not b.commands._cancel_site(site))
  assert(b.gold==paid.gold+150 and b.wood==paid.wood+75 and b.stone==paid.stone+75)
  print("ECONOMY UNLOCK PASS ",map_id," prerequisites / HQ roster / researched types / production ticks / 75% refunds / zero-HP site")
  b.free()
 upgrade_rules()
 limits()
 done=true;quit()


func upgrade_rules() -> void:
 # 逐张检查项目关卡数据的门槛，与用户给出的两线开放关数对应。
 var directory:=DirAccess.open("res://data")
 var count:=0
 for filename in directory.get_files():
  if not filename.begins_with("chibi") or not filename.ends_with(".json"):continue
  var file:=FileAccess.open("res://data/"+filename,FileAccess.READ)
  var doc:Dictionary=JSON.parse_string(file.get_as_text())
  var chapter:int=filename.substr(6).to_int()
  var expected:int
  if filename.begins_with("chibic"):
   expected=1 if chapter<4 else (2 if chapter<9 else (3 if chapter<11 else 4))
  else:
   expected=1 if chapter<3 else (2 if chapter<8 else (3 if chapter<10 else 4))
  assert(int(doc.scenario.sides[0].init[1])==expected,"campaign upgrade gate "+filename)
  count+=1
 assert(count==34)
 open_battle()
 assert(b.commands.tech_rows_for_building(0).is_empty() and b.commands.tech_block_reason(0)!="")
 var hq:Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit)==0)[0]
 var w:Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit)==30)[0]
 var lumber:=depot(4)
 var armory:=depot(2)
 var tower:=depot(18)
 b.scenario_sides[0].init[1]=2
 assert(b.commands._player_unit_count()==0 and b.commands.tech_block_reason(0)!="","workers and independent commander do not unlock HQ")
 assert(b.commands._spawn_unit(47,b.player_owner,800,2200,true))
 assert(b.commands._player_unit_count()==0,"unarmed transport does not count as combat unit")
 for i in range(2):assert(b.commands._spawn_unit(32,b.player_owner,400+i*44,2200,true))
 assert(b.commands._player_unit_count()==2 and b.commands.tech_block_reason(0)=="")
 b.gold=50000;b.wood=50000;b.stone=50000
 assert(b.commands.tech_cost(0)=={"gold":2000.0,"wood":1000.0,"stone":700.0,"food":0.0})
 var money:Dictionary=b.commands._resources()
 b.selected=[hq]
 assert(b.commands._start_tech(0))
 assert(b.commands._cancel_tech() and not b.commands._cancel_tech())
 assert(b.gold==money.gold-500 and b.wood==money.wood-250 and b.stone==money.stone-175)
 var worker_base:float=w.maxhp
 var tower_base:float=tower.maxhp
 var hq_base:float=hq.maxhp
 w.hp-=20
 b.selected=[hq]
 assert(b.commands._start_tech(0))
 for tick in range(199):b.commands._process_tech(b.SIM_DT)
 assert(w.maxhp==worker_base and b.player_tech.level==0)
 var save:=snapshot()
 assert(b.saver.apply_snapshot(save))
 w=b.units.filter(func(u):return u.uid==w.uid)[0]
 tower=b.units.filter(func(u):return u.uid==tower.uid)[0]
 hq=b.units.filter(func(u):return u.uid==hq.uid)[0]
 b.commands._process_tech(b.SIM_DT)
 assert(b.player_tech.level==1 and w.maxhp==worker_base and w.hp==worker_base-20)
 assert(hq.maxhp==hq_base+400 and tower.maxhp==tower_base)
 assert(b.commands._spawn_unit(38,b.player_owner,600,2200,true))
 assert(b.units.back().maxhp==b.units.back().base_maxhp and b.units.back().hp==b.units.back().base_maxhp+400,"200-man type plus400 current HP")
 assert(b.commands._spawn_unit(18,b.player_owner,700,2200,true))
 assert(b.units.back().maxhp==tower_base,"new towers exempt")
 assert(b.commands.tech_rows_for_building(0).is_empty() and b.commands.tech_block_reason(1)!="")
 b.scenario_sides[0].init[1]=3
 assert(b.commands.tech_block_reason(1)=="")
 b.selected=[hq]
 assert(b.commands._start_tech(1))
 for tick in range(200):b.commands._process_tech(b.SIM_DT)
 assert(w.maxhp==worker_base and tower.maxhp==tower_base)
 b.scenario_sides[0].init[1]=4
 assert(b.commands.tech_block_reason(2)!="")
 assert(b.commands._spawn_unit(32,b.player_owner,800,2200,true))
 b.player_tech.bow=2;b.player_tech.weapon=2
 assert(b.commands.tech_block_reason(2)=="" and b.commands._start_tech(2))
 for tick in range(200):b.commands._process_tech(b.SIM_DT)
 assert(w.maxhp==worker_base and tower.maxhp==tower_base and b.player_tech.level==3 and b.commands.tech_rows_for_building(0).is_empty())
 var upgraded:=snapshot()
 assert(b.saver.apply_snapshot(upgraded))
 assert(b.player_tech.level==3 and b.player_tech.bow==2 and b.player_tech.weapon==2,"named tech keys survive load")
 assert(b.commands._spawn_unit(38,b.player_owner,900,2200,true) and b.units.back().maxhp==b.units.back().base_maxhp and b.units.back().hp==b.units.back().base_maxhp+1200)
 print("ECONOMY HQ PASS 34 chapter gates / combat-only counts / costs / 200 ticks / 75% / three upgrades / existing+new HP / tower exemption")
 b.free()

func limits() -> void:
 open_battle()
 var leader:Dictionary=b.selected[0]
 var workers:Array=b.units.filter(func(u):return int(u.unit)==30 and int(u.owner)==b.player_owner)
 for i in range(19):
  var extra:Dictionary=leader.duplicate(true)
  extra.uid=1000+i;extra.officer.index=i
  b.units.append(extra)
 assert(b.commands._commander_count(b.player_owner)==20)
 assert(not b.commands._form_hero_unit(workers[0],39),"twenty commander limit")
 var cash:Dictionary=b.commands._resources()
 assert(not b.commands._build_site_at(Vector2(600,2200),{"unit":21,"gold":0}),"scenario-only object cannot bypass menu")
 assert(b.commands._resources()==cash)
 var hq:Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit)==0)[0]
 while b.commands._army_count(b.player_owner)<200:assert(b.commands._spawn_unit(30,b.player_owner,500,2200,true))
 assert(not b.commands._spawn_unit(30,b.player_owner,500,2200) and not b.commands._queue_train(b.player_owner,hq,30))
 assert(b.commands._resources()==cash,"capacity rejection cannot spend resources")
 print("ECONOMY LIMIT PASS 20 commanders / 200 objects / no cost on rejected commands")
 b.free()
