class_name FruitAtlas
extends SubViewport
## 카드 그림 모음 – 앞면 20종과 뒷면을 화면 해상도에 맞춰 한 번만 그려 두고 그림으로 재사용
## (카드 한 장은 도형 수십 개라 매 프레임 새로 그리면 폰이 뜨거워져요)
## 투명한 화면에 그린 그림이라 색에 투명도가 이미 곱해져 있음 → 쓰는 층은 UIKit.premult_material()로 그려야 함

const COLS := 7
const BACK := 20          # 칸 번호: 0~19 = 과일 4종 × 1~5개, 20 = 뒷면
const MAX_W := 3200       # 전체 그림 가로 한도 (픽셀)

var _card := Vector2.ZERO      # 카드 크기 (화면 좌표)
var _px := 0.0                 # 화면 배율 (화면 좌표 1 = 몇 픽셀)
var _scale := 1.0              # 그려 두는 배율 (두 배로 그려 줄여 쓰면 가장자리가 매끈함, 너무 커지면 한 배)
var _cell := Vector2i.ZERO     # 한 칸 크기 (픽셀)
var _painter: Node2D


func _init() -> void:
	disable_3d = true
	transparent_bg = true
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	add_child(_painter)
	set_process(false)


func _process(_delta: float) -> void:
	if UIKit.release_paint(self, _painter):
		set_process(false)


## 카드 크기나 화면 배율이 바뀌었을 때만 다시 그림
func prepare(card: Vector2, px_scale: float) -> void:
	if card.is_equal_approx(_card) and is_equal_approx(px_scale, _px):
		return
	_card = card
	_px = px_scale
	_scale = maxf(0.1, px_scale)
	if (card.x * 1.1 * _scale * 2.0 + 6.0) * COLS <= MAX_W:
		_scale *= 2.0
	# 그림자(아래로 3%)와 가장자리 번짐이 들어갈 여백
	var pad := ceilf(card.y * 0.03 * _scale) + 3.0
	_cell = Vector2i((card * _scale).ceil() + Vector2(pad, pad) * 2.0)
	size = Vector2i(_cell.x * COLS, _cell.y * 3)
	_painter.scale = Vector2(_scale, _scale)
	_painter.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE
	set_process(true)


func _cell_rect(i: int) -> Rect2:
	return Rect2(Vector2(i % COLS * _cell.x, i / COLS * _cell.y), Vector2(_cell))


func _paint() -> void:
	for i in BACK + 1:
		var r := Rect2(_cell_rect(i).get_center() / _scale - _card / 2.0, _card)
		if i == BACK:
			FruitArt.draw_back(_painter, r)
		else:
			FruitArt.draw_card(_painter, r, FruitLogic.card(i / 5, i % 5 + 1))


## 카드 앞면. squash: 뒤집는 중의 가로 폭 (1 = 그대로)
func draw_face(ci: CanvasItem, center: Vector2, c: int, rot: float = 0.0, squash: float = 1.0) -> void:
	_draw_cell(ci, FruitLogic.fruit_of(c) * 5 + FruitLogic.count_of(c) - 1, center, rot, squash)


## 카드 뒷면
func draw_back(ci: CanvasItem, center: Vector2, rot: float = 0.0, squash: float = 1.0) -> void:
	_draw_cell(ci, BACK, center, rot, squash)


func _draw_cell(ci: CanvasItem, i: int, center: Vector2, rot: float, squash: float) -> void:
	var s := Vector2(_cell) / _scale
	ci.draw_set_transform(center, rot, Vector2(squash, 1.0))
	ci.draw_texture_rect_region(get_texture(), Rect2(-s / 2.0, s), _cell_rect(i))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
