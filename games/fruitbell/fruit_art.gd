class_name FruitArt
extends RefCounted
## 과일 종치기 그림 – 과일 4종, 카드 앞 · 뒤, 종 (코드로 그린 캐주얼 스타일)

const INK := Color("#3D3450")
const CARD := Color("#FFFDF7")
const CARD_EDGE := Color("#E9DCC6")
const BACK := Color("#FF8FA3")
const BACK_DARK := Color("#E8607A")
const GOLD := Color("#FFC93C")
const GOLD_DARK := Color("#D99A16")
const RED := Color("#FF4F6D")
const BANANA := Color("#FFD54A")
const LIME := Color("#7BCB4B")
const GRAPE := Color("#9B6BD3")
const LEAF := Color("#4CAF50")

## 주사위 눈처럼 놓는 자리 (카드 안 -1~1 좌표)
const SPOTS := [
	[],
	[[0.0, 0.0]],
	[[-0.42, -0.45], [0.42, 0.45]],
	[[-0.42, -0.5], [0.0, 0.0], [0.42, 0.5]],
	[[-0.42, -0.45], [0.42, -0.45], [-0.42, 0.45], [0.42, 0.45]],
	[[-0.42, -0.5], [0.42, -0.5], [0.0, 0.0], [-0.42, 0.5], [0.42, 0.5]],
]


## 과일 하나. c: 가운데, s: 크기(지름 정도)
static func draw_fruit(ci: CanvasItem, fruit: int, c: Vector2, s: float) -> void:
	var r := s * 0.5
	match fruit:
		FruitLogic.Fruit.STRAWBERRY:
			var body := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				var y := -cos(a)
				# 위는 넓고 아래는 뾰족
				var w := 0.7 if y < 0.0 else 0.7 * (1.0 - y * 0.55)
				body.append(c + Vector2(sin(a) * w, y * 0.9 + 0.08) * r)
			_shadowed(ci, body, RED)
			for p in [[-0.35, -0.1], [0.3, -0.15], [0.0, 0.25], [-0.2, 0.5], [0.25, 0.45], [0.0, -0.3]]:
				ci.draw_circle(c + Vector2(p[0], p[1]) * r, r * 0.07, Color("#FFE9A8"), true, -1.0, true)
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.55
				var tip := c + Vector2(0, -0.78) * r + Vector2(cos(a), sin(a) * 0.7 + 0.3) * r * 0.5
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, -0.82) * r, tip, c + Vector2(0.12, -0.82) * r]), LEAF)
			ci.draw_circle(c + Vector2(-0.3, -0.35) * r, r * 0.12, Color(1, 1, 1, 0.5), true, -1.0, true)
		FruitLogic.Fruit.BANANA:
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				var a := lerpf(PI * 0.15, PI * 0.85, t)
				pts.append(c + Vector2(-cos(a) * 0.95, sin(a) * 0.75 - 0.35) * r)
			for i in 13:
				var t := 1.0 - i / 12.0
				var a := lerpf(PI * 0.2, PI * 0.8, t)
				pts.append(c + Vector2(-cos(a) * 0.7, sin(a) * 0.35 - 0.2) * r)
			_shadowed(ci, pts, BANANA)
			ci.draw_circle(c + Vector2(-0.82, -0.1) * r, r * 0.09, Color("#7A5230"), true, -1.0, true)
			ci.draw_circle(c + Vector2(0.84, -0.12) * r, r * 0.08, Color("#7A5230"), true, -1.0, true)
			ci.draw_arc(c + Vector2(0, -0.3) * r, r * 0.62, PI * 0.3, PI * 0.7, 10, Color(1, 1, 1, 0.55), r * 0.08, true)
		FruitLogic.Fruit.LIME:
			ci.draw_circle(c + Vector2(0, r * 0.08), r * 0.86, LIME.darkened(0.3), true, -1.0, true)
			ci.draw_circle(c, r * 0.86, LIME, true, -1.0, true)
			ci.draw_circle(c, r * 0.68, Color("#D8F5A2"), true, -1.0, true)
			for k in 8:
				var a := TAU * k / 8.0
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.64, Color("#A6DE6A"), maxf(1.5, r * 0.07), true)
			ci.draw_circle(c, r * 0.1, Color("#F2FFE0"), true, -1.0, true)
		FruitLogic.Fruit.GRAPE:
			var berries := [[0.0, 0.62], [-0.3, 0.3], [0.3, 0.3], [-0.55, -0.05], [0.0, -0.02], [0.55, -0.05], [-0.28, -0.36], [0.28, -0.36]]
			for b in berries:
				ci.draw_circle(c + Vector2(b[0], b[1] + 0.06) * r, r * 0.27, GRAPE.darkened(0.3), true, -1.0, true)
			for b in berries:
				ci.draw_circle(c + Vector2(b[0], b[1]) * r, r * 0.27, GRAPE, true, -1.0, true)
				ci.draw_circle(c + Vector2(b[0] - 0.08, b[1] - 0.09) * r, r * 0.07, Color(1, 1, 1, 0.5), true, -1.0, true)
			ci.draw_line(c + Vector2(0, -0.6) * r, c + Vector2(0.08, -0.92) * r, Color("#7A5230"), r * 0.1, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.05, -0.75) * r, c + Vector2(0.6, -0.95) * r,
				c + Vector2(0.5, -0.65) * r]), LEAF)


