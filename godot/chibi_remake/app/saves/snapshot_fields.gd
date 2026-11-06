extends RefCounted
## Stable scalar snapshot fields shared by serialization and restoration.
const UNIT_FIELDS := ["last_attacker_uid", "A", "B", "maxhp", "base_maxhp", "hold", "cool", "repath", "pi", "anim", "dir", "moved", "build_frame", "status_173", "event_experience", "attack_bonus", "defence_bonus", "officer_might", "officer_intellect", "group_officer", "team_kind", "carry", "carry_kind", "gather_t", "gather_ticks", "delivery_ticks", "tech_hp_bonus", "mou", "formation", "haste_t", "slow_t", "farsight_t", "confused_t", "burn_t", "burn_dps", "fo_x", "fo_y", "site", "rest_t", "build_t", "action_wait", "action_phase", "action_started", "action_kind", "action_target_uid", "inspired_t", "stock", "stock_max", "attached", "join_target_uid", "aboard_uid", "carry_n", "carry_hp", "loaded", "unload_active", "unload_t", "site_inside_uid", "site_follow_uid", "site_entry_x", "site_entry_y", "site_exit_pending", "build_cost"]
const ACTION_FIELDS := ["action_wait", "action_phase", "action_started", "action_kind", "action_target_uid"]

static func restore_fields() -> Array:
	return UNIT_FIELDS.filter(func(key): return key not in ACTION_FIELDS)
