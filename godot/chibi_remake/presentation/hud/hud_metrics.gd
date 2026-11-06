extends RefCounted
## REQ-006（review.md R-06）：唯一战场矩形。
##
## 背景：过去相机夹边、小地图取景框、边缘平移都按**整视口**估算，而 HUD
## 实际遮盖了顶栏、右侧面板、左条和底栏 —— 相机停在"地图右缘=视口右缘"，
## 但可操作战场的右缘其实还差着一个侧栏宽，被遮住的那条地图永远进不来。
##
## 本模块持有这张唯一矩形：
##   · battle_rect —— HUD 之外的可操作战场区域（视口坐标）。**唯一写回方**
##     是 battle_view._apply_metrics{,_original}（布局权威），矩形与布局同步更新。
##   · clamp_world_pos() / visible_world_rect() —— 两个纯函数，供相机夹边与
##     小地图取景框使用；输入输出全部显式传参，布局不参与，可被合成分辨率直接断言。
##
## 地形预取允许比战场矩形更宽（缓冲），但预取范围不当可操作范围用。

## 顶/左/右/底四个内缩量（视口坐标）。布局函数按当前皮肤（现代/原版）写回，
## 也暴露给后续 HUD 组件（REQ-005 命令面板）复用，避免各自重算。
var top_inset := 0.0
var left_inset := 0.0
var right_inset := 0.0
var bottom_inset := 0.0

## 当前战场矩形（视口坐标）；布局从未运行时 size 为 0，
## 消费方应退化为整视口（见 battle_view.battle_rect()）。
var battle_rect := Rect2()

func update(vp: Vector2, top: float, left: float, right: float, bottom: float) -> void:
	top_inset = top
	left_inset = left
	right_inset = right
	# 底部内缩不允许吞掉整屏：视口过窄时 top+bottom 不得盖满高度
	bottom_inset = minf(bottom, maxf(0.0, vp.y * 0.5 - top))
	battle_rect = Rect2(
		Vector2(left_inset, top_inset),
		Vector2(maxf(4.0, vp.x - left_inset - right_inset),
			maxf(4.0, vp.y - top_inset - bottom_inset)))

# ------------------------------------------------------------ 纯函数：相机 ----
## 相机夹边：让**战场矩形**内的可见世界落在 [map_min, map_max] 内。
## rect == 视口时与旧整视口公式完全一致（所见即所得地退化）。
static func clamp_world_pos(cam_pos: Vector2, map_size: Vector2, rect: Rect2, vp: Vector2, zoom: Vector2) -> Vector2:
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return cam_pos
	var vis: Vector2 = rect.size / zoom
	# 矩形四角相对视口中心的世界偏移（除以 zoom：zoom 小 = 世界被放大）
	var t0: Vector2 = (rect.position - vp * 0.5) / zoom   # 矩形左上角 ↔ 世界
	var t1: Vector2 = (rect.end - vp * 0.5) / zoom        # 矩形右下角 ↔ 世界
	var p := cam_pos
	# 可见窗 ⊆ [0, map_size]：cam ∈ [-t0, map_size - t1]。
	# rect == 视口时 t0 = -half、t1 = half ⇒ 与旧整视口公式逐值相等。
	# 可见窗比地图大 → 以矩形中心对齐地图中心（rect==视口时即 cam=map/2，旧行为）。
	p.x = map_size.x * 0.5 - (t0.x + t1.x) * 0.5 if vis.x >= map_size.x else clampf(p.x, -t0.x, map_size.x - t1.x)
	p.y = map_size.y * 0.5 - (t0.y + t1.y) * 0.5 if vis.y >= map_size.y else clampf(p.y, -t0.y, map_size.y - t1.y)
	return p

## 给定相机，世界从战场矩形里能看到的那一块（小地图取景框画它）。
static func visible_world_rect(cam_pos: Vector2, rect: Rect2, vp: Vector2, zoom: Vector2) -> Rect2:
	var t0: Vector2 = (rect.position - vp * 0.5) / zoom
	var t1: Vector2 = (rect.end - vp * 0.5) / zoom
	return Rect2(cam_pos + t0, (t1 - t0))
