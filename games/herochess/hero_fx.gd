class_name HeroFx
extends RefCounted
## 히어로 체스 공격 · 능력 효과 그리기 (돌진 · 베기 · 빛기둥 · 파이어볼 · 십자 · 충격파 · 낫 · 유령 소용돌이 …)
## HeroBoard 가 효과마다 매 프레임 부름. 위치와 크기는 화면 좌표로 받아요


## kind: 효과 이름, pa → pb: 화면 위치, s: 크기(칸의 1.2배), k: 0 → 1 진행
static func draw(ci: CanvasItem, kind: String, pa: Vector2, pb: Vector2, s: float, k: float, col: Color) -> void:
	var fade := 1.0 - k
	match kind:
		"ring":
			ci.draw_arc(pa, s * (0.2 + 0.5 * k), 0, TAU, 32, Color(col, fade), 6.0 * fade + 1.0, true)
		"burst":
			if k < 0.3:
				ci.draw_circle(pa, s * 0.45 * (k / 0.3), Color(1, 1, 0.85, 0.7 * (1.0 - k / 0.3)), true, -1.0, true)
			for i in 8:
				var ang := TAU * i / 8.0 + 0.2
				var d := Vector2(cos(ang), sin(ang))
				ci.draw_line(pa + d * s * (0.15 + 0.35 * k), pa + d * s * (0.3 + 0.55 * k), Color(col, fade), maxf(2.0, s * 0.09 * fade), true)
			for i in 4:
				var ang2 := TAU * i / 4.0 + k * 2.0
				HeroArt._star(ci, pa + Vector2(cos(ang2), sin(ang2)) * s * (0.3 + 0.5 * k), s * 0.12 * fade, Color(Color.WHITE, fade))
		"lance":
			var e := clampf(k / 0.6, 0.0, 1.0)
			var tip := pa.lerp(pb, e)
			ci.draw_line(pa.lerp(pb, maxf(0.0, e - 0.45)), tip, Color(col, 0.9 * fade), s * 0.12, true)
			ci.draw_line(pa.lerp(pb, maxf(0.0, e - 0.3)), tip, Color(1, 1, 1, 0.8 * fade), s * 0.05, true)
		"fireball":
			var e2 := clampf(k / 0.55, 0.0, 1.0)
			if k < 0.55:
				var bp := pa.lerp(pb, e2)
				for i in 5:
					var tp := pa.lerp(pb, maxf(0.0, e2 - (i + 1) * 0.07))
					ci.draw_circle(tp, s * 0.12 * (1.0 - i * 0.17), Color(1.0, 0.45 + i * 0.08, 0.15, 0.55 - i * 0.1), true, -1.0, true)
				ci.draw_circle(bp, s * 0.18, Color(1.0, 0.5, 0.15), true, -1.0, true)
				ci.draw_circle(bp, s * 0.1, Color(1.0, 0.92, 0.45), true, -1.0, true)
			else:
				var kk := (k - 0.55) / 0.45
				ci.draw_circle(pb, s * 0.6 * minf(1.0, kk * 1.6), Color(1.0, 0.5, 0.15, 0.75 * (1.0 - kk)), true, -1.0, true)
				ci.draw_circle(pb, s * 0.35 * minf(1.0, kk * 1.6), Color(1.0, 0.9, 0.4, 0.85 * (1.0 - kk)), true, -1.0, true)
				for i in 8:
					var ang := TAU * i / 8.0 + 0.3
					ci.draw_circle(pb + Vector2(cos(ang), sin(ang)) * s * (0.3 + 0.4 * kk), s * 0.06 * (1.0 - kk) + 0.5, Color(1.0, 0.7, 0.3, 1.0 - kk), true, -1.0, true)
		"crosshit":
			# 성직자: 금빛 십자가를 들어 옆 칸을 내려침
			var eh := clampf(k / 0.45, 0.0, 1.0)
			var turn := lerpf(-1.3, 0.3, eh * eh) * (-1.0 if pb.x < pa.x else 1.0)
			ci.draw_set_transform(pa.lerp(pb, 0.3 + 0.7 * eh), turn, Vector2.ONE)
			var al := 1.0 if k < 0.6 else (1.0 - k) / 0.4
			for grow: float in [0.035, 0.0]:
				var cc := Color(col.darkened(0.45), al) if grow > 0.0 else Color(col, al)
				ci.draw_rect(Rect2(Vector2(-0.07, -0.42) * s, Vector2(0.14, 0.72) * s).grow(s * grow), cc)
				ci.draw_rect(Rect2(Vector2(-0.24, -0.24) * s, Vector2(0.48, 0.14) * s).grow(s * grow), cc)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if k > 0.4:
				var hk := (k - 0.4) / 0.6
				ci.draw_arc(pb, s * (0.2 + 0.45 * hk), 0, TAU, 32, Color(1.0, 0.95, 0.7, 1.0 - hk), s * 0.1 * (1.0 - hk) + 1.0, true)
		"slash":
			for j in 2:
				var kk := clampf((k - j * 0.25) / 0.5, 0.0, 1.0)
				if kk <= 0.0:
					continue
				var start := -PI * 0.75 + j * PI * 0.5
				var sweep := PI * 0.9 * kk
				var cc := pa + Vector2(-s * 0.3 if j == 0 else s * 0.3, s * 0.3)
				ci.draw_arc(cc, s * 0.55, start, start + sweep, 16, Color(0.55, 0.8, 1.0, (1.0 - kk) * 0.8), s * 0.2 * (1.0 - kk * 0.5), true)
				ci.draw_arc(cc, s * 0.55, start, start + sweep, 16, Color(col, (1.0 - kk) * 0.95 + 0.05), s * 0.1 * (1.0 - kk * 0.5), true)
		"shock":
			ci.draw_arc(pa + Vector2(0, s * 0.2), s * (0.15 + 0.7 * k), 0, TAU, 36, Color(col, fade), s * 0.12 * fade + 1.0, true)
			for i in 6:
				var ang := TAU * i / 6.0 + 0.5
				var d := Vector2(cos(ang), sin(ang) * 0.6)
				var ln := s * 0.5 * minf(1.0, k * 3.0)
				ci.draw_line(pa + Vector2(0, s * 0.2), pa + Vector2(0, s * 0.2) + d * ln, Color(0.35, 0.22, 0.12, 0.8 * fade), maxf(2.0, s * 0.05), true)
				var rock := pa + d * s * (0.2 + 0.6 * k) + Vector2(0, -s * 0.8 * sin(k * PI))
				ci.draw_rect(Rect2(rock - Vector2(s, s) * 0.04, Vector2(s, s) * 0.08), Color(0.5, 0.35, 0.22, fade))
		"holy":
			var top := pa - Vector2(0, s * 2.2)
			var w := s * 0.6 * (1.0 - absf(k - 0.4))
			var beam := PackedVector2Array([top - Vector2(w * 0.4, 0), top + Vector2(w * 0.4, 0), pa + Vector2(w, s * 0.3), pa + Vector2(-w, s * 0.3)])
			ci.draw_colored_polygon(beam, Color(col, 0.45 * fade))
			ci.draw_circle(pa + Vector2(0, s * 0.25), s * 0.4 * (0.5 + k), Color(1, 0.95, 0.6, 0.5 * fade), true, -1.0, true)
			for i in 4:
				var fx_x := sin(k * 6.0 + i * 1.7) * s * 0.4
				var fp := pa + Vector2(fx_x, -s * 1.2 + s * 1.4 * k + i * s * 0.15)
				ci.draw_set_transform(fp, k * 3.0 + i, Vector2(1.0, 0.45))
				ci.draw_circle(Vector2.ZERO, s * 0.1, Color(1, 1, 1, fade), true, -1.0, true)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"stars":
			for i in 7:
				var ang := TAU * i / 7.0 + k * 4.0
				var dist := s * (0.1 + 0.6 * k)
				var c2: Color = [Color("#FF7EB6"), Color("#B48CFF"), HeroBoard.GOLD][i % 3]
				HeroArt._star(ci, pa + Vector2(cos(ang), sin(ang)) * dist, s * 0.16 * (1.0 - k * 0.6), Color(c2, fade))
			ci.draw_circle(pa, s * 0.25 * (1.0 - k), Color(1, 1, 1, 0.6 * fade), true, -1.0, true)
		"swirl":
			for j in 3:
				var pts := PackedVector2Array()
				for i in 16:
					var t := i / 15.0
					var ang := t * PI * 1.5 + j * TAU / 3.0 + k * 6.0
					pts.append(pa + Vector2(cos(ang), sin(ang) * 0.6) * s * (0.12 + 0.35 * t) * (0.6 + 0.6 * k))
				ci.draw_polyline(pts, Color(col, fade), maxf(2.0, s * 0.06), true)
		"cross":
			var g := s * (0.25 + 0.4 * minf(1.0, k * 2.5))
			ci.draw_line(pa - Vector2(0, g), pa + Vector2(0, g), Color(col, fade), s * 0.16, true)
			ci.draw_line(pa - Vector2(g * 0.65, g * 0.3), pa + Vector2(g * 0.65, -g * 0.3), Color(col, fade), s * 0.16, true)
			ci.draw_line(pa - Vector2(0, g), pa + Vector2(0, g), Color(1, 1, 1, fade), s * 0.06, true)
			for i in 6:
				var ang := TAU * i / 6.0
				ci.draw_circle(pa + Vector2(cos(ang), sin(ang)) * s * (0.3 + 0.4 * k), s * 0.04 * fade + 0.5, Color(1, 0.95, 0.6, fade), true, -1.0, true)
		"reap":
			var sweep := minf(1.0, k * 2.0)
			ci.draw_arc(pa + Vector2(s * 0.1, -s * 0.05), s * 0.5, -PI * 0.9, -PI * 0.9 + PI * 1.2 * sweep, 20, Color(HeroBoard.PURPLE_DARK, fade), s * 0.14, true)
			ci.draw_arc(pa + Vector2(s * 0.1, -s * 0.05), s * 0.42, -PI * 0.85, -PI * 0.85 + PI * 1.1 * sweep, 20, Color(0.85, 0.75, 1.0, fade), s * 0.05, true)
			if k > 0.3:
				var kk := (k - 0.3) / 0.7
				var soul := pa - Vector2(0, s * 0.9 * kk)
				ci.draw_circle(soul, s * 0.14, Color(1, 1, 1, 0.75 * (1.0 - kk)), true, -1.0, true)
				ci.draw_circle(soul + Vector2(sin(kk * 9.0) * s * 0.06, s * 0.16), s * 0.08, Color(1, 1, 1, 0.5 * (1.0 - kk)), true, -1.0, true)
		"spook":
			var pts := PackedVector2Array()
			for i in 30:
				var t := i / 29.0
				var ang := t * TAU * 2.0 - k * 8.0
				pts.append(pa + Vector2(cos(ang), sin(ang)) * s * 0.55 * t * (1.0 - k * 0.5))
			ci.draw_circle(pa, s * 0.4 * (1.0 - k * 0.5), Color(0.3, 0.1, 0.45, 0.35 * fade), true, -1.0, true)
			ci.draw_polyline(pts, Color(col, fade), maxf(3.0, s * 0.1), true)
		"smoke":
			for i in 6:
				var ang := TAU * i / 6.0 + 0.4
				var pp := pa + Vector2(cos(ang), sin(ang) * 0.6) * s * (0.15 + 0.3 * k) + Vector2(0, s * 0.15)
				ci.draw_circle(pp, s * (0.12 + 0.12 * k), Color(0.82, 0.82, 0.88, 0.8 * fade), true, -1.0, true)
		"dust":
			for i in 3:
				var pp := pa + Vector2((i - 1) * s * 0.25, s * 0.3 - s * 0.15 * k)
				ci.draw_circle(pp, s * (0.08 + 0.1 * k), Color(0.95, 0.9, 0.78, 0.7 * fade), true, -1.0, true)
		"spark":
			for j in 4:
				var ang := TAU * j / 4.0 + k * 3.0
				var p0 := pa + Vector2(cos(ang), sin(ang)) * s * 0.2
				var pts := PackedVector2Array([p0])
				for i in 3:
					pts.append(p0 + Vector2(cos(ang), sin(ang)) * s * 0.12 * (i + 1) + Vector2(-sin(ang), cos(ang)) * s * (0.08 if i % 2 == 0 else -0.08))
				ci.draw_polyline(pts, Color(col, fade), maxf(2.0, s * 0.05), true)
		"build", "crumble":
			pa = (pa + pb) / 2.0
			var drop := kind == "crumble"
			for i in 6:
				var ang := -PI * 0.5 + (i - 2.5) * 0.45
				var v := Vector2(cos(ang), sin(ang)) * s * 0.6 * k
				var pp := pa + v + Vector2(0, (s * 0.9 * k * k) if drop else (-s * 0.3 * sin(k * PI)))
				ci.draw_rect(Rect2(pp - Vector2(s * 0.06, s * 0.04), Vector2(s * 0.12, s * 0.08)), Color(Color("#B8754A"), fade))
			for i in 3:
				ci.draw_circle(pa + Vector2((i - 1) * s * 0.3, s * 0.1), s * (0.1 + 0.12 * k), Color(0.92, 0.86, 0.74, 0.6 * fade), true, -1.0, true)
		"boom":
			var e := minf(1.0, k * 3.0)
			ci.draw_circle(pa, s * 0.7 * e, Color(1.0, 0.55, 0.2, 0.8 * fade), true, -1.0, true)
			ci.draw_circle(pa, s * 0.42 * e, Color(1.0, 0.9, 0.4, 0.9 * fade), true, -1.0, true)
			for i in 7:
				var ang := TAU * i / 7.0
				ci.draw_circle(pa + Vector2(cos(ang), sin(ang)) * s * (0.35 + 0.45 * k), s * 0.14 * fade, Color(0.5, 0.45, 0.5, 0.7 * fade), true, -1.0, true)
		"bubble":
			ci.draw_arc(pa + Vector2(0, -s * 0.02), s * 0.47 * minf(1.0, k * 2.0), 0, TAU, 32, Color(HeroBoard.SHIELD_C, fade), s * 0.07, true)
			for i in 5:
				var ang := TAU * i / 5.0 + k * 3.0
				HeroArt._star(ci, pa + Vector2(cos(ang), sin(ang)) * s * 0.5, s * 0.08 * fade, Color(1, 1, 1, fade))
		"pop":
			for i in 8:
				var ang := TAU * i / 8.0
				var d := Vector2(cos(ang), sin(ang))
				ci.draw_line(pa + d * s * (0.3 + 0.3 * k), pa + d * s * (0.42 + 0.4 * k), Color(HeroBoard.SHIELD_C, fade), s * 0.08, true)
		"heart":
			var lift := s * 1.1 * k
			var spread := s * 0.35 * k
			var hs := s * 0.5
			var c0 := pa + Vector2(0, -s * 0.2 - lift)
			ci.draw_set_transform(c0 - Vector2(spread, 0), -0.5 * k, Vector2.ONE)
			_half_heart(ci, hs, -1.0, fade)
			ci.draw_set_transform(c0 + Vector2(spread, 0), 0.5 * k, Vector2.ONE)
			_half_heart(ci, hs, 1.0, fade)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"rise":
			var w := s * 0.38
			var top := pa - Vector2(0, s * 1.6)
			ci.draw_colored_polygon(PackedVector2Array([top - Vector2(w * 0.5, 0), top + Vector2(w * 0.5, 0), pa + Vector2(w, s * 0.35), pa + Vector2(-w, s * 0.35)]),
				Color(col, 0.4 * fade))
			for i in 6:
				var t := fmod(k * 1.5 + i / 6.0, 1.0)
				HeroArt._star(ci, pa + Vector2(sin(i * 2.3) * s * 0.35, s * 0.3 - s * 1.3 * t), s * 0.09 * (1.0 - t), Color(1, 1, 0.8, fade))
		"copy":
			for i in 6:
				var t := fmod(k * 1.4 + i / 6.0, 1.0)
				HeroArt._star(ci, pa.lerp(pb, t), s * 0.1 * (1.0 - absf(t - 0.5)), Color(HeroBoard.SWAP_C.lightened(0.3), fade))
			ci.draw_arc(pb, s * (0.3 + 0.2 * k), 0, TAU, 28, Color(HeroBoard.SWAP_C, fade), s * 0.06, true)
		"stun":
			for i in 3:
				var ang := k * 8.0 + TAU * i / 3.0
				HeroArt._star(ci, pa + Vector2(cos(ang) * s * 0.3, -s * 0.45 + sin(ang) * s * 0.08), s * 0.11 * fade + 1.0, Color(HeroBoard.GOLD, fade))


static func _half_heart(ci: CanvasItem, s: float, side: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := PI * i / 12.0
		var x := 16.0 * pow(sin(t), 3) * side
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(x, y) * s / 34.0)
	ci.draw_colored_polygon(pts, Color(HeroArt.HEART, a))
