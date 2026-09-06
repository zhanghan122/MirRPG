# MirRPG 项目指令

## Hum 人物动画

处理人物动画前，必须完整读取：

HUM_FRAME_RULES.md

该文件是 Hum 人物套内 0-599 帧结构的唯一事实来源。

必须遵守：

- 不得扫描 PNG 来重新推断动作结构。
- 不得根据 PNG 尺寸猜测方向或帧数。
- 不得重新编号、删除、移动或覆盖 Hum 原始素材。
- 必须使用 HUM_FRAME_RULES.md 中的精确动作数组。
- 必须保留 Godot 动画帧到原始 Hum 索引的映射。
- Placement 第一行是 X，第二行是 Y。
- Placement 必须预加载并缓存，禁止每帧读取磁盘。
- 修改完成后必须运行 Godot headless 检查。