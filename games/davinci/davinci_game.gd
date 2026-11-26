extends GameScreen
## 비밀 숫자 – 게임 화면 (2~4명 · AI 대전 / 친구끼리 폰 돌리기)
## 차례: 더미에서 뽑기 → 상대 숨은 타일 맞히기 → (맞히면) 계속 or 멈추기

var logic: DavinciLogic
var ai: DavinciAI = null
var players: int = 2

var board: DavinciBoard
var stop_btn: Button

var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _viewer: int = 0


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "비밀 숫자"


func _mode_label(id: String) -> String:
	if id == "local":
		return "친구끼리"
	return super(id)


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	return (
		"[color=#%s]1. 타일[/color]  0~11이 적힌 검정·하양 타일 24개. 처음에 2~3명이면 4개, 4명이면 3개씩 받아요.\n" % c1
		+ "[color=#%s]2. 줄 세우기[/color]  타일은 항상 [b]작은 숫자부터 왼쪽→오른쪽[/b]. 숫자가 같으면 검정이 왼쪽이에요. 타일 색은 모두에게 보여요.\n" % c2
		+ "[color=#%s]3. 내 차례[/color]  더미에서 타일 1개를 뽑고(색은 골라요), 상대의 숨은 타일 하나를 골라 숫자를 맞혀요.\n" % c3
		+ "[color=#%s]4. 맞히면[/color]  그 타일이 공개돼요. 한 번 더 도전하거나, [b]멈추기[/b]로 뽑은 타일을 숨긴 채 내 줄에 넣어요.\n" % c1
		+ "[color=#%s]5. 틀리면[/color]  뽑은 타일을 [b]공개한 채[/b] 내 줄에 넣고 차례 끝. (더미가 비었으면 내 타일 하나를 공개)\n" % c4
		+ "[color=#%s]6. 승리[/color]  타일이 모두 공개되면 탈락! 마지막까지 숨은 타일이 남은 사람이 이겨요. 주황 테두리 = 공개된 타일\n" % c2
		+ "[color=#%s]꿀팁[/color]  양옆 타일 사이에 들어갈 수 있는 숫자만 남겨 보세요. 남이 틀린 숫자도 힌트!" % c4
	)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "인원 (나 포함)", ["2명", "3명", "4명"], players - 2, UIKit.player_color(1),
		func(i: int) -> void: players = i + 2)
	box.add_child(UIKit.make_label("친구끼리: 폰 하나를 돌려 가며 해요 (차례마다 화면 가리개)", 21, UIKit.INK_SOFT))


func _on_setup_opened() -> void:
	_busy = false
	if board != null:
		board.input_mode = DavinciBoard.Tap.NONE
		board.target_key = -1
		board.clear_bubble()


func _is_game_over() -> bool:
	return logic == null or logic.is_over() or (ai_level >= 0 and logic.out[human_player])


func player_name(p: int) -> String:
	if ai_level >= 0:
		if p == human_player:
			return "나"
		if players == 2:
			return "AI · " + LEVEL_NAMES[ai_level]
		return "AI %d" % p
	return _side_name(p)


func subject(p: int) -> String:
	if ai_level >= 0:
		if p == human_player:
			return "내가"
		if players == 2:
			return "AI가"
	return josa(player_name(p), "이", "가")


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "davinci"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	players = clampi(int(Global.get_setting(game_id, "players", 2)), 2, 4)
	_rng.randomize()
	build_frame()

	board = DavinciBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 560)
	board.tile_tapped.connect(_on_tile)
	board.pile_tapped.connect(_on_pile)
	content.add_child(board)
	attach_toast(board)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	content.add_child(bottom)
	stop_btn = UIKit.make_button("멈추기", UIKit.ORANGE, Vector2(0, 96), 30)
	stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_btn.disabled = true
	stop_btn.pressed.connect(_on_stop_or_result)
	bottom.add_child(stop_btn)
	var new_btn := UIKit.make_button("새 게임", UIKit.GREEN, Vector2(0, 96), 30)
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(show_setup)
	bottom.add_child(new_btn)

	# 설정 화면 뒤에 보일 판
	apply_mode()
	logic = DavinciLogic.new()
	logic.setup(players, _rng, 0)
	_viewer = 0
	board.setup(logic, _colors(), _names())
	board.reveal_all = false
	setup_cards(range(players))
	_refresh_ui()
	set_status("어떻게 플레이할지 골라 주세요")
	show_setup()


