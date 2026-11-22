## 美术资源

`full` 是运行时成品素材，`production` 是制作这些素材的过程数据与参考输入。

|              | `art/full/`                                                  | `art/production/`                            |
| ------------ | ------------------------------------------------------------ | -------------------------------------------- |
| 角色         | 游戏实际加载、打包的高清素材                                 | 美术生产契约、提示词、交付记录、参考图       |
| 谁在用       | 运行时 `full_art_catalog.gd`、`stage_release.mjs`、发布包    | 美术工具、审计脚本、人工追溯；**运行时不读** |
| 是否进发布包 | 是，按 `full/manifest.json` 选择打包                         | 否                                           |
| Godot 导入   | 是（图集、头像、地形块、UI 都是资源）                        | 否，目录内有 `.gdignore`                     |
| 体积/文件数  | 12.2 GB / 72,863 个文件                                      | 24.2 MB / 913 个文件                         |
| Git          | 绝大部分不入 Git；只跟踪少量 UI 母版、城门地形、清单/着色器（154 个） | 912 个文件随 Git 维护                        |
| 丢失后果     | 母版不可再生，只能从备份恢复                                 | 可从 Git 恢复；不影响游戏运行                |

## 典型内容

**`art/full/`：成品**

```
art/full/
├── units/032/page-00-v1.png          兵种图集（运行时帧表引用）
├── officers/000-portrait-v2.png      武将头像
├── terrain_chunks/chibic1/*.jpg      地图分块（流式加载）
├── backgrounds/bmp-054-v1.png        主菜单书桌
├── ui/                               HUD、命令图标、光标
├── manifest.json                     ID → 纹理/帧/锚点 的运行清单
└── team_palette.json                 阵营色
```

**`art/production/`：配方与档案**

```
art/production/
├── catalog.json                素材契约：ID、帧、锚点、来源、验收状态
├── coverage.json               3028 个银行帧的覆盖/交付记录
├── *-prompts*.json             各批次绘制提示词
├── deliveries/                 每项素材的生成源、尺寸、SHA-256
├── references/                 538 张原图参考/截图（重绘输入）
└── *-contract.json             动画、调色板、阵营色等专项契约
```

## 关系

```
references/ + 提示词/契约
        │  重绘、装配、验收
        ▼
art/full/  ── manifest.json ──►  运行时加载 / 发布包
        ▲
deliveries/ 记录每项成品的来源、哈希与验收
```

- `production` 回答“这张图从哪来、按什么规格画、验收没有”；
- `full` 回答“游戏运行时到底加载哪张图、哪一帧、锚点在哪”。

因此之前把 `docs/art` 移到 `art/production` 是归位：它属于美术生产数据；而 `art/full` 保持为唯一运行素材目录。