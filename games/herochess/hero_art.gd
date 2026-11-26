class_name HeroArt
extends RefCounted
## 히어로 체스 그림 – 앱의 캐주얼 스타일로 그린 영웅 10명 · 성 · 지뢰 · 하트
## 영웅 = 팀 색 말(PieceArt) + 영웅마다 다른 모자 · 무기 (로봇은 네모 몸)
## 유령(쓰러진 영웅)은 그 영웅 그림을 투명한 팀 색으로 (HeroBoard 가 따로 그려 둠). 하트 줄은 HeroHearts, 초상화는 HeroPortrait

const K := HeroLogic.Kind
const INK := Color("#3D3450")
const WOOD := Color("#9A6A44")
const METAL := Color("#CBD3DE")
const METAL_DARK := Color("#8E99A8")
const GOLD := Color("#FFC93C")
const HAT := Color("#7E57C2")
const HOOD := Color("#4B3F63")
const NINJA_CLOTH := Color("#2F2B42")
const GREY := Color("#9C97A8")
const WHITE_SOFT := Color("#FFF8EC")
const HELMET := Color("#8FA36B")
const HARDHAT := Color("#FFC21A")
const HEART := Color("#FF4F6D")
const STONE := Color("#B9B4C6")


## c: 몸 중심, r: 몸 반지름, lift: 0~1 점프, bound: 무력(전사), shield: 배리어
## blink: 눈 감음 (-1 = t로 정함), orbit: 도는 별과 배리어 앞 테두리까지 그릴지 (판은 따로 얹어서 움직임), shadow: 바닥 그림자
static func draw_hero(ci: CanvasItem, c: Vector2, r: float, kind: int, team: Color, t: float, phase: float = 0.0,
		lift: float = 0.0, happy: bool = false, bound: bool = false, shield: bool = false, mounted: bool = false,
		blink: int = -1, orbit: bool = true, shadow: bool = true) -> void:
	if r <= 1.0:
		return
	if mounted:
		# 말: 영웅을 조금 올려 앉힘
		draw_horse(ci, c - Vector2(0, clampf(lift, 0.0, 1.0) * r * 0.9), r, t + phase)
		c -= Vector2(0, r * 0.22)
	var col := team.lerp(GREY, 0.55) if bound else team
	var body := c - Vector2(0, clampf(lift, 0.0, 1.0) * r * 0.9)
	# 배리어: 영웅을 감싸는 비눗방울 (뒤에 밝은 속 → 영웅 → 앞에 굵은 테두리 · 광택 · 반짝이)
	var sc := body + Vector2(0, -r * 0.12)
	var big := r * 1.46 * (1.0 + 0.035 * sin(t * 4.0 + phase))
	if shield:
		ci.draw_circle(sc, big, Color(0.62, 0.9, 1.0, 0.5), true, -1.0, true)
		ci.draw_circle(sc, big * 0.8, Color(0.85, 0.97, 1.0, 0.35), true, -1.0, true)
	_behind(ci, body, r, kind, col, t)
	PieceArt.draw_piece(ci, c, r, col, t, phase, lift, happy, kind == K.ROBOT, blink, shadow)
	_front(ci, body, r, kind, col, t)
	if bound:
		_rope(ci, body, r)
		if orbit:
			for i in 3:
				_star(ci, body + bound_star(t, i) * r, r * 0.17, GOLD)
	if shield and orbit:
		_bubble(ci, sc, big, r)
		for i in 3:
			_star(ci, sc + bubble_star(t, phase, i) * big, r * 0.17, Color(1, 1, 1, 0.95))


## 무력에 걸린 영웅 머리 위를 도는 별 (반지름 단위)
static func bound_star(t: float, i: int) -> Vector2:
	var a := t * 3.0 + TAU * i / 3.0
	return Vector2(cos(a) * 0.75, -1.35 + sin(a) * 0.2)


## 배리어 테두리를 도는 반짝이 (방울 반지름 단위)
static func bubble_star(t: float, phase: float, i: int) -> Vector2:
	var a := t * 1.6 + phase + TAU * i / 3.0
	return Vector2(cos(a), sin(a))


## 가만히 있어도 움직이는 소품의 빠르기 sin(t × 이 값) (날개 · 별 지팡이 · 띠 · 깃털), 없으면 0
static func sway(kind: int) -> float:
	match kind:
		K.ANGEL:
			return 4.0
		K.MAGICIAN:
			return 5.0
		K.NINJA:
			return 6.0
		K.KNIGHT:
			return 3.0
	return 0.0


