class_name DrawDoodles
extends RefCounted
## 그림 퀴즈 – AI가 그리는 낙서 그림 모음 (혼자 맞히기)
## 그림 하나 = 선(획) 여러 개. 좌표는 100 × 100 칸 안. 획마다 색이 있어요
## 새 그림을 넣으려면 WORDS 에 이름을 넣고 _build() 에 같은 이름으로 획을 추가하면 돼요

const K := Color("#3D3450")
const RED := Color("#FF5A5F")
const ORANGE := Color("#FF9F43")
const YELLOW := Color("#F5B700")
const GREEN := Color("#2FB36F")
const BLUE := Color("#4D96FF")
const SKY := Color("#45B8F0")
const BROWN := Color("#9A6A44")
const PINK := Color("#FF6FAE")
const PURPLE := Color("#8C6AE6")
const GREY := Color("#8E8A9C")

const WORDS := ["사과", "바나나", "집", "나무", "해", "달", "별", "구름", "우산", "자동차",
	"물고기", "고양이", "꽃", "하트", "눈사람", "컵", "안경", "열쇠", "연필", "시계",
	"아이스크림", "케이크", "돛단배", "비행기", "로켓", "전구", "텔레비전", "책", "왕관", "버섯",
	"달팽이", "나비", "피자", "수박", "무지개", "번개", "산", "선물", "풍선", "의자",
	"휴대폰", "문어", "거북이", "새", "종", "망치", "기타", "선인장", "당근"]

static var _cache := {}


## 그림의 획 목록 [{c: 색, p: PackedVector2Array}]
static func strokes(word: String) -> Array:
	if not _cache.has(word):
		_cache[word] = _build(word)
	return _cache[word]


## 그림 그리기. rect 안 가운데 정사각형에 맞춤. reveal: 0~1 (전체 선 길이 중 그린 만큼)
static func draw(ci: CanvasItem, st: Array, rect: Rect2, reveal: float, width: float) -> void:
	var side := minf(rect.size.x, rect.size.y)
	var o := rect.position + (rect.size - Vector2(side, side)) / 2.0
	var k := side / 100.0
	var budget := total_length(st) * clampf(reveal, 0.0, 1.0)
	for s in st:
		if budget <= 0.0:
			break
		var pts: PackedVector2Array = s["p"]
		var col: Color = s["c"]
		var out := PackedVector2Array([o + pts[0] * k])
		for i in range(1, pts.size()):
			var seg := pts[i - 1].distance_to(pts[i])
			if seg <= budget:
				out.append(o + pts[i] * k)
				budget -= seg
			else:
				out.append(o + pts[i - 1].lerp(pts[i], budget / maxf(seg, 0.001)) * k)
				budget = 0.0
				break
		if out.size() >= 2:
			ci.draw_polyline(out, col, width, true)
		ci.draw_circle(out[0], width * 0.5, col, true, -1.0, true)
		ci.draw_circle(out[out.size() - 1], width * 0.5, col, true, -1.0, true)


## 지금 펜 끝 위치 (그리는 중인 곳)
static func tip(st: Array, rect: Rect2, reveal: float) -> Vector2:
	var side := minf(rect.size.x, rect.size.y)
	var o := rect.position + (rect.size - Vector2(side, side)) / 2.0
	var k := side / 100.0
	var budget := total_length(st) * clampf(reveal, 0.0, 1.0)
	var last := Vector2(50, 50)
	for s in st:
		var pts: PackedVector2Array = s["p"]
		last = pts[0]
		for i in range(1, pts.size()):
			var seg := pts[i - 1].distance_to(pts[i])
			if seg >= budget:
				return o + pts[i - 1].lerp(pts[i], budget / maxf(seg, 0.001)) * k
			budget -= seg
			last = pts[i]
	return o + last * k


static func total_length(st: Array) -> float:
	var t := 0.0
	for s in st:
		var pts: PackedVector2Array = s["p"]
		for i in range(1, pts.size()):
			t += pts[i - 1].distance_to(pts[i])
	return t


