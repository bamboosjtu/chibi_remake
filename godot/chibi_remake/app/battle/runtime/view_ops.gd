extends RefCounted
## The narrow presentation capability App's save transaction is allowed to use.
## The implementation remains battle_view.gd; this wrapper keeps the transaction
## independent of presentation node types and gives the rollback contract one name.

var view: Node2D

func _init(target: Node2D) -> void:
	view = target

func camera() -> Camera2D:
	return view.cam

func host() -> Object:
	return view.host

func set_host(value: Object) -> void:
	view.host = value

func prepare_map_terrain(map_id: String) -> Dictionary:
	return view.prepare_map_terrain(map_id)

func stage_world_nodes() -> Dictionary:
	return view.stage_world_nodes()

func attach_loaded_world(rows: Array) -> bool:
	return view.attach_loaded_world(rows) == true

func stage_map_terrain(map_id: String, plan: Dictionary) -> Node2D:
	return view.stage_map_terrain(map_id, plan)

func rollback_world_nodes(presentation: Dictionary) -> void:
	view.rollback_world_nodes(presentation)

func commit_world_nodes(presentation: Dictionary) -> void:
	view.commit_world_nodes(presentation)

func commit_map_terrain(terrain: Node2D) -> void:
	view.commit_map_terrain(terrain)

func finish_map_change() -> void:
	view.finish_map_change()

func finish_loaded_world(rows: Array, game_end: int) -> void:
	view.finish_loaded_world(rows, game_end)
