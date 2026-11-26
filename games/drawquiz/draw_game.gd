extends GameScreen
## 그림 퀴즈 – 두 가지 방식
##  친구들과   : 폰을 돌려 가며 한 명이 제시어를 그리고, 나머지는 말로 맞혀요 (2~8명)
##               맞히면 맞힌 사람 +1점, 그린 사람 +1점. 모두 정해진 바퀴만큼 그리면 끝
##  혼자 맞히기: AI가 펜으로 그려 나가는 낙서를 보고 6개 중에서 빨리 골라요 (10문제, 빠를수록 높은 점수)

enum Step { IDLE, WORD, DRAW, REVEAL, SOLO, DONE }

const COLORS := [Color("#FF6B6B"), Color("#4D96FF"), Color("#FFC93C"), Color("#6BCB77"),
	Color("#A685E2"), Color("#FF9F43"), Color("#FF7EB6"), Color("#2EC4B6")]
const PEN_COLORS := [Color("#3D3450"), Color("#FF5A5F"), Color("#FF9F43"), Color("#F5B700"),
	Color("#2FB36F"), Color("#4D96FF"), Color("#8C6AE6"), Color("#9A6A44")]
const TIMES := [60, 90, 120]
const TIME_LABELS := ["60초", "90초", "120초"]
const LAP_LABELS := ["1바퀴", "2바퀴", "3바퀴"]
const SOLO_COUNT := 10
const SOLO_DRAW := 7.0        # AI가 다 그리는 데 걸리는 시간
const SOLO_EXTRA := 5.0       # 다 그린 뒤 더 기다려 주는 시간
const THIN := 8.0
const THICK := 16.0

var players: int = 4
var laps: int = 1
var time_idx: int = 1
var category_idx: int = 0

var step: int = Step.IDLE
var scores: Array = []
var used: Array = []
var turn_i: int = 0
var drawer: int = 0
var word: String = ""
var category: String = ""
var rerolls: int = 2
var _rng := RandomNumberGenerator.new()
var _time_left: float = 0.0
var _timer_on: bool = false
# 혼자 맞히기
var _q: int = 0
var _solo_score: int = 0
var _solo_right: int = 0
var _solo_words: Array = []
var _options: Array = []
var _answer: String = ""
var _solo_t: float = 0.0
var _solo_locked: bool = true

# 화면
var canvas: DrawCanvas
var _chip_a: Label
var _chip_b: Label
var _chip_c: Label
var _chip_c_panel: PanelContainer
var _tools: VBoxContainer
var _swatches: Array = []
var _width_btn: Button
var _eraser_btn: Button
var _bottom: HBoxContainer
var _reveal: VBoxContainer
var _choices: GridContainer
var _choice_btns: Array = []
var _bar: Control


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "그림 퀴즈"


func _setup_title() -> String:
	return "어떻게 할까요?"


func _mode_ids() -> Array:
	return ["party", "solo"]


func _mode_label(id: String) -> String:
	return "친구들과" if id == "party" else "혼자 맞히기"


func _side_name(p: int) -> String:
	return "%d번" % (p + 1)


func _side_color(p: int) -> Color:
	return COLORS[p % COLORS.size()]


func _side_accent(p: int) -> Color:
	return COLORS[p % COLORS.size()]


func _side_text_color(p: int) -> Color:
	return (COLORS[p % COLORS.size()] as Color).darkened(0.25)


