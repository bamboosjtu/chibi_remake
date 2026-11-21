extends Object
## Presentation construction boundary. main.gd owns this factory; app code receives
## it as an object so it never preloads presentation scripts.
const View = preload("res://presentation/battle/view/battle_view.gd")
const ViewContext = preload("res://presentation/battle/view/battle_view_context.gd")
const Sfx = preload("res://presentation/audio/sfx.gd")
const Bgm = preload("res://presentation/audio/bgm.gd")
const Completion = preload("res://presentation/battle/hud/battle_completion.gd")
const Console = preload("res://presentation/battle/hud/cheat_console.gd")
const RemasterArt = preload("res://presentation/battle/resources/art_catalog.gd")
const InputController = preload("res://presentation/battle/controller/battle_input_controller.gd")
const FrameController = preload("res://presentation/battle/controller/battle_frame_controller.gd")
const PresentationState = preload("res://presentation/battle/view/battle_presentation_state.gd")
const CheatInput = preload("res://presentation/battle/input/cheat_input.gd")

func create_view(context: Node2D) -> Node2D:
	return View.new(context)

func create_sfx() -> Node:
	return Sfx.new()

func create_bgm() -> Node:
	return Bgm.new()

func create_completion(host: Node) -> Node:
	return Completion.new(host)

func create_cheat_console(rect: Callable) -> CanvasLayer:
	return Console.new(rect)

func create_art_catalog() -> Object:
	return RemasterArt.new()

func create_cheat_input(node: Node2D, scene: Object) -> Object:
	return CheatInput.new(node, scene, Callable(self, "create_cheat_console"))

func create_scene_state() -> Object:
	return PresentationState.new()

func create_input_controller(scene: Object, node: Node2D, screenshotter: Callable) -> Object:
	return InputController.new(scene, node, screenshotter)

func create_frame_controller(scene: Object, node: Node2D, owner: Object) -> Object:
	return FrameController.new(scene, node, owner)

func create_view_context(scene: Object, queries: Object, actions: Object, session_actions: Object) -> Node2D:
	return ViewContext.new(scene, queries, actions, session_actions)

func screenshot(node: Node) -> void:
	await View.screenshot(node)
