# MOVEMENT_OFFSET_BASELINE（修改前基线）

本文件在**任何代码改动之前**记录当前已验证正确的移动与 Offset 实现，作为后续动作开发的冻结参照。
事实来源：`HUM_FRAME_RULES.md`、`scripts/hum_frames.gd`、`scripts/hum_character.gd`。

## 1. 方向输入映射（player.gd `_input_dir()`）
- A / KEY_LEFT → x -= 1
- D / KEY_RIGHT → x += 1
- W / KEY_UP → y -= 1
- S / KEY_DOWN → y += 1
- 长度 > 1 时归一化（`v.length() > 1.0 → v = v.normalized()`）
- Shift 或 Space = Run（`_run_held()`：KEY_SHIFT 或 KEY_SPACE）

## 2. 方向判定（player.gd `_direction_from_vector()`，规则一符号法）
- `dx = (v.x > 0.5) ? 1 : (v.x < -0.5) ? -1 : 0`；`dy` 同理。
- (0,-1)=n, (1,-1)=ne, (1,0)=e, (1,1)=se, (0,1)=s, (-1,1)=sw, (-1,0)=w, (-1,-1)=nw

## 3. Idle / Walk / Run 动画选择
- `_physics_process()`：`input_dir != ZERO` → `current_action = Run(若按住Shift) else Walk`，调用 `_update_continuous(input_dir)`；否则 `velocity=ZERO`、`move_and_slide()`，且当 `current_action != Idle` 时切回 `idle_<last_direction>`。
- `_update_continuous(v)`：`_direction_from_vector(v)` → `_play("<walk|run>_<dir>")`。
- 动画名格式：`<action>_<direction>`（如 walk_e、run_ne、idle_s）。

## 4. appearance_base 计算方式
- `hum_frames.set_appearance(0)`；`appearance_id = 0`（本轮固定，不切换外观）。
- `appearance_base = appearance_id * 600 = 0`。绝对索引 = `appearance_base + local_index`。

## 5. Godot 动画帧 → 原始 Hum 索引映射
- `_rebuild_sprite_frames()` 为每个 `<action>_<dir>` 建立 `_animation_source_indices[anim_name] = [local_idx...]`（按 Godot 帧顺序）。
- 某 Godot 帧 `fi`：`local_idx = _animation_source_indices[anim_name][fi]`；`abs_idx = appearance_base + local_idx`；PNG = `res://Hum/%05d.png % abs_idx`。

## 6. Placement TXT 读取方式（player.gd `_read_placement()`）
- 路径：`res://Hum/Placements/%05d.txt % abs_idx`。
- **第一行 = X，第二行 = Y**；用 `split(",")[0]` 容错 "X,Y" 格式。
- 文件不存在 / 空 → `Vector2.ZERO`（不崩溃）。

## 7. Placement 缓存键
- `_placement_cache[abs_idx]`，其中 `abs_idx = appearance_base + local_index`（**绝对索引**为键）。
- `_preload_placements()` 在 `_ready` 一次性预加载全部已构建动作帧的 Placement；运行期只查缓存，**禁止每帧读盘**。

## 8. Placement 最终应用到哪个节点
- `SpriteAnchor.position = Vector2(x, y)`（AnimatedSprite2D 的父 Node2D）。
- **不**改 CharacterBody2D、碰撞体、Camera2D。

## 9. AnimatedSprite2D 设置
- `centered=false`、`position=Vector2.ZERO`、`offset=Vector2.ZERO`、`flip_h=false`、`scale=ONE`（见 player.tscn）。

## 10. Player 节点结构（scenes/hum_character.tscn）
```
CharacterBody2D (player)
├── SpriteAnchor (Node2D)          ← Placement 应用到这里
│   └── AnimatedSprite2D           ← centered=false, offset=ZERO
├── CollisionShape2D               ← RectangleShape2D 48x64
├── Camera2D                       ← position(0,-96), zoom(1.5)
└── DebugCanvasLayer
    └── DebugLabel (Label)         ← F4 诊断
```

## 11. 当前正常工作的脚本与函数
- `scripts/hum_frames.gd`（Autoload `HumFrames`）：`HUM_ACTIONS`(11动作×8方向)、`DIRECTIONS`、`ALL_ACTIONS`、`BUILT_ACTIONS`、`set_appearance`、`abs_index`、`png_path`、`placement_path`、`local_frames`、`built_local_indices`、`all_action_names`、`all_local_indices`。
- `scripts/hum_character.gd`：`_ready`、`_rebuild_sprite_frames`、`_preload_placements`、`_play`、`_physics_process`、`_input_dir`、`_run_held`、`_update_continuous`、`_direction_from_vector`、`_on_frame_changed`、`_apply_current_offset`、`_read_placement`、`_unhandled_key_input`(F1-F4)、`_process`、`_build_diag_text`。

## 12. 冻结项（后续动作开发不得改动）
- WASD/方向键输入映射；Idle/Walk/Run 选择逻辑；appearance_base 计算；
- `_animation_source_indices` 基础结构；Placement 读取与缓存逻辑；frame_changed Offset 应用；
- `SpriteAnchor.position` 作为唯一 Offset 目标；AnimatedSprite2D 的 centered/position/offset/flip_h。
