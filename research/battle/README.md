# 原版《赤壁》对战模式

> 目标：`CB.EXE` SHA-256 `2db7cc102e6fde547ab05d77cfddabc2079f5bc9be9b6b59b17bf435c5798cb7`。  
> 仅以原版二进制与 `SET/M_*.EXP` 菜单资源静态分析为准；`docs/` 和重制实现只用于差异对照。

## 0. 结论

**原版主菜单第三项确实叫「对战模式」，但在本 `CB.EXE` 中没有可玩功能。**

- 主菜单资源 `M_MAIN.EXP` 第三项：**frame 273 / command 21000**。
- 菜单命令处理函数 `FUN_00409d70` 中，21000 被一个**没有 else 的取反分支**排除：

```c
else if (param_2 < 0x5209) {
    if (param_2 != 21000) {
        // 0x4F1C / 0x4F1D 的网络菜单分支在这里
        ...
    }
    // 21000 直接落到函数返回，没有任何动作
}
```

- 点击「对战模式」**不会加载场景、不会弹提示、不会进入联机菜单**；代码里没有 21000 的 `PostMessage`/`FUN_00405e80` 调用。
- 原版仍保留一套**未接通的多人对战菜单资源**：
  - `M_NET.EXP`：INTERNET连接、网络连接、调制解调器连接、姓名输入、取消；
  - `M_IPX.EXP`：创建战局、加入战局、观看战局、列表/翻页；
  - `M_MODEM.EXP`：拨号、等待拨号；
  - `M_SERIAL.EXP`：创建战局、加入战局。
- 但 `CB.EXE` **没有导入任何网络/串口/TAPI 传输库**：
  - 导入：`KERNEL32`、`USER32`、`GDI32`、`DDRAW`、`DSOUND`、`WINMM`、`IMM32`、`AVIFIL32`、`MSVFW32`；
  - 没有 Winsock、IPX、TAPI、COMM 等。
- 因此它不是“隐藏的联网模式”，也不是本地 AI 遭遇战/热座；**是保留的按钮和未完成的多人 UI 设计**。

> 这与 `docs/` 的“对战模式暂未开放”方向一致，但原版没有找到“暂未开放”提示；原版更像**死按钮/空处理**。重制版若显示提示，是重制新增行为。

## 1. 主菜单资源与第三项

### 1.1 M_*.EXP 的编码

`M_MAIN.EXP` / `M_NET.EXP` 等是 **XOR 0x22 的 ASCII 菜单布局脚本**：

- `FUN_0041ba50` 打开文件；
- `FUN_0041bb20` 逐字节 `xor 0x22` 解码；
- 解码后是空格/制表符分隔的数字记录（位置、按钮帧、命令 ID）。

`M_MAIN.EXP` 解码后的开头：

```text
207 252 225 190 171 207 252 225 30 20100
53 207 292 225 30 20200
273 207 332 225 30 21000
29 207 372 225 30 26000
26 207 412 225 30 27000
```

前五项菜单按钮：

| # | 标签 | frame | command | 位置（x,y,w,h） |
|---:|---|---:|---:|---|
| 0 | 开始游戏 | 171 | 20100 | 207,252,225,30 |
| 1 | 读取进度 | 53 | 20200 | 207,292,225,30 |
| 2 | **对战模式** | **273** | **21000** | **207,332,225,30** |
| 3 | 历史简介 | 29 | 26000 | 207,372,225,30 |
| 4 | 退出游戏 | 26 | 27000 | 207,412,225,30 |

- frame 273 是「对战模式」的按钮帧；
- 完整帧为 **225×120**，包含四态：普通 / 悬停 / 按下 / **灰色禁用**；
- 正常态裁切：`assets/main_menu_battle.png`；
- 四态条带：`assets/main_menu_battle_states.png`；
- 五项目录：`assets/main_menu_items.png`。

### 1.2 代码处理

`FUN_00409d70` 处理主菜单命令。与 21000 相关的位置：

```c
else if (param_2 < 0x5209) {
    if (param_2 != 21000) {
        if (param_2 == 0x4f1c) { ... FUN_00405e80(0x5209,0); ... }
        else {
            if (param_2 != 0x4f1d) { uVar3 = 0; goto LAB_0040a3f4; }
            ...
        }
    }
}
```

- 如果 `param_2 == 21000`，整个内部块跳过；
- 没有 `else`、没有 `PostMessageA`、没有 `FUN_00405e80`；
- 最终返回原值/0，界面不切换。