## 로봇 안테나 불
static func robot_on(t: float) -> bool:
	return fmod(t, 1.2) < 0.6


## 기사가 탄 말 (오른쪽을 봄). 몸 · 다리 · 꼬리 · 목과 머리
static func draw_horse(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var fur := Color("#A8703F")
	var mane := Color("#5B3A20")
	var nod := sin(t * 3.0) * 0.05
	ci.draw_colored_polygon(_pts(c, r, [[-0.85, 0.5], [-1.3, 0.48], [-1.45, 0.95], [-1.22, 1.08], [-1.1, 0.76], [-0.85, 0.8]]), mane)
	for x: float in [-0.72, -0.4, 0.34, 0.66]:
		UIKit.draw_rbox(ci, Rect2(c + Vector2(x, 0.85) * r, Vector2(0.22, 0.46) * r), fur.darkened(0.18), r * 0.07)
	_ellipse(ci, c + Vector2(0, 0.74) * r, Vector2(1.04, 0.46) * r, fur)
	var neck := _pts(c, r, [[0.52, 0.8], [0.66, 0.05], [0.9, -0.38 + nod], [1.16, -0.42 + nod], [1.52, -0.06 + nod], [1.48, 0.16 + nod],
		[1.22, 0.18 + nod], [1.06, 0.12], [1.02, 0.8]])
	ci.draw_colored_polygon(neck, fur)
	_outline(ci, neck, fur.darkened(0.4), r * 0.05)
	ci.draw_colored_polygon(_pts(c, r, [[0.9, -0.34 + nod], [0.96, -0.7 + nod], [1.12, -0.38 + nod]]), fur.darkened(0.15))
	ci.draw_colored_polygon(_pts(c, r, [[0.5, 0.7], [0.6, 0.0], [0.86, -0.42 + nod], [0.98, -0.32 + nod], [0.78, 0.08], [0.68, 0.72]]), mane)
	ci.draw_circle(c + Vector2(1.18, -0.12 + nod) * r, r * 0.07, Color("#2B1B10"), true, -1.0, true)
	ci.draw_circle(c + Vector2(1.43, 0.04 + nod) * r, r * 0.04, Color("#2B1B10"), true, -1.0, true)


## 배리어 방울의 앞쪽: 진한 바깥 선 + 굵은 하늘색 테 + 흰 안쪽 선 + 광택
static func _bubble(ci: CanvasItem, sc: Vector2, big: float, r: float) -> void:
	ci.draw_circle(sc, big, Color(0.8, 0.96, 1.0, 0.1), true, -1.0, true)
	ci.draw_arc(sc, big + r * 0.09, 0, TAU, 48, Color("#1B5AA6"), maxf(2.0, r * 0.08), true)
	ci.draw_arc(sc, big, 0, TAU, 48, Color("#45CBFF"), maxf(3.0, r * 0.17), true)
	ci.draw_arc(sc, big - r * 0.11, 0, TAU, 48, Color(1, 1, 1, 0.8), maxf(1.2, r * 0.05), true)
	ci.draw_arc(sc, big * 0.76, PI * 1.1, PI * 1.42, 10, Color(1, 1, 1, 0.92), maxf(2.0, r * 0.14), true)
	ci.draw_circle(sc + Vector2(-0.3, -0.83) * big * 0.76, r * 0.08, Color(1, 1, 1, 0.92), true, -1.0, true)


# ── 몸 뒤에 그리는 소품 ────────────────────────────────
static func _behind(ci: CanvasItem, c: Vector2, r: float, kind: int, _team: Color, t: float) -> void:
	match kind:
		K.REAPER:
			# 큰 낫
			ci.draw_line(c + Vector2(0.95, 0.95) * r, c + Vector2(0.62, -1.3) * r, WOOD.darkened(0.2), r * 0.17, true)
			ci.draw_line(c + Vector2(0.95, 0.95) * r, c + Vector2(0.62, -1.3) * r, WOOD, r * 0.11, true)
			var blade := _pts(c, r, [[0.66, -1.32], [0.3, -1.58], [-0.15, -1.64], [-0.58, -1.45], [-0.82, -1.06],
				[-0.48, -1.26], [-0.1, -1.4], [0.3, -1.36], [0.6, -1.14]])
			ci.draw_colored_polygon(blade, METAL)
			_outline(ci, blade, METAL_DARK.darkened(0.3), r * 0.06)
		K.KNIGHT:
			# 창
			var lance := _pts(c, r, [[-1.08, 0.78], [-0.82, 0.78], [-1.32, -1.55]])
			ci.draw_colored_polygon(lance, METAL)
			_outline(ci, lance, METAL_DARK.darkened(0.2), r * 0.06)
			ci.draw_circle(c + Vector2(-0.95, 0.72) * r, r * 0.2, GOLD.darkened(0.1), true, -1.0, true)
		K.SOLDIER:
			# 짧은 칼
			var blade := _pts(c, r, [[0.86, 0.3], [1.06, 0.3], [1.12, -1.05], [0.96, -1.32], [0.8, -1.05]])
			ci.draw_colored_polygon(blade, METAL)
			_outline(ci, blade, METAL_DARK.darkened(0.2), r * 0.06)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(0.62, 0.22) * r, Vector2(0.68, 0.16) * r), GOLD.darkened(0.1), r * 0.06)
		K.ANGEL:
			# 날개 (살랑살랑)
			var flap := sin(t * 4.0) * 0.08
			for sx in [-1.0, 1.0]:
				var wing := PackedVector2Array()
				var pts := [[0.55, -0.2], [1.25, -0.75 - flap], [1.62, -0.55 - flap], [1.5, -0.15], [1.62, 0.12], [1.3, 0.35], [0.6, 0.25]]
				for pp in pts:
					wing.append(c + Vector2(sx * pp[0], pp[1]) * r)
				ci.draw_colored_polygon(wing, WHITE_SOFT)
				_outline(ci, wing, Color("#D9CDB8"), r * 0.07)
				ci.draw_line(c + Vector2(sx * 0.8, -0.1) * r, c + Vector2(sx * 1.35, -0.38 - flap) * r, Color("#E6DCC8"), r * 0.06, true)
		K.PRIEST:
			# 십자 지팡이
			ci.draw_line(c + Vector2(-1.0, 0.85) * r, c + Vector2(-1.0, -1.3) * r, WOOD, r * 0.12, true)
			ci.draw_line(c + Vector2(-1.0, -1.25) * r, c + Vector2(-1.0, -1.75) * r, GOLD.darkened(0.05), r * 0.14, true)
			ci.draw_line(c + Vector2(-1.22, -1.52) * r, c + Vector2(-0.78, -1.52) * r, GOLD.darkened(0.05), r * 0.14, true)
		K.ARCHITECT:
			# 망치
			ci.draw_line(c + Vector2(0.75, 0.85) * r, c + Vector2(1.05, -0.95) * r, WOOD, r * 0.13, true)
			var head := _pts(c, r, [[0.72, -1.22], [1.42, -1.05], [1.34, -0.72], [0.66, -0.9]])
			ci.draw_colored_polygon(head, METAL_DARK)
			_outline(ci, head, METAL_DARK.darkened(0.3), r * 0.06)
		K.ROBOT:
			# 안테나 (깜빡이는 불)
			ci.draw_line(c + Vector2(0, -0.9) * r, c + Vector2(0, -1.45) * r, METAL_DARK, r * 0.1, true)
			var on := robot_on(t)
			ci.draw_circle(c + Vector2(0, -1.5) * r, r * 0.17, Color("#FF5A5A") if on else Color("#9A3B3B"), true, -1.0, true)


