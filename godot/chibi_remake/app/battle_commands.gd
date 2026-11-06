extends RefCounted
## Stable domain command ports. No flat command forwarding or business dispatch.
var technology := preload("res://app/commands/technology_commands.gd").new()
var economy := preload("res://app/commands/economy_commands.gd").new()
var military := preload("res://app/commands/military_commands.gd").new()
var orders := preload("res://app/commands/orders_commands.gd").new()
var world := preload("res://app/commands/world_commands.gd").new()
var session := preload("res://app/commands/session_commands.gd").new()

func port_objects() -> Dictionary:
	return {"commands.technology": technology, "commands.economy": economy, "commands.military": military, "commands.orders": orders, "commands.world": world, "commands.session": session}

func disconnect_services() -> void:
	for port in port_objects().values(): port.disconnect_services()