func player_name(p: int) -> String:
	return "나" if mode == "solo" else _side_name(p)


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	return (
		"[color=#%s]친구들과 (2~8명)[/color]\n" % c1
		+ "  · 그릴 사람에게 폰을 넘기면, 그 사람만 몰래 [b]제시어[/b]를 봐요.\n"
		+ "  · 제시어를 [b]그림으로만[/b]그려요. 글자나 숫자를 쓰면 안 돼요!\n"
		+ "  · 다른 사람들은 그림을 보고 [b]말로 외쳐서[/b] 맞혀요. 화면 위에 글자 수 힌트가 나와요.\n"
		+ "  · 누군가 맞히면 그린 사람이 [b]'맞혔어요!'[/b]를 누르고 맞힌 사람을 골라요.\n"
		+ "[color=#%s]점수[/color]  맞힌 사람 +1점, 그린 사람 +1점. 시간 안에 못 맞히면 아무도 점수가 없어요.\n" % c2
		+ "[color=#%s]도구[/color]  색 8가지, 굵게 · 가늘게, 지우개, 되돌리기, 다 지우기. 제시어가 기억 안 나면 [b]'단어'[/b] 버튼을 꾹 누르고 있어요.\n" % c3
		+ "[color=#%s]혼자 맞히기[/color]  AI가 펜으로 그려 나가는 그림을 보고 6개 중에서 골라요. 10문제, [b]빨리 맞힐수록[/b] 점수가 높아요. 틀리면 -10점!" % c4
	)


func _add_setup_options(box: VBoxContainer) -> void:
	var counts: Array = []
	for n in range(2, 9):
		counts.append("%d" % n)
	add_choice_row(box, "인원 (친구들과)", counts, players - 2, UIKit.player_color(1),
		func(i: int) -> void: players = i + 2, 7)
	add_choice_row(box, "한 사람이 그리는 횟수", LAP_LABELS, laps - 1, UIKit.PURPLE,
		func(i: int) -> void: laps = i + 1)
	add_choice_row(box, "그리는 시간", TIME_LABELS, time_idx, UIKit.GREEN,
		func(i: int) -> void: time_idx = i)
	add_choice_row(box, "주제", ["랜덤"] + QuizWords.CATEGORIES, category_idx, UIKit.ORANGE,
		func(i: int) -> void: category_idx = i, 4)
	box.add_child(UIKit.make_label("혼자 맞히기: AI가 그리는 그림 10개를 빨리 맞혀요", 21, UIKit.INK_SOFT))


func _on_setup_opened() -> void:
	_timer_on = false
	_solo_locked = true
	if canvas != null:
		canvas.drawing_enabled = false


func _is_game_over() -> bool:
	return step == Step.IDLE or step == Step.DONE


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "drawquiz"
	mode = str(Global.get_setting(game_id, "mode", "party"))
	if not ["party", "solo"].has(mode):
		mode = "party"
	players = clampi(int(Global.get_setting(game_id, "players", 4)), 2, 8)
	laps = clampi(int(Global.get_setting(game_id, "laps", 1)), 1, 3)
	time_idx = clampi(int(Global.get_setting(game_id, "time", 1)), 0, TIMES.size() - 1)
	category_idx = clampi(int(Global.get_setting(game_id, "category", 0)), 0, QuizWords.CATEGORIES.size())
	_rng.randomize()
	build_frame()
	_cards_row.visible = false
	content.add_theme_constant_override("separation", 12)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	content.add_child(chips)
	_chip_a = _chip(chips, UIKit.PURPLE)
	_chip_b = _chip(chips, UIKit.ORANGE)
	_chip_c = _chip(chips, Color("#3FA9F5"))
	_chip_c_panel = _chip_c.get_parent() as PanelContainer

	canvas = DrawCanvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(0, 420)
	content.add_child(canvas)
	attach_toast(canvas)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.draw.connect(_draw_bar)
	content.add_child(_bar)

	_choices = GridContainer.new()
	_choices.columns = 3
	_choices.add_theme_constant_override("h_separation", 12)
	_choices.add_theme_constant_override("v_separation", 12)
	content.add_child(_choices)
	for i in 6:
		var b := UIKit.make_button("", Color("#3FA9F5"), Vector2(0, 92), 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_choice.bind(i))
		_choices.add_child(b)
		_choice_btns.append(b)

	_build_tools()
	_reveal = VBoxContainer.new()
	_reveal.add_theme_constant_override("separation", 10)
	content.add_child(_reveal)

	_layout(Step.IDLE)
	canvas.doodle = DrawDoodles.strokes("꽃")
	canvas.reveal = 1.0
	set_status("어떻게 할지 골라 주세요")
	show_setup()


