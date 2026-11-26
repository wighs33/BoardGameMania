extends GameScreen
## 리버시 – 게임 화면 (착수 · 패스 · 무르기 · AI 차례 관리)
## 상단 바 / 플레이어 카드 / 팝업 등 공통 UI는 GameScreen 에 있음

const SIDE_NAMES := ["흑", "백"]

var logic: ReversiLogic
var ai: ReversiAI = null
var color_choice: int = 0     # 0 = 흑, 1 = 백, 2 = 랜덤 (AI 대전에서 내 돌)
var show_hints: bool = true

var board: ReversiBoard
var undo_btn: Button
var result_btn: Button

var _busy: bool = false
var _thread: Thread = null
var _thread_token: int = -1
var _ai_started_ms: int = 0
var _last_counts: Array = [2, 2]


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "리버시"


func _side_name(p: int) -> String:
	return SIDE_NAMES[p]


func _side_color(p: int) -> Color:
	return ReversiBoard.BLACK if p == 0 else Color("#F4F1F8")


func _side_accent(p: int) -> Color:
	return Color("#3D3450") if p == 0 else Color("#B3A6C6")


func _side_text_color(p: int) -> Color:
	return Color("#2B2B3A") if p == 0 else Color("#8A7F99")


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	return (
		"[color=#%s]1. 시작[/color]  가운데 4개(흑 2 · 백 2)로 시작하고, 흑이 먼저 둬요.\n" % c1
		+ "[color=#%s]2. 놓기[/color]  상대 돌을 내 돌 사이에 [b]끼울 수 있는 곳[/b]에만 둘 수 있어요. (가로·세로·대각선)\n" % c2
		+ "[color=#%s]3. 뒤집기[/color]  끼인 상대 돌은 모두 내 색으로 뒤집혀요.\n" % c3
		+ "[color=#%s]4. 패스[/color]  둘 곳이 없으면 차례가 자동으로 넘어가요.\n" % c1
		+ "[color=#%s]5. 승리[/color]  둘 다 둘 곳이 없으면 끝! 돌이 더 많은 쪽이 이겨요.\n" % c2
		+ "[color=#%s]꿀팁[/color]  네 귀퉁이(귀)는 절대 뒤집히지 않는 최고의 자리예요. 귀 바로 옆 칸은 귀를 내줄 수 있으니 조심!" % c4
	)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "내 돌 (AI 대전)", ["흑 · 먼저", "백 · 나중", "랜덤"], color_choice, Color("#3D3450"),
		func(i: int) -> void: color_choice = i)
	add_choice_row(box, "둘 수 있는 곳 표시", ["켜기", "끄기"], 0 if show_hints else 1, UIKit.GREEN,
		func(i: int) -> void: show_hints = i == 0)


func _on_setup_opened() -> void:
	_busy = false
	if board != null:
		board.input_enabled = false


func _is_game_over() -> bool:
	return logic != null and logic.over


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "reversi"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	color_choice = int(Global.get_setting(game_id, "color", 0))
	show_hints = bool(Global.get_setting(game_id, "hints", true))
	build_frame()

	board = ReversiBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 480)
	board.cell_tapped.connect(_on_cell)
	content.add_child(board)
	attach_toast(board)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	content.add_child(bottom)
	undo_btn = UIKit.make_button("무르기", UIKit.PURPLE, Vector2(0, 96), 30)
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_btn.disabled = true
	undo_btn.pressed.connect(_on_undo_or_result)
	bottom.add_child(undo_btn)
	var new_btn := UIKit.make_button("새 게임", UIKit.GREEN, Vector2(0, 96), 30)
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(show_setup)
	bottom.add_child(new_btn)

	logic = ReversiLogic.new()
	logic.setup()
	board.setup(logic)
	_refresh_ui()
	set_status("어떻게 플레이할지 골라 주세요")
	show_setup()


func _exit_tree() -> void:
	_token += 1
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func _process(delta: float) -> void:
	super(delta)
	if _thread != null and not _thread.is_alive():
		var result: Variant = _thread.wait_to_finish()
		_thread = null
		if _thread_token == _token:
			_apply_ai_result(result)


# ══════════════════════════════════════════════════════
#  게임 진행
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	_busy = false
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "color", color_choice)
	Global.set_setting(game_id, "hints", show_hints)
	apply_mode()
	ai = ReversiAI.new(ai_level) if ai_level >= 0 else null
	if ai_level >= 0:
		human_player = color_choice if color_choice < 2 else randi() % 2
	else:
		human_player = 0
	logic = ReversiLogic.new()
	logic.setup()
	board.setup(logic)
	_last_counts = [2, 2]
	close_overlay()
	if ai_level >= 0:
		toast("나는 %s! %s" % [_side_name(human_player), "먼저 두세요" if human_player == 0 else "AI가 먼저 둬요"])
	else:
		toast("흑이 먼저 둬요!")
	_next_turn()


