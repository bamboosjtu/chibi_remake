extends RefCounted
## entity factory: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/entity_factory_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _rate_of(meta: Dictionary) -> int:
	var r := int(meta.get("f9", 100))
	return r if r > 0 else 100

func _make_unit(ob: Dictionary, is_map_object: bool) -> Dictionary:
	var w := int(ob.w)
	var h := int(ob.h)
	var ax := float(ob.px) + w * 0.5
	var ay := float(ob.py) + h
	var tail_v := 0
	for i in range(ob.tail.size()):
		tail_v += int(ob.tail[i]) << (8 * i)
	var building: bool = int(ob.unit) <= 26
	# 注意：JSON 里的数字是 float，str(32.0) 与 JSON 的键 "32" 不一定相等；
	# 必须 str(int(...)) 才能命中（此前 v6 的属性没生效就是这个原因）。
	var meta: Dictionary = battle.map_data.units.get(str(int(ob.unit)), {})
	var frames: Dictionary = meta.get("frames", {})
	# 属性来自 DATA.EXP 的类型表（docs/UNIT-ATTRIBUTES.md §1）。
	# 物件记录里的「尾部数值」语义仍未定，只在没有类型 HP 时兜底。
	var hp := 60.0
	if meta.has("hp"):
		hp = float(meta.hp)
	elif tail_v > 0:
		hp = float(tail_v)
	var attack := float(meta.get("attack", 8))
	var defence := float(meta.get("defence", 0))
	var vision := float(meta.get("vision", 5)) * Config.VISION_SCALE
	var atk_range := float(meta.get("range", 1))
	var mitig := float(meta.get("mitig", 0))

	# ARCH-013：sprite/skin/选中菱形/血条由 battle_view.gd 建；view 缺席时 u 里没有这些键。
	# 倍率 k 是**数据**（图集自己的倍率优先，全图 spriteK 只作旧数据回退），所以留在 main。
	var k: float = float(meta.get("sheetK", battle.map_data.get("spriteK", 1)))

	var uid := battle.next_uid
	battle.next_uid += 1
	var u := {
		"uid": uid, "map_object": is_map_object,
		"unit": int(ob.unit), "owner": int(ob.owner), "A": int(ob.A), "B": int(ob.B),
		"is_building": building, "name": str(meta.get("name", "unit")),
		"k": k,
		"w": w, "h": h,
		# 原地警戒：为 true 时**不自动索敌**（原版由玩家的"警戒"指令置位）。
		# 注意这与 idle 不同 —— idle 仍会按视野主动接敌。
		"hold": false,
		"status_173": 70, "event_experience": 0,
		"count": int(frames.get("count", 1)),
		"grid": int(frames.get("cols", Config.GRID_FALLBACK)),
		"build_frame": 0,       # B8：建筑当前建造阶段（建造系统尚未实现，固定 0）
		"clips": (meta.get("clips", {}) as Dictionary),
		# 原版 `+0x1F` 速率：运输船/云梯为 **0**（没有攻击节拍），但仍有行走动画。
		# 0 直接做除数会把帧间隔算成 20 s（船看起来冻住），这里生产按钮00（默认速率）回退。
		"rate": _rate_of(meta),
		"frame_sec": maxf(0.05, (1000.0 / maxf(1.0, float(_rate_of(meta)))) * 0.02),
		# DATA.EXP 类型属性（真实值，非估计）
		"attack": attack, "defence": defence, "vision": vision, "base_vision": float(meta.get("vision",0)), "atk_range": atk_range,
		"attack_b": float(meta.get("attackB", 0)), "defence_b": float(meta.get("defenceB", 0)),
		"attack_b_bonus": 0.0, "defence_b_bonus": 0.0, "defence_bonus": 0.0,
		"mitig": mitig,           # 伤害减免系数：减免 = 武将武力 × mitig / 100
		# 原版 FUN_00422a20：击杀方所辖将的经验/士气增量（DATA.EXP +0x34/+0x35）
		"exp_gain": float(meta.get("expGain", 0)),
		"morale_gain": float(meta.get("moraleGain", 0)),
		"group_officer": -1,      # 所属将领的稳定素材编号；将领本身用 officer.index
		"officer": {},            # DATA.EXP 第 5 段的武将（_assign_officers 填入）
		"officer_might": 0.0,     # 武力 → 减免项 + 第二口径攻击力
		"officer_intellect": 0.0, # 智力（计谋/单挑待用）
		"attack_bonus": 0.0,      # 原版按「玩家 × 职业」查表；见 UNIT-ATTRIBUTES §1.4
		# REQ-001：状态字段**在模型里声明**（快照/typeof/读档兜底都依赖形状稳定）
		"carry": 0.0, "carry_kind": "", "gather_t": 0.0, "gather_ticks": 0, "delivery_ticks": 0, "gather_obj": null,
		"mou": 0.0,               # 谋略值（带将时 _attach_officer 初始化）
		"formation": -1,          # 阵法（-1 = 未变阵）
		"fo_x": 0, "fo_y": 0,     # 阵法偏移（格；原版 +0x134/+0x138，移动时加到点击格）
		"site": false,            # 工地（模式 0x13：HP=0 起，工人每 4 tick +2 HP）
		"rest_t": 0, "build_t": 0,   # 已经过的逻辑 tick（v6）
		"repair_target": null, "build_target": null,
		"inspired_t": 0,        # 七种计谋状态的剩余单位更新次数
		"haste_t": 0, "slow_t": 0, "confused_t": 0, "farsight_t": 0,
		"ambush_t": 0, "rolling_t":0,"rolling_ticks":0,"effect_tasks":[],"effect_task":0,"burn_t": 0.0, "burn_dps": 0.0,
		# ---- 水战/装载（原版模式 0xC/0xD，见分析 §13）----
		"attached": false,        # 被载单位：已附着到运输船（脱离地图，不可操作）
		"aboard_uid": -1,         # 所附运输船的 uid（读档后仍能按 uid 找回来）
		"board_target": null,     # 上船命令的目标船（对象引用）
		"join_target_uid": -1,
		"carry_n": 0,             # 运输船：载员数（原版 +0x168，上限 16）
		"carry_hp": 0.0,          # 运输船：载员 HP 合计（原版 +0x16C）
		"loaded": false,          # 运输船：装载标志（原版 +0x164）
		# R03：持续卸载状态与每 4 tick 的节拍相位。新命令可打断 state，但不打断在舱卸载；
		# 这两个字段必须进存档，否则读档后卸载静默停止/节拍归零。
		"unload_active": false, "unload_t": 0,
		"site_inside_uid": -1, "site_follow_uid": -1, "site_entry_x": 0.0, "site_entry_y": 0.0, "site_exit_pending": false,
		"tail_value": tail_v,   # 移动部队为统辖武将编号；建筑/资源尾字段另行解释。
		"ax": ax, "ay": ay, "hp": hp, "maxhp": hp, "base_maxhp": hp, "alive": true,
		"last_attacker_uid":-1,"action_wait":0,"action_phase":0,"action_started":false,"action_kind":"","action_target_uid":-1,
		"state": "idle", "target": null, "cool": 0.0, "repath": 0.0,
		"path": [], "pi": 0,
		"anim": 0.0, "dir": 0, "moved": false, "die_t": -1.0,
	}

	battle.sheet_by_unit["%d_%d" % [int(ob.unit), int(ob.owner)]] = str(ob.sheet)
	# 用户确认首版统一铁矿50000、民居500；保留tail_value供后续规则校准。
	if is_map_object and Config.STOCK_UNITS.has(int(ob.unit)):
		u["stock"] = 50000.0 if int(ob.unit) == 22 else 500.0
		u["stock_max"] = u.stock # 用户确认首版统一存量；逐点差异列入GAP。
	_initialize_unit(u, ob, w, h, k)
	return u

