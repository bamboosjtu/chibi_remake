extends SceneTree
const Rules = preload("res://simulation/systems/combat_rules.gd")
var done := false
func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	# 独立期望值按骑/步/弓/文排列，防止实现与测试同时误用列顺序。
	var expected := [[2,3,1,0],[4,5,2,3],[6,3,6,3],[8,4,8,4],[9,6,9,6],
		[12,6,12,6],[12,14,7,9],[8,16,10,14],[9,18,11,16],[20,20,20,20]]
	for level in range(10):
		for tier in range(1,5):
			var officer := {"tier":tier,"level":level,"might":66}
			assert(Rules.grade(officer)==expected[level][tier-1])
	assert(Rules.grade({"tier":0,"level":9})==0)
	var a := {"unit":31,"attack":29.0,"attack_b":37.0,"officer":{"might":66,"tier":2,"level":6},"attack_bonus":99}
	var d := {"unit":35,"defence":7.0,"defence_b":13.0,"officer":{"might":71,"tier":1,"level":9}}
	assert(Rules.attack(a)==23)
	assert(Rules.attack(a,true)==29)
	assert(Rules.defence(d)==4)
	assert(Rules.defence(d,true)==9)
	assert(Rules.damage(a,d,false)==19 and Rules.damage(a,d,true)==20)
	assert(Rules.damage({"unit":31,"attack":12,"officer":{"might":66,"tier":2,"level":0}},
		{"unit":31,"defence":8,"officer":{"might":66,"tier":2,"level":0}},false)==3,"integer hero stats: 8-5 = 3")
	assert(Rules.damage({"attack":0},{"defence":50},false)==1)
	print("COMBAT FORMULA PASS 40 grades / integer hero A-B formulas / minimum")
	root.get_node("Game").current_map="chibil1"
	var b:Node2D=load("res://main.tscn").instantiate()
	root.add_child(b);b.set_process(false);b.cli_mode=true;b.ai=null
	assert(b.commands._stamina_of(a)==80)
	# 各档兵器/弓术/盔甲四效果列；A和B各自独立，武将不吃普通科技加成。
	for level in range(1,4):
		b.player_tech={"weapon":level,"bow":level,"armor":level}
		for ids in [[32,36,45],[37,38,39],[40,41,42],[43,44]]:
			var category:int=[[32,36,45],[37,38,39],[40,41,42],[43,44]].find(ids)
			for id in ids:
				var u:Dictionary=b.units.filter(func(unit):return unit.owner==b.player_owner)[0].duplicate()
				u.unit=id;u.officer={};u.attack=12;u.attack_b=15;u.defence=4;u.defence_b=7
				b.commands._apply_tech_bonuses(u)
				assert(u.attack_bonus==(3+category)*level)
				assert(u.attack_b_bonus==(2+category)*level)
				assert(u.defence_bonus==(2+category)*level and u.defence_b_bonus==u.defence_bonus)
				assert(Rules.attack(u)==12+(3+category)*level)
				assert(Rules.attack(u,true)==15+(2+category)*level)
	var hero:Dictionary=b.units.filter(func(unit):return not unit.officer.is_empty())[0]
	assert(b.commands._stamina_of(hero)==float(hero.officer.might)+Rules.grade(hero.officer))
	# 快船/战船分别占独立研究位；连船使用用户确认的相邻字段规则。
	for ship_level in range(3):
		for armored in [0,1]:
			for catapult in range(3):
				b.player_tech={"weapon":3,"bow":3,"armor":3,"ship_atk":ship_level,"ship_def":armored,"catapult":catapult}
				for id in [46,48,49,47,52]:
					# 运输船普通研究档位尚待确认，此处只验证专用船舶研究不外溢。
					for key in ["weapon","bow","armor"]:b.player_tech[key]=0 if id==47 else 3
					var ship:Dictionary=hero.duplicate(true)
					ship.unit=id;ship.officer={};ship.attack=10;ship.attack_b=30;ship.defence=4;ship.defence_b=7
					if id==52:ship.officer={"might":66,"tier":1,"level":6}
					b.commands._apply_tech_bonuses(ship)
					var attack_b:=0.0
					var defence:=0.0
					if id==46:attack_b=6.0 if ship_level>=1 else 0.0;defence=6.0*armored
					if id==48:attack_b=15.0 if ship_level>=2 else 0.0;defence=10.0*armored
					if id==49:attack_b=10.0*catapult;defence=15.0 if ship_level>=2 else 0.0
					assert(ship.attack_b_bonus==attack_b and ship.defence_bonus==defence and ship.defence_b_bonus==defence)
					assert(ship.attack_bonus==(9.0 if id==46 else (12.0 if id==48 else 0.0)))
					if id==52:assert(Rules.attack(ship,true)==23 and Rules.defence(ship,true)==4)
	print("COMBAT NAVAL PASS 18 research combinations x 5 ship types / separate A-B / flagship grade / linked-ship adjacent fields")
	b.player_tech={"weapon":3,"bow":3,"armor":3,"ship_atk":2,"ship_def":1,"catapult":2}
	var game:=root.get_node("Game")
	for u in b.units:b.commands._apply_tech_bonuses(u)
	assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
	var snapshot:Dictionary=game.load_save()
	# 迁移旧缓存，读档应按等级重算，而非保留旧版统一+3/+2。
	for rec in snapshot.units:rec.simulation.attack_bonus=999
	assert(b.saver.apply_snapshot(snapshot))
	for u in b.units:
		if u.owner==b.player_owner:assert(float(u.attack_bonus)!=999)
	print("COMBAT TECH PASS 3 levels / 11 troop types / 4 research columns / stamina / old-cache save migration")
	b.free();done=true;quit()
