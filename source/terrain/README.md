# 可重建地形源输入

`index.json` 和 34 个关卡 JSON 保存原 MED 的层序、图块编号及几何。`paint/` 为 14 张重绘源图集，`masks/` 为原始几何透明掩码，PNG 通过 Git LFS 保存。`catalog.json`、`mapping.json` 保存图块边界和图集映射；`inputs.json` 声明构建所需 65 个输入的哈希。

从项目根执行 `node tools/build_terrain.mjs`，缺失或改变的输入会导致构建失败。缓存位于 `_work/terrain/`，键包含源内容、地图层数据、烘焙器代码、Godot 版本及编码参数。整图和 LOD/传输分块均为派生物，不提交 Git。`--dev` 将当前生成的资源连接到开发工程的受忽略目录。

修改源图或导入关卡后，审阅变更并执行 `node tools/terrain_sources.mjs --write` 更新哈希。导入 MED 的入口为 `tools/hd/remaster_map_sources.mjs --meds <目录> --set <目录>`。构建不需要原光盘文件，也不下载派生资产包。

`README.md` 是维护说明，不是烘焙输入。删除 Git 跟踪的派生物不会改写 Git/LFS 历史，也不会删除本地派生文件。