func _chip(parent: Container, color: Color) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := UIKit.make_label("", 26, Color.WHITE, 800)
	p.add_child(l)
	parent.add_child(p)
	return l


func _build_tools() -> void:
	_tools = VBoxContainer.new()
	_tools.add_theme_constant_override("separation", 10)
	content.add_child(_tools)
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 10)
	_tools.add_child(row1)
	for i in PEN_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick_color.bind(i))
		row1.add_child(b)
		_swatches.append(b)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	_tools.add_child(row2)
	_width_btn = _tool_btn(row2, "굵게", Color("#3FA9F5"), _toggle_width)
	_eraser_btn = _tool_btn(row2, "지우개", UIKit.GREY.darkened(0.15), _toggle_eraser)
	_tool_btn(row2, "되돌리기", UIKit.PURPLE, func() -> void: canvas.undo())
	_tool_btn(row2, "다 지우기", Color("#FF6B6B"), func() -> void: canvas.clear())
	_paint_swatches()

	_bottom = HBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 12)
	content.add_child(_bottom)
	var ok := UIKit.make_button("맞혔어요!", UIKit.GREEN, Vector2(0, 96), 34)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.size_flags_stretch_ratio = 1.6
	ok.pressed.connect(func() -> void: _open_pick(false))
	_bottom.add_child(ok)
	var pass_btn := UIKit.make_button("패스", UIKit.PURPLE, Vector2(0, 96), 30)
	pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_btn.pressed.connect(_on_pass)
	_bottom.add_child(pass_btn)
	var peek := UIKit.make_button("단어", UIKit.ORANGE, Vector2(0, 96), 30)
	peek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	peek.button_down.connect(func() -> void: _chip_b.text = "제시어: " + word)
	peek.button_up.connect(func() -> void: _chip_b.text = "힌트: " + QuizWords.hint(word))
	_bottom.add_child(peek)


