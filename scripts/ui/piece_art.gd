class_name PieceArt
extends RefCounted
## 눈 달린 귀여운 말(토큰) 그리기 – 보드, 플레이어 카드, 메뉴 마스코트에서 공용으로 사용

const EYE_INK := Color("#2B2B3A")


## ci: 그릴 CanvasItem, center: 바닥 기준 중심, r: 반지름
## t: 시간(깜빡임용), phase: 개체별 위상, lift: 0~1 점프 높이, happy: 웃는 눈, square: 네모 몸통, blink: 눈 감음 (-1 = t로 정함)
static func draw_piece(ci: CanvasItem, center: Vector2, r: float, color: Color, t: float = 0.0,
		phase: float = 0.0, lift: float = 0.0, happy: bool = false, square: bool = false, blink: int = -1, shadow: bool = true) -> void:
	if r <= 0.5:
		return
	var l := clampf(lift, 0.0, 1.0)
	if shadow:
		draw_shadow(ci, center, r, l)
	draw_body(ci, center - Vector2(0, l * r * 0.9), r, color, blinking(t, phase) if blink < 0 else blink == 1, happy, square)


static func blinking(t: float, phase: float) -> bool:
	return fmod(t + phase * 1.37, 3.7) < 0.12


## 바닥 그림자 (점프하면 작아짐)
static func draw_shadow(ci: CanvasItem, center: Vector2, r: float, l: float) -> void:
	ci.draw_set_transform(center + Vector2(0, r * 0.82), 0.0, Vector2(1.0, 0.3))
	ci.draw_circle(Vector2.ZERO, r * (0.95 - l * 0.3), Color(0.2, 0.1, 0.15, 0.2), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 몸통과 얼굴. c: 몸 가운데
static func draw_body(ci: CanvasItem, c: Vector2, r: float, color: Color, blink: bool, happy: bool, square: bool) -> void:
	# 몸통 (아래 진한 테두리로 입체감)
	if square:
		var h := r * 0.93
		UIKit.draw_rbox(ci, Rect2(c + Vector2(-h, -h + r * 0.14), Vector2(h, h) * 2.0), color.darkened(0.3), r * 0.42)
		UIKit.draw_rbox(ci, Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), color, r * 0.42)
		UIKit.draw_rbox(ci, Rect2(c + Vector2(-h * 0.72, -h * 0.78), Vector2(r * 0.42, r * 0.22)), Color(1, 1, 1, 0.45), r * 0.11)
	else:
		ci.draw_circle(c + Vector2(0, r * 0.14), r, color.darkened(0.3), true, -1.0, true)
		ci.draw_circle(c, r, color, true, -1.0, true)
		ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.42), r * 0.2, Color(1, 1, 1, 0.5), true, -1.0, true)

	# 볼터치
	var blush := Color(1.0, 0.55, 0.6, 0.35)
	ci.draw_circle(c + Vector2(-r * 0.58, r * 0.3), r * 0.14, blush, true, -1.0, true)
	ci.draw_circle(c + Vector2(r * 0.58, r * 0.3), r * 0.14, blush, true, -1.0, true)

	# 눈 (몸이 어두우면 선을 밝은 색으로)
	var ink := EYE_INK if color.get_luminance() > 0.25 else Color("#F4F1F8")
	var lw := maxf(2.0, r * 0.11)
	for sx in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * r * 0.33, -r * 0.04)
		if happy:
			ci.draw_arc(e + Vector2(0, r * 0.06), r * 0.15, PI * 1.1, PI * 1.9, 10, ink, lw, true)
		elif blink:
			ci.draw_line(e - Vector2(r * 0.15, 0), e + Vector2(r * 0.15, 0), ink, lw, true)
		else:
			ci.draw_circle(e, r * 0.23, Color.WHITE, true, -1.0, true)
			ci.draw_circle(e + Vector2(0, r * 0.04), r * 0.12, EYE_INK, true, -1.0, true)
			ci.draw_circle(e + Vector2(-r * 0.04, -r * 0.01), r * 0.04, Color.WHITE, true, -1.0, true)

	# 입
	if happy:
		ci.draw_arc(c + Vector2(0, r * 0.2), r * 0.16, 0.15, PI - 0.15, 12, ink, lw, true)
	else:
		ci.draw_arc(c + Vector2(0, r * 0.22), r * 0.1, 0.3, PI - 0.3, 10, ink, lw * 0.9, true)
