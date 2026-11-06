extends TextureRect
## 武将身份只取稳定 index；没有已制作头像的身份隐藏，不能拿别人图片代替。
const Art = preload("res://presentation/battle/art_catalog.gd")
var _art := Art.new()
var _index := -2

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_officer(officer: Dictionary) -> void:
	var index := int(officer.get("index", -1))
	if index != _index:
		_index = index
		texture = _art.officer_texture(index) if index >= 0 else null
	visible = texture != null