# ── 몸 앞에 그리는 소품 ────────────────────────────────
static func _front(ci: CanvasItem, c: Vector2, r: float, kind: int, team: Color, t: float) -> void:
	match kind:
		K.MAGICIAN:
			# 고깔모자 + 별 지팡이
			var cone := _pts(c, r, [[-0.6, -0.7], [0.6, -0.7], [0.36, -1.32], [0.62, -1.78], [0.04, -1.3]])
			ci.draw_colored_polygon(cone, HAT)
			_outline(ci, cone, HAT.darkened(0.35), r * 0.06)
			ci.draw_colored_polygon(_pts(c, r, [[-0.6, -0.7], [0.6, -0.7], [0.53, -0.86], [-0.53, -0.86]]), GOLD)
			_ellipse(ci, c + Vector2(0, -0.66) * r, Vector2(1.0, 0.2) * r, HAT.darkened(0.15))
			_star(ci, c + Vector2(0.08, -1.12) * r, r * 0.17, GOLD)
			ci.draw_line(c + Vector2(0.8, 0.62) * r, c + Vector2(1.2, -0.12) * r, WOOD, r * 0.11, true)
			var tw := 1.0 + 0.15 * sin(t * 5.0)
			_star(ci, c + Vector2(1.22, -0.18) * r, r * 0.24 * tw, GOLD)
		K.REAPER:
			# 두건 (얼굴만 보이게)
			var hood: PackedVector2Array = []
			for i in 15:
				var a := deg_to_rad(160.0 + 220.0 * i / 14.0)
				hood.append(c + Vector2(cos(a) * 1.08, sin(a) * 1.08) * r)
			for i in 15:
				var a := deg_to_rad(380.0 - 220.0 * i / 14.0)
				hood.append(c + Vector2(cos(a) * 0.8, 0.08 + sin(a) * 0.7) * r)
			ci.draw_colored_polygon(hood, HOOD)
			ci.draw_colored_polygon(_pts(c, r, [[-0.4, -0.92], [0.4, -0.92], [0.7, -1.42]]), HOOD)
			ci.draw_circle(c + Vector2(-0.45, -0.72) * r, r * 0.1, Color(1, 1, 1, 0.18), true, -1.0, true)
		K.NINJA:
			# 이마 띠 + 입 가리개
			ci.draw_colored_polygon(_pts(c, r, [[-0.8, -0.68], [0.8, -0.68], [0.97, -0.4], [-0.97, -0.4]]), NINJA_CLOTH)
			ci.draw_colored_polygon(_pts(c, r, [[-0.18, -0.64], [0.18, -0.64], [0.18, -0.44], [-0.18, -0.44]]), METAL)
			var wave := sin(t * 6.0) * 0.08
			ci.draw_colored_polygon(_pts(c, r, [[0.88, -0.6], [1.45, -0.62 + wave], [1.32, -0.45 + wave], [0.9, -0.44]]), NINJA_CLOTH)
			ci.draw_colored_polygon(_pts(c, r, [[0.88, -0.52], [1.3, -0.25 - wave], [1.14, -0.14 - wave], [0.85, -0.42]]), NINJA_CLOTH)
			var mask: PackedVector2Array = []
			for i in 13:
				var a := deg_to_rad(8.0 + 164.0 * i / 12.0)
				mask.append(c + Vector2(cos(a), sin(a)) * r * 1.01)
			ci.draw_colored_polygon(mask, NINJA_CLOTH)
			ci.draw_line(c + Vector2(-0.82, 0.3) * r, c + Vector2(0.82, 0.3) * r, Color(1, 1, 1, 0.12), r * 0.06, true)
		K.WARRIOR:
			# 뿔 달린 투구
			var horn_l := _pts(c, r, [[-0.58, -0.74], [-1.02, -0.96], [-1.16, -1.38], [-1.3, -0.82], [-0.88, -0.44]])
			var horn_r := _pts(c, r, [[0.88, -0.44], [1.3, -0.82], [1.16, -1.38], [1.02, -0.96], [0.58, -0.74]])
			for h in [horn_l, horn_r]:
				ci.draw_colored_polygon(h, Color("#FFF1D6"))
				_outline(ci, h, Color("#C9A878"), r * 0.06)
			_dome(ci, c, r, METAL)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-1.0, -0.46) * r, Vector2(2.0, 0.16) * r), METAL_DARK, r * 0.08)
			ci.draw_circle(c + Vector2(-0.35, -0.78) * r, r * 0.09, Color(1, 1, 1, 0.6), true, -1.0, true)
		K.SOLDIER:
			# 둥근 철모
			var h := PackedVector2Array()
			for i in 15:
				var a := deg_to_rad(195.0 + 150.0 * i / 14.0)
				h.append(c + Vector2(cos(a), sin(a)) * r * 1.06)
			ci.draw_colored_polygon(h, HELMET)
			_outline(ci, h, HELMET.darkened(0.35), r * 0.06)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-1.12, -0.42) * r, Vector2(2.24, 0.17) * r), HELMET.darkened(0.2), r * 0.08)
			ci.draw_circle(c + Vector2(-0.4, -0.78) * r, r * 0.09, Color(1, 1, 1, 0.45), true, -1.0, true)
		K.ANGEL:
			# 금빛 고리
			var bob := sin(t * 3.0) * 0.06
			_ellipse_ring(ci, c + Vector2(0, -1.28 + bob) * r, Vector2(0.62, 0.2) * r, GOLD, maxf(2.0, r * 0.16))
		K.PRIEST:
			# 하얀 주교관 + 금 십자
			var m := _pts(c, r, [[-0.62, -0.6], [0.62, -0.6], [0.5, -1.25], [0.0, -1.62], [-0.5, -1.25]])
			ci.draw_colored_polygon(m, WHITE_SOFT)
			_outline(ci, m, Color("#D6C7A8"), r * 0.06)
			ci.draw_colored_polygon(_pts(c, r, [[-0.62, -0.6], [0.62, -0.6], [0.58, -0.78], [-0.58, -0.78]]), GOLD)
			ci.draw_line(c + Vector2(0, -0.86) * r, c + Vector2(0, -1.36) * r, GOLD.darkened(0.08), r * 0.13, true)
			ci.draw_line(c + Vector2(-0.2, -1.12) * r, c + Vector2(0.2, -1.12) * r, GOLD.darkened(0.08), r * 0.13, true)
		K.ROBOT:
			# 볼트 귀 + 얼굴 화면 테두리
			for sx in [-1.0, 1.0]:
				UIKit.draw_rbox(ci, Rect2(c + Vector2(sx * 1.0 - 0.14, -0.3) * r, Vector2(0.28, 0.5) * r), METAL_DARK, r * 0.1)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-0.72, -0.46) * r, Vector2(1.44, 0.12) * r), Color(1, 1, 1, 0.35), r * 0.06)
		K.ARCHITECT:
			# 노란 안전모
			var hh := PackedVector2Array()
			for i in 15:
				var a := deg_to_rad(198.0 + 144.0 * i / 14.0)
				hh.append(c + Vector2(cos(a), sin(a)) * r * 1.08)
			ci.draw_colored_polygon(hh, HARDHAT)
			_outline(ci, hh, HARDHAT.darkened(0.3), r * 0.06)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-1.2, -0.48) * r, Vector2(2.4, 0.18) * r), HARDHAT.darkened(0.12), r * 0.09)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-0.1, -1.08) * r, Vector2(0.2, 0.55) * r), HARDHAT.darkened(0.18), r * 0.06)
		K.KNIGHT:
			# 깃털 달린 투구
			var sway := sin(t * 3.0) * 0.06
			var plume := _pts(c, r, [[-0.12, -0.98], [0.12, -0.98], [0.34, -1.3], [0.72 + sway, -1.5], [0.42 + sway, -1.72],
				[0.05 + sway, -1.62], [-0.2, -1.3]])
			ci.draw_colored_polygon(plume, Color("#FF7EB6"))
			_outline(ci, plume, Color("#FF7EB6").darkened(0.3), r * 0.06)
			_dome(ci, c, r, METAL.lightened(0.1))
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-0.1, -0.98) * r, Vector2(0.2, 0.56) * r), METAL_DARK, r * 0.06)
			UIKit.draw_rbox(ci, Rect2(c + Vector2(-1.0, -0.46) * r, Vector2(2.0, 0.16) * r), GOLD.darkened(0.15), r * 0.08)


