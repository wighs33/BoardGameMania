class_name WallLogic
extends RefCounted
## 벽 땅따먹기 규칙 엔진 – 화면과 분리된 순수 게임 로직 (룰 1 · 룰 2 공용)
##
## 공통 규칙
##  - 7×7 판. 정해진 순서(정순 → 역순 반복)로 빈칸에 말을 하나씩 놓는다.
##  - 내 차례: 내 말 하나를 움직인 뒤, 그 말이 선 칸의 네 변 중 빈 곳에 반드시 벽을 세운다.
##    (다른 말이 있는 칸으로는 못 가고, 벽은 지나갈 수 없다)
##    움직이지 않고 제자리에서 벽만 세워도 된다 (원작 규칙에 없는 보완 규칙:
##    갇힌 말끼리 한 구역에 남으면 아무도 벽을 못 세워 게임이 끝나지 않는 문제를 막음)
##  - 벽 부수기(3인전): 게임 중 한 번, 이동 경로에 있는 벽 하나를 부수고 지나갈 수 있다.
##  - 모든 플레이어의 말이 벽으로 서로 다른 구역에 갈라지면 즉시 종료.
##  - 내 말이 있는 구역의 칸 수 합계가 점수. 같으면 가장 큰 구역이 넓은 쪽이 앞선다.
##
## 룰 1 이동: 상하좌우로 0~2칸 (꺾어도 되고, 지나온 칸으로 되돌아와도 됨)
## 룰 2 이동: 사각 말 = 제자리 또는 한 방향으로 곧게 1~2칸
##           원형 말 = 제자리 또는 1칸 이동 후, 원하면 왼쪽/오른쪽으로 꺾어 1칸 더

enum Phase { PLACE, MOVE, WALL, OVER }
enum Kind { ROUND, SQUARE }

## 방향 인덱스: 0=위, 1=오른쪽, 2=아래, 3=왼쪽
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NO_SLOT := Vector2i(-1, -1)
## 1:1 대결에서 미리 놓이는 말 위치 (선 플레이어: B6·F2, 후 플레이어: F6·B2)
const DUEL_FIXED := [[0, Vector2i(1, 1)], [0, Vector2i(5, 5)], [1, Vector2i(5, 1)], [1, Vector2i(1, 5)]]

var size: int = 7
var rule: int = 1
var num_players: int = 2

## h_walls[y*size + x]  : (x,y) 칸과 (x,y+1) 칸 사이 가로벽  (값 = 세운 플레이어 + 1, 0 = 없음)
## v_walls[y*(size-1)+x]: (x,y) 칸과 (x+1,y) 칸 사이 세로벽
var h_walls := PackedByteArray()
var v_walls := PackedByteArray()

var piece_pos: Array[Vector2i] = []
var piece_owner := PackedInt32Array()
var piece_kind := PackedInt32Array()
var breaks_left := PackedInt32Array()

var phase: int = Phase.PLACE
var current: int = 0
var place_order := PackedInt32Array()
var place_index: int = 0
## 플레이어별 아직 놓지 않은 말 종류 목록
var to_place: Array = []
var moved_piece: int = -1
var move_origin := Vector2i.ZERO
var move_broken := NO_SLOT
var move_broken_value: int = 0
var turn_count: int = 0
## 직전 턴 전환에서 움직일 수 없어 건너뛴 플레이어들 (UI 알림용)
var skipped: Array[int] = []


# ── 준비 ───────────────────────────────────────────────
## 3인전: 각자 말 2개를 놓고 시작, 벽 부수기 1회
func setup_trio(p_rule: int) -> void:
	var kinds := [Kind.ROUND, Kind.ROUND] if p_rule == 1 else [Kind.SQUARE, Kind.ROUND]
	setup(p_rule, 3, [kinds.duplicate(), kinds.duplicate(), kinds.duplicate()], [], true)


## 1:1: 각자 말 4개 (2개는 고정 위치), 벽 부수기 없음
## 룰 2 에서는 원형 말 2개가 고정, 사각 말 2개를 직접 놓음
func setup_duel(p_rule: int) -> void:
	var fixed: Array = []
	for f in DUEL_FIXED:
		fixed.append([f[0], f[1], Kind.ROUND])
	var kinds := [Kind.ROUND, Kind.ROUND] if p_rule == 1 else [Kind.SQUARE, Kind.SQUARE]
	setup(p_rule, 2, [kinds.duplicate(), kinds.duplicate()], fixed, false)


