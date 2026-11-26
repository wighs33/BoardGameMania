extends GameScreen
## 라이어 찾기 – 폰 하나를 돌려 가며 하는 파티 게임 (3~8명)
## 진행: 카드 확인(라이어는 정답 후보 20개) → 설명 두 바퀴(순서대로 → 거꾸로) → 다 같이 지목
##       → (라이어를 잡으면 후보 20개 중 제시어 맞히기) → 결과 · 점수판

enum Step { SETUP, REVEAL, TALK, VOTE, JUDGE, GUESS, DONE }

const COLORS := [Color("#FF6B6B"), Color("#4D96FF"), Color("#FFC93C"), Color("#6BCB77"),
	Color("#A685E2"), Color("#FF9F43"), Color("#FF7EB6"), Color("#2EC4B6")]
const TIMER_SECS := [0, 10, 20, 30]     # 한 사람이 설명하는 시간
const TIMER_LABELS := ["없음", "10초", "20초", "30초"]
const LIAR_RED := Color("#FF5E5E")

var players: int = 4
var category_idx: int = 0        # 0 = 랜덤, 그 외 = LiarWords.CATEGORIES[idx - 1]
var fool_mode: bool = false
var timer_idx: int = 2

var logic: LiarLogic
var step: int = Step.SETUP
var scores: Array = []
var used_words: Array = []
var round_no: int = 0
var _rng := RandomNumberGenerator.new()

var stage: VBoxContainer
var _card: Button
var _reveal_btn: Button
var _reveal_p: int = 0
var _card_open: bool = false
var _flipping: bool = false
var _timer_label: Label
var _time_left: float = 0.0
var _timer_on: bool = false
var _talk_i: int = 0             # 설명 두 바퀴 중 몇 번째 사람인지 (0 .. 2×인원-1)


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "라이어 찾기"


func _setup_title() -> String:
	return "게임 설정"


func _mode_ids() -> Array:
	return []


func _side_name(p: int) -> String:
	return "%d번" % (p + 1)


func _side_color(p: int) -> Color:
	return COLORS[p % COLORS.size()]


func _side_accent(p: int) -> Color:
	return COLORS[p % COLORS.size()]


func _side_text_color(p: int) -> Color:
	return (COLORS[p % COLORS.size()] as Color).darkened(0.25)


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	return (
		"[color=#%s]1. 카드 확인[/color]  폰을 돌려 가며 한 명씩 몰래 카드를 봐요. 시민은 [b]제시어[/b]를 보고, 라이어는 제시어 대신 [b]정답 후보 단어 20개[/b]를 봐요. (이 중 하나가 제시어!)\n" % c1
		+ "[color=#%s]2. 설명 두 바퀴[/color]  먼저 말할 사람부터 [b]한 바퀴[/b], 그다음 [b]거꾸로 한 바퀴 더[/b] 제시어를 한 마디씩 설명해요. 너무 쉽게 말하면 라이어가 눈치채요!\n" % c2
		+ "[color=#%s]3. 지목[/color]  두 바퀴가 끝나면 \"하나, 둘, 셋!\" 하고 다 같이 라이어를 가리켜요. 가장 많이 지목된 사람을 눌러요.\n" % c3
		+ "[color=#%s]4. 결과[/color]  시민을 지목하면 라이어 승리! 라이어를 잡으면 라이어가 [b]후보 20개 중에서 제시어를 맞힐 마지막 기회[/b]가 있어요. 맞히면 라이어의 역전승!\n" % c1
		+ "[color=#%s]5. 점수[/color]  안 잡힌 라이어 +3점, 역전승한 라이어 +2점, 시민이 이기면 시민 모두 +1점\n" % c2
		+ "[color=#%s]바보 라이어[/color]  라이어도 같은 주제의 [b]다른 단어[/b]를 받아서, 자기가 라이어인 줄 몰라요! 잡히면 그때 후보 20개를 보고 맞혀요." % c4
	)