static func _rope(ci: CanvasItem, c: Vector2, r: float) -> void:
	var rope := Color("#C08A56")
	ci.draw_line(c + Vector2(-0.95, -0.2) * r, c + Vector2(0.95, 0.35) * r, rope.darkened(0.3), r * 0.2, true)
	ci.draw_line(c + Vector2(-0.95, -0.2) * r, c + Vector2(0.95, 0.35) * r, rope, r * 0.13, true)
	ci.draw_line(c + Vector2(-0.95, 0.4) * r, c + Vector2(0.95, -0.1) * r, rope.darkened(0.3), r * 0.2, true)
	ci.draw_line(c + Vector2(-0.95, 0.4) * r, c + Vector2(0.95, -0.1) * r, rope, r * 0.13, true)
	ci.draw_circle(c + Vector2(0, 0.08) * r, r * 0.16, rope.darkened(0.15), true, -1.0, true)


# ── 성 ─────────────────────────────────────────────────
## rect: 성 칸, lives: 남은 목숨 (1 이면 불, 0 이면 무너짐), hit: 0~1 흔들림
static func draw_castle(ci: CanvasItem, rect: Rect2, team: Color, lives: int, t: float, hit: float = 0.0, flag_on: bool = true) -> void:
	var s := rect.size.x
	var o := rect.position + Vector2(sin(hit * 40.0) * hit * s * 0.05, 0)
	var stone := Color("#D9D3E6") if lives > 0 else Color("#A7A1B3")
	var dark := stone.darkened(0.22)
	var base_y := s * 0.92
	# 양쪽 탑
	for tx in [0.08, 0.66]:
		var tr := Rect2(o + Vector2(tx * s, s * 0.22), Vector2(s * 0.26, base_y - s * 0.22))
		UIKit.draw_rbox(ci, Rect2(tr.position + Vector2(0, s * 0.04), tr.size), dark, s * 0.04)
		UIKit.draw_rbox(ci, tr, stone, s * 0.04)
		for k in 2:
			UIKit.draw_rbox(ci, Rect2(o + Vector2((tx + k * 0.15) * s, s * 0.14), Vector2(s * 0.1, s * 0.12)), stone, s * 0.02)
		UIKit.draw_rbox(ci, Rect2(o + Vector2((tx + 0.09) * s, s * 0.36), Vector2(s * 0.08, s * 0.12)), INK.lightened(0.2), s * 0.04)
	# 가운데 벽
	var wall := Rect2(o + Vector2(s * 0.2, s * 0.4), Vector2(s * 0.6, base_y - s * 0.4))
	UIKit.draw_rbox(ci, Rect2(wall.position + Vector2(0, s * 0.04), wall.size), dark, s * 0.04)
	UIKit.draw_rbox(ci, wall, stone, s * 0.04)
	for k in 3:
		UIKit.draw_rbox(ci, Rect2(o + Vector2((0.24 + k * 0.19) * s, s * 0.32), Vector2(s * 0.13, s * 0.12)), stone, s * 0.02)
	# 문
	var door := Rect2(o + Vector2(s * 0.39, s * 0.6), Vector2(s * 0.22, base_y - s * 0.6))
	UIKit.draw_rbox(ci, door, Color("#6B4A3A"), s * 0.1)
	# 깃발
	var pole := o + Vector2(s * 0.5, s * 0.34)
	ci.draw_line(pole, pole - Vector2(0, s * 0.32), INK, maxf(2.0, s * 0.025), true)
	if lives > 0 and flag_on:
		draw_flag(ci, pole, s, team, t)
	# 불 (목숨 1)
	if lives == 1:
		for fx in [0.2, 0.78]:
			_flame(ci, o + Vector2(fx * s, s * 0.16), s * 0.16, t + fx * 3.0)


