class_name GameScreen
extends Control
## 모든 게임 화면이 함께 쓰는 뼈대
##  - 상단 바(뒤로 / 제목 / 도움말), 플레이어 카드 2장, 상태 안내, 토스트 알림
##  - 팝업: 설정 / 게임 방법 / 나가기 확인 / 결과
##  - 안드로이드 뒤로 버튼 · ESC 처리
## 새 게임은 이 클래스를 상속하고 '덮어쓰는 함수'들을 구현한 뒤,
## _ready() 에서 build_frame() 을 부르고 content 에 보드와 버튼을 넣으면 됩니다.

const MODE_IDS := ["ai_easy", "ai_normal", "ai_hard", "local"]
const MODE_LABELS := ["AI 쉬움", "AI 보통", "AI 어려움", "친구와 2인"]
const LEVEL_NAMES := ["쉬움", "보통", "어려움"]

var game_id: String = ""
var mode: String = "ai_normal"
var ai_level: int = -1          # -1 이면 친구와 2인
var human_player: int = 0

var content: VBoxContainer      # 하위 클래스가 보드/버튼을 넣는 곳
var status_label: Label
var overlay: Control

var _token: int = 0             # 새 게임/설정 열기마다 증가 → 이전 코루틴 무효화
var _thinking: bool = false
var _think_t: float = 0.0
var _cards: Array = []
var _cards_row: HBoxContainer
var _status_style: StyleBoxFlat
var _status_base: String = ""
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _overlay_kind: String = ""
var _rules_from_setup: bool = false
var _last_result: Array = []
var _curtain: Control = null


# ══════════════════════════════════════════════════════
#  하위 클래스에서 덮어쓰는 함수
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return ""


## 게임 방법 팝업 내용 (BBCode)
func _rules_text() -> String:
	return ""


## 2인 모드에서 쓰는 진영 이름 (예: 빨강/파랑, 흑/백)
func _side_name(p: int) -> String:
	return UIKit.PLAYER_NAMES[p]


## 카드/결과에 그려지는 말 색
func _side_color(p: int) -> Color:
	return UIKit.player_color(p)


## 차례 표시 테두리 · 배지 색
func _side_accent(p: int) -> Color:
	return UIKit.player_color(p)


## 카드의 큰 숫자 글자색
func _side_text_color(p: int) -> Color:
	return UIKit.player_dark(p)


## 설정 팝업 맨 위 제목
func _setup_title() -> String:
	return "누구와 대결할까요?"


## 설정 팝업에 보여 줄 대전 방식 (빈 배열이면 대전 방식 버튼을 숨김)
func _mode_ids() -> Array:
	return MODE_IDS


func _mode_label(id: String) -> String:
	var i := MODE_IDS.find(id)
	return MODE_LABELS[i] if i >= 0 else id


## 설정 팝업에 게임별 선택지 추가
func _add_setup_options(_box: VBoxContainer) -> void:
	pass


## 설정 팝업이 열릴 때 (진행 중인 게임 멈추기)
func _on_setup_opened() -> void:
	pass


func _start_game() -> void:
	pass


func _is_game_over() -> bool:
	return false


# ══════════════════════════════════════════════════════
#  화면 뼈대
# ══════════════════════════════════════════════════════
func build_frame() -> void:
	add_child(UIKit.make_background())
	add_child(BgDecor.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22 + Global.safe_top())
	margin.add_theme_constant_override("margin_bottom", 26 + Global.safe_bottom())
	add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	# 상단 바
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	content.add_child(top)
	var back := UIKit.make_round_button("back", UIKit.PURPLE)
	back.pressed.connect(_on_back)
	top.add_child(back)
	var title := UIKit.make_label(_game_title(), 42, UIKit.INK, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var help := UIKit.make_round_button("help", UIKit.ORANGE)
	help.pressed.connect(show_rules.bind(false))
	top.add_child(help)

	# 플레이어 카드
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 14)
	content.add_child(_cards_row)
	setup_cards([0, 1])

	# 상태 안내
	var status_panel := PanelContainer.new()
	_status_style = UIKit.panel_style(Color.WHITE, 40, 14)
	_status_style.content_margin_left = 20
	_status_style.content_margin_right = 20
	_status_style.set_border_width_all(4)
	_status_style.border_color = _side_accent(0)
	status_panel.add_theme_stylebox_override("panel", _status_style)
	status_label = UIKit.make_label("", 28, UIKit.INK, 800)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(status_label)
	content.add_child(status_panel)

	# 팝업 레이어 (항상 맨 위)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


