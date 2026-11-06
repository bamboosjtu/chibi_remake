extends RefCounted
## Per-world transient controls; intentionally not part of the save format.
var cheats_enabled := false
var cheat_build_any := false
var cheat_invulnerable := false
var cheat_reveal := false
var cli_mode := false           # --demo/--selftest/--screenshot 时关掉边缘滚屏，保证出图可复现
var simtest_seconds := 0.0      # --simtest=秒：跑固定模拟时长后打印状态摘要并退出
var _input_command := false
