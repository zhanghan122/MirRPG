# CHARACTER_TEMPLATE.md — Hum 人物模板说明

本文件描述由 `scenes/hum_character.tscn` + `scripts/hum_character.gd` 构成的可复用人物模板，以及如何派生具体预设（如 `base_male_no_weapon`）。

> **当前版本 = v1.0-stable 稳定基线**（2026-09-06）：24 套外观 × 8 方向 Idle/Walk/Run + 全部 11 个动作已实机验证通过。
> 冻结模块清单与“只能经模板接口调用”的约束见 `PROJECT_STATUS.md`（第 4、5 节）。后续开发**不得重构**冻结模块，只能通过已有模板接口调用。

## 1. 目录结构

```
scripts/
  hum_frames.gd          # Hum 帧数据（唯一事实来源：HUM_FRAME_RULES.md），禁止改动动作数组
  hum_character.gd       # 人物模板脚本（移动 / 方向 / 动画 / 状态锁定 / 外观切换）
  appearance_gallery.gd  # 24 套外观画廊预览逻辑
scenes/
  hum_character.tscn     # 人物模板场景（CharacterBody2D + SpriteAnchor + WeaponLayer ...）
  base_male_no_weapon.tscn   # 预设：继承模板，appearance_id=0, weapon_enabled=false
  test_scene.tscn        # WASD / 方向键测试场景（实例化当前预设）
  appearance_gallery.tscn    # 24 套外观画廊预览（←/→ 切换）
characters/presets/
  HumAppearance01..24.tscn   # 24 套外观预设，appearance_id=0..23, weapon_enabled=false
```

## 2. 外观切换机制

- `hum_character.gd` 暴露两个导出参数：
  - `@export var appearance_id: int = 0`
  - `@export var weapon_enabled: bool = false`
- `_ready()` 中计算 `appearance_base = appearance_id * 600`，并调用 `hum_frames.set_appearance(appearance_id)`。
- 帧选择完全由 `appearance_base` 驱动（见 `hum_character.gd` 的 `_rebuild_sprite_frames` / `_preload_placements` / `_apply_current_offset`）：
  - PNG：`res://Hum/%05d.png % (appearance_base + local_idx)`
  - Placement：`res://Hum/Placements/%05d.txt % (appearance_base + local_idx)`
- 切换外观 = 只改 `appearance_id`（或派生预设时覆盖该属性），**不复制动作表、不改 `hum_frames.gd`**。

## 3. 武器图层

- 模板场景在 `SpriteAnchor` 下保留一个可开关节点：`WeaponLayer`（Node2D，默认 `visible=false`）。
- 由导出参数 `weapon_enabled` 控制显隐（`_ready()` 中设置）。
- 后续接入武器时，把武器 Sprite / AnimatedSprite 挂到 `WeaponLayer` 下即可自动跟随身体锚点偏移。

## 4. 如何创建新预设

1. Godot 编辑器：右键 `scenes/hum_character.tscn` → **Inherit Scene**（继承场景）。
2. 保存为 `scenes/<preset_name>.tscn`。
3. 在检查器里覆盖根节点属性：
   - `appearance_id` = 目标外观编号（0-599 套内为 0；其它套按 ×600 基址）
   - `weapon_enabled` = true / false
4. （可选）把该预设实例化到测试场景或正式场景。

示例：`base_male_no_weapon.tscn` 即 `appearance_id=0`、`weapon_enabled=false` 的继承预设。

## 5. 已验证逻辑（禁止改动）

以下行为已在 headless 下验证通过，模板与所有预设必须保持，详见 `MOVEMENT_OFFSET_BASELINE.md`：

- 移动：WASD + 方向键；Shift=Run(360px/s)，否则 Walk(200px/s)；无输入=Idle。
- 8 方向判定（含对角），方向切换立即生效。
- 动画帧映射、Placement 偏移（X/Y）、SpriteAnchor 锚点逻辑。
- 状态锁定：动作播放期间锁定移动/转向，播完回 Idle；死亡后永久锁定，R 键复活。
- 全部 11 个动作（idle/walk/run/pose/attack_onehand/attack_twohand/attack_power/cast/dig/hit/death）与按键映射。

帧结构唯一事实来源：`HUM_FRAME_RULES.md`。禁止扫描 PNG 重新推断、禁止改动原始素材。

## 6. 运行 / 验证

- 测试场景（WASD + 方向键，Shift 跑步）：
  `"Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" res://scenes/test_scene.tscn`
- Headless 校验（解析 / 场景 / 资源路径错误）：
  `"Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" --headless --editor --quit`

## 7. 调试快捷键（hum_character.gd）

- F1 显示/隐藏 DebugLabel；F2 强制 Idle；F3 强制 Walk(南)；F4 强制 Run(南)。
- J/K/L/U/I/P/H/Y/R = 各动作；R 同时用于死亡复活。
