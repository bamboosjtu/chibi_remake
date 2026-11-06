extends RefCounted
## 回归夹具：严格仓库规则下显式提供已完工仓库；不改资源格的200存量。
static func warehouses(b: Node2D) -> void:
 var base: Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit) in [0,1])[0]
 for uid in [10,4,2]:
  var depot: Dictionary={}
  for dy in [0,200,-200,400,-400,600,-600]:
   for dx in [0,300,-300,600,-600,900,-900]:
    depot=b.commands.economy._place_building(b.player_owner,uid,Vector2(base.ax+dx,base.ay+dy))
    if not depot.is_empty():break
   if not depot.is_empty():break
  assert(not depot.is_empty(),"fixture warehouse")