## 성 깃발. pole: 깃대 아래쪽
static func draw_flag(ci: CanvasItem, pole: Vector2, s: float, team: Color, t: float) -> void:
	var w := sin(t * 4.0) * s * 0.03
	ci.draw_colored_polygon(PackedVector2Array([pole - Vector2(0, s * 0.32), pole + Vector2(s * 0.26, -s * 0.26 + w), pole - Vector2(0, s * 0.18)]), team)


static func _flame(ci: CanvasItem, p: Vector2, h: float, t: float) -> void:
	var k := 1.0 + 0.15 * sin(t * 9.0)
	var outer := PackedVector2Array([p + Vector2(-h * 0.45, 0), p + Vector2(-h * 0.3, -h * 0.7 * k), p + Vector2(0, -h * 1.25 * k),
		p + Vector2(h * 0.3, -h * 0.75 * k), p + Vector2(h * 0.45, 0), p + Vector2(0, h * 0.3)])
	ci.draw_colored_polygon(outer, Color("#FF7A3D"))
	var inner := PackedVector2Array([p + Vector2(-h * 0.22, 0), p + Vector2(0, -h * 0.7 * k), p + Vector2(h * 0.22, 0), p + Vector2(0, h * 0.18)])
	ci.draw_colored_polygon(inner, Color("#FFD54A"))