func _tool_btn(parent: Container, text: String, color: Color, cb: Callable) -> Button:
	var b := UIKit.make_button(text, color, Vector2(0, 62), 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _paint_swatches() -> void:
	for i in _swatches.size():
		var b: Button = _swatches[i]
		var on: bool = not canvas.eraser and canvas.pen_color == PEN_COLORS[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = PEN_COLORS[i]
		sb.set_corner_radius_all(31)
		sb.corner_detail = 12
		sb.set_border_width_all(7 if on else 3)
		sb.border_color = Color.WHITE if on else (PEN_COLORS[i] as Color).darkened(0.25)
		sb.shadow_color = Color(0.3, 0.2, 0.25, 0.35 if on else 0.15)
		sb.shadow_size = 8 if on else 3
		for key in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(key, sb)
	_width_btn.text = "가늘게" if canvas.pen_width > THIN else "굵게"
	_eraser_btn.text = "펜으로" if canvas.eraser else "지우개"


func _pick_color(i: int) -> void:
	canvas.pen_color = PEN_COLORS[i]
	canvas.eraser = false
	_paint_swatches()


func _toggle_width() -> void:
	canvas.pen_width = THIN if canvas.pen_width > THIN else THICK
	_paint_swatches()


func _toggle_eraser() -> void:
	canvas.eraser = not canvas.eraser
	_paint_swatches()


## 단계마다 보이는 줄 바꾸기
func _layout(s: int) -> void:
	step = s
	var drawing := s == Step.DRAW
	_tools.visible = drawing
	_bottom.visible = drawing
	_reveal.visible = s == Step.REVEAL
	_choices.visible = s == Step.SOLO
	_bar.visible = s == Step.SOLO
	(_chip_a.get_parent() as Control).visible = s != Step.IDLE
	(_chip_b.get_parent() as Control).visible = s != Step.IDLE
	_chip_c_panel.visible = s != Step.IDLE and (s == Step.SOLO or not category.is_empty())


func _process(delta: float) -> void:
	super(delta)
	if _overlay_kind != "" or has_curtain():
		return
	# 뒤로 가기 확인 창을 닫고 돌아왔을 때 이어 가기
	if step == Step.WORD:
		_show_word()
		return
	if step == Step.DRAW and not _timer_on:
		if _time_left > 0.0:
			_timer_on = true
			canvas.drawing_enabled = true
		else:
			_open_pick(true)
		return
	if step == Step.DRAW and _timer_on:
		_time_left -= delta
		_chip_a.text = "%d초" % ceili(maxf(_time_left, 0.0))
		if _time_left <= 10.0:
			(_chip_a.get_parent() as PanelContainer).modulate = Color(1, 1, 1, 0.6 + 0.4 * absf(sin(_time_left * 4.0)))
		if _time_left <= 0.0:
			_time_up()
	elif step == Step.SOLO and not _solo_locked:
		_solo_t += delta
		canvas.reveal = minf(1.0, _solo_t / SOLO_DRAW)
		_bar.queue_redraw()
		if _solo_t >= SOLO_DRAW + SOLO_EXTRA:
			_solo_timeout()


func _draw_bar() -> void:
	var r := Rect2(Vector2(8, 2), _bar.size - Vector2(16, 4))
	UIKit.draw_rbox(_bar, r, Color(0.3, 0.2, 0.25, 0.12), r.size.y / 2.0)
	var left := clampf(1.0 - _solo_t / (SOLO_DRAW + SOLO_EXTRA), 0.0, 1.0)
	var col := UIKit.GREEN if left > 0.45 else (UIKit.ORANGE if left > 0.2 else Color("#FF6B6B"))
	if left > 0.0:
		UIKit.draw_rbox(_bar, Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * left), r.size.y)), col, r.size.y / 2.0)


# ══════════════════════════════════════════════════════
#  시작
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "players", players)
	Global.set_setting(game_id, "laps", laps)
	Global.set_setting(game_id, "time", time_idx)
	Global.set_setting(game_id, "category", category_idx)
	apply_mode()
	close_overlay()
	canvas.doodle = []
	canvas.clear()
	if mode == "solo":
		_start_solo()
	else:
		_start_party()


# ══════════════════════════════════════════════════════
#  친구들과
# ══════════════════════════════════════════════════════
func _start_party() -> void:
	scores = []
	for p in players:
		scores.append(0)
	used = []
	turn_i = 0
	_next_drawer()


func _next_drawer() -> void:
	drawer = turn_i % players
	rerolls = 2
	_pick_word()
	canvas.clear()
	canvas.drawing_enabled = false
	_layout(Step.WORD)
	_chip_a.text = "%d / %d번째" % [turn_i + 1, players * laps]
	_chip_b.text = "%s 차례" % _side_name(drawer)
	_chip_c.text = category
	set_status_side(drawer)
	set_status("%s 그릴 차례예요" % josa(_side_name(drawer), "이", "가"))
	show_curtain("%s 차례!" % _side_name(drawer), "다른 사람은 화면을 보지 마세요", _side_color(drawer), _show_word, "제시어 보기")


func _pick_word() -> void:
	var cat := "" if category_idx == 0 else str(QuizWords.CATEGORIES[category_idx - 1])
	var r := QuizWords.pick(cat, _rng, used)
	word = r[0]
	category = r[1]
	used.append(word)