func _colors() -> Array:
	var out: Array = []
	for p in players:
		out.append(UIKit.player_color(p))
	return out


func _names() -> Array:
	var out: Array = []
	for p in players:
		out.append(player_name(p))
	return out


# ══════════════════════════════════════════════════════
#  게임 진행
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	_busy = false
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "players", players)
	apply_mode()
	ai = DavinciAI.new(ai_level) if ai_level >= 0 else null
	human_player = 0
	logic = DavinciLogic.new()
	logic.setup(players, _rng, _rng.randi() % players)
	_viewer = human_player if ai_level >= 0 else -1
	board.setup(logic, _colors(), _names())
	board.viewer = maxi(_viewer, 0)
	setup_cards(range(players))
	stop_btn.text = "멈추기"
	stop_btn.disabled = true
	close_overlay()
	_refresh_ui()
	toast("%s 먼저 시작해요!" % subject(logic.current))
	_next_turn()


func _next_turn() -> void:
	board.input_mode = DavinciBoard.Tap.NONE
	board.target_key = -1
	stop_btn.disabled = true
	_refresh_ui()
	if logic.is_over():
		_game_over()
		return
	if ai_level >= 0 and logic.out[human_player]:
		_human_out()
		return
	var cur := logic.current
	if is_ai(cur):
		_ai_turn()
		return
	if ai_level < 0 and _viewer != cur:
		# 친구끼리: 숨은 타일이 보이지 않게 가리고 다음 사람에게
		show_curtain("%s 차례!" % _side_name(cur), "%s에게 폰을 넘겨 주세요" % _side_name(cur), _side_color(cur), _begin_human)
		return
	_begin_human()


func _begin_human() -> void:
	var cur := logic.current
	if ai_level < 0:
		_viewer = cur
		board.viewer = cur
	_refresh_ui()
	var who := who_prefix(cur)
	stop_btn.disabled = true
	match logic.phase:
		DavinciLogic.Phase.DRAW:
			board.input_mode = DavinciBoard.Tap.PILE
			set_status("%s검정·하양 더미 중 하나를 눌러 뽑아요" % who)
		DavinciLogic.Phase.GUESS:
			board.input_mode = DavinciBoard.Tap.TARGET
			set_status("%s상대의 숨은 타일을 눌러 맞혀 보세요" % who)
			if logic.pool.is_empty() and logic.guesses_this_turn == 0:
				toast("더미가 비었어요! 뽑지 않고 바로 맞혀요")
		DavinciLogic.Phase.DECIDE:
			board.input_mode = DavinciBoard.Tap.TARGET
			stop_btn.disabled = false
			set_status("%s정답! 한 번 더 맞히거나 멈추세요" % who)
		DavinciLogic.Phase.REVEAL_OWN:
			board.input_mode = DavinciBoard.Tap.OWN
			set_status("%s공개할 내 타일 하나를 고르세요" % who)


func _human_turn_ok() -> bool:
	return not _busy and not logic.is_over() and not is_ai(logic.current) and not has_curtain() and _overlay_kind == ""


func _on_pile(color: int) -> void:
	if not _human_turn_ok() or logic.phase != DavinciLogic.Phase.DRAW:
		return
	var k := logic.draw(color, _rng)
	if k < 0:
		return
	board.pop(k)
	toast("%s %s 뽑았어요" % ["검정" if DavinciLogic.color_of(k) == 0 else "하양", josa(str(DavinciLogic.num_of(k)), "을", "를")])
	_begin_human()


func _on_tile(p: int, i: int) -> void:
	if not _human_turn_ok():
		return
	if logic.phase == DavinciLogic.Phase.REVEAL_OWN:
		if p == logic.current and not logic.revealed[p][i]:
			_reveal_own(i)
		return
	if logic.phase == DavinciLogic.Phase.DRAW:
		toast("먼저 더미에서 타일을 뽑아요")
		return
	if p == logic.current:
		toast("상대의 타일을 골라야 해요")
		return
	if logic.revealed[p][i]:
		toast("이미 공개된 타일이에요")
		return
	if logic.can_target(p, i):
		_open_picker(p, i)