# ── 지뢰 · 하트 · 벽 ──────────────────────────────────
## 표창 (따라 한 모습의 닌자 표시)
static func _shuriken(ci: CanvasItem, c: Vector2, rad: float, t: float) -> void:
	var spin := sin(t * 1.5) * 0.15
	var pts := PackedVector2Array()
	for i in 8:
		var a := spin + TAU * i / 8.0 - PI / 2.0
		var d := rad if i % 2 == 0 else rad * 0.38
		pts.append(c + Vector2(cos(a), sin(a)) * d)
	ci.draw_colored_polygon(pts, METAL_DARK)
	_outline(ci, pts, METAL_DARK.darkened(0.4), maxf(1.0, rad * 0.12))
	ci.draw_circle(c, rad * 0.2, STONE.darkened(0.3), true, -1.0, true)
	ci.draw_circle(c + Vector2(-rad * 0.25, -rad * 0.35), rad * 0.12, Color(1, 1, 1, 0.5), true, -1.0, true)


## 포탑 (건축가가 빈 칸을 벽 네 개로 둘러싸면 생김): 돌 탑 + 팀 색 띠 · 깃발 + 깜빡이는 눈
static func draw_turret(ci: CanvasItem, c: Vector2, s: float, team: Color, t: float) -> void:
	var w := s * 0.5
	var h := s * 0.46
	var base := c + Vector2(0, s * 0.3)
	ci.draw_set_transform(base, 0.0, Vector2(1.0, 0.3))
	ci.draw_circle(Vector2.ZERO, s * 0.32, Color(0.2, 0.15, 0.2, 0.22), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Rect2(base + Vector2(-w * 0.5, -h), Vector2(w, h))
	var stone := STONE.lightened(0.12)
	UIKit.draw_rbox(ci, Rect2(body.position + Vector2(0, s * 0.03), body.size), STONE.darkened(0.3), s * 0.05)
	UIKit.draw_rbox(ci, body, stone, s * 0.05)
	for i in 3:
		var bx := body.position.x + w * (0.04 + i * 0.35)
		UIKit.draw_rbox(ci, Rect2(Vector2(bx, body.position.y - s * 0.08), Vector2(w * 0.24, s * 0.1)), stone, s * 0.02)
	UIKit.draw_rbox(ci, Rect2(body.position + Vector2(0, h * 0.16), Vector2(w, h * 0.16)), team, s * 0.02)
	var eye := body.position + Vector2(w * 0.5, h * 0.62)
	UIKit.draw_rbox(ci, Rect2(eye - Vector2(w * 0.17, h * 0.17), Vector2(w * 0.34, h * 0.32)), INK.lightened(0.15), s * 0.05)
	var glow := 0.55 + 0.45 * sin(t * 4.0)
	ci.draw_circle(eye, s * 0.05, Color(team.lightened(0.35), glow), true, -1.0, true)
	var pole := body.position + Vector2(w * 0.5, -s * 0.08)
	ci.draw_line(pole, pole - Vector2(0, s * 0.2), INK, maxf(1.5, s * 0.025), true)
	var wv := sin(t * 4.0) * s * 0.02
	ci.draw_colored_polygon(PackedVector2Array([pole - Vector2(0, s * 0.2), pole + Vector2(s * 0.16, -s * 0.16 + wv),
		pole - Vector2(0, s * 0.11)]), team)


## 지뢰: 팀 색 불이 깜빡임
static func mine_on(t: float) -> bool:
	return fmod(t * 1.6, 1.0) < 0.5


static func draw_mine(ci: CanvasItem, c: Vector2, s: float, team: Color, on: bool) -> void:
	var p := c + Vector2(s * 0.28, s * 0.26)
	var rad := s * 0.13
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		ci.draw_line(p, p + Vector2(cos(a), sin(a)) * rad * 1.45, Color("#3A3346"), maxf(1.5, s * 0.04), true)
	ci.draw_circle(p, rad, Color("#4A4258"), true, -1.0, true)
	ci.draw_circle(p + Vector2(-rad * 0.35, -rad * 0.35), rad * 0.3, Color(1, 1, 1, 0.3), true, -1.0, true)
	ci.draw_circle(p + Vector2(0, -rad * 0.1), rad * 0.42, team.lightened(0.25) if on else team.darkened(0.3), true, -1.0, true)


## 쓰러진 천사의 십자가: 흙더미에 꽂힌 하얀 십자가와 팀 색 띠, 위에는 금빛 고리
static func draw_cross(ci: CanvasItem, c: Vector2, s: float, team: Color, t: float) -> void:
	var line := maxf(2.0, s * 0.045)
	ci.draw_circle(c + Vector2(0, -s * 0.06), s * 0.4, Color(1.0, 0.95, 0.7, 0.2 + 0.07 * sin(t * 2.4)), true, -1.0, true)
	_ellipse(ci, c + Vector2(0, s * 0.31), Vector2(0.3, 0.1) * s, Color("#7A5A3C"))
	_ellipse(ci, c + Vector2(0, s * 0.29), Vector2(0.24, 0.07) * s, Color("#96724E"))
	var up := Rect2(c + Vector2(-0.075, -0.3) * s, Vector2(0.15, 0.6) * s)
	var side := Rect2(c + Vector2(-0.23, -0.16) * s, Vector2(0.46, 0.15) * s)
	var dark := Color("#8A7A5C")
	ci.draw_rect(up.grow(line * 0.6), dark)
	ci.draw_rect(side.grow(line * 0.6), dark)
	ci.draw_rect(up, Color("#FFF8E4"))
	ci.draw_rect(side, Color("#FFF8E4"))
	ci.draw_rect(Rect2(up.position, Vector2(up.size.x * 0.35, up.size.y)), Color(1, 1, 1, 0.9))
	# 팀 색 띠
	ci.draw_rect(Rect2(c + Vector2(-0.075, 0.03) * s, Vector2(0.15, 0.1) * s), team)
	ci.draw_rect(Rect2(c + Vector2(-0.075, 0.03) * s, Vector2(0.15, 0.1) * s), team.darkened(0.35), false, maxf(1.0, s * 0.02))
	_ellipse_ring(ci, c + Vector2(0, -s * (0.38 + 0.02 * sin(t * 2.4))), Vector2(0.15, 0.05) * s, GOLD, maxf(1.5, s * 0.04))


static func draw_heart(ci: CanvasItem, c: Vector2, s: float, full: bool = true, color: Color = HEART) -> void:
	## s = 하트 너비
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
		pts.append(c + Vector2(x, y) * s / 34.0)
	if full:
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(0, s * 0.07))
		ci.draw_colored_polygon(sh, color.darkened(0.3))
		ci.draw_colored_polygon(pts, color)
		ci.draw_circle(c + Vector2(-s * 0.2, -s * 0.12), s * 0.1, Color(1, 1, 1, 0.55), true, -1.0, true)
	else:
		ci.draw_colored_polygon(pts, Color(0.55, 0.5, 0.62, 0.35))
		_outline(ci, pts, Color(0.55, 0.5, 0.62, 0.7), maxf(1.5, s * 0.07))


