class_name PieceView
extends Control
## UI 안에 넣는 말 하나 (플레이어 카드, 결과 화면 등)

var color: Color = Color.WHITE
var phase: float = 0.0
var bob: bool = true
var happy: bool = false
var square: bool = false
var _t: float = 0.0
var _piece: PieceNode


func _init() -> void:
	_piece = PieceNode.new()
	add_child(_piece)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree():
		return
	_piece.r = minf(size.x, size.y) * 0.34
	_piece.color = color
	_piece.phase = phase
	_piece.happy = happy
	_piece.square = square
	_piece.position = size / 2.0 + Vector2(0, _piece.r * 0.05)
	_piece.pose(_t, (sin(_t * 3.0 + phase) * 0.5 + 0.5) * 0.25 if bob else 0.0)
