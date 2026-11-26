extends SceneTree
## 온라인 대전 확인: 중계 서버로 AI 둘이 판을 끝까지 두고, 두 쪽 판 상태가 끝까지 같은지 확인
## 실행 (서버를 먼저 띄운 뒤): Godot --headless --path . -s res://tests/online_selftest.gd -- <서버 주소> <판 수>

var url := "ws://127.0.0.1:8765"
var games := 1
var bots: Array = []
var done_games := 0
var desync := 0
var t0 := 0


class Bot:
	var net: OnlineClient
	var seat := -1
	var L: HeroLogic = null
	var ai := HeroAI.new(HeroAI.Level.EASY)
	var placed_mine := false
	var their_place := {}
	var started := false
	var bad := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		url = args[0]
	if args.size() > 1:
		games = int(args[1])
	t0 = Time.get_ticks_msec()
	_new_game()


func _new_game() -> void:
	for b in bots:
		(b as Bot).net.queue_free()
	bots.clear()
	for i in 2:
		var b := Bot.new()
		b.net = OnlineClient.new()
		root.add_child(b.net)
		b.net.matched.connect(_on_matched.bind(b))
		b.net.message.connect(_on_message.bind(b))
		b.net.failed.connect(func(r: String) -> void: print("FAILED ", r))
		b.net.opponent_left.connect(func() -> void: print("LEFT"))
		b.net.start(url, HeroNet.GAME, HeroNet.VER)
		bots.append(b)


func _on_matched(seat: int, first: int, b: Bot) -> void:
	b.seat = seat
	b.L = HeroLogic.new()
	b.L.setup(first)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	b.L.random_formation(seat, rng)
	b.placed_mine = true
	b.net.send(HeroNet.formation_msg(b.L, seat))
	_try_start(b)


func _try_start(b: Bot) -> void:
	if b.started or not b.placed_mine or b.their_place.is_empty():
		return
	if not b.L.set_formation(1 - b.seat, b.their_place):
		print("BAD FORMATION")
		b.bad += 1
	b.L.start_play()
	b.started = true


func _on_message(d: Dictionary, b: Bot) -> void:
	if str(d.get("k", "")) == "place":
		b.their_place = HeroNet.formation_cells(d)
		_try_start(b)
		return
	if not HeroNet.apply(b.L, d):
		b.bad += 1
		desync += 1
		print("DESYNC at turn %d (%s)" % [b.L.turn, d.get("k", "")])


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - t0 > 600000:
		print("TIMEOUT")
		quit(1)
		return true
	if bots.size() < 2:
		return false
	for b in bots:
		var bot := b as Bot
		if not bot.started or bot.L.over or bot.L.current != bot.seat:
			continue
		# 내 차례: AI 계획을 한 단계씩 두며 상대에게 보냄
		var plan: Array = bot.ai.plan(bot.L)
		for step in plan:
			var s: Dictionary = step
			if bot.L.over or bot.L.current != bot.seat:
				break
			if s.has("summon"):
				bot.L.do_summon(s["summon"], s["cell"])
				bot.net.send({"k": "summon", "id": int(s["summon"]), "c": HeroNet.cell(s["cell"]), "h": bot.L.state_hash()})
				continue
			var taps: Array = s["taps"]
			if not bot.L.begin_action(taps[0]):
				break
			for i in range(1, taps.size()):
				if taps[i] == HeroLogic.STOP:
					bot.L.stop_action()
				else:
					bot.L.choose(taps[i])
			var sent: Array = taps.duplicate()
			if bot.L.act_hero >= 0:
				# 계획이 어긋나 남은 단계는 '능력 안 씀'으로 끝냄 – 상대도 똑같이 하도록 함께 보냄
				bot.L.stop_action()
				sent.append(HeroLogic.STOP)
				if bot.L.act_hero >= 0:
					bot.L.cancel_action()
					continue
			bot.net.send({"k": "act", "taps": HeroNet.encode_taps(sent), "h": bot.L.state_hash()})
		if not bot.L.over and bot.L.current == bot.seat and bot.L.used > 0 and bot.L.act_hero < 0:
			bot.L.end_turn()
			bot.net.send({"k": "end", "h": bot.L.state_hash()})
		if not bot.L.over and bot.L.current == bot.seat and bot.L.used == 0:
			print("STUCK (AI plan did nothing)")
			quit(1)
			return true
	var a := bots[0] as Bot
	var c := bots[1] as Bot
	if a.started and c.started and a.L.over and c.L.over:
		done_games += 1
		var same := a.L.state_hash() == c.L.state_hash()
		print("GAME %d: %s, winner %d, turns %d, same state %s, desync %d" % [done_games, a.L.end_reason, a.L.winner,
			a.L.turn, same, a.bad + c.bad])
		if not same:
			desync += 1
		if done_games >= games:
			print("RESULT ", "OK" if desync == 0 else "DESYNC %d" % desync, " in %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
			for b in bots:
				(b as Bot).net.close()
			quit(0 if desync == 0 else 1)
			return true
		_new_game()
	return false