func _show_word() -> void:
	var box := open_overlay("word")
	box.add_child(UIKit.make_label("%s만 보세요!" % _side_name(drawer), 28, _side_text_color(drawer), 800))
	box.add_child(UIKit.make_label("주제: %s" % category, 26, UIKit.INK_SOFT, 800))
	var w := UIKit.make_label(word, 76, UIKit.INK, 900)
	box.add_child(w)
	UIKit.pop_in(w, 0.05, 0.6)
	box.add_child(UIKit.make_label("글자 · 숫자 없이 그림으로만!", 24, UIKit.INK_SOFT))
	var re := UIKit.make_button("다른 단어로 (%d번 남음)" % rerolls, UIKit.ORANGE, Vector2(0, 84), 28)
	re.disabled = rerolls <= 0
	re.pressed.connect(func() -> void:
		rerolls -= 1
		_pick_word()
		_show_word())
	box.add_child(re)
	var go := UIKit.make_button("그리기 시작!", UIKit.GREEN, Vector2(0, 110), 40)
	go.pressed.connect(_begin_draw)
	box.add_child(go)


func _begin_draw() -> void:
	close_overlay()
	_time_left = float(TIMES[time_idx])
	_layout(Step.DRAW)
	canvas.clear()
	canvas.drawing_enabled = true
	_time_left = float(TIMES[time_idx])
	_timer_on = true
	(_chip_a.get_parent() as PanelContainer).modulate = Color.WHITE
	_chip_a.text = "%d초" % TIMES[time_idx]
	_chip_b.text = "힌트: " + QuizWords.hint(word)
	_chip_c.text = category
	set_status("%s 그리는 중 · 말로 맞혀요!" % _side_name(drawer))


func _time_up() -> void:
	_timer_on = false
	canvas.drawing_enabled = false
	toast("시간 끝!")
	_open_pick(true)


func _on_pass() -> void:
	if step != Step.DRAW:
		return
	_timer_on = false
	_finish_turn(-1)


## 누가 맞혔는지 고르기
func _open_pick(timeout: bool) -> void:
	if step != Step.DRAW:
		return
	_timer_on = false
	var box := open_overlay("pick")
	box.add_child(UIKit.make_label("누가 맞혔나요?", 44, UIKit.INK, 800))
	box.add_child(UIKit.make_label("정답: %s" % word, 30, UIKit.INK_SOFT, 800))
	var grid := GridContainer.new()
	grid.columns = 4 if players > 4 else maxi(1, players - 1)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for p in players:
		if p == drawer:
			continue
		var b := UIKit.make_button(_side_name(p), _side_color(p), Vector2(0, 92), 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var who: int = p
		b.pressed.connect(func() -> void: _finish_turn(who))
		grid.add_child(b)
	var nobody := UIKit.make_button("아무도 못 맞혔어요", UIKit.GREY.darkened(0.2), Vector2(0, 84), 28)
	nobody.pressed.connect(func() -> void: _finish_turn(-1))
	box.add_child(nobody)
	if not timeout:
		var back := UIKit.make_button("계속 그리기", UIKit.PURPLE, Vector2(0, 84), 28)
		back.pressed.connect(func() -> void:
			close_overlay()
			_timer_on = true)
		box.add_child(back)


func _finish_turn(guesser: int) -> void:
	close_overlay()
	_timer_on = false
	canvas.drawing_enabled = false
	if guesser >= 0:
		scores[guesser] += 1
		scores[drawer] += 1
	_layout(Step.REVEAL)
	_time_left = 0.0
	(_chip_a.get_parent() as PanelContainer).modulate = Color.WHITE
	_chip_a.text = "정답"
	_chip_b.text = word
	for c in _reveal.get_children():
		c.queue_free()
	var msg := ""
	if guesser >= 0:
		msg = "%s 맞혔어요! (%s +1 · %s +1)" % [josa(_side_name(guesser), "이", "가"), _side_name(guesser), _side_name(drawer)]
		var conf := Confetti.new()
		overlay.add_child(conf)
		conf.burst(50)
	else:
		msg = "아무도 못 맞혔어요"
	set_status(msg)
	_reveal.add_child(_scoreboard(guesser))
	var last := turn_i + 1 >= players * laps
	var nxt := UIKit.make_button("최종 결과 보기" if last else "다음: %s 차례 ▶" % _side_name((turn_i + 1) % players),
		UIKit.GREEN, Vector2(0, 96), 32)
	nxt.pressed.connect(_next_turn)
	_reveal.add_child(nxt)


func _scoreboard(highlight: int = -1) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var best := 0
	for s in scores:
		best = maxi(best, int(s))
	for p in players:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cs := StyleBoxFlat.new()
		cs.bg_color = _side_color(p).lerp(Color.WHITE, 0.8)
		cs.set_corner_radius_all(20)
		cs.set_content_margin_all(8)
		if best > 0 and int(scores[p]) == best:
			cs.set_border_width_all(4)
			cs.border_color = UIKit.GOLD
		cell.add_theme_stylebox_override("panel", cs)
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 2)
		cell.add_child(ch)
		var pv := PieceView.new()
		pv.color = _side_color(p)
		pv.happy = p == highlight or p == drawer and highlight >= 0
		pv.bob = pv.happy
		pv.custom_minimum_size = Vector2(44, 44)
		ch.add_child(pv)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", -6)
		info.add_child(UIKit.make_label(_side_name(p), 19, UIKit.INK_SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT))
		info.add_child(UIKit.make_label("%d점" % int(scores[p]), 28, _side_text_color(p), 900, HORIZONTAL_ALIGNMENT_LEFT))
		ch.add_child(info)
		grid.add_child(cell)
	return grid


