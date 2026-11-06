extends CanvasLayer
signal media_finished
var previous_pause := false
var host:Node
var cursor:=0
var player:VideoStreamPlayer
var backdrop:ColorRect
var text:Label
var caption:Label
var events:Dictionary={}
var catalog:Dictionary={}
var active:=false
var completion:=Callable()
var ending_caption:=""
var ending_at:=-1.0
var media_path:=""
var segments:Array=[]
var segment_index:=0

func _init(h:Node) -> void:
	host=h
	if host.has_method("is_battle_context"):cursor=host.task_events.size()
	events=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/events.json")).events
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/video_catalog.json")).files

func _ready() -> void:
	layer=20;process_mode=Node.PROCESS_MODE_ALWAYS
	backdrop=ColorRect.new();backdrop.color=Color.BLACK
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop);backdrop.hide()
	player=VideoStreamPlayer.new();player.expand=false
	player.mouse_filter=Control.MOUSE_FILTER_IGNORE;player.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(player);player.finished.connect(_finish_media);player.hide()
	text=Label.new();text.position=Vector2(40,110);text.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(text)
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",24)
	caption.add_theme_color_override("font_color",Color("ffe1a3"))
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption);caption.hide()
	get_viewport().size_changed.connect(func():
		if active:_layout_video(media_path))

static func original_path(name:String) -> String:
	return "res://media/videos/"+name.get_file().to_upper()

func _native_size(path:String) -> Vector2:
	var entry:Dictionary=catalog.get(path.get_file(),{})
	return Vector2(float(entry.get("width",320)),float(entry.get("height",240)))

func _layout_video(path:String) -> void:
	# Cancel the game's canvas stretch so ONE video pixel remains ONE window pixel.
	var stretch:Transform2D=get_viewport().get_stretch_transform()
	transform=stretch.affine_inverse()
	var physical:Vector2=get_viewport().get_visible_rect().size*stretch.get_scale()
	var native:Vector2=_native_size(path)
	backdrop.position=Vector2.ZERO;backdrop.size=physical
	player.scale=Vector2.ONE;player.expand=false;player.size=native
	player.position=((physical-native)*0.5).floor()
	caption.position=player.position-Vector2(0,64);caption.size=Vector2(native.x,60)

func restore_history() -> void:
	if host.has_method("is_battle_context"):
		if host.view!=null:host.view.opening_pending=false
		cursor=host.task_events.size()
	active=false;completion=Callable();ending_caption="";segments=[];caption.hide()
	player.stop();player.stream=null;player.hide();backdrop.hide();text.text=""
	get_tree().paused=false

## AVI bytes are read by the native decoder. No intermediate video is produced.
func play_media(path:String,completed:=Callable(),heading:="",ending:="",ending_start:=-1.0,spans:Array=[]) -> bool:
	if active or not FileAccess.file_exists(path) or not ClassDB.class_exists("VideoStreamFFmpeg"):return false
	var stream:VideoStream=ClassDB.instantiate("VideoStreamFFmpeg")
	stream.file=path;stream.resource_path=path
	player.stream=stream
	if player.get_video_texture()==null:player.stream=null;return false
	active=true;completion=completed;media_path=path;segments=spans.duplicate(true);segment_index=0
	ending_caption=ending;ending_at=ending_start;previous_pause=get_tree().paused
	text.text="";caption.text=heading;caption.visible=not heading.is_empty()
	_layout_video(path);backdrop.show();player.show();player.play()
	if not segments.is_empty():player.stream_position=float(segments[0][0])
	get_tree().paused=true
	return true

func _finish_media() -> void:
	if not active:return
	active=false
	var finished:=completion;completion=Callable();segments=[]
	player.stop();player.stream=null;player.hide();backdrop.hide();caption.hide()
	get_tree().paused=previous_pause
	if finished.is_valid():finished.call()
	media_finished.emit()

func _input(event:InputEvent) -> void:
	if not active:return
	var skip:bool=(event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if skip:_finish_media();get_viewport().set_input_as_handled()

func _process(_delta:float) -> void:
	if active:
		if not segments.is_empty() and player.stream_position>=float(segments[segment_index][1]):
			segment_index+=1
			if segment_index>=segments.size():_finish_media();return
			player.stream_position=float(segments[segment_index][0])
		if not ending_caption.is_empty() and ((not segments.is_empty() and segment_index>0) or (segments.is_empty() and ending_at>=0 and player.stream_position>=ending_at)):
			caption.text=ending_caption;caption.show()
		return
	if not host.has_method("is_battle_context") or get_tree().paused or cursor>=host.task_events.size():return
	var entry:Dictionary=events.get(str(int(host.task_events[cursor].id)),{})
	cursor+=1
	if entry.has("video") and FileAccess.file_exists(entry.video):play_media(str(entry.video))
	elif entry.has("text"):text.text=str(entry.text)
