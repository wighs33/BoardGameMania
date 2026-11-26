extends GameScreen
## 오목 – 게임 화면 (착수 · 무르기 · AI 차례 관리)
## 상단 바 / 플레이어 카드 / 팝업 등 공통 UI는 GameScreen 에 있음

const BOARD_SIZE := 15
const SIDE_NAMES := ["흑", "백"]

var logic: OmokLogic
var ai: OmokAI = null
var color_choice: int = 0     # 0 = 흑, 1 = 백, 2 = 랜덤 (AI 대전에서 내 돌)
var ban33: bool = true

var board: OmokBoard
var undo_btn: Button
var place_btn: Button

var _busy: bool = false
var _thread: Thread = null
var _thread_token: int = -1
var _ai_started_ms: int = 0


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "오목"


func _side_name(p: int) -> String:
	return SIDE_NAMES[p]


func _side_color(p: int) -> Color:
	return OmokBoard.BLACK if p == 0 else Color("#F4F1F8")


func _side_accent(p: int) -> Color:
	return Color("#3D3450") if p == 0 else Color("#B3A6C6")


func _side_text_color(p: int) -> Color:
	return Color("#2B2B3A") if p == 0 else Color("#8A7F99")


func _rules_text() -> String:
	var c1 := UIKit.INK.to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := Color("#E04848").to_html(false)
	var c4 := UIKit.player_dark(1).to_html(false)
	return (
		"[color=#%s]1. 놓기[/color]  흑부터 번갈아 판의 교차점에 돌을 하나씩 놓아요.\n" % c1
		+ "[color=#%s]2. 승리[/color]  가로·세로·대각선으로 [b]5개 이상[/b] 나란히 놓으면 이겨요.\n" % c2
		+ "[color=#%s]3. 쌍삼 금지[/color] (선택)  열린 3을 [b]한 번에 두 개[/b] 만드는 자리는 흑·백 모두 둘 수 없어요. 판에 빨간 X로 표시돼요. (그 수로 오목이 되면 OK)\n" % c3
		+ "[color=#%s]4. 두는 법[/color]  누르면 미리보기 돌이 나와요. 같은 곳을 한 번 더 누르거나 '여기에 두기'를 누르면 확정!\n" % c4
		+ "[color=#%s]5. 무르기[/color]  실수했다면 한 수 되돌릴 수 있어요. (AI 대전은 AI 수까지 함께)" % c1
	)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "내 돌 (AI 대전)", ["흑 · 먼저", "백 · 나중", "랜덤"], color_choice, Color("#3D3450"),
		func(i: int) -> void: color_choice = i)
	add_choice_row(box, "규칙", ["자유룰", "쌍삼 금지"], 1 if ban33 else 0, UIKit.player_color(1),
		func(i: int) -> void: ban33 = i == 1)


func _on_setup_opened() -> void:
	_busy = false
	if board != null:
		board.input_enabled = false
		board.clear_preview()


func _is_game_over() -> bool:
	return logic != null and logic.over


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "omok"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	color_choice = int(Global.get_setting(game_id, "color", 0))
	ban33 = bool(Global.get_setting(game_id, "ban33", true))
	build_frame()

	board = OmokBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 520)
	board.point_tapped.connect(_on_point)
	content.add_child(board)
	attach_toast(board)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	content.add_child(bottom)
	undo_btn = UIKit.make_button("무르기", UIKit.PURPLE, Vector2(0, 96), 28)
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_btn.disabled = true
	undo_btn.pressed.connect(_on_undo)
	bottom.add_child(undo_btn)
	place_btn = UIKit.make_button("여기에 두기", UIKit.GREEN, Vector2(0, 96), 30)
	place_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_btn.size_flags_stretch_ratio = 1.5
	place_btn.disabled = true
	place_btn.pressed.connect(_on_place_btn)
	bottom.add_child(place_btn)
	var new_btn := UIKit.make_button("새 게임", UIKit.ORANGE, Vector2(0, 96), 28)
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(show_setup)
	bottom.add_child(new_btn)

	logic = OmokLogic.new()
	logic.setup(BOARD_SIZE, ban33)
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
	Global.set_setting(game_id, "ban33", ban33)
	apply_mode()
	ai = OmokAI.new(ai_level) if ai_level >= 0 else null
	if ai_level >= 0:
		human_player = color_choice if color_choice < 2 else randi() % 2
	else:
		human_player = 0
	logic = OmokLogic.new()
	logic.setup(BOARD_SIZE, ban33)
	board.setup(logic)
	close_overlay()
	if ai_level >= 0:
		toast("나는 %s! %s" % [_side_name(human_player), "먼저 두세요" if human_player == 0 else "AI가 먼저 둬요"])
	else:
		toast("흑이 먼저 둬요!")
	_next_turn()