## 플레이어 카드 다시 만들기. ids 순서대로 카드 칸(slot)이 됨. 3명 이상이면 작은 카드
func setup_cards(ids: Array) -> void:
	for c in _cards_row.get_children():
		_cards_row.remove_child(c)
		c.queue_free()
	_cards.clear()
	var compact := ids.size() > 2
	_cards_row.add_theme_constant_override("separation", 10 if compact else 14)
	for p in ids:
		var card := _make_card(int(p), compact)
		_cards_row.add_child(card["panel"])
		_cards.append(card)


func _make_card(p: int, compact: bool = false) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := 10 if compact else 14
	var off := UIKit.panel_style(Color.WHITE, 30, margin)
	var on := UIKit.panel_style(Color.WHITE, 30, margin)
	on.set_border_width_all(6)
	on.border_color = _side_accent(p)
	panel.add_theme_stylebox_override("panel", off)
	UIKit.keep_pivot_centered(panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4 if compact else 8)
	panel.add_child(hb)
	var piece := PieceView.new()
	piece.color = _side_color(p)
	piece.phase = p * 1.7
	piece.custom_minimum_size = Vector2(54, 64) if compact else Vector2(76, 76)
	hb.add_child(piece)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", -4)
	hb.add_child(info)
	var name_l := UIKit.make_label("", 20 if compact else 23, UIKit.INK_SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.clip_text = true
	info.add_child(name_l)
	var big_l := UIKit.make_label("", 34 if compact else 42, _side_text_color(p), 800, HORIZONTAL_ALIGNMENT_LEFT)
	info.add_child(big_l)

	var badge := UIKit.make_chip("차례", _side_accent(p), 20)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.visible = not compact
	hb.add_child(badge)
	return {"panel": panel, "name": name_l, "big": big_l, "badge": badge, "piece": piece, "on": on, "off": off}


## 플레이어 카드 갱신. bump=true 면 큰 글자가 통통 튐
func set_card(p: int, name_text: String, big_text: String, active: bool, bump: bool = false) -> void:
	var card: Dictionary = _cards[p]
	(card["name"] as Label).text = name_text
	var big: Label = card["big"]
	big.text = big_text
	if bump:
		UIKit.keep_pivot_centered(big)
		big.scale = Vector2(1.35, 1.35)
		big.create_tween().tween_property(big, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var panel: PanelContainer = card["panel"]
	panel.add_theme_stylebox_override("panel", card["on"] if active else card["off"])
	(card["badge"] as Control).modulate.a = 1.0 if active else 0.0
	(card["piece"] as PieceView).bob = active
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE * (1.03 if active else 0.97), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 카드의 큰 글자 자리에 다른 표시(예: 성 하트)를 넣음
func set_card_widget(p: int, widget: Control) -> void:
	var big: Label = (_cards[p] as Dictionary)["big"]
	big.visible = false
	var box := big.get_parent()
	box.add_child(widget)
	box.move_child(widget, big.get_index() + 1)


func attach_toast(parent: Control) -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_bottom = 80
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	_toast_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.2, 0.31, 0.92)
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.modulate.a = 0.0
	_toast_label = UIKit.make_label("", 26, Color.WHITE, 800)
	_toast_panel.add_child(_toast_label)
	holder.add_child(_toast_panel)


## 화면 가리개: 친구끼리 폰 하나로 할 때 숨겨진 패를 가리고 다음 사람에게 넘기기
func show_curtain(title: String, sub: String, color: Color, on_ready: Callable, button_text: String = "준비됐어요!") -> void:
	hide_curtain()
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	move_child(c, overlay.get_index())
	_curtain = c
	c.add_child(UIKit.make_background())
	c.add_child(BgDecor.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	center.add_child(vb)
	var pv := PieceView.new()
	pv.color = color
	pv.happy = true
	pv.custom_minimum_size = Vector2(0, 200)
	vb.add_child(pv)
	vb.add_child(UIKit.make_label(title, 54, color.darkened(0.25), 800))
	vb.add_child(UIKit.make_label(sub, 28, UIKit.INK_SOFT))
	var b := UIKit.make_button(button_text, color, Vector2(480, 120), 40)
	b.pressed.connect(func() -> void:
		hide_curtain()
		on_ready.call())
	vb.add_child(b)
	UIKit.pop_in(vb, 0.0, 0.9)


func hide_curtain() -> void:
	if _curtain != null:
		_curtain.queue_free()
		_curtain = null


func has_curtain() -> bool:
	return _curtain != null


# ══════════════════════════════════════════════════════
#  도우미
# ══════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if _thinking:
		_think_t += delta
		status_label.text = _status_base + ".".repeat(int(_think_t * 3.0) % 4)


func apply_mode() -> void:
	var idx := MODE_IDS.find(mode)
	ai_level = idx if idx >= 0 and idx < 3 else -1


func is_ai(p: int) -> bool:
	return ai_level >= 0 and p != human_player


func player_name(p: int) -> String:
	if ai_level >= 0:
		return "나" if p == human_player else "AI · " + LEVEL_NAMES[ai_level]
	return _side_name(p)


## 문장 주어 ("내가", "AI가", "빨강이", "흑이")
func subject(p: int) -> String:
	if ai_level >= 0:
		return "내가" if p == human_player else "AI가"
	return josa(_side_name(p), "이", "가")


## 2인 모드에서 누구 차례인지 앞에 붙이는 말
func who_prefix(p: int) -> String:
	if ai_level >= 0:
		return ""
	return "[%s] " % _side_name(p)


## 받침에 따라 조사 붙이기 (숫자로 끝나면 읽는 소리 기준: 1(일)이, 2(이)가 …)
static func josa(word: String, with_final: String, without_final: String) -> String:
	if word.is_empty():
		return word + without_final
	var code := word.unicode_at(word.length() - 1)
	var has_final := false
	if code >= 0xAC00 and code <= 0xD7A3:
		has_final = (code - 0xAC00) % 28 != 0
	elif code >= 48 and code <= 57:
		has_final = [true, true, false, true, false, false, true, true, true, false][code - 48]
	return word + (with_final if has_final else without_final)


func set_status(text: String) -> void:
	_thinking = false
	_status_base = text
	status_label.text = text


func set_status_side(p: int) -> void:
	_status_style.border_color = _side_accent(p)


func start_thinking(text: String = "AI가 생각 중") -> void:
	_status_base = text
	_think_t = 0.0
	_thinking = true
	status_label.text = text


func toast(msg: String) -> void:
	if _toast_panel == null:
		return
	_toast_label.text = msg
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	UIKit.keep_pivot_centered(_toast_panel)
	_toast_panel.scale = Vector2(0.8, 0.8)
	_toast_tween = _toast_panel.create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.3).set_delay(1.4)


## 화면이 사라지면 함께 사라지는 대기 (await wait(0.3))
func wait(sec: float) -> Signal:
	var t := create_tween()
	t.tween_interval(sec)
	return t.finished


func record_result(w: int) -> void:
	Global.add_stat(game_id, "played")
	if ai_level >= 0 and w == human_player:
		Global.add_stat(game_id, "wins")


# ══════════════════════════════════════════════════════
#  팝업
# ══════════════════════════════════════════════════════
func open_overlay(kind: String) -> VBoxContainer:
	close_overlay()
	_overlay_kind = kind
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.1, 0.22, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color.WHITE, 46, 34))
	center.add_child(panel)
	UIKit.pop_in(panel, 0.0, 0.8)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	return vb


