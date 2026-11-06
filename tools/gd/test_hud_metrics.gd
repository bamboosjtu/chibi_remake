extends SceneTree
# REQ-006（review.md R-06）回归夹具：唯一战场矩形（HudMetrics）。
#
# 验收：640×480 / 1280×720 / 1600×900 / 窄窗口，四条地图边缘都能滚进**可操作**
# 战场矩形；小地图取景框与实际可见区域一致；矩形==视口时与旧公式逐值等价。
# 运行：隔离 APPDATA + --headless --path godot/chibi_remake \
#   --script ../../tools/gd/test_hud_metrics.gd   （**不带** --noview：活体接线也要验）

var _done := false

const HUD = preload("res://presentation/hud/hud_metrics.gd")

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		if not _done:
			printerr("HUD-METRICS TIMEOUT: 断言失败即此表现")
			quit(1))
	_run.call_deferred()

func _run() -> void:
	# ---- 纯函数：合成视口四档 ----
	var map_size := Vector2(4048, 3130)          # chibic1 实测
	for size in [Vector2(640, 480), Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080), Vector2(1560, 1440), Vector2(900, 700)]:
		var m = HUD.new()
		var s := clampf(minf(size.y / 480.0, size.x / 640.0), 0.5, 3.0)
		var panel_w := clampf(size.x * 0.235, 210.0 * s, 300.0 * s)
		m.update(size, 40.0 * s, 28.0 * s, 12.0 + panel_w, 25.0 * s)
		var rect: Rect2 = m.battle_rect
		# 写回的内缩量逐边正确，且矩形非零
		assert(is_equal_approx(rect.position.y, 40.0 * s), "顶栏内缩")
		assert(is_equal_approx(rect.position.x, 28.0 * s), "左条内缩")
		assert(is_equal_approx(rect.end.x, size.x - (12.0 + panel_w)), "右面板内缩")
		assert(rect.size.x > 0.0 and rect.size.y > 0.0, "矩形零尺寸（内缩吞满视口）")
		for zoom in [Vector2(1.0, 1.0), Vector2(2.0, 2.0)]:
			# 相机无论初始在哪，夹紧后战场矩形里可见的世界必须整块落在地图内
			for cam_pos in [Vector2.ZERO, Vector2(9999, -500), map_size, map_size * 0.5, Vector2(-3, 5)]:
				var p := HUD.clamp_world_pos(cam_pos, map_size, rect, size, zoom)
				var vis := HUD.visible_world_rect(p, rect, size, zoom)
				if rect.size.x / zoom.x < map_size.x:
					assert(vis.position.x >= -0.01 and vis.end.x <= map_size.x + 0.01, "右面板挡住的条带仍在地图外(%s)" % size)
				else:
					assert(is_equal_approx(vis.get_center().x, map_size.x * 0.5), "视野大于地图必须居中")
				if rect.size.y / zoom.y < map_size.y:
					assert(vis.position.y >= -0.01 and vis.end.y <= map_size.y + 0.01)
			# 四条边都能单独滚进战场矩形（验收矩阵：地图四边）
			var vl := HUD.visible_world_rect(Vector2(HUD.clamp_world_pos(Vector2(-1e5, 0), map_size, rect, size, zoom).x, 0.0), rect, size, zoom)
			assert(is_equal_approx(vl.position.x, 0.0), "左缘进不了战场矩形(%s)" % size)
			var vr := HUD.visible_world_rect(Vector2(HUD.clamp_world_pos(Vector2(1e5, 0), map_size, rect, size, zoom).x, 0.0), rect, size, zoom)
			assert(is_equal_approx(vr.end.x, map_size.x), "右缘进不了战场矩形(原缺陷 R-06)(%s)" % size)
			var pt := HUD.clamp_world_pos(Vector2(0, -1e5), map_size, rect, size, zoom)
			var vt := HUD.visible_world_rect(pt, rect, size, zoom)
			assert(is_equal_approx(vt.position.y, 0.0), "上缘进不了战场矩形(%s)" % size)
			var pb := HUD.clamp_world_pos(Vector2(0, 1e5), map_size, rect, size, zoom)
			var vb := HUD.visible_world_rect(pb, rect, size, zoom)
			assert(is_equal_approx(vb.end.y, map_size.y), "下缘进不了战场矩形(%s)" % size)
	print("HUD-METRICS PASS: four sizes, both zooms, four map edges enter the battle rect")

	# ---- 矩形==视口时与旧整视口公式逐值等价（digest 不变的保底）----
	var vp := Vector2(1600, 900)
	var zz := Vector2(1.5, 1.5)
	var cam0 := Vector2(1234, 567)
	var half := Vector2(vp.x / (2 * zz.x), vp.y / (2 * zz.y))
	var old_p := Vector2(
		clampf(cam0.x, half.x, map_size.x - half.x),
		clampf(cam0.y, half.y, map_size.y - half.y))
	var new_p := HUD.clamp_world_pos(cam0, map_size, Rect2(Vector2.ZERO, vp), vp, zz)
	assert(is_equal_approx(new_p.x, old_p.x) and is_equal_approx(new_p.y, old_p.y), "矩形==视口必须等价旧公式")

	# ---- 窄窗护栏：top+bottom 不得盖满半屏以上 ----
	var narrow = HUD.new()
	narrow.update(Vector2(900, 700), 400.0, 0.0, 0.0, 300.0)   # 400+300 > 700/2 → 底部被压回
	assert(narrow.battle_rect.size.y > 0.0, "护栏失效：矩形仍被吞满")
	print("HUD-METRICS PASS: old-formula equivalence, narrow-window guard")

	# ---- 活体接线：headless 带 view 启动 → main.tscn 的布局写回矩形并消费 ----
	var game := root.get_node("Game")
	game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	await process_frame
	await process_frame
	var view = battle.view
	assert(view != null)
	var vsize: Vector2 = view.get_viewport_rect().size
	var vrect: Rect2 = view.battle_rect()
	assert(vrect.size.x > 0.0 and vrect.size.y > 0.0, "布局未写回战场矩形")
	assert(vrect.position.y > 0.0 and vrect.position.x > 0.0, "顶栏/左条内缩未写回")
	assert(vrect.end.x < vsize.x - 1.0, "右面板内缩未写回")
	assert(vrect.end.y < vsize.y - 1.0, "底栏内缩未写回")
	var info_rect: Rect2 = view.info.get_global_rect()
	assert(info_rect.position.y >= vrect.end.y - 0.5 and info_rect.end.y <= vsize.y + 0.5, "状态提示必须完整落在底栏，不能盖住战场")
	battle.show_debug = true
	view.update_hud_text()
	await process_frame
	var debug_rect: Rect2 = view.status_sub.get_global_rect()
	info_rect = view.info.get_global_rect()
	assert(debug_rect.position.y >= vrect.end.y - 0.5 and debug_rect.end.y <= info_rect.position.y + 0.5, "调试状态行必须留在底栏并位于反馈文字上方 debug=%s info=%s battle=%s viewport=%s" % [debug_rect, info_rect, vrect, vsize])
	assert(info_rect.position.y >= vrect.end.y - 0.5 and info_rect.end.y <= vsize.y + 0.5, "反馈文字不能压进游戏画面")
	battle.show_debug = false
	view.update_hud_text()
	# clamp_camera 消费同一矩形：乱置相机后被夹回矩形可表示范围
	view.cam.position = Vector2(-99999, 99999)
	view.clamp_camera()
	var visv := HUD.visible_world_rect(view.cam.position, view.battle_rect(), vsize, view.cam.zoom)
	assert(visv.position.x >= -0.5 and visv.end.y <= float(battle.map_data.terrainH) + 0.5, "夹边未按战场矩形生效")
	print("HUD-METRICS PASS: live battle_view writes and consumes the rect")
	battle.free()
	_done = true
	quit()
