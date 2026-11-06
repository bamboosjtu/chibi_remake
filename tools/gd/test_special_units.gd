extends SceneTree
const Rules = preload("res://simulation/systems/combat_rules.gd")
var done := false
var b: Node2D

func _initialize() -> void:
	create_timer(75).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var maps := 0
	# 数据均来自仓库已有JSON，不重新读取原版素材。费用另由用户确认表覆盖。
	for file in DirAccess.get_files_at("res://data"):
		if not file.begins_with("chibi") or not file.ends_with(".json"):continue
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+file))
		var meta:Dictionary=data.units["34"]
		for key in {"hp":100,"attack":150,"attackB":150,"defence":1,"defenceB":2,"vision":10,"range":10,"expGain":15,"moraleGain":2}:
			assert(int(meta[key])==int({"hp":100,"attack":150,"attackB":150,"defence":1,"defenceB":2,"vision":10,"range":10,"expGain":15,"moraleGain":2}[key]),file+" "+key)
		for key in ["attack","attackB","defence","defenceB","range"]:assert(int(data.units["47"][key])==0)
		maps+=1
	assert(maps==34)
	var game:=root.get_node("Game")
	game.current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	var base:Dictionary=b.units.filter(func(u):return u.owner==b.player_owner and int(u.unit) in [0,1])[0]
	assert(b.commands.world._spawn_unit(34,b.player_owner,base.ax,base.ay,true))
	var cat:Dictionary=b.units.back()
	assert(b.commands.world._spawn_unit(47,b.player_owner,base.ax,base.ay,true))
	var ship:Dictionary=b.units.back()
	assert(cat.hp==100 and cat.maxhp==100 and cat.attack==150 and cat.attack_b==150 and cat.defence==1 and cat.defence_b==2)
	assert(cat.vision==20 and cat.atk_range==10 and cat.exp_gain==15 and cat.morale_gain==2)
	assert(ship.attack==0 and ship.attack_b==0 and ship.defence==0 and ship.defence_b==0 and ship.atk_range==0)
	assert(b.commands.economy.ai_unit_cost(34)=={"gold":800.0,"wood":300.0,"food":100.0,"stone":400.0})
	assert(b.commands.economy.train_types_for(8)[0].unit==34 and b.commands.economy.train_types_for(9)[0].unit==34 and not b.commands.economy.train_types_for(20).is_empty())
	print("SPECIAL DATA PASS 34 maps / actual model stats / catapult gold800-wood300-food100-iron400 / production still gated")
	# 三条普通研究相互独立，不能把3级当作1+2+3的累加。
	for bow in range(4):
		for armor in range(4):
			for weapon in range(4):
				b.player_tech={"bow":bow,"armor":armor,"weapon":weapon,"catapult":0,"ship_atk":2,"ship_def":1}
				for unit in [cat,ship]:b.commands.technology._apply_tech_bonuses(unit)
				assert(Rules.defence(ship)==5*bow and Rules.defence(ship,true)==5*armor)
				assert(Rules.attack(ship)==0 and Rules.attack(ship,true)==6*weapon)
				assert(Rules.defence(cat)==1+5*bow and Rules.defence(cat,true)==2+5*armor)
				assert(Rules.attack(cat)==150 and Rules.attack(cat,true)==150)
				assert(not Rules.can_attack(ship) and Rules.can_attack(cat))
	for level in range(3):
		b.player_tech.catapult=level;b.commands.technology._apply_tech_bonuses(cat)
		assert(Rules.attack(cat)==150 and Rules.attack(cat,true)==150+10*level)
	print("SPECIAL RESEARCH PASS 64 independent research combinations / overwriting values / catapult B150-160-170 / transport full defence15-15")
	var enemy:Dictionary=b.units.filter(func(u):return int(u.owner)!=b.player_owner and int(u.owner)!=0 and not u.is_building)[0]
	enemy.officer={};enemy.defence=50;enemy.defence_b=7;enemy.hp=1000;enemy.maxhp=1000;enemy.base_maxhp=1000
	b.units=[cat,ship,enemy] # 单格落点只保留本测试实体，不让原地图建筑占地充当受击者。
	cat.ax=1000;cat.ay=1500;ship.ax=1000;ship.ay=1500
	enemy.ax=1160;enemy.ay=1500;cat.state="attack";cat.target=enemy;cat.cool=0
	assert(b.commands.military._damage(cat,enemy)==163,"catapult must use B170 minus B defence7, rather than A150 minus A defence50")
	# 此测试验收首击的数值，不把当前旧冷却的首tick击发固定成规格。
	for step in range(300):
		b.projectiles.step();b.commands.orders._step_unit(cat,b.SIM_DT)
		if enemy.hp<1000:break
	assert(enemy.hp==837,"existing attack execution must consume the B calculation")
	# 即使攻击计算达到18，船也不能主动索敌、执行人工/AI攻击或恢复旧攻击订单。
	ship.ax=enemy.ax;ship.ay=enemy.ay;ship.state="idle";ship.hold=false
	b.selected=[ship]
	assert(b.commands.orders._attack_selected(enemy)==0 and ship.state=="idle")
	for step in range(120):b.commands.orders._step_unit(ship,b.SIM_DT)
	assert(ship.state=="idle" and ship.target==null and enemy.hp==837)
	ship.state="attack";ship.target=enemy;ship.cool=0
	b.commands.orders._step_unit(ship,b.SIM_DT)
	assert(ship.state=="idle" and ship.target==null and enemy.hp==837)
	assert(b.commands.world._spawn_unit(47,int(enemy.owner),enemy.ax,enemy.ay,true))
	var ai_ship:Dictionary=b.units.back()
	b.commands.military.ai_order_assault(int(enemy.owner));assert(ai_ship.state=="idle" and ai_ship.target==null)
	b.commands.military.ai_order_intercept(int(enemy.owner),cat,1000);assert(ai_ship.state=="idle" and ai_ship.target==null)
	# 保存故意构造的旧版攻击态；新运行时须清掉它，且保留载员与资源。
	ship.state="attack";ship.target=enemy
	ship.carry=137;ship.carry_kind="wood"
	var ship_uid:int=ship.uid
	var enemy_uid:int=enemy.uid
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()))
	var snapshot:Dictionary=game.load_save()
	#旧缓存不是新四计算器的可信来源。
	for rec in snapshot.units:
		if int(rec.uid)==ship_uid:rec.simulation.attack_bonus=999;rec.simulation.defence_bonus=999
	assert(b.saver.apply_snapshot(snapshot))
	ship=b.units.filter(func(u):return int(u.uid)==ship_uid)[0]
	enemy=b.units.filter(func(u):return int(u.uid)==enemy_uid)[0]
	assert(Rules.attack(ship,true)==18 and Rules.defence(ship)==15 and Rules.defence(ship,true)==15)
	b.commands.orders._step_unit(ship,b.SIM_DT)
	assert(ship.state=="idle" and ship.target==null and ship.carry==137 and enemy.hp==837)
	print("SPECIAL EXECUTION PASS actual catapult B hit / unarmed idle-manual-AI-legacy attack rejection / snapshot recomputation / cargo retained")
	b.free();done=true;quit()
