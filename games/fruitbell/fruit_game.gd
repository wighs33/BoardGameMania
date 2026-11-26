extends GameScreen
## 과일 종치기 – 게임 화면 (AI 1~3명과 대결 / 친구와 2인 마주 보기)
## 실시간 진행: 차례대로 카드 펼치기 → 한 과일이 딱 5개면 먼저 종 치기
## 팝업(설정 · 게임 방법)이 열려 있으면 시간이 멈춰요

const LOCK_AFTER_RING := 1.0     # 종을 친 뒤 잠깐 멈춤

var players: int = 2              # AI 대전 인원 (나 포함)
var logic: FruitLogic
var ais: Array = []               # 자리별 AI (사람이면 null)
var table: FruitTable
var _rng := RandomNumberGenerator.new()
var _playing: bool = false
var _now: float = 0.0
var _lock_until: float = 0.0
var _next_flip_at: float = 0.0
var _version: int = 0             # 판이 바뀔 때마다 증가 (예약된 AI 종 치기 무효화)
var _rings: Array = []            # 예약된 AI 종 치기 [{p, at, version, real}]
var _rings_ok: Array = []         # 자리별 맞게 친 횟수


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "과일 종치기"


func _mode_label(id: String) -> String:
	if id == "local":
		return "친구와 2인"
	return super(id)


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	return (
		"[color=#%s]1. 준비[/color]  과일 카드 56장(딸기 · 바나나 · 라임 · 포도)을 똑같이 나눠 엎어 둬요.\n" % c1
		+ "[color=#%s]2. 펼치기[/color]  차례대로 내 카드 더미를 눌러 맨 위 카드를 내 앞에 펼쳐요. 새 카드는 전에 펼친 카드 위에 겹쳐요.\n" % c2
		+ "[color=#%s]3. 종 치기[/color]  펼쳐진 [b]맨 위 카드들[/b]에서 한 과일이 [b]딱 5개[/b]가 되면 가운데 종을 빨리 눌러요!\n" % c3
		+ "  · 맞으면 펼쳐진 카드를 [b]모두 가져가요[/b]. 그리고 내가 다음에 펼쳐요.\n"
		+ "  · 틀리면 다른 사람 모두에게 내 카드를 [b]한 장씩[/b] 줘요.\n"
		+ "[color=#%s]4. 탈락 · 승리[/color]  펼칠 차례에 엎은 카드가 없으면 탈락! 마지막까지 남은 사람이 승리해요.\n" % c4
		+ "[color=#%s]친구와 2인[/color]  폰을 탁자에 놓고 마주 앉아요. 각자 내 쪽 카드를 누르고, 종은 [b]내 쪽 반쪽[/b]을 눌러요." % c1
	)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "인원 (AI 대전, 나 포함)", ["2명", "3명", "4명"], players - 2, UIKit.player_color(1),
		func(i: int) -> void: players = i + 2)
	box.add_child(UIKit.make_label("친구와 2인: 폰을 사이에 두고 마주 보고 해요", 21, UIKit.INK_SOFT))


func _on_setup_opened() -> void:
	if table != null:
		table.input_enabled = false


func _is_game_over() -> bool:
	return not _playing


func player_name(p: int) -> String:
	if ai_level >= 0:
		if p == human_player:
			return "나"
		if players == 2:
			return "AI"
		return "AI %d" % p
	return _side_name(p)


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "fruitbell"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	players = clampi(int(Global.get_setting(game_id, "players", 2)), 2, 4)
	_rng.randomize()
	build_frame()
	_cards_row.visible = false
	table = FruitTable.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.deck_tapped.connect(_on_deck)
	table.bell_tapped.connect(_on_bell)
	content.add_child(table)
	attach_toast(table)
	logic = FruitLogic.new()
	logic.setup(2, 0, _rng)
	_apply_names()
	table.setup(logic)
	set_status("어떻게 플레이할지 골라 주세요")
	show_setup()


func _apply_names() -> void:
	table.names = []
	table.colors = []
	for p in logic.n:
		table.names.append(player_name(p))
		table.colors.append(UIKit.player_color(p))


func _process(delta: float) -> void:
	super(delta)
	if not _playing or _overlay_kind != "":
		return
	_now += delta
	if _now < _lock_until:
		return
	# 예약된 AI 종 치기
	for i in _rings.size():
		var r: Dictionary = _rings[i]
		if _now < float(r["at"]):
			continue
		_rings.remove_at(i)
		if int(r["version"]) == _version and not logic.out[int(r["p"])] and (not bool(r["real"]) or logic.has_five()):
			_do_ring(int(r["p"]))
		return
	# AI 펼치기
	if ais[logic.current] != null and _now >= _next_flip_at:
		_do_flip(logic.current)


