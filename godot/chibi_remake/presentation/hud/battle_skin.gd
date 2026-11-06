extends RefCounted
## 高清重绘的面板是唯一装饰母版；裁片在运行时引用，动态 UI 不烘焙进图片。
const Textures = preload("res://presentation/battle/runtime_textures.gd")
var _panel: Texture2D
var _banner: Texture2D

func texture_for(key: String) -> Texture2D:
	if key in ["btn_special", "btn_next"]:
		var controls := Textures.load_texture("res://art/full/ui/left-controls-redraw-v4.png")
		var half := controls.get_size() / Vector2(2, 1)
		return _region(controls, Rect2(Vector2.ZERO if key == "btn_special" else Vector2(half.x, 0), half))
	if key in ["hud_top_left", "hud_top_right"]:
		return texture_for("hud_bar_tile") # 只维持经典布局入口；旧烘焙左右簇从不显示。
	if key not in ["hud_right", "hud_banner", "hud_left", "hud_bottom", "hud_bar_tile", "res_food", "res_gold", "res_wood", "res_stone"]: return null
	if _panel == null:
		_panel = Textures.load_texture("res://art/full/ui/hud_right-redraw-v2.png")
	if key == "hud_right": return _panel
	if key in ["res_gold", "res_food", "res_wood", "res_stone"]:
		var icons := Textures.load_texture("res://art/full/ui/resource-icons-redraw-v3.png")
		var index := ["res_gold", "res_food", "res_wood", "res_stone"].find(key)
		var cell := icons.get_size() / Vector2(2, 2)
		return _region(icons, Rect2(Vector2(index % 2, index / 2) * cell, cell))
	if key == "hud_banner":
		if _banner == null:
			_banner = Textures.load_texture("res://art/full/ui/hud_banner-redraw-v2.png")
		return _region(_banner, Rect2(_banner.get_image().get_used_rect()))
	var sz := _panel.get_size()
	if key == "hud_left": return _region(_panel, Rect2(0, 0, sz.x * 0.09, sz.y))
	if key == "hud_bottom": return _region(_panel, Rect2(sz.x * 0.1, sz.y * 0.70, sz.x * 0.8, sz.y * 0.013))
	return _region(_panel, Rect2(sz.x * 0.015, sz.y * 0.12, sz.x * 0.06, sz.y * 0.06))

func _region(source: Texture2D, area: Rect2) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = source; t.region = area
	return t