func _add_setup_options(box: VBoxContainer) -> void:
	var counts: Array = []
	for n in range(3, 9):
		counts.append("%d명" % n)
	add_choice_row(box, "인원", counts, players - 3, UIKit.player_color(1),
		func(i: int) -> void: players = i + 3)
	var cats: Array = ["랜덤"] + LiarWords.CATEGORIES
	add_choice_row(box, "주제", cats, category_idx, UIKit.ORANGE,
		func(i: int) -> void: category_idx = i, 5)
	add_choice_row(box, "라이어 종류", ["일반 라이어", "바보 라이어"], 1 if fool_mode else 0, UIKit.PURPLE,
		func(i: int) -> void: fool_mode = i == 1)
	box.add_child(UIKit.make_label("바보 라이어: 라이어도 다른 단어를 받아서 자기가 라이어인 줄 몰라요", 21, UIKit.INK_SOFT))
	add_choice_row(box, "한 사람 설명 시간", TIMER_LABELS, timer_idx, UIKit.GREEN,
		func(i: int) -> void: timer_idx = i)


func _on_setup_opened() -> void:
	_timer_on = false


func _is_game_over() -> bool:
	return step == Step.SETUP or step == Step.DONE


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "liar"
	mode = "local"
	players = clampi(int(Global.get_setting(game_id, "players", 4)), 3, 8)
	category_idx = clampi(int(Global.get_setting(game_id, "category", 0)), 0, LiarWords.CATEGORIES.size())
	fool_mode = bool(Global.get_setting(game_id, "fool", false))
	timer_idx = clampi(int(Global.get_setting(game_id, "timer", 2)), 0, TIMER_SECS.size() - 1)
	_rng.randomize()
	build_frame()
	_cards_row.visible = false

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(holder)
	stage = VBoxContainer.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_theme_constant_override("separation", 16)
	holder.add_child(stage)
	attach_toast(holder)

	_show_idle()
	set_status("인원과 주제를 골라 주세요")
	show_setup()


func _process(delta: float) -> void:
	super(delta)
	if _timer_on and _overlay_kind == "":
		_time_left -= delta
		if _timer_label != null and is_instance_valid(_timer_label):
			_timer_label.text = _fmt_time(_time_left)
		if _time_left <= 0.0:
			_timer_on = false
			if _timer_label != null and is_instance_valid(_timer_label):
				_timer_label.add_theme_color_override("font_color", LIAR_RED)
			toast("시간 끝! 다음 사람 차례예요")


func _fmt_time(t: float) -> String:
	var s := ceili(maxf(t, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


func _clear_stage() -> void:
	for c in stage.get_children():
		stage.remove_child(c)
		c.queue_free()
	_timer_label = null


## 흰 판 하나를 무대에 넣고 안쪽 세로 줄을 돌려줌
func _stage_panel() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color.WHITE, 46, 28))
	stage.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	UIKit.pop_in(panel, 0.0, 0.92)
	return vb


func _chip(text: String, color: Color, font_size: int = 24) -> PanelContainer:
	var c := UIKit.make_chip(text, color, font_size)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _piece(p: int, h: float, happy: bool = false) -> PieceView:
	var pv := PieceView.new()
	pv.color = _side_color(p)
	pv.phase = p * 1.3
	pv.happy = happy
	pv.custom_minimum_size = Vector2(h, h)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return pv


func _wrap_label(text: String, font_size: int, color: Color = UIKit.INK_SOFT, weight: int = 700) -> Label:
	var l := UIKit.make_label(text, font_size, color, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _show_idle() -> void:
	step = Step.SETUP
	_clear_stage()
	var vb := _stage_panel()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -10)
	for p in 4:
		row.add_child(_piece(p, 110, p != 2))
	vb.add_child(row)
	vb.add_child(UIKit.make_label("우리 중에 라이어가 있다!", 40, UIKit.INK, 800))
	vb.add_child(_wrap_label("폰 하나로 3~8명이 함께 해요", 26))


# ══════════════════════════════════════════════════════
#  게임 시작
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	Global.set_setting(game_id, "players", players)
	Global.set_setting(game_id, "category", category_idx)
	Global.set_setting(game_id, "fool", fool_mode)
	Global.set_setting(game_id, "timer", timer_idx)
	apply_mode()
	scores = []
	for p in players:
		scores.append(0)
	used_words = []
	round_no = 0
	close_overlay()
	_new_round()


func _next_round() -> void:
	_token += 1
	close_overlay()
	_new_round()