# ══════════════════════════════════════════════════════
#  게임 진행
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "players", players)
	apply_mode()
	human_player = 0
	var n := players if ai_level >= 0 else 2
	logic = FruitLogic.new()
	var first := _rng.randi() % n
	logic.setup(n, first, _rng)
	ais = []
	for p in n:
		ais.append(FruitAI.new(ai_level) if ai_level >= 0 and p != human_player else null)
	table.face_to_face = ai_level < 0
	table.human = human_player if ai_level >= 0 else -1
	_apply_names()
	table.setup(logic)
	_rings_ok = []
	for p in n:
		_rings_ok.append(0)
	(status_label.get_parent() as Control).visible = ai_level >= 0
	close_overlay()
	_now = 0.0
	_lock_until = 0.8
	_version = 0
	_rings = []
	_next_flip_at = _lock_until + 0.4
	_playing = true
	table.input_enabled = true
	_refresh_status()
	_notify("%s 먼저 펼쳐요!" % subject(first), UIKit.INK)


func _refresh_status() -> void:
	if ai_level < 0 or not _playing:
		return
	set_status_side(logic.current)
	if logic.current == human_player:
		set_status("내 차례! 카드 더미를 눌러 펼쳐요")
	else:
		set_status("%s 차례 · 딱 5개면 종을 쳐요!" % player_name(logic.current))


func _on_deck(p: int) -> void:
	if not _playing or _overlay_kind != "" or _now < _lock_until:
		return
	if ais[p] != null:
		return
	if p != logic.current:
		if ai_level >= 0:
			toast("아직 내 차례가 아니에요")
		return
	_do_flip(p)


func _on_bell(p: int) -> void:
	if not _playing or _overlay_kind != "" or _now < _lock_until:
		return
	if p < 0 or ais[p] != null or logic.out[p]:
		return
	_do_ring(p)


func _do_flip(p: int) -> void:
	var c := logic.flip(p)
	if c < 0:
		return
	table.anim_flip(p, c)
	_version += 1
	_rings = []
	_announce_out()
	if _check_end():
		return
	# AI 들이 판을 보고 반응을 예약
	for q in logic.n:
		var ai: FruitAI = ais[q]
		if ai == null or logic.out[q]:
			continue
		var d: Array = ai.ring_delay(logic)
		if float(d[0]) >= 0.0:
			_rings.append({"p": q, "at": _now + float(d[0]), "version": _version, "real": d[1]})
	_rings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	_schedule_flip(0.0)
	_refresh_status()


func _schedule_flip(extra: float) -> void:
	var ai: FruitAI = ais[logic.current]
	if ai != null:
		_next_flip_at = maxf(_now, _lock_until) + extra + ai.flip_delay()


func _do_ring(p: int) -> void:
	var res := logic.ring(p)
	if res.is_empty():
		return
	_version += 1
	_rings = []
	var ok: bool = res["ok"]
	table.bell(p, ok)
	if ok:
		_rings_ok[p] += 1
		var got := 0
		for t in res["taken"]:
			got += int(t[1])
		table.anim_collect(res["taken"], p)
		_notify("땡! %s %d장을 가져가요" % [subject(p), got], UIKit.player_dark(p))
	else:
		table.anim_give(p, res["gave"])
		_notify("삑! %s 잘못 쳐서 한 장씩 줘요" % subject(p), Color("#E8505B"))
	_lock_until = _now + LOCK_AFTER_RING
	_announce_out()
	if _check_end():
		return
	_schedule_flip(0.2)
	_refresh_status()


func _notify(msg: String, color: Color) -> void:
	if ai_level >= 0:
		toast(msg)
	else:
		table.say(msg, color)


func _announce_out() -> void:
	for q in logic.newly_out:
		_notify("%s 카드가 없어서 탈락했어요" % subject(q), UIKit.INK)


## 끝났으면 결과로 (AI 대전에서 내가 탈락해도 끝)
func _check_end() -> bool:
	var human_out: bool = ai_level >= 0 and logic.out[human_player]
	if not logic.over and not human_out:
		return false
	_playing = false
	table.input_enabled = false
	var w := logic.winner
	if human_out and not logic.over:
		var rank := logic.ranking()
		w = int(rank[0])
	record_result(w)
	set_status("게임 끝! " + ("%s 이겼어요!" % subject(w)))
	_show_end(w, human_out)
	return true


func _show_end(w: int, human_out: bool) -> void:
	var tok := _token
	await wait(1.4)
	if tok != _token:
		return
	var rows: Array = []
	for p in logic.ranking():
		var small := "탈락" if logic.out[p] else "남은 카드"
		small += " · 종 %d번 맞힘" % _rings_ok[p]
		rows.append({"p": p, "big": "%d장" % logic.card_count(p), "small": small})
	var note := ""
	if human_out and not logic.over:
		note = "내 카드가 다 떨어졌어요. 다음엔 더 빨리 쳐 봐요!"
	elif logic.end_reason == "flips":
		note = "%d번 펼쳐서 카드가 가장 많은 사람이 이겼어요" % FruitLogic.MAX_FLIPS
	else:
		note = "마지막까지 카드가 남은 사람이 승리!"
	show_standard_result(w, rows, note)
