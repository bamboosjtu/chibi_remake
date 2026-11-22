extends Node
## Persistent presentation host. Owns widgets that must survive battle/menu swaps.
## The software cursor is intentionally an autoload-owned CanvasLayer, not a
## scene node: rebuilding a battle must not create a second cursor.
func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	add_child(preload("res://presentation/shell/software_cursor.gd").new())
