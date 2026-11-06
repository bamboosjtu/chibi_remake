extends SceneTree
func _initialize() -> void:
	var revisions := {}
	var host := Node2D.new()
	host.set_script(load("res://main.gd"))
	var service = load("res://app/save_service.gd").new(host)
	for path in DirAccess.get_files_at("res://data"):
		if path.begins_with("chibi") and path.ends_with(".json"):
			host.map_id = path.trim_suffix(".json")
			revisions[host.map_id] = service.content_revision()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(revisions))
	host.free()
	quit()