这就是“按钮存在但无动作”的代码级原因。

## 2. 残留的多人对战菜单

这些文件是原版资源，但**不是从主菜单 21000 可达的路径**；下面按菜单实际标签记录。

### 2.1 M_NET：连接方式

| command | 标签 | frame | 位置 | 素材 |
|---:|---|---:|---|---|
| 24000 | 串口连接（菜单记录；未见可读文字帧） | — | 226,225 | — |
| 25000 | INTERNET连接 | 30 | 39,266,225,30 | `assets/net_internet.png` |
| 22000 | 网络连接 | 10 | 39,306,225,30 | `assets/net_lan.png` |
| 23000 | 调制解调器连接 | 13 | 39,346,225,30 | `assets/net_modem.png` |
| 21010 | 请输入您的姓名 | 14 | 374,239,225,60 | `assets/net_name.png` |
| 21004 | 取消 | 7 | 468,335,126,30 | `assets/net_cancel.png` |

`M_NET` 的加载器是 `FUN_00405e80(0x5209)`（0x5209 = 21001）；但主菜单 21000 没有调用它。代码中的 0x4F1C/0x4F1D 分支才会走这条加载路径，与第三项没有连接。

### 2.2 M_IPX：局域网战局

| command | 标签 | frame | 位置 | 素材 |
|---:|---|---:|---|---|
| 22200 | 创建战局 | 9 | 35,265,225,30 | `assets/ipx_create.png` |
| 22500 | 加入战局 | 11 | 35,305,225,30 | `assets/ipx_join.png` |
| 22800 | 观看战局 | 17 | 35,345,225,30 | `assets/ipx_watch.png` |
| 22110 | 上翻 | 2 | 584,221,23,29 | — |
| 22120 | 下翻 | 1 | 584,343,23,29 | — |
| 22130 | 取消 | 7 | 472,400,126,30 | `assets/ipx_cancel.png` |
| 22111 | 战局列表行 | 50 | 281,216,300,40 | — |

- `M_IPX.EXP` 的加载器是 `FUN_00405e80(0x55f1)`；
- 二进制中 `set\m_ipx.exp` 的引用在 `0x406B52`，所以它不是完全未被引用的文件；
- 但只能从网络菜单 22000 等路径进入，主菜单 21000 没有这条路径。

### 2.3 M_MODEM / M_SERIAL

| 菜单 | command | 标签 | frame | 素材 |
|---|---:|---|---:|---|
| M_MODEM | 23100 | 拨号 | 16 | `assets/modem_dial.png` |
| M_MODEM | 23020 | 等待拨号 | 20 | `assets/modem_wait.png` |
| M_MODEM | 23010 | 取消 | 7 | `assets/modem_cancel.png` |
| M_SERIAL | 24020 | 创建战局 | 9 | `assets/serial_create.png` |
| M_SERIAL | 26070 | 加入战局 | 11 | `assets/serial_join.png` |
| M_SERIAL | 24010 | 取消 | 7 | `assets/serial_cancel.png` |

- `M_MODEM` 加载器：`FUN_00405e80(0x59d9)`；
- `M_SERIAL` 加载器：`FUN_00405e80(0x5dc1)`；
- 两者都需要从 M_NET 的连接方式进入；同样没有从 21000 的直接路径。

## 3. 为什么不是“实际可用的联网模式”

### 3.1 没有传输 API

`CB.EXE` 导入表：

```text
KERNEL32.dll  USER32.dll  GDI32.dll  DDRAW.dll  DSOUND.dll
WINMM.dll     IMM32.dll   AVIFIL32.dll  MSVFW32.dll
```

没有：

- Winsock / `WS2_32` / `WSOCK32`；
- IPX/SPX 接口；
- TAPI / 调制解调器拨号 API；
- 串口通信 API（无 `CreateFile("COMx")`/DCB 配置路径可确认）。

`WINMM` 在这里用于计时/MCI/声音，不是网络传输。

### 3.2 没有主菜单入口

- 21000 → 无动作；
- 网络菜单的 `0x4F1C/0x4F1D` 分支存在，但不是 21000；
- `M_IPX`、`M_MODEM`、`M_SERIAL` 的加载器只在网络菜单命令链里出现；
- 没有找到从主菜单第三项到这些菜单的 `PostMessage` 或 `FUN_00405e80` 调用。

### 3.3 结论边界