func _next_turn() -> void:
	turn_i += 1
	if turn_i >= players * laps:
		_party_end()
	else:
		_next_drawer()


func _party_end() -> void:
	_layout(Step.DONE)
	Global.add_stat(game_id, "played")
	var best := 0
	for s in scores:
		best = maxi(best, int(s))
	var winners: Array = []
	for p in players:
		if int(scores[p]) == best:
			winners.append(_side_name(p))
	set_status("게임 끝!")
	var box := open_overlay("result")
	var title := UIKit.make_label("최종 결과", 64, UIKit.ORANGE, 800)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	box.add_child(title)
	if best > 0:
		box.add_child(UIKit.make_label("1등: %s (%d점)" % [", ".join(winners), best], 30, UIKit.INK, 800))
	else:
		box.add_child(UIKit.make_label("아무도 점수를 못 얻었어요", 28, UIKit.INK_SOFT, 800))
	box.add_child(_scoreboard())
	var again := UIKit.make_button("한 판 더!", UIKit.GREEN, Vector2(0, 104), 38)
	again.pressed.connect(_start_game)
	box.add_child(again)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var setup_btn := UIKit.make_button("설정 바꾸기", UIKit.ORANGE, Vector2(0, 84), 26)
	setup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_btn.pressed.connect(show_setup)
	row.add_child(setup_btn)
	var home := UIKit.make_button("메뉴로", UIKit.PURPLE, Vector2(0, 84), 26)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(Global.go_home)
	row.add_child(home)
	if best > 0:
		var conf := Confetti.new()
		overlay.add_child(conf)
		conf.burst(90)


