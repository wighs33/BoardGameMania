class_name DrawCanvas
extends Control
## 그림 퀴즈 – 손가락으로 그리는 도화지 (색 · 굵기 · 지우개 · 되돌리기)
## 혼자 맞히기에서는 AI 낙서를 펜으로 그려 나가는 모습도 보여 줘요

signal stroke_started

const PAPER := Color("#FFFFFF")
const ERASER := Color(1, 1, 1, 1)

var drawing_enabled: bool = false
var pen_color: Color = Color("#3D3450")
var pen_width: float = 8.0
var eraser: bool = false
var strokes: Array = []            # [{c, w, p: PackedVector2Array}] (도화지 안 좌표)
# AI 낙서
var doodle: Array = []
var reveal: float = 0.0
var show_pen: bool = false
var flash: float = 0.0             # 정답 · 오답 테두리 반짝 (1 → 0)
var flash_color: Color = Color.WHITE

var _cur: int = -1


func clear() -> void:
	strokes.clear()
	_cur = -1
	queue_redraw()


func undo() -> void:
	if not strokes.is_empty():
		strokes.pop_back()
	_cur = -1
	queue_redraw()


func paper_rect() -> Rect2:
	return Rect2(Vector2(6, 4), size - Vector2(12, 12))


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 1.8)
	if not doodle.is_empty() or flash > 0.0:
		queue_redraw()


func _draw() -> void:
	var r := paper_rect()
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, 7), r.size), Color(0.3, 0.2, 0.25, 0.16), 34)
	UIKit.draw_rbox(self, r, Color("#E9E2D6"), 34)
	UIKit.draw_rbox(self, r.grow(-5), PAPER, 30)
	if flash > 0.0:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(10)
		sb.border_color = Color(flash_color, flash)
		sb.set_corner_radius_all(34)
		draw_style_box(sb, r)
	for s in strokes:
		var pts: PackedVector2Array = s["p"]
		var col: Color = s["c"]
		var w: float = s["w"]
		if pts.size() == 1:
			draw_circle(pts[0], w * 0.5, col, true, -1.0, true)
			continue
		draw_polyline(pts, col, w, true)
		# 둥근 끝 · 이음
		for i in range(0, pts.size(), maxi(1, pts.size() / 24)):
			draw_circle(pts[i], w * 0.5, col, true, -1.0, true)
		draw_circle(pts[0], w * 0.5, col, true, -1.0, true)
		draw_circle(pts[pts.size() - 1], w * 0.5, col, true, -1.0, true)
	if not doodle.is_empty():
		var area := r.grow(-r.size.x * 0.1)
		var w := maxf(5.0, minf(area.size.x, area.size.y) * 0.022)
		DrawDoodles.draw(self, doodle, area, reveal, w)
		if show_pen and reveal < 1.0:
			var t := DrawDoodles.tip(doodle, area, reveal)
			draw_line(t, t + Vector2(26, -44), Color("#FFC93C"), 14.0, true)
			draw_line(t + Vector2(20, -34), t + Vector2(26, -44), Color("#FF7EB6"), 14.0, true)
			draw_line(t, t + Vector2(5, -8), Color("#3D3450"), 10.0, true)


func _gui_input(event: InputEvent) -> void:
	if not drawing_enabled:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and paper_rect().grow(-6).has_point(mb.position):
			var w := pen_width * (3.2 if eraser else 1.0)
			strokes.append({"c": ERASER if eraser else pen_color, "w": w, "p": PackedVector2Array([mb.position])})
			_cur = strokes.size() - 1
			stroke_started.emit()
			queue_redraw()
		elif not mb.pressed:
			_cur = -1
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _cur >= 0 and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var r := paper_rect().grow(-4)
		var p := Vector2(clampf(mm.position.x, r.position.x, r.end.x), clampf(mm.position.y, r.position.y, r.end.y))
		var pts: PackedVector2Array = strokes[_cur]["p"]
		if pts[pts.size() - 1].distance_to(p) >= 2.5:
			pts.append(p)
			strokes[_cur]["p"] = pts
			queue_redraw()
		accept_event()
