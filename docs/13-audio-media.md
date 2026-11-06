# 13 音频与媒体

> 本章定义背景音乐、音效、开场与事件视频的播放规则。事件触发条件见[战役](11-campaign.md)；媒体权利见[权利与分发](20-legal.md)。

## 1. 媒体清单

| 类别 | 数量 | 目录 | 格式 |
|---|---:|---|---|
| 背景音乐 | 13 | `media/music/` | OGG（12 首入音频索引，含未接入的结局曲） |
| 音效 | 110 | `media/sfx/` | WAV（8-bit / 11 kHz / 单声道） |
| 关卡开场 | 34 | `media/videos/` | 原始 AVI（Indeo3 + PCM） |
| 事件视频 | 10 | `media/videos/` | 原始 AVI |
| 启动、历史与单挑 | 3 | `media/videos/` | START / LISHI / LDAN 原始 AVI |

47 个 AVI 原片共 400383226 字节。`tools/import_original_media.py` 只逐字节复制原片并用 ffprobe 读取尺寸/帧率/时长；`data/db/video_catalog.json` 记录原始 SHA256。旧 OGV 衍生片不进入正式包。音乐与音效使用 OGG/WAV；12 首原曲 WAV 只作为 OGG 导出母版，留在本地工作目录，不随包分发。

音频重导使用 `tools/export_audio.ps1`，从本地声音输入复制 WAV 并生成 OGG 音乐及音频索引。视频导入只使用 `tools/import_original_media.py`；单挑按播放时间段定位 AVI，无需生成剪辑文件。

## 2. 背景音乐

| 场景 | 曲目 |
|---|---|
| 主菜单 | `media/music/start.ogg` |
| 战场 | `media/music/record01.ogg` |

- 单播放器，音量 −9 dB，循环播放；同一路径重复调用不重启。
- 无头模式跳过播放。
- 战场与菜单切换时重新选择曲目；不实现动态战斗音乐。
- 13 首 OGG 随包，当前播放层只使用上表两首；其余循环曲与结局曲 `vend.ogg` 作为素材保留，未接入播放。

## 3. 音效

### 3.1 播放

| 项 | 规则 |
|---|---|
| 通道 | 8 个播放器轮转 |
| 音量 | 默认 −4 dB；选中语音 −5 dB；攻击 −7 dB |
| 缓存 | 按路径缓存已解码流 |
| 解码 | 运行期解析 RIFF；导出包无原始 WAV 时回退导入资源 |
| 无头 | 跳过播放 |

### 3.2 当前生效的触发

| 触发 | 音效 |
|---|---|
| 选中武将队伍 | `pmove01.wav`（“主公有何吩咐”） |
| 选中普通部队 | `pmove02.wav`（“将军请下令”） |
| 按钮按下 | `click.wav` |
| 近战击发 | `fight*.wav` 随机 |
| 远程击发 | `arrow*.wav` 随机 |
| 投石击发 | `throw*.wav` 随机 |
| 武将升级 | `died2.wav`（音频索引 106） |

- 攻击音只在实际击发时播放；未命中或等待期不播放。
- 只播放玩家方或玩家可见单位的攻击音；升级提示音只给玩家方武将。
- 其余音效（建造、生产、提示、胜负等）在本版本未接入播放层。

## 4. 视频

### 4.1 原格式与原尺寸

视频由 `addons/ffmpegplayer` 的 VideoStreamFFmpeg 原生解码，并交给 VideoStreamPlayer 显示。原 AVI 不转码、不改帧率、不改分辨率，也不生成中间视频。PCM整数样本在播放时归一化为音频混合器需要的浮点样本，保持采样率和声道；禁止把FFmpeg对齐填充当作声音。解码线程与锁在关闭后释放。

视频始终以原始像素1:1在黑底中央显示，开场/事件通常320×240，LDAN为224×140。播放器所在CanvasLayer抵消游戏画布缩放，所以640/1280/1920窗口不会把视频额外放大、压缩或拉伸。播放期间暂停模拟，任意键/鼠标点击跳过，结束后恢复先前暂停状态。

### 4.2 章节、事件、启动与历史

- 章节使用 `scenario.avi` 对应的原 AVI；读档、测试与 `--no-intro` 跳过，结束后进入已有任务开场白。
- 事件仍由 `events.json` 映射；事件4没有对应原片，保留文本。读档恢复事件游标而不重播历史。
- 正常首次启动菜单直接播放START.AVI，每进程一次；历史简介按钮播放LISHI.AVI。
- 缺少媒体时跳过或保留文本，不阻塞游戏。

### 4.3 单挑

单挑直接打开LDAN.AVI，依已确定结果在播放时定位原文件片段：共同交锋24–38秒；平局78–87秒；胜负99–106秒及125秒至片尾。没有剪辑、拼接或重新编码文件。姓名字幕对应实际胜方；自然结束和跳过都只执行原有结算一次，读档取消旧世界回调。

## 5. 资源打包

- 47个AVI原文件随PCK打包；原生解码DLL及其依赖随同一不可变版本发布。发布清单逐个记录DLL哈希，缺失或更改时拒绝切换启动入口。
- 110 个音效 WAV 与 13 首 OGG 随包；12 首原曲 WAV（`media/sfx/record*.wav`、`start.wav`）与 `vend.wav` 只是导出母版，不随包分发，重新导出时由 `tools/export_audio.ps1` 从本地声音输入生成。
- 公开分发时可用 `-NoOriginalMedia` 排除过场视频；缺视频时运行时跳过播放。
- 默认运行集中的原片通过 Git LFS 获取；重新导入用 `tools/import_original_media.py`。解码器的修正源码、依赖锁与重建脚本保存在 `tools/native/avi_decoder/`，MIT/LGPL及运行库说明随包提供。

## 6. 实现对应

| 职责 | 模块 |
|---|---|
| 音乐 | `presentation/audio/bgm.gd` |
| 音效 | `presentation/audio/sfx.gd`、`data/db/audio_index.json` |
| 视频与事件 | `presentation/media/event_view.gd`、`data/db/events.json` |
| 开场选择 | `presentation/battle/components/controller.gd::maybe_play_intro`（由 `battle_view.gd` 转发） |

## 7. 验收要点

- 同一曲目重复调用不重启；无头模式不产生音频错误。
- 攻击音只在击发时播放，且不暴露雾中敌军位置。
- 47个AVI与tmp来源哈希一致；在640/1280/1920窗口保持原尺寸1:1居中。原生音频采样必须有限、有信号且在正常幅度内；跳过或自然结束恢复模拟。
- 读档不重播已播放的事件。
- `-NoOriginalMedia` 包缺视频时，开场与事件直接跳过，不报错阻塞。
