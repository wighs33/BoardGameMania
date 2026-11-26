class_name WavyTitle
extends Control
## 글자마다 색이 다르고 물결처럼 출렁이는 로고 타이틀 (글자는 한 번만 그리고 자리만 옮김)

var text: String = "보드게임마니아"
var font_size: int = 80
var colors: Array = [Color("#FF6B6B"), Color("#FF9F43"), Color("#FFC93C"), Color("#6BCB77"), Color("#4D96FF"), Color("#8C7AE6"), Color("#FF7EB6")]
var outline_color: Color = Color("#3D3450")
var _t: float = 0.0
var _key: Array = []
var _letters: Array[Node2D] = []
var _fs: int = 80
var _base_y: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var key := [text, font_size, size]
	if key != _key:
		_key = key
		_build()
	for i in _letters.size():
		_letters[i].position.y = _base_y + sin(_t * 3.2 - i * 0.65) * _fs * 0.07


func _build() -> void:
	for n in _letters:
		n.queue_free()
	_letters.clear()
	var f := UIKit.font(800)
	_fs = font_size
	var widths: Array[float] = []
	var total := 0.0
	for ch in text:
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
		widths.append(w)
		total += w
	# 화면보다 넓으면 줄이기
	var max_w := size.x * 0.94
	if total > max_w and total > 0.0:
		var k := max_w / total
		_fs = int(_fs * k)
		for i in widths.size():
			widths[i] *= k
		total = max_w
	var x := (size.x - total) / 2.0
	_base_y = size.y / 2.0 + _fs * 0.36
	for i in text.length():
		var n := Node2D.new()
		n.position.x = x
		n.draw.connect(_draw_letter.bind(n, text[i], colors[i % colors.size()]))
		add_child(n)
		_letters.append(n)
		x += widths[i]


func _draw_letter(n: Node2D, ch: String, col: Color) -> void:
	var f := UIKit.font(800)
	var outline := maxi(6, int(_fs * 0.2))
	n.draw_string_outline(f, Vector2(0, _fs * 0.08), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, outline, outline_color)
	n.draw_string_outline(f, Vector2.ZERO, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, outline, outline_color)
	n.draw_string(f, Vector2.ZERO, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, col)
