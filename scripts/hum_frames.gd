extends Node

# HumFrames Autoload: 0-599 帧结构的唯一事实来源。
# 禁止改动动作数组、方向顺序或 appearance_base 计算方式。

const HUM_ACTIONS := {
	"idle": {"fps": 5.0, "loop": true, "frames": {
		"n": [0, 1, 2, 3], "ne": [8, 9, 10, 11], "e": [16, 17, 18, 19], "se": [24, 25, 26, 27],
		"s": [32, 33, 34, 35], "sw": [40, 41, 42, 43], "w": [48, 49, 50, 51], "nw": [56, 57, 58, 59]}},
	"walk": {"fps": 8.0, "loop": true, "frames": {
		"n": [64, 65, 66, 67, 68, 69], "ne": [72, 73, 74, 75, 76, 77], "e": [80, 81, 82, 83, 84, 85],
		"se": [88, 89, 90, 91, 92, 93], "s": [96, 97, 98, 99, 100, 101], "sw": [104, 105, 106, 107, 108, 109],
		"w": [112, 113, 114, 115, 116, 117], "nw": [120, 121, 122, 123, 124, 125]}},
	"run": {"fps": 10.0, "loop": true, "frames": {
		"n": [128, 129, 130, 131, 132, 133], "ne": [136, 137, 138, 139, 140, 141],
		"e": [144, 145, 146, 147, 148, 149], "se": [152, 153, 154, 155, 156, 157],
		"s": [160, 161, 162, 163, 164, 165], "sw": [168, 169, 170, 171, 172, 173],
		"w": [176, 177, 178, 179, 180, 181], "nw": [184, 185, 186, 187, 188, 189]}},
	"pose": {"fps": 5.0, "loop": false, "frames": {
		"n": [192], "ne": [193], "e": [194], "se": [195], "s": [196], "sw": [197], "w": [198], "nw": [199]}},
	"attack_onehand": {"fps": 10.0, "loop": false, "frames": {
		"n": [200, 201, 202, 203, 204, 205], "ne": [208, 209, 210, 211, 212, 213],
		"e": [216, 217, 218, 219, 220, 221], "se": [224, 225, 226, 227, 228, 229],
		"s": [232, 233, 234, 235, 236, 237], "sw": [240, 241, 242, 243, 244, 245],
		"w": [248, 249, 250, 251, 252, 253], "nw": [256, 257, 258, 259, 260, 261]}},
	"attack_twohand": {"fps": 10.0, "loop": false, "frames": {
		"n": [264, 265, 266, 267, 268, 269], "ne": [272, 273, 274, 275, 276, 277],
		"e": [280, 281, 282, 283, 284, 285], "se": [288, 289, 290, 291, 292, 293],
		"s": [296, 297, 298, 299, 300, 301], "sw": [304, 305, 306, 307, 308, 309],
		"w": [312, 313, 314, 315, 316, 317], "nw": [320, 321, 322, 323, 324, 325]}},
	"attack_power": {"fps": 12.0, "loop": false, "frames": {
		"n": [328, 329, 330, 331, 332, 333, 334, 335], "ne": [336, 337, 338, 339, 340, 341, 342, 343],
		"e": [344, 345, 346, 347, 348, 349, 350, 351], "se": [352, 353, 354, 355, 356, 357, 358, 359],
		"s": [360, 361, 362, 363, 364, 365, 366, 367], "sw": [368, 369, 370, 371, 372, 373, 374, 375],
		"w": [376, 377, 378, 379, 380, 381, 382, 383], "nw": [384, 385, 386, 387, 388, 389, 390, 391]}},
	"cast": {"fps": 10.0, "loop": false, "frames": {
		"n": [392, 393, 394, 395, 396, 397], "ne": [400, 401, 402, 403, 404, 405],
		"e": [408, 409, 410, 411, 412, 413], "se": [416, 417, 418, 419, 420, 421],
		"s": [424, 425, 426, 427, 428, 429], "sw": [432, 433, 434, 435, 436, 437],
		"w": [440, 441, 442, 443, 444, 445], "nw": [448, 449, 450, 451, 452, 453]}},
	"dig": {"fps": 8.0, "loop": false, "frames": {
		"n": [456, 457], "ne": [458, 459], "e": [460, 461], "se": [462, 463],
		"s": [464, 465], "sw": [466, 467], "w": [468, 469], "nw": [470, 471]}},
	"hit": {"fps": 10.0, "loop": false, "frames": {
		"n": [472, 473, 474], "ne": [480, 481, 482], "e": [488, 489, 490], "se": [496, 497, 498],
		"s": [504, 505, 506], "sw": [512, 513, 514], "w": [520, 521, 522], "nw": [528, 529, 530]}},
	"death": {"fps": 6.0, "loop": false, "frames": {
		"n": [536, 537, 538, 539], "ne": [544, 545, 546, 547], "e": [552, 553, 554, 555],
		"se": [560, 561, 562, 563], "s": [568, 569, 570, 571], "sw": [576, 577, 578, 579],
		"w": [584, 585, 586, 587], "nw": [592, 593, 594, 595]}},
}

const DIRECTIONS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ALL_ACTIONS := ["idle", "walk", "run", "pose", "attack_onehand", "attack_twohand",
	"attack_power", "cast", "dig", "hit", "death"]
# 本轮固定：只构建 Idle / Walk / Run。
const BUILT_ACTIONS := ["idle", "walk", "run"]

var appearance_base: int = 0


func set_appearance(appearance_id: int) -> void:
	appearance_base = appearance_id * 600


func abs_index(local_idx: int) -> int:
	return appearance_base + local_idx


func png_path(abs_idx: int) -> String:
	return "res://Hum/%05d.png" % abs_idx


func placement_path(abs_idx: int) -> String:
	return "res://Hum/Placements/%05d.txt" % abs_idx


func local_frames(action: String, direction: String) -> Array:
	return HUM_ACTIONS[action]["frames"][direction]


func all_action_names() -> Array:
	return ALL_ACTIONS.duplicate()


func built_local_indices() -> Array:
	return _collect_indices(BUILT_ACTIONS)


func all_local_indices() -> Array:
	return _collect_indices(ALL_ACTIONS)


func _collect_indices(actions: Array) -> Array:
	var seen := {}
	var out := []
	for action in actions:
		for dir in DIRECTIONS:
			for li in HUM_ACTIONS[String(action)]["frames"][String(dir)]:
				if not seen.has(li):
					seen[li] = true
					out.append(li)
	return out
