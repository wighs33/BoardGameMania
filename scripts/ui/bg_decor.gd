class_name BgDecor
extends Control
## 배경에 둥둥 떠다니는 반투명 도형들
## 도형마다 한 번만 그려 두고 자리 · 각도만 옮겨요 (매 프레임 다시 그리면 폰이 뜨거워짐)

var _t: float = 0.0
var _items: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20251121
	for i in 16:
		var it := {
			"x": rng.randf(), "y": rng.randf(),
			"r": rng.randf_range(16.0, 46.0),
			"kind": rng.randi() % 3,
			"ph": rng.randf() * TAU,
			"sp": rng.randf_range(0.4, 0.9),
			"rot": rng.randf() * TAU,
			"c": UIKit.PLAYER_COLORS[rng.randi() % UIKit.PLAYER_COLORS.size()],
		}
		var n := Node2D.new()
		n.draw.connect(_draw_shape.bind(n, int(it["kind"]), float(it["r"]), Color(it["c"], 0.16)))
		add_child(n)
		it["node"] = n
		_items.append(it)
	_move()


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		_move()


func _move() -> void:
	for it in _items:
		var sp: float = it["sp"]
		var pos := Vector2(float(it["x"]) * size.x, float(it["y"]) * size.y + sin(_t * sp + float(it["ph"])) * 16.0)
		(it["node"] as Node2D).transform = Transform2D(float(it["rot"]) + _t * 0.15 * sp, pos)


static func _draw_shape(n: Node2D, kind: int, r: float, col: Color) -> void:
	match kind:
		0:
			n.draw_circle(Vector2.ZERO, r, col, true, -1.0, true)
		1:
			UIKit.draw_rbox(n, Rect2(-r, -r, r * 2.0, r * 2.0), col, r * 0.45)
		_:
			UIKit.draw_rbox(n, Rect2(-r, -r * 0.3, r * 2.0, r * 0.6), col, r * 0.3)
			UIKit.draw_rbox(n, Rect2(-r * 0.3, -r, r * 0.6, r * 2.0), col, r * 0.3)
