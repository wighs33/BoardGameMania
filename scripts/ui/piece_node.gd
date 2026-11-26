class_name PieceNode
extends Node2D
## 움직이는 말 하나. 그림자와 몸을 한 번씩만 그려 두고 움직임은 자리 · 크기로만 바꿔요 (눈 · 표정이 바뀔 때만 다시 그림)

var r: float = 0.0
var color: Color = Color.WHITE
var phase: float = 0.0
var happy: bool = false
var square: bool = false
var _blink: bool = false
var _key: Array = []
var _shadow: Node2D
var _body: Node2D


func _init(p_color: Color = Color.WHITE, p_phase: float = 0.0, p_happy: bool = false, p_square: bool = false) -> void:
	color = p_color
	phase = p_phase
	happy = p_happy
	square = p_square
	_shadow = Node2D.new()
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_body = Node2D.new()
	_body.draw.connect(_draw_body)
	add_child(_body)


## t: 시간(깜빡임용), lift: 0~1 점프 높이
func pose(t: float, lift: float = 0.0) -> void:
	_blink = PieceArt.blinking(t, phase)
	var key := [r, color, happy, square, _blink]
	if key != _key:
		_key = key
		_shadow.queue_redraw()
		_body.queue_redraw()
	var l := clampf(lift, 0.0, 1.0)
	_body.position = Vector2(0, -l * r * 0.9)
	_shadow.position = Vector2(0, r * 0.82)
	_shadow.scale = Vector2.ONE * (0.95 - l * 0.3) / 0.95


func _draw_shadow() -> void:
	if r > 0.5:
		PieceArt.draw_shadow(_shadow, Vector2(0, -r * 0.82), r, 0.0)


func _draw_body() -> void:
	if r > 0.5:
		PieceArt.draw_body(_body, Vector2.ZERO, r, color, _blink, happy, square)