# ══════════════════════════════════════════════════════
#  혼자 맞히기
# ══════════════════════════════════════════════════════
func _start_solo() -> void:
	category = ""
	_q = 0
	_solo_score = 0
	_solo_right = 0
	_solo_words = DrawDoodles.WORDS.duplicate()
	for i in range(_solo_words.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t: Variant = _solo_words[i]
		_solo_words[i] = _solo_words[j]
		_solo_words[j] = t
	_solo_words = _solo_words.slice(0, SOLO_COUNT)
	set_status_side(0)
	_solo_next()


func _solo_next() -> void:
	if _q >= SOLO_COUNT:
		_solo_end()
		return
	_layout(Step.SOLO)
	_answer = _solo_words[_q]
	var others: Array = DrawDoodles.WORDS.filter(func(w: String) -> bool: return w != _answer)
	_options = [_answer]
	while _options.size() < 6:
		var w: String = others[_rng.randi() % others.size()]
		if not _options.has(w):
			_options.append(w)
	_options.shuffle()
	for i in 6:
		var b: Button = _choice_btns[i]
		b.text = _options[i]
		b.disabled = false
		_paint_btn(b, Color("#3FA9F5"))
	canvas.doodle = DrawDoodles.strokes(_answer)
	canvas.reveal = 0.0
	canvas.show_pen = true
	_solo_t = 0.0
	_solo_locked = false
	_chip_a.text = "%d / %d" % [_q + 1, SOLO_COUNT]
	_chip_b.text = "점수 %d" % _solo_score
	_chip_c.text = "최고 %d" % int(Global.get_setting(game_id, "best", 0))
	_bar.queue_redraw()
	set_status("AI가 그리는 그림은 무엇일까요?")


func _paint_btn(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", UIKit._btn_style(color, 30, 8, 0))
	b.add_theme_stylebox_override("hover", UIKit._btn_style(color.lightened(0.08), 30, 8, 0))
	b.add_theme_stylebox_override("disabled", UIKit._btn_style(color if color != Color("#3FA9F5") else UIKit.GREY, 30, 8, 0))


func _on_choice(i: int) -> void:
	if step != Step.SOLO or _solo_locked:
		return
	var b: Button = _choice_btns[i]
	if _options[i] == _answer:
		_solo_locked = true
		var pts := int(round(10.0 + 90.0 * clampf(1.0 - _solo_t / (SOLO_DRAW + SOLO_EXTRA), 0.0, 1.0)))
		_solo_score += pts
		_solo_right += 1
		canvas.reveal = 1.0
		canvas.show_pen = false
		canvas.flash = 1.0
		canvas.flash_color = UIKit.GREEN
		_paint_btn(b, UIKit.GREEN)
		for c in _choice_btns:
			(c as Button).disabled = true
		_chip_b.text = "점수 %d" % _solo_score
		toast("정답! +%d점" % pts)
		_solo_advance(1.1)
	else:
		_solo_score = maxi(0, _solo_score - 10)
		b.disabled = true
		canvas.flash = 1.0
		canvas.flash_color = Color("#FF6B6B")
		_chip_b.text = "점수 %d" % _solo_score
		toast("땡! -10점")


func _solo_timeout() -> void:
	_solo_locked = true
	canvas.reveal = 1.0
	canvas.show_pen = false
	for i in 6:
		var b: Button = _choice_btns[i]
		b.disabled = true
		if _options[i] == _answer:
			_paint_btn(b, UIKit.ORANGE)
	toast("시간 끝! 정답은 '%s'" % _answer)
	_solo_advance(1.6)


func _solo_advance(delay: float) -> void:
	var tok := _token
	await wait(delay)
	if tok != _token or step != Step.SOLO:
		return
	_q += 1
	_solo_next()


func _solo_end() -> void:
	_layout(Step.DONE)
	canvas.show_pen = false
	Global.add_stat(game_id, "played")
	var best := int(Global.get_setting(game_id, "best", 0))
	var new_best := _solo_score > best
	if new_best:
		Global.set_setting(game_id, "best", _solo_score)
	set_status("끝! %d점" % _solo_score)
	var rows := [{"p": 0, "big": "%d점" % _solo_score, "small": "맞힌 그림 %d / %d" % [_solo_right, SOLO_COUNT]}]
	var note := "새 최고 기록이에요!" if new_best else "최고 기록: %d점" % maxi(best, _solo_score)
	show_result("%d점!" % _solo_score, UIKit.ORANGE, new_best or _solo_right >= 8, 0, rows, note)
