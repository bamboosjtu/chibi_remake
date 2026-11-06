extends CanvasLayer
## Shared save/load picker for the campaign menu and paused battle.
signal confirmed(slot: int, title: String)
signal cancelled
var overlay: ColorRect
var panel: Panel
var heading: Label
var records: ItemList
var name_field: LineEdit
var status: Label
var confirm_button: Button
var entries := []
var selected_slot := -1
var saving := false

func _init() -> void:
	layer=70;process_mode=Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	overlay=ColorRect.new();overlay.color=Color(0,0,0,0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	panel=Panel.new();panel.custom_minimum_size=Vector2(880,620)
	panel.add_theme_stylebox_override("panel",_surface(Color("242b2d"),18));overlay.add_child(panel)
	var list:=VBoxContainer.new();list.add_theme_constant_override("separation",12);panel.add_child(list)
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list.offset_left=18;list.offset_top=18;list.offset_right=-18;list.offset_bottom=-18
	heading=Label.new();heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",30);heading.add_theme_color_override("font_color",Color("ffe1a3"));list.add_child(heading)
	records=ItemList.new();records.custom_minimum_size=Vector2(830,300)
	records.size_flags_vertical=Control.SIZE_EXPAND_FILL;records.add_theme_font_size_override("font_size",21)
	records.add_theme_constant_override("v_separation",10)
	records.add_theme_color_override("font_color",Color("f1d59c"))
	records.add_theme_stylebox_override("panel",_surface(Color("382216"),10))
	records.add_theme_stylebox_override("selected",_surface(Color("71502c"),4))
	records.item_selected.connect(_selected);records.item_activated.connect(func(_index):_confirm())
	list.add_child(records)
	name_field=LineEdit.new();name_field.placeholder_text="进度名称";name_field.max_length=40
	name_field.add_theme_font_size_override("font_size",22);name_field.custom_minimum_size.y=40;list.add_child(name_field)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",18);status.add_theme_color_override("font_color",Color("ffe1a3"));list.add_child(status)
	var actions:=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",24);list.add_child(actions)
	confirm_button=_button("确定",_confirm);actions.add_child(confirm_button)
	actions.add_child(_button("取消",close))
	get_viewport().size_changed.connect(_fit)
	overlay.hide()

func open(for_save: bool, default_title := "") -> void:
	saving=for_save;heading.text="存 储 进 度" if saving else "读 取 进 度"
	name_field.visible=saving;name_field.text=default_title
	records.clear();entries.clear();selected_slot=-1;status.text=""
	var preferred := -1
	for entry in Game.save_slots():
		if int(entry.slot)==0 and (saving or not bool(entry.occupied)):continue
		entries.append(entry)
		var prefix: String="自动进度 / 旧版进度" if int(entry.slot)==0 else "记录 %02d" % int(entry.slot)
		var caption: String="空记录"
		if entry.valid:
			var title: String=entry.name if entry.name!="" else Game.campaign_caption(entry.map)
			var campaign: String=Game.campaign_caption(entry.map)
			caption="%s%s  ·  %s" % [title.left(24),"  ·  "+campaign if title!=campaign else "",str(entry.savedAt).replace("T"," ")]
		elif entry.occupied:caption="记录损坏，无法读取"
		records.add_item("%s    %s" % [prefix,caption])
		var index:=entries.size()-1
		if not saving and not entry.valid:records.set_item_disabled(index,true)
		if preferred<0 and ((saving and not entry.occupied) or (not saving and entry.valid)):preferred=index
	if preferred<0 and saving:preferred=0
	if preferred>=0:
		records.select(preferred);records.ensure_current_is_visible();_selected(preferred)
	else:confirm_button.disabled=true;status.text="没有可读取的进度"
	overlay.show();_fit();records.grab_focus()

func _selected(index: int) -> void:
	if index<0 or index>=entries.size():return
	var entry: Dictionary=entries[index]
	selected_slot=int(entry.slot)
	confirm_button.disabled=not saving and not entry.valid
	confirm_button.text=("覆盖选中记录" if entry.occupied else "保存新进度") if saving else "读取选中记录"
	if saving:
		status.text="只会覆盖选中的记录，其余进度保留。" if entry.occupied else "将保存为一条新进度。"
	else:status.text="读取所选进度，恢复该记录中的战役与部队。"

func _confirm() -> void:
	if selected_slot<0 or confirm_button.disabled:return
	confirmed.emit(selected_slot,name_field.text.strip_edges())

func close() -> void:
	overlay.hide();cancelled.emit()

func dismiss() -> void:overlay.hide()
func show_error(message: String) -> void:status.text=message

func _input(event: InputEvent) -> void:
	if not is_instance_valid(overlay) or not overlay.visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:close();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ENTER or event.keycode==KEY_KP_ENTER:_confirm();get_viewport().set_input_as_handled()

func _fit() -> void:
	if not is_inside_tree():return
	var vp:=get_viewport().get_visible_rect().size
	var factor:=minf(1.0,minf(vp.x/920.0,vp.y/660.0))
	panel.scale=Vector2.ONE*factor
	panel.size=Vector2(880,620);panel.position=(vp-panel.size*factor)*0.5

func _button(caption: String, action: Callable) -> Button:
	var button:=Button.new();button.text=caption;button.custom_minimum_size=Vector2(260,46)
	button.add_theme_font_size_override("font_size",23);button.add_theme_color_override("font_color",Color("ffe1a3"))
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,_surface(Color("71502c") if state=="hover" else Color("4b2c17"),6))
	button.pressed.connect(action);return button

func _surface(color: Color, margin: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.border_color=Color("c79b51")
	style.set_border_width_all(2);style.set_content_margin_all(margin)
	return style