# ── 획 만들기 도우미 ───────────────────────────────────
static func _s(c: Color, p: PackedVector2Array) -> Dictionary:
	return {"c": c, "p": p}


## [x1, y1, x2, y2, …] → 꺾은선. closed 면 처음 점으로 돌아옴
static func _l(flat: Array, closed: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	if closed:
		out.append(out[0])
	return out


## 원호 (도 단위, 0 = 오른쪽, 90 = 아래)
static func _arc(cx: float, cy: float, r: float, a0: float = 0.0, a1: float = 360.0, rx: float = -1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rr := rx if rx > 0.0 else r
	var segs := maxi(8, int(absf(a1 - a0) / 12.0))
	for i in segs + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / segs))
		out.append(Vector2(cx + cos(a) * rr, cy + sin(a) * r))
	return out


static func _join(a: PackedVector2Array, b: PackedVector2Array, closed: bool = false) -> PackedVector2Array:
	var out := a.duplicate()
	out.append_array(b)
	if closed:
		out.append(a[0])
	return out


static func _rev(a: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(a.size() - 1, -1, -1):
		out.append(a[i])
	return out


static func _box(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return _l([x0, y0, x1, y0, x1, y1, x0, y1], true)


static func _wavy(cx: float, cy: float, r: float, bumps: int, amp: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		var rr := r + amp * sin(a * bumps)
		out.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
	return out


# ── 그림들 ─────────────────────────────────────────────
static func _build(w: String) -> Array:
	match w:
		"사과":
			return [_s(RED, _join(_arc(50, 58, 30, 285, 615), PackedVector2Array())), _s(BROWN, _l([50, 33, 53, 16])),
				_s(GREEN, _l([54, 26, 64, 16, 74, 18, 66, 27, 54, 26]))]
		"바나나":
			return [_s(YELLOW, _join(_arc(50, 22, 40, 20, 160), _rev(_arc(50, 18, 32, 35, 145)), true)),
				_s(BROWN, _l([86, 34, 90, 30]))]
		"집":
			return [_s(BROWN, _l([16, 48, 50, 18, 84, 48])), _s(K, _box(24, 46, 76, 86)), _s(ORANGE, _box(44, 62, 56, 86)),
				_s(SKY, _box(30, 54, 40, 64)), _s(SKY, _l([35, 54, 35, 64])), _s(SKY, _l([30, 59, 40, 59]))]
		"나무":
			return [_s(GREEN, _wavy(50, 40, 26, 7, 4)), _s(BROWN, _l([44, 64, 42, 92, 58, 92, 56, 64]))]
		"해":
			var st := [_s(ORANGE, _arc(50, 50, 17))]
			for i in 8:
				var a := TAU * i / 8.0
				st.append(_s(YELLOW, _l([50 + cos(a) * 25, 50 + sin(a) * 25, 50 + cos(a) * 38, 50 + sin(a) * 38])))
			return st
		"달":
			return [_s(YELLOW, _join(_arc(50, 50, 30, 70, 290), _arc(66, 50, 28.8, 258.6, 101.4), true))]
		"별":
			var p := PackedVector2Array()
			for i in 11:
				var a := -PI / 2.0 + PI * i / 5.0
				var r := 38.0 if i % 2 == 0 else 16.0
				p.append(Vector2(50 + cos(a) * r, 54 + sin(a) * r))
			return [_s(YELLOW, p)]
		"구름":
			var p := _arc(76, 57, 8, 90, -90)
			p.append_array(_arc(58, 46, 15, -5, -175))
			p.append_array(_arc(36, 50, 12, -40, -180))
			p.append_array(_arc(24, 58, 8, -90, -270))
			p.append(Vector2(76, 65))
			return [_s(SKY, p)]
		"우산":
			return [_s(PINK, _join(_arc(50, 52, 36, 180, 360), _join(_arc(74, 52, 12, 0, -180), _join(_arc(50, 52, 12, 0, -180), _arc(26, 52, 12, 0, -180))))),
				_s(K, _join(_l([50, 40, 50, 82]), _arc(44, 82, 6, 0, 180)))]
		"자동차":
			return [_s(RED, _l([12, 70, 12, 55, 26, 52, 36, 36, 66, 36, 76, 52, 88, 55, 88, 70, 12, 70])),
				_s(SKY, _l([40, 40, 50, 40, 50, 51, 33, 51], true)), _s(SKY, _l([54, 40, 64, 40, 71, 51, 54, 51], true)),
				_s(K, _arc(30, 72, 9)), _s(K, _arc(70, 72, 9))]
		"물고기":
			return [_s(BLUE, _arc(44, 50, 16, 0, 360, 28)), _s(BLUE, _l([70, 50, 90, 34, 90, 66, 70, 50])),
				_s(K, _arc(28, 46, 2.5)), _s(BLUE, _l([40, 38, 48, 28, 54, 36]))]
		"고양이":
			return [_s(ORANGE, _arc(50, 56, 26, -60, 240)), _s(ORANGE, _l([37, 34, 30, 14, 46, 30, 54, 30, 70, 14, 63, 34])),
				_s(K, _arc(41, 53, 3)), _s(K, _arc(59, 53, 3)), _s(PINK, _l([47, 60, 53, 60, 50, 64, 47, 60])),
				_s(K, _l([38, 63, 16, 59])), _s(K, _l([38, 67, 16, 70])), _s(K, _l([62, 63, 84, 59])), _s(K, _l([62, 67, 84, 70]))]
		"꽃":
			var st := [_s(GREEN, _l([50, 50, 50, 94])), _s(GREEN, _l([50, 78, 64, 68, 70, 72, 52, 82]))]
			for i in 6:
				var a := TAU * i / 6.0
				st.append(_s(PINK, _arc(50 + cos(a) * 15, 34 + sin(a) * 15, 9)))
			st.append(_s(YELLOW, _arc(50, 34, 7)))
			return st
		"하트":
			var p := PackedVector2Array()
			for i in 41:
				var t := TAU * i / 40.0
				p.append(Vector2(50 + 16.0 * pow(sin(t), 3) * 2.3, 48 - (13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)) * 2.3))
			return [_s(RED, p)]
		"눈사람":
			return [_s(SKY, _arc(50, 70, 21)), _s(SKY, _arc(50, 36, 14)), _s(K, _arc(45, 33, 2)), _s(K, _arc(55, 33, 2)),
				_s(ORANGE, _l([50, 38, 63, 40, 50, 42])), _s(BROWN, _l([31, 64, 14, 52])), _s(BROWN, _l([69, 64, 86, 52])),
				_s(K, _arc(50, 64, 2)), _s(K, _arc(50, 74, 2))]
		"컵":
			return [_s(BLUE, _l([28, 36, 32, 84, 68, 84, 72, 36, 28, 36])), _s(BLUE, _arc(72, 58, 11, -80, 80)),
				_s(GREY, _l([42, 28, 38, 22, 42, 16, 38, 10])), _s(GREY, _l([56, 28, 52, 22, 56, 16, 52, 10]))]
		"안경":
			return [_s(K, _arc(31, 52, 14)), _s(K, _arc(69, 52, 14)), _s(K, _l([45, 50, 50, 46, 55, 50])),
				_s(K, _l([17, 50, 7, 42])), _s(K, _l([83, 50, 93, 42]))]
		"열쇠":
			return [_s(YELLOW, _arc(26, 50, 14)), _s(YELLOW, _arc(26, 50, 5)), _s(YELLOW, _l([40, 50, 90, 50])),
				_s(YELLOW, _l([80, 50, 80, 62])), _s(YELLOW, _l([70, 50, 70, 58]))]
		"연필":
			return [_s(YELLOW, _l([16, 42, 70, 42, 70, 58, 16, 58], true)), _s(ORANGE, _l([70, 42, 90, 50, 70, 58])),
				_s(K, _l([84, 47, 90, 50, 84, 53])), _s(PINK, _l([16, 42, 8, 42, 8, 58, 16, 58]))]
		"시계":
			var st := [_s(K, _arc(50, 50, 34))]
			for i in 12:
				var a := TAU * i / 12.0
				st.append(_s(K, _l([50 + cos(a) * 28, 50 + sin(a) * 28, 50 + cos(a) * 32, 50 + sin(a) * 32])))
			st.append(_s(RED, _l([50, 50, 50, 26])))
			st.append(_s(RED, _l([50, 50, 66, 58])))
			return st
		"아이스크림":
			return [_s(ORANGE, _l([32, 50, 68, 50, 50, 94, 32, 50])), _s(ORANGE, _l([40, 60, 60, 60])), _s(ORANGE, _l([44, 72, 56, 72])),
				_s(PINK, _join(_arc(50, 40, 19, 165, 375), PackedVector2Array())), _s(PINK, _l([31, 46, 38, 52, 44, 47, 50, 53, 56, 47, 62, 52, 69, 46]))]
		"케이크":
			return [_s(PINK, _box(18, 62, 82, 88)), _s(PINK, _box(28, 44, 72, 62)), _s(BLUE, _l([40, 44, 40, 30])),
				_s(BLUE, _l([50, 44, 50, 28])), _s(BLUE, _l([60, 44, 60, 30])), _s(ORANGE, _l([40, 26, 38, 22, 40, 18, 42, 22, 40, 26])),
				_s(ORANGE, _l([50, 24, 48, 20, 50, 16, 52, 20, 50, 24])), _s(ORANGE, _l([60, 26, 58, 22, 60, 18, 62, 22, 60, 26]))]
		"돛단배":
			return [_s(BROWN, _l([12, 66, 88, 66, 74, 84, 26, 84, 12, 66])), _s(K, _l([50, 66, 50, 12])),
				_s(RED, _l([53, 16, 53, 60, 82, 60, 53, 16])), _s(SKY, _l([6, 92, 18, 88, 30, 92, 42, 88, 54, 92, 66, 88, 78, 92, 90, 88]))]
		"비행기":
			return [_s(GREY, _arc(50, 50, 8, 0, 360, 40)), _s(BLUE, _l([44, 46, 30, 18, 40, 18, 58, 46])),
				_s(BLUE, _l([44, 54, 30, 82, 40, 82, 58, 54])), _s(BLUE, _l([16, 46, 10, 32, 18, 32, 26, 44])),
				_s(K, _arc(66, 49, 2)), _s(K, _arc(74, 49, 2))]
		"로켓":
			return [_s(K, _l([50, 8, 62, 26, 62, 70, 38, 70, 38, 26, 50, 8])), _s(BLUE, _arc(50, 36, 6)),
				_s(RED, _l([38, 54, 26, 74, 38, 70])), _s(RED, _l([62, 54, 74, 74, 62, 70])), _s(ORANGE, _l([42, 72, 50, 94, 58, 72]))]
		"전구":
			var st := [_s(YELLOW, _arc(50, 40, 22, 130, 410)), _s(K, _l([36, 57, 42, 68, 58, 68, 64, 57])),
				_s(K, _l([42, 74, 58, 74])), _s(K, _l([44, 80, 56, 80]))]
			for a in [200, 240, 270, 300, 340]:
				var r := deg_to_rad(a)
				st.append(_s(ORANGE, _l([50 + cos(r) * 28, 40 + sin(r) * 28, 50 + cos(r) * 36, 40 + sin(r) * 36])))
			return st
		"텔레비전":
			return [_s(K, _box(14, 30, 86, 78)), _s(SKY, _box(20, 36, 70, 72)), _s(K, _arc(78, 44, 3)), _s(K, _arc(78, 56, 3)),
				_s(K, _l([40, 30, 28, 12])), _s(K, _l([60, 30, 72, 12])), _s(K, _l([26, 78, 22, 88])), _s(K, _l([74, 78, 78, 88]))]
		"책":
			return [_s(BLUE, _l([50, 30, 14, 24, 14, 76, 50, 82, 86, 76, 86, 24, 50, 30, 50, 82])),
				_s(GREY, _l([22, 38, 42, 42])), _s(GREY, _l([22, 50, 42, 54])), _s(GREY, _l([58, 42, 78, 38])), _s(GREY, _l([58, 54, 78, 50]))]
		"왕관":
			return [_s(YELLOW, _l([16, 74, 16, 34, 33, 56, 50, 26, 67, 56, 84, 34, 84, 74, 16, 74])),
				_s(RED, _arc(33, 65, 4)), _s(BLUE, _arc(50, 65, 4)), _s(GREEN, _arc(67, 65, 4))]
		"버섯":
			return [_s(RED, _join(_arc(50, 54, 34, 180, 360), _l([84, 54, 16, 54]))), _s(BROWN, _l([40, 54, 38, 88, 62, 88, 60, 54])),
				_s(ORANGE, _arc(36, 42, 5)), _s(ORANGE, _arc(55, 32, 6)), _s(ORANGE, _arc(68, 44, 4))]
		"달팽이":
			var p := PackedVector2Array()
			for i in 61:
				var t := i / 60.0
				var a := t * TAU * 2.6
				var r := 24.0 * (1.0 - t * 0.85)
				p.append(Vector2(56 + cos(a) * r, 48 + sin(a) * r))
			return [_s(ORANGE, p), _s(GREEN, _l([12, 74, 90, 74, 84, 68, 76, 68])), _s(GREEN, _l([22, 74, 18, 54, 26, 52, 30, 72])),
				_s(GREEN, _l([20, 54, 12, 40])), _s(GREEN, _l([25, 53, 28, 38]))]
		"나비":
			return [_s(PURPLE, _arc(34, 38, 18, 0, 360, 15)), _s(PURPLE, _arc(66, 38, 18, 0, 360, 15)),
				_s(PINK, _arc(37, 66, 12, 0, 360, 11)), _s(PINK, _arc(63, 66, 12, 0, 360, 11)), _s(K, _l([50, 26, 50, 80])),
				_s(K, _l([50, 26, 42, 12])), _s(K, _l([50, 26, 58, 12]))]
		"피자":
			return [_s(ORANGE, _l([18, 22, 82, 22, 50, 90, 18, 22])), _s(BROWN, _l([14, 17, 86, 17])),
				_s(RED, _arc(40, 36, 6)), _s(RED, _arc(60, 40, 6)), _s(RED, _arc(50, 60, 5))]
		"수박":
			return [_s(GREEN, _join(_arc(50, 38, 40, 0, 180), _l([10, 38, 90, 38]))), _s(RED, _arc(50, 38, 32, 0, 180)),
				_s(K, _l([38, 50, 37, 54])), _s(K, _l([50, 56, 50, 60])), _s(K, _l([62, 50, 63, 54])), _s(K, _l([44, 63, 44, 67])), _s(K, _l([56, 63, 56, 67]))]
		"무지개":
			return [_s(RED, _arc(50, 80, 42, 180, 360)), _s(ORANGE, _arc(50, 80, 35, 180, 360)), _s(YELLOW, _arc(50, 80, 28, 180, 360)),
				_s(GREEN, _arc(50, 80, 21, 180, 360)), _s(BLUE, _arc(50, 80, 14, 180, 360))]
		"번개":
			return [_s(YELLOW, _l([58, 6, 28, 52, 48, 52, 36, 94, 76, 40, 54, 40, 68, 6, 58, 6]))]
		"산":
			return [_s(GREEN, _l([6, 84, 36, 32, 52, 58, 66, 40, 94, 84, 6, 84])), _s(SKY, _l([27, 46, 36, 32, 45, 46, 40, 42, 36, 47, 31, 42, 27, 46]))]
		"선물":
			return [_s(RED, _box(20, 46, 80, 88)), _s(RED, _box(15, 34, 85, 46)), _s(YELLOW, _l([50, 34, 50, 88])),
				_s(YELLOW, _arc(40, 27, 7, 0, 360, 10)), _s(YELLOW, _arc(60, 27, 7, 0, 360, 10))]
		"풍선":
			return [_s(RED, _arc(50, 38, 28, 0, 360, 23)), _s(RED, _l([46, 70, 54, 70, 50, 66, 46, 70])),
				_s(K, _l([50, 70, 45, 78, 54, 86, 48, 95]))]
		"의자":
			return [_s(BROWN, _l([30, 56, 30, 14, 70, 14, 70, 56])), _s(BROWN, _l([30, 30, 70, 30])), _s(BROWN, _l([22, 56, 78, 56])),
				_s(BROWN, _l([26, 56, 22, 90])), _s(BROWN, _l([74, 56, 78, 90]))]
		"휴대폰":
			return [_s(K, _box(30, 8, 70, 92)), _s(SKY, _box(34, 18, 66, 78)), _s(K, _arc(50, 85, 3)), _s(K, _l([44, 13, 56, 13]))]
		"문어":
			var st := [_s(PURPLE, _join(_arc(50, 38, 24, 160, 380), PackedVector2Array())), _s(K, _arc(42, 38, 3)), _s(K, _arc(58, 38, 3))]
			for i in 6:
				var x := 30.0 + i * 8.0
				st.append(_s(PURPLE, _l([x, 50, x - 4, 62, x + 2, 72, x - 3, 84])))
			return st
		"거북이":
			return [_s(GREEN, _join(_arc(48, 62, 30, 180, 360), _l([78, 62, 18, 62]))), _s(GREEN, _l([36, 62, 40, 44, 56, 44, 60, 62])),
				_s(GREEN, _arc(86, 56, 7)), _s(GREEN, _l([26, 62, 24, 74, 32, 74])), _s(GREEN, _l([64, 62, 66, 74, 72, 74])),
				_s(GREEN, _l([18, 60, 10, 66]))]
		"새":
			return [_s(SKY, _arc(46, 54, 22)), _s(SKY, _l([34, 54, 46, 66, 58, 54])), _s(ORANGE, _l([66, 48, 80, 52, 66, 57])),
				_s(K, _arc(56, 46, 2.5)), _s(ORANGE, _l([40, 76, 38, 88])), _s(ORANGE, _l([52, 76, 54, 88]))]
		"종":
			return [_s(YELLOW, _l([30, 72, 32, 42, 50, 24, 68, 42, 70, 72])), _s(YELLOW, _l([22, 72, 78, 72])),
				_s(K, _arc(50, 79, 5)), _s(YELLOW, _arc(50, 19, 5))]
		"망치":
			return [_s(BROWN, _l([28, 90, 56, 34])), _s(GREY, _l([38, 24, 70, 12, 76, 28, 44, 40, 38, 24]))]
		"기타":
			return [_s(ORANGE, _arc(40, 68, 18)), _s(ORANGE, _arc(54, 48, 13)), _s(K, _arc(46, 60, 5)),
				_s(BROWN, _l([60, 42, 84, 14])), _s(BROWN, _box(80, 6, 90, 16)), _s(K, _l([34, 76, 82, 18]))]
		"선인장":
			return [_s(GREEN, _l([40, 92, 40, 26, 50, 16, 60, 26, 60, 92])), _s(GREEN, _l([40, 62, 26, 62, 26, 42])),
				_s(GREEN, _l([60, 54, 74, 54, 74, 36])), _s(BROWN, _l([28, 92, 72, 92]))]
		"당근":
			return [_s(ORANGE, _l([36, 32, 64, 32, 50, 94, 36, 32])), _s(ORANGE, _l([42, 48, 50, 48])), _s(ORANGE, _l([48, 66, 54, 66])),
				_s(GREEN, _l([44, 32, 36, 10])), _s(GREEN, _l([50, 32, 50, 6])), _s(GREEN, _l([56, 32, 64, 10]))]
	return [_s(K, _arc(50, 50, 30))]