## 하트 여러 개 한 줄 (가운데 정렬)
static func draw_hearts(ci: CanvasItem, center: Vector2, s: float, lives: int, max_lives: int) -> void:
	var gap := s * 1.12
	var x0 := center.x - gap * (max_lives - 1) / 2.0
	for i in max_lives:
		draw_heart(ci, Vector2(x0 + gap * i, center.y), s, i < lives)


## 벽: 두 칸 사이 변 (a → b 선분)
## tint: 포탑의 벽이면 포탑 주인 팀 색 (투명 = 보통 벽)
static func draw_wall(ci: CanvasItem, a: Vector2, b: Vector2, thick: float, pop: float = 1.0,
		tint: Color = Color(0, 0, 0, 0)) -> void:
	var k := clampf(pop, 0.0, 1.0)
	var mid := (a + b) / 2.0
	var aa := mid + (a - mid) * k
	var bb := mid + (b - mid) * k
	ci.draw_line(aa + Vector2(0, thick * 0.25), bb + Vector2(0, thick * 0.25), Color("#5B3C2A"), thick, true)
	ci.draw_line(aa, bb, Color("#B8754A").lerp(tint, tint.a * 0.75), thick * 0.78, true)
	ci.draw_line(aa + (bb - aa).normalized() * thick * 0.3 - Vector2(0, thick * 0.15),
		bb - (bb - aa).normalized() * thick * 0.3 - Vector2(0, thick * 0.15), Color(1, 1, 1, 0.3), thick * 0.18, true)
	for e in [aa, bb]:
		ci.draw_circle(e, thick * 0.5, Color("#5B3C2A"), true, -1.0, true)
		ci.draw_circle(e - Vector2(0, thick * 0.08), thick * 0.38, Color("#C98A5E"), true, -1.0, true)


# ── 도우미 ─────────────────────────────────────────────
static func _pts(c: Vector2, r: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(c + Vector2(p[0], p[1]) * r)
	return out


static func _outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


static func _ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, color: Color) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(radii.x / maxf(radii.y, 0.001), 1.0))
	ci.draw_circle(Vector2.ZERO, radii.y, color, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ellipse_ring(ci: CanvasItem, c: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_polyline(pts, color.darkened(0.2), width * 1.3, true)
	ci.draw_polyline(pts, color, width, true)


static func _dome(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 15:
		var a := deg_to_rad(198.0 + 144.0 * i / 14.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r * 1.05)
	ci.draw_colored_polygon(pts, color)
	_outline(ci, pts, METAL_DARK, r * 0.05)


static func _star(ci: CanvasItem, c: Vector2, rad: float, color: Color) -> void:
	if rad < 0.8:
		return
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		var rr := rad if i % 2 == 0 else rad * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)