static func _shadowed(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var sh := PackedVector2Array()
	var off := Vector2(0, 0)
	if pts.size() > 0:
		var top := pts[0].y
		var bottom := pts[0].y
		for p in pts:
			top = minf(top, p.y)
			bottom = maxf(bottom, p.y)
		off = Vector2(0, (bottom - top) * 0.07)
	for p in pts:
		sh.append(p + off)
	ci.draw_colored_polygon(sh, color.darkened(0.3))
	ci.draw_colored_polygon(pts, color)


## 카드 앞면. rect: 카드 자리, rot: 돌리기(라디안, 가운데 기준)
static func draw_card(ci: CanvasItem, rect: Rect2, c: int, rot: float = 0.0, alpha: float = 1.0) -> void:
	_begin(ci, rect, rot)
	var r := Rect2(-rect.size / 2.0, rect.size)
	var rad := rect.size.x * 0.14
	UIKit.draw_rbox(ci, Rect2(r.position + Vector2(0, rect.size.y * 0.03), r.size), Color(0.3, 0.2, 0.25, 0.22 * alpha), rad)
	UIKit.draw_rbox(ci, r, Color(CARD_EDGE, alpha), rad)
	UIKit.draw_rbox(ci, r.grow(-rect.size.x * 0.035), Color(CARD, alpha), rad * 0.8)
	var f := FruitLogic.fruit_of(c)
	var k := FruitLogic.count_of(c)
	var s := rect.size.x * (0.34 if k >= 4 else 0.4 if k >= 2 else 0.56)
	for sp in SPOTS[k]:
		draw_fruit(ci, f, Vector2(sp[0] * rect.size.x * 0.5, sp[1] * rect.size.y * 0.5), s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 카드 뒷면
static func draw_back(ci: CanvasItem, rect: Rect2, rot: float = 0.0) -> void:
	_begin(ci, rect, rot)
	var r := Rect2(-rect.size / 2.0, rect.size)
	var rad := rect.size.x * 0.14
	UIKit.draw_rbox(ci, Rect2(r.position + Vector2(0, rect.size.y * 0.03), r.size), Color(0.3, 0.2, 0.25, 0.2), rad)
	UIKit.draw_rbox(ci, r, Color.WHITE, rad)
	var inner := r.grow(-rect.size.x * 0.06)
	UIKit.draw_rbox(ci, inner, BACK, rad * 0.75)
	# 물방울 무늬
	var step := rect.size.x * 0.2
	var y := inner.position.y + step * 0.5
	var row := 0
	while y < inner.end.y - step * 0.2:
		var x := inner.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < inner.end.x - step * 0.2:
			ci.draw_circle(Vector2(x, y), step * 0.18, BACK_DARK, true, -1.0, true)
			x += step
		y += step * 0.85
		row += 1
	ci.draw_circle(Vector2.ZERO, rect.size.x * 0.24, Color.WHITE, true, -1.0, true)
	draw_fruit(ci, FruitLogic.Fruit.STRAWBERRY, Vector2.ZERO, rect.size.x * 0.32)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _begin(ci: CanvasItem, rect: Rect2, rot: float) -> void:
	ci.draw_set_transform(rect.get_center(), rot, Vector2.ONE)


## 종. c: 가운데, r: 반지름, shake: 0~1 흔들림, t: 시간, half: 2인 모드에서 위 · 아래 반쪽 표시
static func draw_bell(ci: CanvasItem, c: Vector2, r: float, shake: float = 0.0, t: float = 0.0, half: bool = false) -> void:
	draw_bell_base(ci, c, r)
	draw_bell_top(ci, c + Vector2(sin(t * 60.0) * r * 0.05 * shake, 0), r, half)


## 종 받침
static func draw_bell_base(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_set_transform(c + Vector2(0, r * 0.72), 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, r * 1.08, Color(0.3, 0.2, 0.25, 0.22), true, -1.0, true)
	ci.draw_set_transform(c + Vector2(0, r * 0.62), 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, r * 1.0, Color("#8A6A52"), true, -1.0, true)
	ci.draw_set_transform(c + Vector2(0, r * 0.55), 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, r * 0.98, Color("#B08968"), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 종 몸통 (반구)과 단추
static func draw_bell_top(ci: CanvasItem, b: Vector2, r: float, half: bool = false) -> void:
	var dome := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		dome.append(b + Vector2(cos(a) * 0.9, sin(a) * 0.82 + 0.42) * r)
	var shadow := PackedVector2Array()
	for p in dome:
		shadow.append(p + Vector2(0, r * 0.08))
	ci.draw_colored_polygon(shadow, GOLD_DARK)
	ci.draw_colored_polygon(dome, GOLD)
	ci.draw_arc(b + Vector2(0, r * 0.42), r * 0.62, PI * 1.15, PI * 1.45, 10, Color(1, 1, 1, 0.6), r * 0.1, true)
	# 누르는 단추
	ci.draw_circle(b + Vector2(0, -r * 0.44), r * 0.2, GOLD_DARK, true, -1.0, true)
	ci.draw_circle(b + Vector2(0, -r * 0.48), r * 0.17, GOLD.lightened(0.2), true, -1.0, true)
	if half:
		ci.draw_line(b + Vector2(-r * 1.05, r * 0.05), b + Vector2(r * 1.05, r * 0.05), Color(1, 1, 1, 0.55), maxf(2.0, r * 0.03), true)
