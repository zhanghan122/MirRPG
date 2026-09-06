# PROJECT_STATUS — MirRPG 项目状态 / 稳定基线

> 本文件记录当前版本的实现范围、验证结果与冻结模块。
> 帧结构唯一事实来源：`HUM_FRAME_RULES.md`；代码事实来源：`scripts/hum_frames.gd`、`scripts/hum_character.gd`。

## 1. 当前版本状态

- **版本**：v1.0-stable（稳定基线 / Stable Baseline）
- **日期**：2026-09-06
- **引擎**：Godot 4.7.2-stable win64 console（`Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe`）
- **范围**：0–599 套内帧结构 × 24 套外观，8 方向 Idle / Walk / Run + 全部 11 个动作。
- **验证结论**：headless 编辑器检查无错误；`test_scene` 与 `appearance_gallery` 运行时 headless 无 Parse / Script / 资源路径错误；24 套外观及全部动作已实机测试通过。

## 2. 实现内容（已完成并验证）

| 模块 | 说明 |
| --- | --- |
| 帧数据 `hum_frames.gd` | Autoload `HumFrames`，11 动作 × 8 方向精确数组（与 `HUM_FRAME_RULES.md` 完全一致），`appearance_base = appearance_id * 600`。 |
| 人物模板 `hum_character.tscn/.gd` | CharacterBody2D + SpriteAnchor + AnimatedSprite2D(centered=false) + WeaponLayer；WASD/方向键移动，Shift/Space=Run。 |
| 8 方向映射 | n/ne/e/se/s/sw/w/nw（含对角），符号法判定，切换立即生效。 |
| Idle / Walk / Run | 循环动画；无输入回 `idle_<last_dir>`；Walk 200px/s、Run 360px/s。 |
| 全部动作状态机 | pose/attack_onehand/attack_twohand/attack_power/cast/dig/hit/death（非循环，`animation_finished` 结束）；播放期锁定移动/转向；死亡永久锁定，R 复活。 |
| Placement 读取与缓存 | `res://Hum/Placements/%05d.txt`，第一行 X / 第二行 Y；`_ready` 一次性预加载并缓存（绝对索引为键），运行期只查缓存，禁止每帧读盘。 |
| SpriteAnchor Offset | 偏移仅赋值到 `SpriteAnchor.position`；不改 CharacterBody2D/碰撞体/Camera2D。 |
| 24 套 appearance_base | `characters/presets/HumAppearance01..24.tscn`，appearance_id=0..23（基址 0,600,…,13800）。 |
| Gallery 预览 | `scenes/appearance_gallery.tscn`：实例化全部 24 套预设，←/→ 或 [ ] / , . 切换，显示外观名与当前帧信息。 |

## 3. 资产清单（实测）

- 帧空间：每套 600 个原始索引；总空间 = 24 × 600 = **14400**（绝对索引 0–14399）。
- 单套实际使用帧：**416** 个不同本地索引
  （idle 32 / walk 48 / run 48 / pose 8 / attack_onehand 48 / attack_twohand 48 / attack_power 64 / cast 48 / dig 16 / hit 24 / death 32）。
- PNG：`res://Hum/*.png` 共 **9984** 个（= 24 × 416，即全部“被使用”的帧；索引范围 0–14395，其余为套内保留空位）。
- Placement：`res://Hum/Placements/*.txt` 共 **14400** 个（完整覆盖 0–14399）。

## 4. 冻结模块（不得重构）

以下模块自本基线起正式冻结。后续开发**不得重构、重排或改动**其内部实现，只能通过第 5 节的模板接口调用：

- `HUM_FRAME_RULES`（帧结构唯一事实来源）
- 八方向映射（n/ne/e/se/s/sw/w/nw + 符号法判定）
- Idle、Walk、Run（循环动画与速度 / 回 idle 逻辑）
- 全部动作状态机（11 动作的播放 / 锁定 / 结束 / 死亡复活）
- Placement 读取和缓存（预加载 + 绝对索引缓存键，禁止每帧读盘）
- SpriteAnchor Offset（偏移唯一目标 = `SpriteAnchor.position`）
- 24 套 appearance_base（appearance_id × 600 基址映射与预设）
- Gallery 预览（`appearance_gallery.tscn/.gd`）

## 5. 模板接口（后续开发只能通过这些调用）

**帧数据 Autoload `HumFrames`（`scripts/hum_frames.gd`）**
- 常量：`HUM_ACTIONS`、`DIRECTIONS`、`ALL_ACTIONS`、`BUILT_ACTIONS`
- `set_appearance(appearance_id: int)` — 设置基址（= id × 600）
- `abs_index(local_idx) -> int`；`png_path(abs_idx) -> String`；`placement_path(abs_idx) -> String`
- `local_frames(action, direction) -> Array`；`built_local_indices() -> Array[int]`；`all_action_names() -> Array[String]`；`all_local_indices() -> Array[int]`

**人物模板（实例化预设场景即可，勿改内部实现）**
- 导出参数：`appearance_id: int`、`preset_name: String`、`weapon_enabled: bool`（`appearance_base` 由 `_ready()` 计算）
- `play_directional_action(action_name: StringName)` — 朝当前朝向播放某动作
- `get_frame_info() -> Dictionary` — 返回当前帧诊断信息
- 内置按键：WASD/方向键移动，Shift/Space=Run；J/K/L/U/I/P/H/Y/R=各动作，R=死亡复活；F1–F4=调试

**新增外观 / 预设的正确做法**
- 继承 `scenes/hum_character.tscn` → 保存为 `characters/presets/<name>.tscn` → 覆盖 `appearance_id`（0–23）与 `weapon_enabled`。不复制动作表、不改 `hum_frames.gd`。

## 6. 运行 / 验证命令

- 测试场景（WASD + 方向键，Shift 跑步）：
  `"Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" res://scenes/test_scene.tscn`
- 外观画廊（←/→ 切换 24 套）：
  `"Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" res://scenes/appearance_gallery.tscn`
- Headless 校验（解析 / 场景 / 资源路径错误）：
  `"Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" --headless --editor --quit`

## 7. 相关文档

- `HUM_FRAME_RULES.md` — 帧结构唯一事实来源（0–599 套内精确数组）。
- `CHARACTER_TEMPLATE.md` — 人物模板与预设派生说明。
- `MOVEMENT_OFFSET_BASELINE.md` — 移动 / Offset 冻结参照基线。
