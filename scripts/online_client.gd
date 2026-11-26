class_name OnlineClient
extends Node
## 중계 서버(server/relay_server.gd)에 붙는 온라인 대전 클라이언트
## 게임 화면이 자식으로 붙여 두면 스스로 poll 함. 연결 → hello → 빠른 매칭 → 짝이 지어지면 matched,
## 그 뒤엔 send(d) 로 보낸 내용이 상대에게 message(d) 로 전달됨

signal matched(seat: int, first: int)
signal message(d: Dictionary)
signal opponent_left
signal failed(reason: String)

const CONNECT_TIMEOUT_MS := 75000   # 무료 서버는 잠들어 있으면 깨어나는 데 1분쯤 걸림
const PING_MS := 5000
const SILENT_MS := 20000          # 서버 소식이 이만큼 없으면 끊긴 것으로 봄

var ws := WebSocketPeer.new()
var game := ""
var ver := 0
var in_room := false
var _started_ms := 0
var _last_ping := 0
var _last_seen := 0
var _hello_sent := false
var _done := false


## 서버에 연결하고 바로 빠른 매칭 줄에 섬
func start(url: String, p_game: String, p_ver: int) -> void:
	game = p_game
	ver = p_ver
	_done = false
	in_room = false
	_hello_sent = false
	_started_ms = Time.get_ticks_msec()
	_last_seen = _started_ms
	var err := ws.connect_to_url(url)
	if err != OK:
		_fail("서버에 연결할 수 없어요")


func send(d: Dictionary) -> void:
	_raw({"t": "relay", "d": d})


## 방에서 나가기 (상대에게 알림) 후 연결 끊기
func close() -> void:
	if _done:
		return
	_done = true
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_raw({"t": "leave"})
		ws.close()


func _raw(msg: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	ws.close()
	failed.emit(reason)


func _process(_delta: float) -> void:
	if _done:
		return
	ws.poll()
	var now := Time.get_ticks_msec()
	match ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if now - _started_ms > CONNECT_TIMEOUT_MS:
				_fail("서버에 연결할 수 없어요")
		WebSocketPeer.STATE_OPEN:
			if not _hello_sent:
				_hello_sent = true
				_raw({"t": "hello", "game": game, "ver": ver})
				_raw({"t": "queue"})
			while ws.get_available_packet_count() > 0:
				_last_seen = now
				_on_packet(ws.get_packet().get_string_from_utf8())
				if _done:
					return
			if now - _last_ping > PING_MS:
				_last_ping = now
				_raw({"t": "ping"})
			if now - _last_seen > SILENT_MS:
				_fail("서버와 연결이 끊겼어요")
		WebSocketPeer.STATE_CLOSED:
			_fail("서버와 연결이 끊겼어요")


func _on_packet(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match str(msg.get("t", "")):
		"matched":
			in_room = true
			matched.emit(int(msg.get("seat", 0)), int(msg.get("first", 0)))
		"relay":
			var d: Variant = msg.get("d", {})
			if typeof(d) == TYPE_DICTIONARY:
				message.emit(d)
		"left":
			in_room = false
			opponent_left.emit()
		"error":
			_fail("서버가 요청을 거절했어요")