func _next_turn() -> void:
	board.clear_preview()
	board.input_enabled = false
	board.forbidden = []
	place_btn.text = "여기에 두기"
	place_btn.disabled = true
	_refresh_ui()
	if logic.over:
		record_result(logic.winner)
		undo_btn.disabled = true
		if logic.winner >= 0:
			board.mark_win()
			set_status("%s 다섯 개를 완성했어요!" % subject(logic.winner))
		else:
			set_status("판이 가득 찼어요. 무승부!")
		place_btn.text = "결과 보기"
		place_btn.disabled = false
		var tok := _token
		await wait(1.6)
		if tok != _token:
			return
		_show_omok_result()
		return
	if is_ai(logic.current):
		_start_ai()
		return
	undo_btn.disabled = not _can_undo()
	board.input_enabled = true
	board.preview_player = logic.current
	if logic.ban_double_three:
		board.forbidden = logic.forbidden_cells(logic.current)
	set_status("%s돌을 놓을 곳을 누르세요" % who_prefix(logic.current))


func _on_point(c: Vector2i) -> void:
	if _busy or _thread != null or logic.over or is_ai(logic.current):
		return
	if not logic.is_empty(c):
		return
	if board.preview == c:
		_confirm()
		return
	board.preview = c
	board.preview_player = logic.current
	board.preview_bad = logic.is_forbidden(c, logic.current)
	place_btn.disabled = board.preview_bad
	if board.preview_bad:
		set_status("쌍삼 자리라서 둘 수 없어요")
	else:
		set_status("한 번 더 누르거나 '여기에 두기'!")


func _on_place_btn() -> void:
	if logic.over:
		reopen_result()  # 게임이 끝난 뒤에는 '결과 보기' 버튼
		return
	_confirm()


func _confirm() -> void:
	var c := board.preview
	if c.x < 0 or _busy or is_ai(logic.current):
		return
	if logic.is_forbidden(c, logic.current):
		toast("쌍삼(3·3) 자리는 둘 수 없어요")
		return
	_put(c)


func _put(c: Vector2i) -> void:
	var who := logic.current
	var shape := logic.analyze(c, who)
	if not logic.place(c):
		return
	board.mark_placed(c)
	if not logic.over:
		if int(shape["open_fours"]) > 0:
			toast("%s 열린 4를 만들었어요!" % subject(who))
		elif int(shape["fours"]) > 0:
			toast("%s 4를 만들었어요! 꼭 막아요" % subject(who))
	_next_turn()


func _can_undo() -> bool:
	if logic.over or logic.history.is_empty():
		return false
	if ai_level >= 0:
		return logic.stones_of(human_player) > 0
	return true


func _on_undo() -> void:
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
	var elapsed := (Time.get_ticks_msec() - _ai_started_ms) / 1000.0
	if elapsed < 0.45:
		await wait(0.45 - elapsed)
		if tok != _token:
			return
	if not logic.can_place(c):
		# 둘 곳이 없으면 (금지 자리만 남은 아주 드문 경우) 무승부 처리
		logic.over = true
		logic.winner = -1
		_next_turn()
		return
	board.preview_player = logic.current
	board.preview = c
	await wait(0.25)
	if tok != _token:
		return
	board.clear_preview()
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
		set_card(p, nm, "%d수" % logic.stones_of(p), active)
	set_status_side(logic.current)


func _show_omok_result() -> void:
	var w := logic.winner
	var rows: Array = []
	for p in 2:
		var big := "무" if w == -1 else ("승" if p == w else "패")
		rows.append({"p": p, "big": big, "small": "%s · %d수" % [_side_name(p), logic.stones_of(p)]})
	show_standard_result(w, rows, "다섯 개를 나란히 완성!" if w >= 0 else "")