func _initialize_unit(u: Dictionary, ob: Dictionary, w: int, h: int, k: float) -> void:
	preload("res://simulation/systems/locomotion.gd").ensure(u)
	ports._apply_tech_bonuses(u)
	# Render nodes belong to the view's UID registry, including during restoration.
	if battle.effects != null:
		battle.effects.visual("attach_unit", [u, ob, w, h, k])

func _spawn_unit(unit_id: int, owner: int, ax: float, ay: float, restoring := false) -> bool:
	if not restoring and ports._army_count(owner) >= 200: return false
	var meta: Dictionary = battle.map_data.units.get(str(unit_id), {})
	if meta.is_empty():
		push_warning("spawn failed: unknown unit %d" % unit_id)
		return false
	if not restoring and unit_id in Config.NAVAL_UNITS and not battle.nav.has_water: return false
	var w := int(meta.w)
	var h := int(meta.h)
	var sheet := ports._sheet_ref_for(unit_id, owner)
	if sheet == "":
		push_warning("spawn failed: no sheet for unit %d owner %d" % [unit_id, owner])
		return false
	# 外观在 _make_unit 内创建，城门安装高度也在此时按格坐标查表。
	# 不能先用 (0,0) 创建，再由读档写回 A/B，否则门体与地形开口分离。
	var cell_at_anchor := battle.nav.cell_of_px(ax, ay)
	var ob := {
		"unit": unit_id, "owner": owner, "A": cell_at_anchor.x, "B": cell_at_anchor.y,
		"px": ax - w * 0.5, "py": ay - h, "w": w, "h": h,
		"tail": [], "sheet": sheet,
	}
	var nu := _make_unit(ob, false)
	# A/B 是“脚底锚点格”，任何路径都会维护它；恢复/夹具路径不走下面的落位分支时
	# 也必须先与坐标一致，否则读档前后的 A/B 会一边是 0 一边是真实格。
	if not nu.is_building:
		var anchor_cell := battle.nav.near_walkable(battle.nav.cell_of_px(ax, ay), ports._nav_layer(nu))
		nu.A = anchor_cell.x; nu.B = anchor_cell.y
	if not nu.is_building and not restoring:
		# 水军按**水面层**落位（船坞产出的船、读档恢复的船都在水上）；陆军仍按陆地层。
		var layer := ports._nav_layer(nu)
		var want := battle.nav.near_walkable(battle.nav.cell_of_px(ax, ay), layer)
		var cell := ports._free_unit_cell(want, layer, int(nu.uid), unit_id)
		if cell.x < 0 or battle.nav.is_solid(cell, layer):
			if battle.effects != null:
				battle.effects.visual("free_unit", [nu])
			return false
		var anchor := battle.nav.anchor_of(cell.x, cell.y)
		nu.ax = anchor.x; nu.ay = anchor.y
		nu.A = cell.x; nu.B = cell.y
		ports._place_unit(nu)
	# 新生产成员保持未编组；只有明确的组建命令才能占用武将。
	# 生产/组建出来的新单位同样套用当前科技（幂等；_make_unit 里已调过一次）。
	if owner == battle.player_owner:
		ports._apply_tech_bonuses(nu)
	battle.units.append(nu)
	battle._index_units_size = battle.units.size()
	ports._index_remember(nu)           # R13：新单位立即进入占格索引
	ports._target_sync(nu)
	return true

func _attach_officer(u: Dictionary, o: Dictionary) -> void:
	u["officer"] = o
	u["officer_might"] = float(o.get("might", 0))
	u["officer_intellect"] = float(o.get("intellect", 0))
	# 谋略池（计谋资源）：上限 = 智力 × 2 + 15（research/magics）。
	u["mou"] = 10.0 # 开局可用谋略；不再凭智力赠送上千点

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	var k1 := "%d_%d" % [unit_id, owner]
	if battle.sheet_by_unit.has(k1):
		return str(battle.sheet_by_unit[k1])
	for key in battle.sheet_by_unit.keys():
		if str(key).begins_with("%d_" % unit_id):
			return str(battle.sheet_by_unit[key])
	# 落回类型表：导出器现在为「AI 可能训练、但地图上没有」的兵种也出了图集，
	# 那些兵种不会进 sheet_by_unit（它只从地图对象填充）。
	# 没有这一层，AI 按等级表训练 34/42/… 就会 "no sheet for unit 34 owner 3"。
	var meta: Dictionary = battle.map_data.units.get(str(int(unit_id)), {})
	var sref: String = str(meta.get("sheet", ""))
	if sref != "":
		return sref
	return ""
