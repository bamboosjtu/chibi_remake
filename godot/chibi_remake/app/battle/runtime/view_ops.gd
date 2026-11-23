extends RefCounted
## The narrow presentation capability App's save transaction is allowed to use.
## The implementation remains battle_view.gd; this wrapper keeps the transaction
## independent of presentation node types and gives the rollback contract one name.

var view: Node2D

func _init(target: Node2D) -> void:
	view = target

func stage(preview: Node2D, rows: Array, map_id: String, cross_map: bool) -> Dictionary:
	return view.stage_world_view(preview, rows, map_id, cross_map)

func apply_nodes(token: Dictionary) -> bool:
	return view.apply_world_view_nodes(token) == true

func apply_terrain(token: Dictionary) -> bool:
	return view.apply_world_view_terrain(token) == true

func rollback(token: Dictionary) -> void:
	view.rollback_world_view(token)

func release_previous(token: Dictionary) -> void:
	view.release_previous_world_view(token)

func finish(token: Dictionary, rows: Array, game_end: int) -> void:
	view.finish_world_view(token, rows, game_end)