- **可玩性**：没有可玩的原版对战模式。
- **资源**：有原版多人对战菜单素材和残留代码路径。
- **本地替代**：没有发现 AI 遭遇战/热座模式入口；不能把战役模式当作对战模式。
- **重制**：docs 说“对战模式暂未开放”方向正确；如果重制显示提示/占位，是重制行为；若要实现，必须新建玩法，不应声称还原原版联网。

## 4. 素材

| 文件 | 内容 |
|---|---|
| `assets/main_menu_items.png` | 主菜单五项目录（开始游戏/读取进度/对战模式/历史简介/退出游戏） |
| `assets/main_menu_battle.png` | 「对战模式」正常态按钮 |
| `assets/main_menu_battle_states.png` | 「对战模式」四态条带（含灰色禁用） |
| `assets/net_*.png` | INTERNET连接、网络连接、调制解调器连接、姓名、取消 |
| `assets/ipx_*.png` | 创建/加入/观看战局、取消 |
| `assets/modem_*.png` | 拨号/等待拨号/取消 |
| `assets/serial_*.png` | 创建/加入战局、取消 |
| `assets/battle_mode_flow.svg` | 主菜单死链与残留多人菜单关系图 |

按钮素材来自 `BMP.LWC` 帧，使用 `RES/MAINBACK.PAL`，裁切第一态（普通态）；完整四态条带保留在 `main_menu_battle_states.png`。

## 5. 与 docs/重制版对照

| 主题 | docs/重制 | 原版 |
|---|---|---|
| 主菜单第三项 | 保留入口，点击提示暂未开放 | 保留按钮；命令 21000 无处理动作，没有找到提示 |
| 多人/联网 | 明确无 | 有残留菜单资源，但没有传输 API 与主菜单入口 |
| 本地对战/遭遇战 | 无 | 未发现 AI 遭遇战/热座入口 |
| 结论 | 不提供对战模式 | **不可玩；不是隐藏模式** |

## 6. 证据

| 结论 | 位置/函数 | Evidence |
|---|---|---|
| 菜单文件 XOR 0x22 | `FUN_0041bb20` | `ev_d0731b4f…` |
| 菜单文件读取 | `FUN_0041ba50` | `ev_7873f82d…` |
| 主菜单 21000 空分支 | `FUN_00409d70`，`if (param_2 != 21000)` 无 else | 0x409D70 |
| M_NET 加载 | `FUN_00405e80(0x5209)` | 0x405E80 |
| M_IPX 加载/引用 | `FUN_00405e80(0x55f1)`；`0x406B52` | `ev_d72adfe1…` |
| M_MODEM 加载 | `FUN_00405e80(0x59d9)` | 0x405E80 |
| M_SERIAL 加载 | `FUN_00405e80(0x5dc1)` | 0x405E80 |
| 导入表无网络 | PE imports | 见 `data/battle.json` |
| 菜单文件哈希 | `data/menus.json` | M_MAIN/M_NET/M_IPX/... |

`data/menus.json` 保存每个 `M_*.EXP` 的原始哈希、XOR 后完整文本和 token 数组。

## 7. 文件

- `README.md`（本文件）
- `index.html`
- `data/battle.json`：主菜单、21000 空分支、残留网络菜单、导入、证据
- `data/menus.json`：M_*.EXP 解码文本与哈希
- `data/battle.csv`：平表
- `data/assets.json`：素材索引
- `assets/main_menu_battle.png` / `main_menu_battle_states.png` / `main_menu_items.png`
- `assets/net_*.png`、`ipx_*.png`、`modem_*.png`、`serial_*.png`
- `assets/battle_mode_flow.svg`
- `tools/extract_battle_mode.mjs`：解码菜单、生成数据/流程图
- `tools/extract_battle_menu_icons.py`：裁切原版按钮帧

## 8. 限制

- 未运行原版逐帧点击验证；结论来自静态代码与菜单资源。
- 主菜单按钮位置来自 `M_MAIN.EXP` token 解析；按钮帧标签由原始 `BMP.LWC` 图像直接读取。
- 网络菜单的 command→文案映射由菜单 token 与按钮帧图像交叉确认；M_NET 的 24000 记录未读到可读文字帧，标为“串口连接（记录）”。
- 未发现网络 API 不等于绝对不会调用外部 DLL；但导入表与代码字符串中均没有网络/串口传输路径。
- 没有修改任何重制玩法代码。
