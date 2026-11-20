extends RefCounted
## 源工程与导出包共用：缺少编辑器缓存时从原 PNG 解码，不能静默退回低清。
##
## REQ-007（纹理加载三态声明）：
##   · formal —— 正式高清：走编辑器导入产物（.ctex）或正式 PNG；声明为 formal 的
##     路径缺失 = **push_error**（不能静默退回低清或消失）。
##   · original —— 显式原图回退：原版素材按声明允许；缺失 = push_warning。
##   · dev_decode —— 清缓存启动：.import 存在但产物缺失（新克隆/无 .godot）时
##     直接解码 PNG，来源**打一次**日志（"日志标注来源"验收项，按路径去重）。
## 开发环境因此不依赖编辑器缓存；成品（已导入 PCK）优先正式导入资源。
## load_texture 的第三参为声明级（""|formal|original），缺省不改变既有调用行为。

static var _log_once := {}            # 日志去重（每条只打一次）
static var missing_paths := []        # 测试取证：本轮加载失败的全部路径

static func load_texture(path: String, cache_mode := ResourceLoader.CACHE_MODE_REUSE, declared := "") -> Texture2D:
	if path.is_empty():
		return null
	if not path.begins_with("res://") and not path.begins_with("user://"):
		path = "res://" + path
	if ResourceLoader.has_cached(path) and cache_mode == ResourceLoader.CACHE_MODE_REUSE:
		return ResourceLoader.load(path, "Texture2D") as Texture2D
	if FileAccess.file_exists(path):
		var imported := ConfigFile.new()
		var compiled := ""
		if imported.load(path + ".import") == OK:
			compiled = str(imported.get_value("remap", "path", ""))
		if compiled.is_empty() or not FileAccess.file_exists(compiled):
			# REQ-007（清缓存启动）：无编辑器产物 → 直接解码 PNG，记录一次来源
			_note_once("TEX 开发解码（无编辑器缓存，直接 PNG）: " + path)
			var image := Image.new()
			if image.load(ProjectSettings.globalize_path(path)) != OK:
				_mark_missing(path, declared)
				return null
			var texture := ImageTexture.create_from_image(image)
			if cache_mode == ResourceLoader.CACHE_MODE_REUSE:
				texture.take_over_path(path)
			return texture
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "Texture2D", cache_mode) as Texture2D
	_mark_missing(path, declared)
	return null

## 缺失分级：声明为 formal 的高清缺失 = 错误；原图/未声明 = 警告。失败路径全部入列取证。
static func _mark_missing(path: String, declared: String) -> void:
	missing_paths.append(path)
	if declared == "formal":
		push_error("TEX 缺失（声明为正式高清，不能回退）: " + path)
	else:
		push_warning("TEX 缺失（原图回退缺失）: " + path)

static func _note_once(msg: String) -> void:
	if _log_once.has(msg):
		return
	_log_once[msg] = true
	print(msg)
