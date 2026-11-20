extends RefCounted
## 逻辑tick与真实秒分开：速度只改变tick投递周期，既有模拟计时仍以固定tick推进。
## 保留原作 100/50/30/20 ms 周期；SIM_DT=1/30 秒时倍率为 1/3、2/3、10/9、5/3。
## 默认“快”档为 10/9 倍，并非实时 1 倍；见 docs/14-architecture.md。
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
