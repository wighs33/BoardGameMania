class_name UIKit
extends RefCounted
## 보드게임마니아 공용 UI 도우미: 색상 · 폰트 · 캐주얼 버튼/패널 · 그리기 유틸

# ── 색상 팔레트 ─────────────────────────────────────────
const BG_TOP := Color("#FFF4DE")
const BG_BOTTOM := Color("#FFD9CC")
const INK := Color("#3D3450")        # 진한 글자색
const INK_SOFT := Color("#8A7F99")   # 연한 글자색
const GREEN := Color("#3DC985")
const ORANGE := Color("#FF9F43")
const PURPLE := Color("#8C7AE6")
const GREY := Color("#BDB5C8")
const GOLD := Color("#FFC93C")

const PLAYER_COLORS := [Color("#FF6B6B"), Color("#4D96FF"), Color("#FFC93C"), Color("#6BCB77")]
const PLAYER_NAMES := ["빨강", "파랑", "노랑", "초록"]

static var _fonts := {}
static var _draw_sb: StyleBoxFlat


static func player_color(p: int) -> Color:
	return PLAYER_COLORS[p % PLAYER_COLORS.size()]


static func player_dark(p: int) -> Color:
	return player_color(p).darkened(0.22)


# ── 폰트 ───────────────────────────────────────────────
## 시스템 한글 폰트를 사용 (Windows: 맑은 고딕, Android: Noto Sans CJK, iOS: Apple SD 고딕)
static func font(weight: int = 700) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"])
		f.font_weight = weight
		_fonts[weight] = f
	return _fonts[weight]


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 28
	t.set_color("font_color", "Label", INK)
	return t


# ── 그리기 유틸 ─────────────────────────────────────────
## 둥근 사각형 즉시 그리기 (커스텀 _draw 용)
static func draw_rbox(ci: CanvasItem, rect: Rect2, color: Color, radius: float) -> void:
	if _draw_sb == null:
		_draw_sb = StyleBoxFlat.new()
		_draw_sb.anti_aliasing = true
		_draw_sb.corner_detail = 10
	_draw_sb.bg_color = color
	_draw_sb.set_corner_radius_all(int(minf(radius, minf(rect.size.x, rect.size.y) * 0.5)))
	ci.draw_style_box(_draw_sb, rect)


## 투명한 화면(SubViewport)에 그려 둔 그림을 찍을 때 쓰는 재질 (색에 투명도가 이미 곱해져 있음)
static func premult_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return m


## 작은 화면(vp)이 다 그려졌으면 그릴 때 쓴 도형들을 비워 메모리를 돌려받음 (그림은 남음). 아직이면 false
static func release_paint(vp: SubViewport, painter: CanvasItem) -> bool:
	if RenderingServer.viewport_get_update_mode(vp.get_viewport_rid()) != RenderingServer.VIEWPORT_UPDATE_DISABLED:
		return false
	RenderingServer.canvas_item_clear(painter.get_canvas_item())
	return true


static func ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


# ── 스타일 박스 ─────────────────────────────────────────
static func panel_style(color: Color = Color.WHITE, radius: int = 36, margin: int = 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.shadow_color = Color(0.35, 0.2, 0.3, 0.14)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(margin)
	return sb


static func _btn_style(color: Color, radius: int, depth: int, shift: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.border_width_bottom = depth
	sb.border_color = color.darkened(0.28)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10 + shift
	sb.content_margin_bottom = 10 + depth
	return sb


# ── 위젯 ───────────────────────────────────────────────
static func make_background() -> Control:
	var g := Gradient.new()
	g.set_color(0, BG_TOP)
	g.set_color(1, BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func make_label(text: String, size: int = 28, color: Color = INK, weight: int = 700,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 700:
		l.add_theme_font_override("font", font(weight))
	return l


## 통통 튀는 캐주얼 버튼 (아래쪽 입체 테두리 + 눌림 애니메이션)
static func make_button(text: String, color: Color, min_size: Vector2 = Vector2(0, 96), font_size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font(800))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.85))
	b.add_theme_stylebox_override("normal", _btn_style(color, 30, 8, 0))
	b.add_theme_stylebox_override("hover", _btn_style(color.lightened(0.08), 30, 8, 0))
	b.add_theme_stylebox_override("pressed", _btn_style(color.darkened(0.05), 30, 3, 5))
	b.add_theme_stylebox_override("hover_pressed", _btn_style(color.darkened(0.05), 30, 3, 5))
	b.add_theme_stylebox_override("disabled", _btn_style(GREY, 30, 8, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_press_effect(b)
	return b


## 동그란 아이콘 버튼
static func make_round_button(icon: String, color: Color, d: float = 84.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(d, d)
	b.focus_mode = Control.FOCUS_NONE
	var r := int(d / 2.0)
	b.add_theme_stylebox_override("normal", _btn_style(color, r, 7, 0))
	b.add_theme_stylebox_override("hover", _btn_style(color.lightened(0.08), r, 7, 0))
	b.add_theme_stylebox_override("pressed", _btn_style(color.darkened(0.05), r, 3, 4))
	b.add_theme_stylebox_override("hover_pressed", _btn_style(color.darkened(0.05), r, 3, 4))
	b.add_theme_stylebox_override("disabled", _btn_style(GREY, r, 7, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := UiIcon.new()
	ic.kind = icon
	ic.offset_bottom = -6
	b.add_child(ic)
	add_press_effect(b)
	return b


## 선택형 토글 버튼 (ButtonGroup 으로 묶어서 사용)
static func make_toggle(text: String, color: Color, group: ButtonGroup, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font(800))
	var idle := _btn_style(Color("#F1ECF6"), 24, 6, 0)
	idle.border_color = Color("#DCD3E6")
	var on := _btn_style(color, 24, 6, 0)
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", idle)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", idle)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", INK_SOFT)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK_SOFT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	add_press_effect(b)
	return b


## 작은 알약 모양 태그
static func make_chip(text: String, color: Color, font_size: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(make_label(text, font_size, Color.WHITE, 800))
	return p


static func keep_pivot_centered(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)


static func add_press_effect(b: BaseButton) -> void:
	keep_pivot_centered(b)
	b.button_down.connect(func() -> void: _tween_scale(b, 0.93))
	b.button_up.connect(func() -> void: _tween_scale(b, 1.0))


static func _tween_scale(c: Control, s: float) -> void:
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(s, s), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 등장 애니메이션 (투명 + 살짝 작게 → 원래대로)
static func pop_in(c: Control, delay: float = 0.0, from_scale: float = 0.85) -> void:
	keep_pivot_centered(c)
	c.modulate.a = 0.0
	c.scale = Vector2(from_scale, from_scale)
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.22).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