## kinds_to_place: 플레이어별 놓을 말 종류 목록, fixed: [[플레이어, 칸, 종류], ...]
func setup(p_rule: int, p_players: int, kinds_to_place: Array, fixed: Array = [], wall_break: bool = false) -> void:
	rule = p_rule
	num_players = p_players
	h_walls.resize((size - 1) * size)
	h_walls.fill(0)
	v_walls.resize(size * (size - 1))
	v_walls.fill(0)
	piece_pos.clear()
	piece_owner = PackedInt32Array()
	piece_kind = PackedInt32Array()
	for f in fixed:
		_add_piece(f[1], f[0], f[2])
	to_place = []
	for k in kinds_to_place:
		to_place.append((k as Array).duplicate())
	breaks_left = PackedInt32Array()
	breaks_left.resize(num_players)
	breaks_left.fill(1 if wall_break else 0)
	# 정순 → 역순 → 정순 … (1-2-3-3-2-1)
	place_order = PackedInt32Array()
	var rounds := 0
	for k in to_place:
		rounds = maxi(rounds, (k as Array).size())
	for r in rounds:
		for i in num_players:
			var p := i if r % 2 == 0 else num_players - 1 - i
			if (to_place[p] as Array).size() > r:
				place_order.append(p)
	place_index = 0
	moved_piece = -1
	move_broken = NO_SLOT
	turn_count = 0
	skipped.clear()
	if place_order.is_empty():
		phase = Phase.MOVE
		current = 0
		_ensure_can_act()
	else:
		phase = Phase.PLACE
		current = place_order[0]


func _add_piece(c: Vector2i, owner: int, kind: int) -> void:
	piece_pos.append(c)
	piece_owner.append(owner)
	piece_kind.append(kind)


func clone() -> WallLogic:
	var c := WallLogic.new()
	c.size = size
	c.rule = rule
	c.num_players = num_players
	c.h_walls = h_walls.duplicate()
	c.v_walls = v_walls.duplicate()
	c.piece_pos = piece_pos.duplicate()
	c.piece_owner = piece_owner.duplicate()
	c.piece_kind = piece_kind.duplicate()
	c.breaks_left = breaks_left.duplicate()
	c.phase = phase
	c.current = current
	c.place_order = place_order.duplicate()
	c.place_index = place_index
	c.to_place = []
	for k in to_place:
		c.to_place.append((k as Array).duplicate())
	c.moved_piece = moved_piece
	c.move_origin = move_origin
	c.move_broken = move_broken
	c.move_broken_value = move_broken_value
	c.turn_count = turn_count
	return c


# ── 조회 ───────────────────────────────────────────────
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


func piece_at(c: Vector2i) -> int:
	for i in piece_pos.size():
		if piece_pos[i] == c:
			return i
	return -1


func pieces_of(p: int) -> Array[int]:
	var out: Array[int] = []
	for i in piece_owner.size():
		if piece_owner[i] == p:
			out.append(i)
	return out


func remaining_kinds(p: int) -> Array:
	return to_place[p] if p < to_place.size() else []


## 판 테두리도 벽으로 취급
func is_wall(c: Vector2i, d: int) -> bool:
	match d:
		0:
			return c.y == 0 or h_walls[(c.y - 1) * size + c.x] != 0
		1:
			return c.x == size - 1 or v_walls[c.y * (size - 1) + c.x] != 0
		2:
			return c.y == size - 1 or h_walls[c.y * size + c.x] != 0
		_:
			return c.x == 0 or v_walls[c.y * (size - 1) + c.x - 1] != 0


## 벽 슬롯: x = 0(가로벽) / 1(세로벽), y = 인덱스. 테두리면 (-1, -1)
func wall_slot(c: Vector2i, d: int) -> Vector2i:
	match d:
		0:
			return Vector2i(0, (c.y - 1) * size + c.x) if c.y > 0 else NO_SLOT
		1:
			return Vector2i(1, c.y * (size - 1) + c.x) if c.x < size - 1 else NO_SLOT
		2:
			return Vector2i(0, c.y * size + c.x) if c.y < size - 1 else NO_SLOT
		_:
			return Vector2i(1, c.y * (size - 1) + c.x - 1) if c.x > 0 else NO_SLOT


## 슬롯이 어느 칸의 어느 변인지 (가로벽 → 위 칸의 아래, 세로벽 → 왼쪽 칸의 오른쪽)
func slot_cell_dir(s: Vector2i) -> Array:
	if s.x == 0:
		return [Vector2i(s.y % size, s.y / size), 2]
	return [Vector2i(s.y % (size - 1), s.y / (size - 1)), 1]


func wall_key(c: Vector2i, d: int) -> String:
	var s := wall_slot(c, d)
	if s.x < 0:
		return ""
	return ("h%d" if s.x == 0 else "v%d") % s.y