func _new_round() -> void:
	round_no += 1
	logic = LiarLogic.new()
	var cat := "" if category_idx == 0 else str(LiarWords.CATEGORIES[category_idx - 1])
	logic.setup(players, cat, fool_mode, _rng, used_words)
	used_words.append(logic.word)
	_reveal_p = 0
	_show_reveal()
	toast("%d판째 · 주제는 '%s'" % [round_no, logic.category])


# ══════════════════════════════════════════════════════
#  1. 카드 확인
# ══════════════════════════════════════════════════════
func _show_reveal() -> void:
	step = Step.REVEAL
	_card_open = false
	_flipping = false
	_clear_stage()
	var p := _reveal_p
	set_status_side(p)
	set_status("%s 플레이어에게 폰을 넘겨 주세요" % _side_name(p))

	_card = Button.new()
	_card.focus_mode = Control.FOCUS_NONE
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := UIKit.panel_style(Color.WHITE, 46, 30)
	var sb_down := UIKit.panel_style(Color("#F7F2FC"), 46, 30)
	for k in ["normal", "hover", "disabled"]:
		_card.add_theme_stylebox_override(k, sb)
	_card.add_theme_stylebox_override("pressed", sb_down)
	_card.add_theme_stylebox_override("hover_pressed", sb_down)
	_card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_card.pressed.connect(_toggle_card)
	stage.add_child(_card)
	UIKit.keep_pivot_centered(_card)
	_fill_card()
	UIKit.pop_in(_card, 0.0, 0.9)

	_reveal_btn = UIKit.make_button("카드 보기", _side_color(p), Vector2(0, 110), 34)
	_reveal_btn.pressed.connect(_on_reveal_button)
	stage.add_child(_reveal_btn)


func _card_body() -> VBoxContainer:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 30)
	_card.add_child(m)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)
	return vb


func _fill_card() -> void:
	var p := _reveal_p
	var vb := _card_body()
	if not _card_open:
		vb.add_child(_piece(p, 190))
		vb.add_child(UIKit.make_label("%s 플레이어" % _side_name(p), 58, _side_text_color(p), 800))
		vb.add_child(_wrap_label("다른 사람이 못 보게 가리고\n카드를 눌러 확인하세요", 26))
		vb.add_child(_chip("%d / %d" % [p + 1, players], UIKit.GREY.darkened(0.15), 22))
		return
	vb.add_child(_chip("주제 · " + logic.category, UIKit.ORANGE, 30))
	var w := logic.card_word(p)
	if w.is_empty():
		vb.add_child(UIKit.make_label("당신은 라이어!", 64, LIAR_RED, 900))
		vb.add_child(_wrap_label("제시어는 아래 %d개 중 하나예요. 잘 기억해 두세요!" % logic.choices.size(), 24, UIKit.INK, 800))
		vb.add_child(_word_grid(logic.choices))
		vb.add_child(_wrap_label("들키지 않게, 다른 사람 설명을 잘 듣고 눈치껏~ (카드를 누르면 다시 덮여요)", 21))
		return
	else:
		vb.add_child(UIKit.make_label("제시어", 32, UIKit.INK_SOFT, 800))
		vb.add_child(UIKit.make_label(w, _word_size(w), UIKit.INK, 900))
		vb.add_child(_wrap_label("라이어가 눈치채지 못하게\n살짝만 설명해요", 25))
	vb.add_child(_wrap_label("다 봤으면 아래 버튼을 눌러요 (카드를 누르면 다시 덮여요)", 21))


## 후보 단어 칸에 넣을 글자와 크기 (긴 단어는 띄어쓰기에서 줄바꿈)
func _fit_word(w: String) -> Array:
	var text := w
	if w.length() >= 6 and w.contains(" "):
		text = w.replace(" ", "\n")
	var longest := 0
	for part in text.split("\n"):
		longest = maxi(longest, part.length())
	var fs := 27
	if longest >= 6:
		fs = 18
	elif longest == 5:
		fs = 22
	elif longest == 4:
		fs = 25
	return [text, fs]


