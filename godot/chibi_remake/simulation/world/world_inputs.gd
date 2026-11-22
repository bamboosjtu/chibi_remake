extends RefCounted
## Map installation and frame-accumulator writes.

static func set_sim_acc(battle: Object, value: Variant) -> void:
	battle.sim_acc = value

static func set_map_id(battle: Object, value: Variant) -> void:
	battle.map_id = value

static func set_map_data(battle: Object, value: Variant) -> void:
	battle.map_data = value

static func set_player_owner(battle: Object, value: Variant) -> void:
	battle.player_owner = value

static func append_to_train_types(battle: Object, value: Variant) -> void:
	battle.train_types.append(value)

static func clear_build_types(battle: Object) -> void:
	battle.build_types.clear()

static func append_to_build_types(battle: Object, value: Variant) -> void:
	battle.build_types.append(value)
