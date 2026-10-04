extends Node

# Mon1Frames Autoload: Mon1 怪物帧结构唯一事实来源（mapping 数据，与播放代码分离）。
# 森林怪人 00280-00547 的映射已按实际 PNG 存在性与空白槽分布验证，见 MON1_FRAME_RULES.md。
# 禁止扫描 PNG 重新推断动作边界；必须直接使用下面的精确数组。

const DIRECTIONS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

# 森林怪人（00280-00547，共 176 张有效帧）
# 槽位规则：F>=3 的动作每方向占 8 个槽（stride=8，与 Hum 一致）；
#           F=2 的 struck 为连续对（stride=2，与 Hum dig/pose 先例一致）。
const FOREST_STRANGER_ACTIONS := {
	"idle": {"fps": 6.0, "loop": true, "frames_per_direction": 4, "frames": {
		"n": [280, 281, 282, 283], "ne": [288, 289, 290, 291], "e": [296, 297, 298, 299], "se": [304, 305, 306, 307],
		"s": [312, 313, 314, 315], "sw": [320, 321, 322, 323], "w": [328, 329, 330, 331], "nw": [336, 337, 338, 339]}},
	"walk": {"fps": 10.0, "loop": true, "frames_per_direction": 6, "frames": {
		"n": [344, 345, 346, 347, 348, 349], "ne": [352, 353, 354, 355, 356, 357],
		"e": [360, 361, 362, 363, 364, 365], "se": [368, 369, 370, 371, 372, 373],
		"s": [376, 377, 378, 379, 380, 381], "sw": [384, 385, 386, 387, 388, 389],
		"w": [392, 393, 394, 395, 396, 397], "nw": [400, 401, 402, 403, 404, 405]}},
	"attack": {"fps": 10.0, "loop": false, "frames_per_direction": 6, "frames": {
		"n": [408, 409, 410, 411, 412, 413], "ne": [416, 417, 418, 419, 420, 421],
		"e": [424, 425, 426, 427, 428, 429], "se": [432, 433, 434, 435, 436, 437],
		"s": [440, 441, 442, 443, 444, 445], "sw": [448, 449, 450, 451, 452, 453],
		"w": [456, 457, 458, 459, 460, 461], "nw": [464, 465, 466, 467, 468, 469]}},
	"struck": {"fps": 8.0, "loop": false, "frames_per_direction": 2, "frames": {
		"n": [472, 473], "ne": [474, 475], "e": [476, 477], "se": [478, 479],
		"s": [480, 481], "sw": [482, 483], "w": [484, 485], "nw": [486, 487]}},
	"death": {"fps": 8.0, "loop": false, "frames_per_direction": 4, "frames": {
		"n": [488, 489, 490, 491], "ne": [496, 497, 498, 499], "e": [504, 505, 506, 507],
		"se": [512, 513, 514, 515], "s": [520, 521, 522, 523], "sw": [528, 529, 530, 531],
		"w": [536, 537, 538, 539], "nw": [544, 545, 546, 547]}},
}

const FOREST_STRANGER_ACTION_ORDER := ["idle", "walk", "attack", "struck", "death"]

# 怪物注册表。
# death_behavior:
#   "stay_last_frame" — 有死亡动画；播放结束后停留在最后一帧（森林怪人）。
#   "disappear"       — 无死亡动画；收到死亡事件时直接隐藏/移除 Sprite，不生成假死亡帧（未来守卫）。
const MONSTERS := {
	"forest_stranger": {
		"display_name": "森林怪人",
		"range_start": 280,
		"range_end": 547,
		"actions": FOREST_STRANGER_ACTIONS,
		"action_order": FOREST_STRANGER_ACTION_ORDER,
		"death_behavior": "stay_last_frame",
	},
	# TODO(guard): 守卫 00000-00189 缺少死亡动画，本次不实现。未来接入时使用：
	#   "guard": {
	#       "display_name": "守卫",
	#       "range_start": 0,
	#       "range_end": 189,
	#       "actions": {...},          # idle/walk/attack 等，无 death
	#       "action_order": [...],
	#       "death_behavior": "disappear",
	#   },
}


func png_path(idx: int) -> String:
	return "res://Mon1/%05d.png" % idx


func placement_path(idx: int) -> String:
	return "res://Mon1/Placements/%05d.txt" % idx


func monster_actions(monster_id: String) -> Dictionary:
	var m: Dictionary = MONSTERS.get(monster_id, {})
	return (m.get("actions", {}) as Dictionary).duplicate(false)


func action_order(monster_id: String) -> Array:
	var m: Dictionary = MONSTERS.get(monster_id, {})
	return (m.get("action_order", []) as Array).duplicate()


func death_behavior(monster_id: String) -> String:
	var m: Dictionary = MONSTERS.get(monster_id, {})
	return str(m.get("death_behavior", "stay_last_frame"))


func display_name(monster_id: String) -> String:
	var m: Dictionary = MONSTERS.get(monster_id, {})
	return str(m.get("display_name", monster_id))


# 该怪物全部有效帧的原始索引（去重，按动作/方向顺序）。
func all_indices(monster_id: String) -> Array:
	var seen := {}
	var out := []
	for action in action_order(monster_id):
		var actions := monster_actions(monster_id)
		if not actions.has(action):
			continue
		var spec: Dictionary = actions[action]
		for dir in DIRECTIONS:
			for idx in (spec["frames"] as Dictionary)[dir]:
				if not seen.has(idx):
					seen[idx] = true
					out.append(int(idx))
	return out