## 라이어 카드에 보여 주는 후보 단어 격자 (4칸)
func _word_grid(words: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for w_v in words:
		var fit := _fit_word(str(w_v))
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = LIAR_RED.lerp(Color.WHITE, 0.86)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 9
		sb.content_margin_bottom = 9
		chip.add_theme_stylebox_override("panel", sb)
		var l := UIKit.make_label(fit[0], fit[1], UIKit.INK, 800)
		l.custom_minimum_size = Vector2(0, 34)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		grid.add_child(chip)
	return grid


func _word_size(w: String) -> int:
	if w.length() <= 3:
		return 100
	if w.length() <= 5:
		return 82
	return 64


func _toggle_card() -> void:
	if _flipping or step != Step.REVEAL:
		return
	_card_open = not _card_open
	_flipping = true
	var tok := _token
	var t := _card.create_tween()
	t.tween_property(_card, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	await t.finished
	if tok != _token:
		return
	_fill_card()
	_reveal_btn.text = _reveal_button_text()
	var t2 := _card.create_tween()
	t2.tween_property(_card, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t2.finished
	if tok != _token:
		return
	_flipping = false


func _reveal_button_text() -> String:
	if not _card_open:
		return "카드 보기"
	return "확인 완료 · 다음 사람" if _reveal_p < players - 1 else "확인 완료 · 설명 시작!"


func _on_reveal_button() -> void:
	if _flipping or step != Step.REVEAL:
		return
	if not _card_open:
		_toggle_card()
		return
	_reveal_p += 1
	if _reveal_p < players:
		_show_reveal()
	else:
		_talk_i = 0
		_show_talk()


# ══════════════════════════════════════════════════════
#  2. 설명 시간
# ══════════════════════════════════════════════════════
## 설명 두 바퀴: 한 사람씩 차례로 (1바퀴 순서대로 → 2바퀴 거꾸로) 진행
func _show_talk() -> void:
	step = Step.TALK
	_clear_stage()
	var order := logic.talk_order()
	_talk_i = clampi(_talk_i, 0, order.size() - 1)
	var i := _talk_i
	var round_i := 0 if i < players else 1
	var p: int = order[i]
	set_status_side(p)
	set_status("%s 차례! 제시어를 한 마디로 설명해요" % _side_name(p))
	var vb := _stage_panel()
	var tags := HBoxContainer.new()
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_theme_constant_override("separation", 10)
	tags.add_child(_chip("주제 · " + logic.category, UIKit.ORANGE, 26))
	tags.add_child(_chip("1바퀴 · 순서대로" if round_i == 0 else "2바퀴 · 거꾸로", UIKit.GREEN if round_i == 0 else UIKit.PURPLE, 26))
	vb.add_child(tags)

	vb.add_child(UIKit.make_label("지금 설명할 사람", 26, UIKit.INK_SOFT, 800))
	var who := HBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 8)
	who.add_child(_piece(p, 120, true))
	who.add_child(UIKit.make_label(_side_name(p), 72, _side_text_color(p), 900))
	vb.add_child(who)
	UIKit.pop_in(who, 0.0, 0.7)

	# 이번 바퀴 순서: 끝난 사람은 흐리게, 지금 사람은 진하게
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var start := round_i * players
	for k in players:
		var q: int = order[start + k]
		var idx := start + k
		var col: Color = _side_color(q)
		if idx < i:
			col = UIKit.GREY
		elif idx > i:
			col = col.lerp(Color.WHITE, 0.45)
		var chip := UIKit.make_chip("%s%s" % ["▶ " if idx == i else "", _side_name(q)], col, 30 if idx == i else 24)
		flow.add_child(chip)
	vb.add_child(flow)
	vb.add_child(UIKit.make_label("%d / %d번째 설명" % [i + 1, order.size()], 22, UIKit.INK_SOFT, 800))

	var secs: int = TIMER_SECS[timer_idx]
	if secs > 0:
		_timer_label = UIKit.make_label(_fmt_time(secs), 80, UIKit.INK, 900)
		vb.add_child(_timer_label)
		_time_left = secs
		_timer_on = true
	else:
		_timer_on = false
	vb.add_child(_wrap_label("라이어는 들키지 않게, 시민은 너무 쉽게 알려 주지 않게!", 22))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stage.add_child(row)
	var prev := UIKit.make_button("이전", UIKit.PURPLE, Vector2(0, 110), 30)
	prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev.disabled = i == 0
	prev.pressed.connect(_talk_step.bind(-1))
	row.add_child(prev)
	var next_text := "지목하러 가기!"
	if i < order.size() - 1:
		var nq: int = order[i + 1]
		next_text = "다음: %s" % _side_name(nq)
		if i == players - 1:
			next_text = "2바퀴(거꾸로): %s" % _side_name(nq)
	var go := UIKit.make_button(next_text, UIKit.GREEN if i < order.size() - 1 else LIAR_RED, Vector2(0, 110), 32)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_stretch_ratio = 2.2
	go.pressed.connect(_talk_step.bind(1))
	row.add_child(go)


func _talk_step(d: int) -> void:
	if step != Step.TALK:
		return
	var total := players * 2
	_talk_i += d
	if _talk_i >= total:
		_show_vote()
		return
	if d > 0 and _talk_i == players:
		toast("이제 거꾸로 한 바퀴 더!")
	elif d > 0 and _talk_i == total - 1:
		toast("마지막 설명이에요!")
	_show_talk()


## 지목 화면에서 '설명 더 하기' → 마지막 설명 차례로 돌아감
func _back_to_talk() -> void:
	if step != Step.VOTE:
		return
	_talk_i = players * 2 - 1
	_show_talk()


# ══════════════════════════════════════════════════════
#  3. 지목
# ══════════════════════════════════════════════════════
func _show_vote() -> void:
	step = Step.VOTE
	_timer_on = false
	_clear_stage()
	set_status_side(logic.first)
	set_status("하나, 둘, 셋! 다 같이 라이어를 가리켜요")
	var vb := _stage_panel()
	vb.add_child(UIKit.make_label("누가 라이어일까요?", 44, UIKit.INK, 800))
	vb.add_child(_wrap_label("가장 많이 지목된 사람을 눌러 주세요\n(동점이면 그 사람들만 한 번 더 설명!)", 24))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	for p in players:
		var b := UIKit.make_button(_side_name(p), _side_color(p), Vector2(0, 100 if players > 6 else 112), 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_confirm_accuse.bind(p))
		grid.add_child(b)
	var back := UIKit.make_button("설명 더 하기", UIKit.PURPLE, Vector2(0, 96), 30)
	back.pressed.connect(_back_to_talk)
	stage.add_child(back)


func _confirm_accuse(p: int) -> void:
	if step != Step.VOTE:
		return
	var box := open_overlay("accuse")
	box.add_child(_piece(p, 130))
	box.add_child(UIKit.make_label("%s 라이어로 지목할까요?" % josa(_side_name(p), "을", "를"), 38, UIKit.INK, 800))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var no := UIKit.make_button("다시 고를래요", UIKit.PURPLE, Vector2(0, 100), 30)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(close_overlay)
	row.add_child(no)
	var yes := UIKit.make_button("지목!", LIAR_RED, Vector2(0, 100), 34)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_judge.bind(p))
	row.add_child(yes)


func _judge(p: int) -> void:
	if step != Step.VOTE:
		return
	step = Step.JUDGE
	close_overlay()
	var caught := logic.accuse(p)
	_clear_stage()
	set_status_side(p)
	set_status("과연 라이어일까요...?")
	var vb := _stage_panel()
	var pv := _piece(p, 190)
	vb.add_child(pv)
	vb.add_child(UIKit.make_label("%s..." % josa(_side_name(p), "은", "는"), 52, _side_text_color(p), 800))
	var verdict := UIKit.make_label("두구두구두구", 42, UIKit.INK_SOFT, 800)
	vb.add_child(verdict)
	var extra := VBoxContainer.new()
	extra.add_theme_constant_override("separation", 14)
	vb.add_child(extra)
	var tok := _token
	await wait(1.6)
	if tok != _token:
		return
	verdict.add_theme_font_size_override("font_size", 80)
	verdict.add_theme_font_override("font", UIKit.font(900))
	if caught:
		verdict.text = "라이어였어요!"
		verdict.add_theme_color_override("font_color", LIAR_RED)
		UIKit.pop_in(verdict, 0.0, 0.6)
		set_status("라이어를 찾았어요! 하지만 아직 끝이 아니에요")
		extra.add_child(_wrap_label("라이어가 제시어를 맞히면 라이어의 역전승!", 26, UIKit.INK, 800))
		if logic.fool_mode:
			extra.add_child(_wrap_label("(바보 라이어가 받은 단어는 '%s'였어요)" % logic.fool_word, 23))
		var b := UIKit.make_button("라이어의 마지막 기회!", LIAR_RED, Vector2(0, 110), 34)
		b.pressed.connect(_show_guess)
		stage.add_child(b)
		UIKit.pop_in(b, 0.2)
	else:
		verdict.text = "시민이었어요!"
		verdict.add_theme_color_override("font_color", UIKit.player_dark(1))
		pv.happy = true
		UIKit.pop_in(verdict, 0.0, 0.6)
		set_status("엉뚱한 사람을 지목했어요!")
		await wait(1.0)
		if tok != _token:
			return
		extra.add_child(UIKit.make_label("진짜 라이어는...", 28, UIKit.INK_SOFT, 800))
		var who := HBoxContainer.new()
		who.alignment = BoxContainer.ALIGNMENT_CENTER
		who.add_theme_constant_override("separation", 8)
		who.add_child(_piece(logic.liar, 96, true))
		who.add_child(UIKit.make_label("%s!" % _side_name(logic.liar), 60, _side_text_color(logic.liar), 900))
		extra.add_child(who)
		UIKit.pop_in(who, 0.0, 0.6)
		var b := UIKit.make_button("결과 보기", UIKit.GREEN, Vector2(0, 110), 36)
		b.pressed.connect(_finish)
		stage.add_child(b)
		UIKit.pop_in(b, 0.3)


# ══════════════════════════════════════════════════════
#  4. 라이어의 마지막 기회
# ══════════════════════════════════════════════════════
func _show_guess() -> void:
	if step != Step.JUDGE:
		return
	step = Step.GUESS
	_clear_stage()
	set_status_side(logic.liar)
	set_status("%s 라이어! 제시어를 맞혀 보세요" % _side_name(logic.liar))
	var vb := _stage_panel()
	vb.add_child(_chip("주제 · " + logic.category, UIKit.ORANGE, 28))
	vb.add_child(UIKit.make_label("시민들의 제시어는?", 42, UIKit.INK, 800))
	vb.add_child(_wrap_label("처음에 본 후보 %d개 중 하나를 골라요" % logic.choices.size(), 23))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	for w_v in logic.choices:
		var w: String = w_v
		var fit := _fit_word(w)
		var b := UIKit.make_toggle(fit[0], LIAR_RED, null, int(fit[1]))
		b.toggle_mode = false
		b.custom_minimum_size = Vector2(0, 78)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_confirm_guess.bind(w))
		grid.add_child(b)