func _next_turn() -> void:
	board.input_enabled = false
	board.hints = []
	undo_btn.text = "무르기"
	_refresh_ui()
	if logic.passed_player >= 0:
		toast("%s 둘 곳이 없어서 차례를 넘겨요" % subject(logic.passed_player))
	if logic.over:
		record_result(logic.winner)
		set_status("게임 끝! 흑 %d : 백 %d" % [logic.count(0), logic.count(1)])
		undo_btn.text = "결과 보기"
		undo_btn.disabled = false
		var tok := _token
		await wait(maxf(1.2, board.anim_time_left() + 0.8))
		if tok != _token:
			return
		_show_reversi_result()
		return
	if is_ai(logic.current):
		_start_ai()
		return
	undo_btn.disabled = not _can_undo()
	board.input_enabled = true
	board.hint_player = logic.current
	if show_hints:
		board.hints = logic.legal_moves(logic.current)
	set_status("%s돌을 놓을 곳을 누르세요" % who_prefix(logic.current))


func _on_cell(c: Vector2i) -> void:
	if _busy or _thread != null or logic.over or is_ai(logic.current):
		return
	if not logic.is_legal(c, logic.current):
		board.flash_bad(c)
		if logic.stone(c) == 0:
			toast("상대 돌을 끼울 수 있는 곳에만 둘 수 있어요")
		return
	_put(c)


func _put(c: Vector2i) -> void:
	var who := logic.current
	if not logic.place(c):
		return
	var flips: Array = logic.history[logic.history.size() - 1]["flips"]
	board.animate_move(c, flips, who)
	var corner := (c.x == 0 or c.x == logic.size - 1) and (c.y == 0 or c.y == logic.size - 1)
	if corner:
		toast("%s 귀를 차지했어요!" % subject(who))
	elif flips.size() >= 5:
		toast("%d개 뒤집기!" % flips.size())
	_next_turn()


func _can_undo() -> bool:
	if logic.over or logic.history.is_empty():
		return false
	if ai_level >= 0:
		return logic.moves_of(human_player) > 0
	return true


func _on_undo_or_result() -> void:
	if logic.over:
		reopen_result()  # 게임이 끝난 뒤에는 '결과 보기' 버튼
		return
	if _busy or _thread != null or not _can_undo():
		return
	if ai_level >= 0:
		# 내 차례가 다시 올 때까지 (AI 수 + 내 수) 되돌림
		while not logic.history.is_empty():
			logic.undo()
			if logic.current == human_player:
				break
	else:
		logic.undo()
	board.reset_anims()
	_last_counts = [logic.count(0), logic.count(1)]
	toast("한 수 물렀어요")
	_next_turn()


# ── AI 차례 (생각은 별도 스레드에서) ───────────────────
func _start_ai() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	board.input_enabled = false
	undo_btn.disabled = true
	start_thinking()
	_ai_started_ms = Time.get_ticks_msec()
	_thread = Thread.new()
	_thread_token = _token
	_thread.start(ai.choose.bind(logic.clone(), logic.current))


func _apply_ai_result(result: Variant) -> void:
	var tok := _token
	var c: Vector2i = result
	# 앞 수의 뒤집기가 다 보이고 나서 두도록
	var wait_s := maxf(0.55 - (Time.get_ticks_msec() - _ai_started_ms) / 1000.0, board.anim_time_left() + 0.15)
	if wait_s > 0.0:
		await wait(wait_s)
		if tok != _token:
			return
	if not logic.is_legal(c, logic.current):
		var legal := logic.legal_moves(logic.current)
		if legal.is_empty():
			_next_turn()
			return
		c = legal[0]
	_put(c)


# ══════════════════════════════════════════════════════
#  화면 갱신 / 결과
# ══════════════════════════════════════════════════════
func _refresh_ui() -> void:
	for p in 2:
		var active := not logic.over and logic.current == p
		var nm := player_name(p)
		if ai_level >= 0:
			nm += " · " + _side_name(p)
		var n := logic.count(p)
		set_card(p, nm, "%d개" % n, active, n > int(_last_counts[p]))
		_last_counts[p] = n
	set_status_side(logic.current)


func _show_reversi_result() -> void:
	var w := logic.winner
	var rows: Array = []
	for p in 2:
		rows.append({"p": p, "big": "%d개" % logic.count(p), "small": "%s · %d수" % [_side_name(p), logic.moves_of(p)]})
	var diff := absi(logic.count(0) - logic.count(1))
	show_standard_result(w, rows, "돌 %d개 차이!" % diff if w >= 0 else "돌 수가 똑같아요!")
