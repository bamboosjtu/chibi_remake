# 13 音频与媒体

> 本章定义背景音乐、音效、开场与事件视频的播放规则。事件触发条件见[战役](11-campaign.md)；媒体权利见[权利与分发](20-legal.md)。

## 1. 媒体清单

| 类别 | 数量 | 目录 | 格式 |
|---|---:|---|---|
| 背景音乐 | 13 | `media/music/` | OGG（12 首入音频索引，含未接入的结局曲） |
| 音效 | 110 | `media/sfx/` | WAV（8-bit / 11 kHz / 单声道） |
| 关卡开场 | 34 | `media/videos/` | 本机私有 720p MP4（H.264 / 双声道 AAC） |
| 事件视频 | 10 | `media/videos/` | 原始 AVI |
| 启动、历史与单挑 | 3 | `media/videos/` | START / LISHI / LDAN 原始 AVI |

共享原片仅保留 13 个 AVI，逐文件沿用原作 SHA256。34 个战役开场的 MP4 与共享 AVI 均记录在 `data/db/video_catalog.json`；运行时无 OGV 中间产物。音乐与音效仍用 OGG/WAV，原始 WAV 母版保留本地。

音频重导使用 `tools/export_audio.ps1`。 `tools/import_original_media.py` 仅恢复共享原片 AVI，`tools/install_campaign_media.mjs` 安装本地高清 MP4。单挑仍按时间段直接播放 LDAN.AVI，无需剪辑或转码。

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

- 新开局按 `scenario.avi`（沿用旧字段名）直接播放对应高清 MP4。读档、`--no-intro`、无媒体包或缺少文件时直接显示关卡简报，不回退低清。
- 事件仍由 `events.json` 映射；事件4没有对应原片，保留文本。读档恢复事件游标而不重播历史。
- 正常首次启动菜单直接播放START.AVI，每进程一次；历史简介按钮播放LISHI.AVI。
- 缺少媒体时跳过或保留文本，不阻塞游戏。

### 4.3 单挑

单挑直接打开LDAN.AVI，依已确定结果在播放时定位原文件片段：共同交锋24–38秒；平局78–87秒；胜负99–106秒及125秒至片尾。没有剪辑、拼接或重新编码文件。姓名字幕对应实际胜方；自然结束和跳过都只执行原有结算一次，读档取消旧世界回调。

## 5. 资源打包

- 13 个共享 AVI 原文件仍随含原媒介包打包；原生解码DLL及其依赖随同一不可变版本发布。发布清单逐个记录DLL哈希，缺失或更改时拒绝切换启动入口。
- 110 个音效 WAV 与 13 首 OGG 随包；12 首原曲 WAV（`media/sfx/record*.wav`、`start.wav`）与 `vend.wav` 只是导出母版，不随包分发，重新导出时由 `tools/export_audio.ps1` 从本地声音输入生成。
- 公开分发时可用 `-NoOriginalMedia` 排除过场视频；缺视频时运行时跳过播放。
- 默认运行集中的原片通过 Git LFS 获取；重新导入用 `tools/import_original_media.py`。解码器的修正源码、依赖锁与重建脚本保存在 `tools/native/avi_decoder/`，MIT/LGPL及运行库说明随包提供。

## 6. 实现对应

| 职责 | 模块 |
|---|---|
| 音乐 | `presentation/audio/bgm.gd` |
| 音效 | `presentation/audio/sfx.gd`、`data/db/audio_index.json` |
| 视频与事件 | `presentation/media/event_view.gd`、`data/db/events.json` |
| 开场选择 | `presentation/battle/view/controller.gd::maybe_play_intro`（由 `battle_view.gd` 转发） |

## 7. 验收要点

- 同一曲目重复调用不重启；无头模式不产生音频错误。
- 攻击音只在击发时播放，且不暴露雾中敌军位置。
- 13 个共享 AVI 与原始目录 SHA256 一致；在640/1280/1920窗口保持原尺寸1:1居中。原生音频采样必须有限、有信号且在正常幅度内；跳过或自然结束恢复模拟。
- 读档不重播已播放的事件。
- `-NoOriginalMedia` 包缺视频时，开场与事件直接跳过，不报错阻塞。

## 本机高清战役视频

34 个战役条目直接使用目录中的 MP4（保留 scenario.avi 旧字段名），不回退到低清战役 AVI。只有关卡开场替换，原作片头、历史介绍、战中事件和单挑仍保持原文件。缺少本地高清资源时显示关卡简报，不阻塞开局。

提供已经校验的一集一个 MP4 的本地目录，然后运行 node tools/install_campaign_media.mjs <本地目录>。安装工具按 video_catalog.json 校验长度与 SHA256，不下载、不覆盖不匹配文件。高清文件放在 godot/chibi_remake/media/videos/，不纳入 Git；原作共享 AVI 可按目录校验从原片重新安装。显式使用 -NoPublish -IncludeLocalCampaignMedia 才会将已校验的高清素材纳入本机候选，默认分发包不纳入未再授权的高清素材；-NoOriginalMedia 同时排除高清 MP4 和共享 AVI（以及原作音频）。含本地高清的构建清单会标记私有媒体，分卷/分发入口拒绝该版本。未经授权不得另行分发本地高清素材。