func _confirm_guess(w: String) -> void:
	if step != Step.GUESS:
		return
	var box := open_overlay("guess")
	box.add_child(UIKit.make_label("'%s'" % w, 70, UIKit.INK, 900))
	box.add_child(UIKit.make_label("이 단어가 정답일까요?", 34, UIKit.INK_SOFT, 800))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var no := UIKit.make_button("다시 고를래요", UIKit.PURPLE, Vector2(0, 100), 30)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(close_overlay)
	row.add_child(no)
	var yes := UIKit.make_button("이걸로!", LIAR_RED, Vector2(0, 100), 34)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_resolve_guess.bind(w))
	row.add_child(yes)


func _resolve_guess(w: String) -> void:
	if step != Step.GUESS:
		return
	close_overlay()
	logic.guess(w)
	_finish()


# ══════════════════════════════════════════════════════
#  5. 결과
# ══════════════════════════════════════════════════════
func _finish() -> void:
	if step == Step.DONE:
		return
	step = Step.DONE
	var pts := logic.points()
	for p in players:
		scores[p] = int(scores[p]) + int(pts[p])
	Global.add_stat(game_id, "played")

	_clear_stage()
	set_status_side(logic.liar)
	set_status("라이어 승리!" if logic.liar_won() else "시민 승리!")
	var vb := _stage_panel()
	vb.add_child(UIKit.make_label("%d판째 결과" % round_no, 30, UIKit.INK_SOFT, 800))
	var who := HBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(_piece(logic.liar, 110, logic.liar_won()))
	who.add_child(UIKit.make_label("라이어: %s" % _side_name(logic.liar), 46, _side_text_color(logic.liar), 800))
	vb.add_child(who)
	vb.add_child(UIKit.make_label("제시어: %s" % logic.word, 40, UIKit.INK, 800))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stage.add_child(row)
	var see := UIKit.make_button("점수판 보기", UIKit.ORANGE, Vector2(0, 110), 30)
	see.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	see.pressed.connect(_show_liar_result)
	row.add_child(see)
	var nxt := UIKit.make_button("다음 판!", UIKit.GREEN, Vector2(0, 110), 34)
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.pressed.connect(_next_round)
	row.add_child(nxt)
	_show_liar_result()


