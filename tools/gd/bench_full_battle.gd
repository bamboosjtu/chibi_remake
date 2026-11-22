extends SceneTree
## Source-engine entry. Exported builds use --full-battle-bench in menu.gd.
const Workload=preload("res://testing/benchmark/full_battle_benchmark.gd")
func _initialize() -> void:
	root.add_child.call_deferred(Workload.new())
static func workload_valid(battle: Node2D) -> bool:
	return Workload.workload_valid(battle)