func close_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_kind = ""


## 토글 버튼 한 줄 (설정 팝업용). columns > 0 이면 여러 줄 격자로
func add_choice_row(box: VBoxContainer, label: String, labels: Array, current: int, color: Color, on_pick: Callable,
		columns: int = 0) -> void:
	box.add_child(UIKit.make_label(label, 26, UIKit.INK_SOFT, 800))
	var row: Container
	if columns > 0:
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		row = grid
	else:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		row = hb
	box.add_child(row)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := UIKit.make_toggle(labels[i], color, group, 28 if columns == 0 else 26)
		if columns > 0:
			b.custom_minimum_size = Vector2(0, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = i == current
		var idx: int = i
		b.pressed.connect(func() -> void: on_pick.call(idx))
		row.add_child(b)


func show_setup() -> void:
	_token += 1
	_thinking = false
	_on_setup_opened()
	hide_curtain()
	var box := open_overlay("setup")
	box.add_child(UIKit.make_label(_setup_title(), 40, UIKit.INK, 800))

	var ids := _mode_ids()
	if not ids.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		box.add_child(grid)
		var mode_group := ButtonGroup.new()
		for id_v in ids:
			var id: String = id_v
			var b := UIKit.make_toggle(_mode_label(id), UIKit.PURPLE if id == "local" else UIKit.ORANGE, mode_group, 30)
			b.custom_minimum_size = Vector2(0, 90)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.button_pressed = id == mode
			b.pressed.connect(func() -> void: mode = id)
			grid.add_child(b)

	_add_setup_options(box)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	var start := UIKit.make_button("게임 시작!", UIKit.GREEN, Vector2(0, 110), 40)
	start.pressed.connect(_start_game)
	box.add_child(start)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var rules := UIKit.make_button("게임 방법", UIKit.ORANGE, Vector2(0, 84), 28)
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.pressed.connect(show_rules.bind(true))
	row.add_child(rules)
	var home := UIKit.make_button("메뉴로", UIKit.PURPLE, Vector2(0, 84), 28)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(Global.go_home)
	row.add_child(home)


func show_rules(from_setup: bool) -> void:
	_rules_from_setup = from_setup
	var box := open_overlay("rules")
	box.add_child(UIKit.make_label("게임 방법", 44, UIKit.INK, 800))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.custom_minimum_size = Vector2(540, 0)
	rt.add_theme_font_size_override("normal_font_size", 26)
	rt.add_theme_font_size_override("bold_font_size", 26)
	rt.add_theme_font_override("bold_font", UIKit.font(900))
	rt.add_theme_constant_override("line_separation", 10)
	rt.add_theme_color_override("default_color", UIKit.INK)
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.text = _rules_text()
	# 설명이 길면 화면 안에서 스크롤 (버튼이 화면 밖으로 밀리지 않게)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(540, 0)
	sc.add_child(rt)
	box.add_child(sc)
	var ok := UIKit.make_button("알겠어요!", UIKit.GREEN, Vector2(0, 100), 34)
	ok.pressed.connect(_close_rules)
	box.add_child(ok)
	var tok := _token
	await get_tree().process_frame
	if tok != _token or not is_instance_valid(sc):
		return
	var max_h := get_viewport_rect().size.y - 420.0 - Global.safe_top() - Global.safe_bottom()
	sc.custom_minimum_size.y = minf(rt.get_content_height(), max_h)


func _close_rules() -> void:
	if _rules_from_setup:
		show_setup()
	else:
		close_overlay()


func show_confirm() -> void:
	var box := open_overlay("confirm")
	box.add_child(UIKit.make_label("게임을 그만둘까요?", 40, UIKit.INK, 800))
	box.add_child(UIKit.make_label("지금 하던 판은 저장되지 않아요", 26, UIKit.INK_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var stay := UIKit.make_button("계속하기", UIKit.GREEN, Vector2(0, 96), 30)
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stay.pressed.connect(close_overlay)
	row.add_child(stay)
	var leave := UIKit.make_button("메뉴로", UIKit.PURPLE, Vector2(0, 96), 30)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(Global.go_home)
	row.add_child(leave)


## 승자 기준 기본 결과 화면. rows: [{p, big, small}] , w = 승자(-1 무승부)
func show_standard_result(w: int, rows: Array, note: String = "") -> void:
	var title := ""
	var color := UIKit.INK
	var celebrate := false
	if ai_level >= 0:
		if w == human_player:
			title = "승리!"
			color = UIKit.ORANGE
			celebrate = true
		elif w == -1:
			title = "무승부"
		else:
			title = "아쉬운 패배..."
			color = UIKit.PURPLE
	else:
		if w == -1:
			title = "무승부!"
		else:
			title = "%s 승리!" % _side_name(w)
			color = _side_text_color(w)
			celebrate = true
	show_result(title, color, celebrate, w, rows, note)


## primary_label / primary_action 으로 큰 버튼을 바꿀 수 있음 (기본: 한 판 더! → _start_game)
func show_result(title: String, color: Color, celebrate: bool, w: int, rows: Array, note: String,
		primary_label: String = "한 판 더!", primary_action: Callable = Callable()) -> void:
	_last_result = [title, color, false, w, rows, note, primary_label, primary_action]
	var box := open_overlay("result")
	var t := UIKit.make_label(title, 70, color, 800)
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_outline_color", Color.WHITE)
	box.add_child(t)

	for r in rows:
		var p: int = r["p"]
		var rp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = _side_accent(p).lerp(Color.WHITE, 0.78)
		sb.set_corner_radius_all(28)
		sb.set_content_margin_all(14)
		if p == w:
			sb.set_border_width_all(5)
			sb.border_color = _side_accent(p)
		rp.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		rp.add_child(row)
		var pv := PieceView.new()
		pv.color = _side_color(p)
		pv.happy = p == w
		pv.bob = p == w
		pv.custom_minimum_size = Vector2(80, 80)
		row.add_child(pv)
		var nm := UIKit.make_label(player_name(p), 30, UIKit.INK, 800, HORIZONTAL_ALIGNMENT_LEFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var detail := VBoxContainer.new()
		detail.add_theme_constant_override("separation", -6)
		detail.add_child(UIKit.make_label(str(r["big"]), 46, _side_text_color(p), 800, HORIZONTAL_ALIGNMENT_RIGHT))
		detail.add_child(UIKit.make_label(str(r["small"]), 20, UIKit.INK_SOFT, 700, HORIZONTAL_ALIGNMENT_RIGHT))
		row.add_child(detail)
		box.add_child(rp)
	if not note.is_empty():
		box.add_child(UIKit.make_label(note, 24, UIKit.INK_SOFT))

	var again := UIKit.make_button(primary_label, UIKit.GREEN, Vector2(0, 108), 38)
	again.pressed.connect(primary_action if primary_action.is_valid() else _start_game)
	box.add_child(again)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	var view_btn := UIKit.make_button("판 보기", Color("#3FA9F5"), Vector2(0, 84), 26)
	view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_btn.pressed.connect(close_overlay)
	row2.add_child(view_btn)
	var setup_btn := UIKit.make_button("설정 바꾸기", UIKit.ORANGE, Vector2(0, 84), 26)
	setup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_btn.pressed.connect(show_setup)
	row2.add_child(setup_btn)
	var home := UIKit.make_button("메뉴로", UIKit.PURPLE, Vector2(0, 84), 26)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(Global.go_home)
	row2.add_child(home)

	if celebrate:
		var conf := Confetti.new()
		overlay.add_child(conf)
		conf.burst()


## '판 보기' 뒤에 결과 팝업 다시 열기
func reopen_result() -> void:
	if not _last_result.is_empty():
		show_result.callv(_last_result)


# ── 뒤로 가기 (안드로이드 뒤로 버튼 / ESC) ─────────────
func _on_back() -> void:
	match _overlay_kind:
		"confirm", "side":
			close_overlay()
		"rules":
			_close_rules()
		"setup", "result":
			Global.go_home()
		_:
			if _is_game_over():
				Global.go_home()
			else:
				show_confirm()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
