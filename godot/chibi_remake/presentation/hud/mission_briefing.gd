extends CanvasLayer
var host: Node2D
var entries := {}
var overlay: ColorRect
var panel: Panel
var title: Label
var body: Label
var done_button: Button
var is_open := false
var previous_pause := false
var opened_frame := -1

func _init(owner: Node2D) -> void:
	host=owner;layer=45;process_mode=Node.PROCESS_MODE_ALWAYS
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/startup_briefings.json"))
	for entry in data.levels:entries[str(entry.map)]=entry

func _ready() -> void:
	overlay=ColorRect.new();overlay.color=Color(0,0,0,0.15)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	panel=Panel.new();panel.size=Vector2(760,360)
	panel.add_theme_stylebox_override("panel",host.view.battle_menu._surface_style(false));overlay.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left=26;box.offset_top=20;box.offset_right=-26;box.offset_bottom=-20
	box.add_theme_constant_override("separation",18)
	var header:=HBoxContainer.new();box.add_child(header)
	var label:=Label.new();label.text="任  务";label.add_theme_font_size_override("font_size",28)
	label.add_theme_color_override("font_color",Color("fff8dd"));header.add_child(label)
	title=Label.new();title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;title.add_theme_font_size_override("font_size",27)
	title.add_theme_color_override("font_color",Color("ffe1a3"));header.add_child(title)
	body=Label.new();body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_font_size_override("font_size",24)
	body.add_theme_color_override("font_color",Color("e9e5d7"));box.add_child(body)
	done_button=host.view.battle_menu._wood_button("完  成",close)
	done_button.custom_minimum_size=Vector2(320,46);done_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	box.add_child(done_button)
	get_viewport().size_changed.connect(_fit);overlay.hide()

func open() -> void:
	var entry: Dictionary=entries.get(str(host.map_id),{})
	if entry.is_empty():push_error("Missing opening briefing: "+str(host.map_id));return
	if not is_open:previous_pause=get_tree().paused
	title.text=str(entry.title);body.text="　　"+str(entry.briefing)
	is_open=true;opened_frame=Engine.get_process_frames()
	overlay.show();_fit();get_tree().paused=true;done_button.grab_focus()

func close() -> void:
	if not is_open:return
	is_open=false;overlay.hide();get_tree().paused=previous_pause

func _input(event: InputEvent) -> void:
	if not is_open or opened_frame==Engine.get_process_frames():return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE]:
		close();get_viewport().set_input_as_handled()

func _fit() -> void:
	if not is_inside_tree():return
	var vp:=get_viewport().get_visible_rect().size
	var factor:=minf(1.4,minf(vp.x*0.8/760.0,vp.y*0.65/360.0))
	panel.scale=Vector2.ONE*factor
	var center: Vector2=host.view.battle_rect().get_center()
	panel.position=(center-panel.size*factor*0.5).clamp(Vector2(8,8),vp-panel.size*factor-Vector2(8,8))