func get_slot(s: Vector2i) -> int:
	if s.x == 0:
		return h_walls[s.y]
	if s.x == 1:
		return v_walls[s.y]
	return 0


func set_slot(s: Vector2i, value: int) -> void:
	if s.x == 0:
		h_walls[s.y] = value
	elif s.x == 1:
		v_walls[s.y] = value


func set_wall(c: Vector2i, d: int, value: int) -> void:
	set_slot(wall_slot(c, d), value)


func open_dirs(c: Vector2i) -> Array[int]:
	return open_dirs_after(c, NO_SLOT)


## broken 슬롯의 벽이 없다고 보고 벽을 세울 수 있는 방향
func open_dirs_after(c: Vector2i, broken: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for d in 4:
		if not is_wall(c, d) or (broken.x >= 0 and wall_slot(c, d) == broken):
			out.append(d)
	return out


# ── 이동 ───────────────────────────────────────────────
## 말이 따라갈 수 있는 방향 순서 목록
func _sequences(piece: int) -> Array:
	var seqs: Array = []
	if rule == 1:
		for d1 in 4:
			seqs.append([d1])
			for d2 in 4:
				seqs.append([d1, d2])   # 되돌아오기(제자리)도 포함
	elif piece_kind[piece] == Kind.SQUARE:
		for d in 4:
			seqs.append([d])
			seqs.append([d, d])
	else:
		for d in 4:
			seqs.append([d])
			seqs.append([d, (d + 1) % 4])
			seqs.append([d, (d + 3) % 4])
	return seqs


## 갈 수 있는 칸들. { 칸: {"path": 경로(시작 칸 제외), "broken": 부순 벽 슬롯 또는 NO_SLOT} }
## 같은 칸에 여러 길이 있으면 벽을 안 부수는 길을 우선
## 제자리(0칸)도 항상 포함 – 옆칸이 모두 막혀 갇힌 말도 벽을 세울 수 있어야
## 한 구역에 갇힌 두 말을 갈라 게임을 끝낼 수 있다
func moves_for(piece: int, allow_break: bool = false) -> Dictionary:
	var start := piece_pos[piece]
	var out := {start: {"path": [], "broken": NO_SLOT}}
	for seq in _sequences(piece):
		var c := start
		var path: Array = []
		var broken := NO_SLOT
		var ok := true
		for d in seq:
			var s := wall_slot(c, d)
			if s.x < 0:
				ok = false
				break
			if is_wall(c, d) and s != broken:
				if not allow_break or broken.x >= 0:
					ok = false
					break
				broken = s
			var n: Vector2i = c + DIRS[d]
			var occ := piece_at(n)
			if occ != -1 and occ != piece:
				ok = false
				break
			c = n
			path.append(n)
		if not ok:
			continue
		if not out.has(c) or ((out[c]["broken"] as Vector2i).x >= 0 and broken.x < 0):
			out[c] = {"path": path, "broken": broken}
	return out


## 실제로 갈 수 있는 칸 (도착해서 벽을 세울 자리가 있어야 함)
func destinations(piece: int, allow_break: bool = false) -> Dictionary:
	var can_break := allow_break and breaks_left[piece_owner[piece]] > 0
	var all := moves_for(piece, can_break)
	var out := {}
	for cell in all:
		var e: Dictionary = all[cell]
		if not open_dirs_after(cell, e["broken"]).is_empty():
			out[cell] = e
	return out


func player_can_act(p: int) -> bool:
	for i in pieces_of(p):
		if not destinations(i, true).is_empty():
			return true
	return false


# ── 진행 ───────────────────────────────────────────────
## kind = -1 이면 남은 말 중 첫 번째
func place_piece(c: Vector2i, kind: int = -1) -> bool:
	if phase != Phase.PLACE or not in_bounds(c) or piece_at(c) != -1:
		return false
	var remaining: Array = to_place[current]
	if remaining.is_empty():
		return false
	if kind < 0:
		kind = remaining[0]
	if not remaining.has(kind):
		return false
	remaining.erase(kind)
	_add_piece(c, current, kind)
	place_index += 1
	if place_index >= place_order.size():
		phase = Phase.MOVE
		current = 0   # 선 플레이어부터 이동
		_ensure_can_act()
	else:
		current = place_order[place_index]
	return true


func move_piece(piece: int, dest: Vector2i, allow_break: bool = false) -> bool:
	if phase != Phase.MOVE or piece < 0 or piece >= piece_pos.size() or piece_owner[piece] != current:
		return false
	var opts := destinations(piece, allow_break)
	if not opts.has(dest):
		return false
	var e: Dictionary = opts[dest]
	move_origin = piece_pos[piece]
	move_broken = e["broken"]
	move_broken_value = 0
	if move_broken.x >= 0:
		move_broken_value = get_slot(move_broken)
		set_slot(move_broken, 0)
		breaks_left[current] -= 1
	piece_pos[piece] = dest
	moved_piece = piece
	phase = Phase.WALL
	return true


func cancel_move() -> void:
	if phase != Phase.WALL:
		return
	piece_pos[moved_piece] = move_origin
	if move_broken.x >= 0:
		set_slot(move_broken, move_broken_value)
		breaks_left[current] += 1
	move_broken = NO_SLOT
	moved_piece = -1
	phase = Phase.MOVE


func place_wall(d: int) -> bool:
	if phase != Phase.WALL:
		return false
	var c := piece_pos[moved_piece]
	if is_wall(c, d):
		return false
	set_wall(c, d, current + 1)
	turn_count += 1
	moved_piece = -1
	move_broken = NO_SLOT
	skipped.clear()
	if is_finished():
		phase = Phase.OVER
		return true
	phase = Phase.MOVE
	current = (current + 1) % num_players
	_ensure_can_act()
	return true


func _ensure_can_act() -> void:
	skipped.clear()
	for k in num_players:
		if player_can_act(current):
			return
		skipped.append(current)
		current = (current + 1) % num_players
	phase = Phase.OVER


# ── 구역 / 점수 ────────────────────────────────────────
## map: 칸별 구역 번호, cells: 구역별 칸 수, owners: 구역별 말 주인 목록
func regions() -> Dictionary:
	var n := size
	var map := PackedInt32Array()
	map.resize(n * n)
	map.fill(-1)
	var cells: Array = []
	var owners: Array = []
	var rid := 0
	for start_i in n * n:
		if map[start_i] != -1:
			continue
		var q: Array[Vector2i] = [Vector2i(start_i % n, start_i / n)]
		map[start_i] = rid
		var head := 0
		while head < q.size():
			var c := q[head]
			head += 1
			for d in 4:
				if is_wall(c, d):
					continue
				var nb: Vector2i = c + DIRS[d]
				var ni := nb.y * n + nb.x
				if map[ni] == -1:
					map[ni] = rid
					q.append(nb)
		cells.append(q.size())
		owners.append([])
		rid += 1
	for i in piece_pos.size():
		var r := map[piece_pos[i].y * n + piece_pos[i].x]
		var o := piece_owner[i]
		var ow: Array = owners[r]
		if not ow.has(o):
			ow.append(o)
	return {"map": map, "cells": cells, "owners": owners}


func is_finished() -> bool:
	var info := regions()
	for ow in info["owners"]:
		if (ow as Array).size() > 1:
			return false
	return true


## 플레이어별 { area: 내 말만 있는 구역 칸 수 합계, largest: 가장 큰 구역 }
func scores() -> Array:
	var info := regions()
	var res: Array = []
	for p in num_players:
		res.append({"area": 0, "largest": 0})
	var cells: Array = info["cells"]
	var owners: Array = info["owners"]
	for r in cells.size():
		var ow: Array = owners[r]
		if ow.size() == 1:
			var p: int = ow[0]
			var cnt: int = cells[r]
			res[p]["area"] = int(res[p]["area"]) + cnt
			res[p]["largest"] = maxi(int(res[p]["largest"]), cnt)
	return res


## 순위 (1등부터). 완전 동률이면 순서가 빠른 쪽이 앞
func ranking() -> Array[int]:
	var sc := scores()
	var order: Array[int] = []
	for p in num_players:
		order.append(p)
	order.sort_custom(_rank_before.bind(sc))
	return order


func _rank_before(a: int, b: int, sc: Array) -> bool:
	var c := _compare(sc[a], sc[b])
	return c > 0 or (c == 0 and a < b)


## 승자 번호, 1등이 완전 동률이면 -1
func winner() -> int:
	var sc := scores()
	var order := ranking()
	if num_players > 1 and _compare(sc[order[0]], sc[order[1]]) == 0:
		return -1
	return order[0]


## 넓이가 같아서 '가장 큰 구역'으로 1등이 갈렸는지
func decided_by_largest() -> bool:
	var sc := scores()
	var order := ranking()
	if num_players < 2:
		return false
	return int(sc[order[0]]["area"]) == int(sc[order[1]]["area"]) and _compare(sc[order[0]], sc[order[1]]) != 0


func _compare(a: Dictionary, b: Dictionary) -> int:
	if int(a["area"]) != int(b["area"]):
		return 1 if int(a["area"]) > int(b["area"]) else -1
	if int(a["largest"]) != int(b["largest"]):
		return 1 if int(a["largest"]) > int(b["largest"]) else -1
	return 0
