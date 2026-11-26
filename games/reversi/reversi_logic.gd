class_name ReversiLogic
extends RefCounted
## 리버시 규칙 엔진 – 화면과 분리된 순수 게임 로직
##
## 규칙
##  - 8×8 판, 가운데 4개(흑 2 · 백 2)를 대각선으로 놓고 흑부터 시작.
##  - 상대 돌을 내 돌 사이에 (가로·세로·대각선으로) 끼울 수 있는 칸에만 둘 수 있다.
##  - 끼인 상대 돌은 모두 내 색으로 뒤집힌다.
##  - 둘 곳이 없으면 차례가 넘어가고(패스), 둘 다 둘 곳이 없으면 게임 끝.
##  - 돌이 더 많은 쪽이 승리.

const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var size: int = 8
var cells := PackedByteArray()      # 0 = 빈칸, 1 = 흑, 2 = 백
var current: int = 0                # 0 = 흑, 1 = 백
## [{ "move": Vector2i, "player": int, "flips": Array[Vector2i] }]
var history: Array = []
var over: bool = false
var winner: int = -1
## 직전 진행에서 둘 곳이 없어 차례를 넘긴 플레이어 (없으면 -1)
var passed_player: int = -1


func setup() -> void:
	cells.resize(size * size)
	cells.fill(0)
	var m := size / 2
	_put_stone(Vector2i(m - 1, m - 1), 2)
	_put_stone(Vector2i(m, m), 2)
	_put_stone(Vector2i(m - 1, m), 1)
	_put_stone(Vector2i(m, m - 1), 1)
	current = 0
	history.clear()
	over = false
	winner = -1
	passed_player = -1


func clone() -> ReversiLogic:
	var c := ReversiLogic.new()
	c.size = size
	c.cells = cells.duplicate()
	c.current = current
	c.over = over
	c.winner = winner
	return c


# ── 조회 ───────────────────────────────────────────────
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


## 0 = 빈칸, 1 = 흑, 2 = 백
func stone(c: Vector2i) -> int:
	return cells[c.y * size + c.x]


func _put_stone(c: Vector2i, v: int) -> void:
	cells[c.y * size + c.x] = v


func count(p: int) -> int:
	var v := p + 1
	var n := 0
	for s in cells:
		if s == v:
			n += 1
	return n


## c 에 p 가 두면 뒤집히는 돌들 (둘 수 없으면 빈 배열)
func flips_for(c: Vector2i, p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not in_bounds(c) or stone(c) != 0:
		return out
	var me := p + 1
	var op := 2 - p
	for d in DIRS:
		var line: Array[Vector2i] = []
		var q: Vector2i = c + d
		while in_bounds(q) and stone(q) == op:
			line.append(q)
			q += d
		if not line.is_empty() and in_bounds(q) and stone(q) == me:
			out.append_array(line)
	return out


func is_legal(c: Vector2i, p: int) -> bool:
	return not flips_for(c, p).is_empty()


func legal_moves(p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size:
		for x in size:
			var c := Vector2i(x, y)
			if stone(c) == 0 and is_legal(c, p):
				out.append(c)
	return out


func can_move(p: int) -> bool:
	for y in size:
		for x in size:
			var c := Vector2i(x, y)
			if stone(c) == 0 and is_legal(c, p):
				return true
	return false


func last_move() -> Vector2i:
	if history.is_empty():
		return Vector2i(-1, -1)
	return history[history.size() - 1]["move"]


func moves_of(p: int) -> int:
	var n := 0
	for e in history:
		if int(e["player"]) == p:
			n += 1
	return n


# ── 진행 ───────────────────────────────────────────────
func place(c: Vector2i) -> bool:
	if over:
		return false
	var f := flips_for(c, current)
	if f.is_empty():
		return false
	var v := current + 1
	_put_stone(c, v)
	for q in f:
		_put_stone(q, v)
	history.append({"move": c, "player": current, "flips": f})
	_advance()
	return true


func _advance() -> void:
	passed_player = -1
	var nxt := 1 - current
	if can_move(nxt):
		current = nxt
	elif can_move(current):
		passed_player = nxt   # 상대가 둘 곳이 없어 같은 사람이 한 번 더
	else:
		over = true
		var b := count(0)
		var w := count(1)
		winner = 0 if b > w else (1 if w > b else -1)


func undo() -> bool:
	if history.is_empty():
		return false
	var e: Dictionary = history.pop_back()
	var p: int = e["player"]
	_put_stone(e["move"], 0)
	for q in e["flips"]:
		_put_stone(q, 2 - p)
	current = p
	over = false
	winner = -1
	passed_player = -1
	return true
