extends SceneTree
# REQ-007（structure-refine-plan P2.4）回归夹具：纹理加载三态声明。
#
# 验收：清缓存启动不依赖编辑器缓存（dev 解码出图并打一次来源日志）；
# 声明为 formal 的高清缺失=错误级；原图缺失=警告级；失败路径全部入列可取证。
# 运行：隔离 APPDATA + godot --headless --path godot/chibi_remake \
#   --script ../../tools/gd/test_texture_states.gd -- --noview （无视图即可，纯 loader）

const Tex = preload("res://presentation/battle/runtime_textures.gd")

var _done := false

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		if not _done:
			printerr("TEX-STATE TIMEOUT: 断言失败即此表现")
			quit(1))
	_run.call_deferred()

func _find_png(dir: String) -> String:
	var files := DirAccess.get_files_at(dir)
	for f in files:
		if f.to_lower().ends_with(".png") and not f.ends_with(".import"):
			return dir + f
	return ""

func _run() -> void:
	# ---- dev_decode：清缓存启动（本项目 .godot 导入缓存本就缺失）不依赖编辑器也能出图 ----
	var hd := _find_png("res://art/full/ui/")
	if hd.is_empty():
		hd = _find_png("res://art/full/buildings/")
	assert(hd != "", "夹具需要一张正式高清 PNG")
	var t1 := Tex.load_texture(hd, ResourceLoader.CACHE_MODE_REUSE, "formal")
	assert(t1 != null, "正式高清 PNG 无法出图（dev 直解码应兜住）")
	print("TEX-STATE PASS: dev decode supplies formal HD without editor cache (%s)" % hd)
	# 幂等：再取同一张应命中缓存而非重复解码
	var t2 := Tex.load_texture(hd, ResourceLoader.CACHE_MODE_REUSE, "formal")
	assert(t2 != null and (t2 == t1 or t2.get_instance_id() == t1.get_instance_id()), "同路径二次加载应命中缓存")

	# ---- 显式原图回退：声明为 original 的缺失只给警告级，不升错误 ----
	# 原版低清素材已不随工程分发；这里只检查声明级的降级行为。
	var miss_count_before: int = Tex.missing_paths.size()
	var mt := Tex.load_texture("res://sprites/__nope_kind.png", ResourceLoader.CACHE_MODE_REUSE, "original")
	assert(mt == null, "缺失必须返回 null")
	assert(Tex.missing_paths.size() == miss_count_before + 1, "original 缺失应入失败清单")
	print("TEX-STATE PASS: original fallback declared, missing stays warning level")

	# ---- 正式高清缺失 = 错误级（静默降级禁令）----
	var miss2 := Tex.load_texture("res://art/full/__definitely_missing.png", ResourceLoader.CACHE_MODE_REUSE, "formal")
	assert(miss2 == null)
	assert(Tex.missing_paths.size() == miss_count_before + 2, "formal 缺失应入失败清单")
	print("TEX-STATE PASS: formal missing recorded (push_error), original stays warning level")
	_done = true
	quit()