func _show_liar_result() -> void:
	var won := logic.liar_won()
	var box := open_overlay("result")
	var title := UIKit.make_label("라이어 승리!" if won else "시민 승리!", 68, LIAR_RED if won else UIKit.player_dark(1), 800)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	box.add_child(title)
	var why := ""
	match logic.result:
		LiarLogic.Result.LIAR_ESCAPED:
			why = "%s 지목했지만 시민이었어요" % josa(_side_name(logic.accused), "을", "를")
		LiarLogic.Result.LIAR_GUESSED:
			why = "라이어가 제시어를 맞혀서 역전승!"
		_:
			why = "라이어를 잡고 제시어도 지켜 냈어요"
	box.add_child(UIKit.make_label(why, 26, UIKit.INK_SOFT, 800))

	# 라이어 · 제시어
	var rp := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _side_color(logic.liar).lerp(Color.WHITE, 0.78)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(14)
	sb.set_border_width_all(5)
	sb.border_color = _side_color(logic.liar)
	rp.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	rp.add_child(hb)
	hb.add_child(_piece(logic.liar, 80, won))
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", -4)
	left.add_child(UIKit.make_label("라이어", 22, UIKit.INK_SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(UIKit.make_label(_side_name(logic.liar), 40, _side_text_color(logic.liar), 800, HORIZONTAL_ALIGNMENT_LEFT))
	hb.add_child(left)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", -4)
	right.add_child(UIKit.make_label("제시어", 22, UIKit.INK_SOFT, 800, HORIZONTAL_ALIGNMENT_RIGHT))
	right.add_child(UIKit.make_label(logic.word, 40, UIKit.INK, 900, HORIZONTAL_ALIGNMENT_RIGHT))
	hb.add_child(right)
	box.add_child(rp)
	if logic.fool_mode:
		box.add_child(UIKit.make_label("바보 라이어가 받은 단어: %s" % logic.fool_word, 23, UIKit.INK_SOFT))
	if logic.result == LiarLogic.Result.CITIZENS and not logic.guessed.is_empty():
		box.add_child(UIKit.make_label("라이어의 답: %s" % logic.guessed, 23, UIKit.INK_SOFT))

	# 점수판
	box.add_child(UIKit.make_label("점수판 · %d판째" % round_no, 26, UIKit.INK_SOFT, 800))
	var pts := logic.points()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
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
		var pv := _piece(p, 46, int(pts[p]) > 0)
		pv.bob = int(pts[p]) > 0
		ch.add_child(pv)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", -6)
		var gained := "  +%d" % int(pts[p]) if int(pts[p]) > 0 else ""
		info.add_child(UIKit.make_label(_side_name(p) + gained, 19, UIKit.INK_SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT))
		info.add_child(UIKit.make_label("%d점" % int(scores[p]), 28, _side_text_color(p), 900, HORIZONTAL_ALIGNMENT_LEFT))
		ch.add_child(info)
		grid.add_child(cell)

	var again := UIKit.make_button("다음 판!", UIKit.GREEN, Vector2(0, 104), 38)
	again.pressed.connect(_next_round)
	box.add_child(again)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	var view_btn := UIKit.make_button("닫기", Color("#3FA9F5"), Vector2(0, 84), 26)
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

	var conf := Confetti.new()
	overlay.add_child(conf)
	conf.burst(90)
