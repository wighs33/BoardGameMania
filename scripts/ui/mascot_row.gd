class_name MascotRow
extends Control
## 메인 메뉴 위쪽에서 차례로 폴짝 뛰는 말 4개

var _t: float = 0.0


var _pieces: Array[PieceNode] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in UIKit.PLAYER_COLORS.size():
		var p := PieceNode.new(UIKit.PLAYER_COLORS[i], float(i))
		add_child(p)
		_pieces.append(p)


func _process(delta: float) -> void:
	_t += delta
	var n := _pieces.size()
	var r := minf(size.y * 0.3, size.x / 14.0)
	var spacing := r * 2.9
	var start_x := size.x / 2.0 - spacing * (n - 1) / 2.0
	for i in n:
		var s := sin(_t * 3.0 - i * 0.8)
		_pieces[i].r = r
		_pieces[i].happy = s > 0.6
		_pieces[i].position = Vector2(start_x + i * spacing, size.y * 0.62)
		_pieces[i].pose(_t, maxf(0.0, s) * 0.7)
