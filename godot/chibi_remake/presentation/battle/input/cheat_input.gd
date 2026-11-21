extends RefCounted
## Presentation-side cheat console lifecycle. App owns matching and state; this
## object owns only the CanvasLayer widget and its text.
var node: Node2D
var scene: Object
var console: CanvasLayer
var console_factory: Callable

func _init(surface: Node2D, services: Object, factory: Callable) -> void:
	node = surface
	scene = services
	console_factory = factory

func open() -> void:
	if not is_instance_valid(console):
		if console_factory.is_valid():
			console = console_factory.call(Callable(scene.view, "battle_rect") if scene.view != null else Callable())
		if console != null:
			node.add_child(console)
	if is_instance_valid(console):
		console.show()

func hide() -> void:
	if is_instance_valid(console):
		console.hide()

func update_input(text: String) -> void:
	if is_instance_valid(console):
		console.update_input(text)
