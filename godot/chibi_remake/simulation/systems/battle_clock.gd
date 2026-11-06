extends RefCounted
## 逻辑tick与真实秒分开：速度只改变tick投递周期，既有模拟计时仍以固定tick推进。
const PERIODS := [0.1, 0.05, 0.03, 0.02]
const LABELS := ["慢", "中", "快", "最快"]
var speed_index := 2
func period() -> float:
 return float(PERIODS[speed_index])
func set_speed(index: int) -> bool:
 if index < 0 or index >= PERIODS.size(): return false
 speed_index = index
 return true
func label() -> String:
 return str(LABELS[speed_index])