func _open_picker(p: int, i: int) -> void:
	var k: int = logic.hands[p][i]
	var col := DavinciLogic.color_of(k)
	board.target_key = k
	var box := open_overlay("pick")
	box.add_child(UIKit.make_label("어떤 숫자일까요?", 44, UIKit.INK, 800))
	box.add_child(UIKit.make_label("%s의 %s 타일 · 왼쪽에서 %d번째" % [player_name(p), "검정" if col == 0 else "하양", i + 1], 24, UIKit.INK_SOFT))
	var ex := logic.excluded_for(_viewer, p, i)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for num in DavinciLogic.MAX_NUM + 1:
		var b := _num_button(num, col)
		b.disabled = ex.has(num)
		b.pressed.connect(_pick_number.bind(p, i, num))
		grid.add_child(b)
	box.add_child(UIKit.make_label("회색 숫자는 이미 보이거나 틀렸던 숫자예요", 21, UIKit.INK_SOFT))
	var cancel := UIKit.make_button("취소", UIKit.PURPLE, Vector2(0, 88), 30)
	cancel.pressed.connect(_cancel_pick)
	box.add_child(cancel)


func _num_button(num: int, col: int) -> Button:
	var body := DavinciBoard.BLACK if col == 0 else Color("#F4F1F8")
	var b := UIKit.make_button(str(num), body, Vector2(0, 100), 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if col == 1:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(key, DavinciBoard.BLACK)
	return b


func _cancel_pick() -> void:
	close_overlay()
	board.target_key = -1


func _pick_number(p: int, i: int, num: int) -> void:
	close_overlay()
	_do_guess(p, i, num)


## 사람의 추측 (말풍선 → 결과 연출)
func _do_guess(p: int, i: int, num: int) -> void:
	_busy = true
	board.input_mode = DavinciBoard.Tap.NONE
	stop_btn.disabled = true
	var tok := _token
	var by := logic.current
	var k: int = logic.hands[p][i]
	board.target_key = k
	board.show_bubble(k, num)
	set_status("%s의 타일이 %d일까요?" % [player_name(p), num])
	await wait(0.7)
	if tok != _token:
		return
	var ok := _resolve(p, i, num, by)
	await wait(1.1 if ok else 1.4)
	if tok != _token:
		return
	board.target_key = -1
	board.clear_bubble()
	_busy = false
	if logic.is_over() or logic.current != by:
		_next_turn()
	else:
		_begin_human()


## 추측 결과 적용 + 알림 (사람/AI 공용)
func _resolve(p: int, i: int, num: int, by: int) -> bool:
	var k: int = logic.hands[p][i]
	var ok := logic.guess(p, i, num)
	board.resolve_bubble(ok)
	if ok:
		board.flip(k)
		var msg := "정답! %s의 타일은 %d" % [player_name(p), num]
		if logic.last.has("out"):
			msg = "%s 타일이 모두 공개돼서 탈락!" % subject(p)
		toast(msg)
	else:
		var msg := "땡! %s 아니에요" % josa(str(num), "이", "가")
		if logic.last.has("placed"):
			var pk: int = logic.last["placed"]
			board.flip(pk)
			msg += " · %s 뽑은 타일이 공개돼요" % subject(by)
		toast(msg)
	_refresh_ui()
	return ok


func _on_stop_or_result() -> void:
	if _is_game_over():
		reopen_result()
		return
	if not _human_turn_ok() or logic.phase != DavinciLogic.Phase.DECIDE:
		return
	var placed := logic.drawn
	logic.stop()
	if placed >= 0:
		board.pop(placed)
		toast("뽑은 타일을 숨긴 채로 넣었어요")
	_busy = true
	stop_btn.disabled = true
	board.input_mode = DavinciBoard.Tap.NONE
	_refresh_ui()
	var tok := _token
	await wait(0.9)
	if tok != _token:
		return
	_busy = false
	_next_turn()


func _reveal_own(i: int) -> void:
	var me := logic.current
	var k: int = logic.hands[me][i]
	if not logic.reveal_own(i):
		return
	_busy = true
	board.input_mode = DavinciBoard.Tap.NONE
	board.flip(k)
	if logic.last.has("out"):
		toast("타일이 모두 공개돼서 탈락!")
	else:
		toast("내 타일 %s 공개했어요" % josa(str(DavinciLogic.num_of(k)), "을", "를"))
	_refresh_ui()
	var tok := _token
	await wait(1.2)
	if tok != _token:
		return
	_busy = false
	_next_turn()


# ── AI 차례 ───────────────────────────────────────────
func _ai_turn() -> void:
	var tok := _token
	var me := logic.current
	_busy = true
	board.input_mode = DavinciBoard.Tap.NONE
	start_thinking("%s 차례" % player_name(me))
	await wait(0.7)
	if tok != _token:
		return
	if logic.phase == DavinciLogic.Phase.DRAW:
		var k := logic.draw(ai.choose_draw(logic, me), _rng)
		if k >= 0:
			board.pop(k)
		_refresh_ui()
		await wait(0.6)
		if tok != _token:
			return
	var tries := 0
	while tries < 30:
		tries += 1
		var g := ai.choose_guess(logic, me)
		if g.is_empty():
			break
		var p: int = g[0]
		var i: int = g[1]
		var num: int = g[2]
		var k: int = logic.hands[p][i]
		board.target_key = k
		set_status("%s %s의 타일을 노려요" % [subject(me), player_name(p)])
		await wait(0.6)
		if tok != _token:
			return
		board.show_bubble(k, num)
		await wait(0.8)
		if tok != _token:
			return
		var ok := _resolve(p, i, num, me)
		await wait(1.1)
		if tok != _token:
			return
		board.clear_bubble()
		board.target_key = -1
		if logic.is_over():
			break
		if ok:
			if ai.should_continue(logic, me):
				set_status("%s 한 번 더 도전해요!" % subject(me))
				continue
			var placed := logic.drawn
			logic.stop()
			if placed >= 0:
				board.pop(placed)
			toast("%s 멈추고 뽑은 타일을 숨겼어요" % subject(me))
			break
		if logic.phase == DavinciLogic.Phase.REVEAL_OWN:
			await wait(0.4)
			if tok != _token:
				return
			var idx := ai.choose_reveal(logic, me)
			var rk: int = logic.hands[me][idx]
			logic.reveal_own(idx)
			board.flip(rk)
			toast("%s 자기 타일 하나를 공개했어요" % subject(me))
		break
	_refresh_ui()
	await wait(0.9)
	if tok != _token:
		return
	_busy = false
	_next_turn()


# ══════════════════════════════════════════════════════
#  화면 갱신 / 결과
# ══════════════════════════════════════════════════════
func _refresh_ui() -> void:
	for p in logic.n:
		var big := "탈락" if logic.out[p] else "%d개" % logic.hidden_count(p)
		set_card(p, player_name(p), big, not logic.is_over() and logic.current == p)
	set_status_side(logic.current)


## AI 대전에서 내가 먼저 탈락하면 남은 AI끼리 하지 않고 바로 끝
func _human_out() -> void:
	_stop_for_result()
	Global.add_stat(game_id, "played")
	set_status("내 타일이 모두 공개됐어요. 탈락!")
	var tok := _token
	await wait(1.4)
	if tok != _token:
		return
	var alive: Array = []
	for p in logic.n:
		if not logic.out[p]:
			alive.append(p)
	alive.sort_custom(func(a: int, b: int) -> bool: return logic.hidden_count(a) > logic.hidden_count(b))
	var order: Array = alive.duplicate()
	for k in range(logic.out_order.size() - 1, -1, -1):
		order.append(logic.out_order[k])
	var rows: Array = []
	for r in order.size():
		var p: int = order[r]
		var small := "숨은 타일 %d개 남음" % logic.hidden_count(p) if not logic.out[p] else "맞힘 %d · 틀림 %d" % [int(logic.hits[p]), int(logic.misses[p])]
		rows.append({"p": p, "big": "%d등" % (r + 1), "small": small})
	show_result("탈락...", UIKit.PURPLE, false, int(order[0]), rows, "다음엔 끝까지 살아남아 봐요!")


func _stop_for_result() -> void:
	board.input_mode = DavinciBoard.Tap.NONE
	board.reveal_all = true
	stop_btn.text = "결과 보기"
	stop_btn.disabled = false


func _game_over() -> void:
	_stop_for_result()
	record_result(logic.winner)
	set_status("게임 끝! %s 끝까지 살아남았어요" % subject(logic.winner))
	var tok := _token
	await wait(1.4)
	if tok != _token:
		return
	var order := logic.ranking()
	var rows: Array = []
	for r in order.size():
		var p: int = order[r]
		rows.append({"p": p, "big": "%d등" % (r + 1), "small": "맞힘 %d · 틀림 %d" % [int(logic.hits[p]), int(logic.misses[p])]})
	show_standard_result(logic.winner, rows, "마지막까지 숨은 타일 %d개가 남았어요" % logic.hidden_count(logic.winner))
