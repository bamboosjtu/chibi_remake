extends "res://named_port.gd"
## Internal collaborators share a world lifetime. Borrow providers once for a
## synchronous function; retain only weak links between calls. Cross-layer and
## native callback ports keep their own guarded command adapters.
var _contracts: Dictionary
var CONTRACTS: Dictionary:
	get: return _contracts
var _references: Dictionary = {}

func _init(contracts: Dictionary) -> void:
	_contracts = preload("res://simulation/definitions/frozen_data.gd").copy(contracts)

func connect_services(services: Dictionary) -> Array:
	disconnect_services()
	var missing := validate_services(services, _contracts)
	for provider in _contracts:
		if services.get(provider) != null: _references[provider] = weakref(services[provider])
	return missing

func disconnect_services() -> void:
	_references.clear()

func acquire(providers: Array) -> Dictionary:
	var scope := {}
	for provider: String in providers:
		var target := _require(_references.get(provider), provider)
		if target == null: return {}
		scope[provider] = target
	scope.make_read_only()
	return scope
