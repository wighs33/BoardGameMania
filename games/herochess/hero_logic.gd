class_name HeroLogic
extends RefCounted
## 히어로 체스 규칙 엔진 (3판 – 사용자가 직접 설계한 '이동 후 능력' 규칙) – 화면과 분리된 순수 게임 로직
## 규칙 원본: 사용자가 고친 아티팩트 "히어로 체스 규칙표" (https://claude.ai/artifact/MY8AWysDi2oMA22ypyYXsm)
##
## 판: 가로 11 × 세로 8 (사용자 결정 2026-11-24). 플레이어 0 은 아래쪽(성 (5,7)), 플레이어 1 은 위쪽(성 (5,0))
## 맨 끝줄 = 성 1칸 + 영웅 10명. 게임 전에 내 끝줄 안에서 영웅끼리 자리를 바꿔 배치 (진영은 없음)
## 내 차례: 행동 2개. (가)와 (나)를 섞어 써도 됨
##  (가) 서로 다른 영웅(또는 유령)을 두 명까지 골라, 한 명씩 이동한 뒤 능력을 씀. 건축가만 행동 2개를 모두 쓸 수 있음 – 사용자 결정 (2026-11-25)
##       - 모든 영웅은 제자리에 있어도 됨 (이동 0칸). 마법사는 이동이 없음 – 사용자 결정
##       - 이동은 빈칸으로만 (적 · 아군 · 성이 있는 칸 X). 이동으로는 공격하지 않음
##       - 능력은 안 써도 됨. 공격과 성 공격은 능력으로만
##  (나) 행동 1개와 내 성의 하트 1개를 써서 성의 능력으로, 판 위의 내 영웅 한 명(유령은 X)을
##       내 성 주위 5칸(성을 둘러싼 칸 중 판 안) 중 빈칸으로 소환 (로봇은 안 됨, 사신은 됨). 하트가 2개 이상일 때만 됨.
##       한 차례에 두 번도 됨. 불러온 영웅은 남은 행동으로 움직일 수 있고, 이미 행동한 영웅도 부를 수 있음 – 사용자 결정 (2026-11-25)
## 공격: 적 영웅은 쓰러지고(그 자리에 유령), 상대 성이 공격 범위 안에 있으면 성 목숨 -1. 상대 성 목숨 3개를 모두 없애면 승리
## 차례 시작: 그 사람의 닌자가 따라 한 모습에서 닌자로 돌아오고, 사신은 대각선 4칸에 남아 있는 적을 자동으로 공격 (행동을 쓰지 않음)
## 유령: 쓰러진 영웅은 그 자리에 유령으로 남음. 비석은 없음 – 사용자 결정 (2026-11-24)
##       - 유령도 행동 1번을 써서 움직임: 상하좌우 한 칸, 빈칸으로만 (제자리도 됨, 벽에 막힘)
##       - 천사의 능력으로만 부활함. 성직자(십자가)와 천사, 사신(저주)만 유령을 없앨 수 있음
##       - 유령 칸에는 영웅도 다른 유령도 못 멈춤(영웅이 지나가기는 됨). 천사만 부활 · 없애기로 들어감 – 사용자 결정 (2026-11-24)
##       - 저주로 사신이 와서 쓰러뜨린 영웅과 포탑에 갇힌 영웅은 유령이 안 생김(부활 못 함) – 사용자 결정 (2026-11-24)
##       - 천사는 쓰러지면 유령 대신 십자가가 생기고, 성직자가 희생해 십자가 자리에서 부활시킴(아래 성직자) – 사용자 결정 (2026-11-25). 겹치는 자리에서 유령이 생겨야 하면 가장 가까운 빈칸에
##       - 십자가 칸에는 아무도 못 멈춤(지나가기는 됨). 포탑에 갇혀 쓰러진 천사는 십자가가 안 생기고, 십자가가 있는 칸이 포탑이 되면(누구 포탑이든) 십자가가 사라짐. 그 밖에는 부활시킬 때까지 남음 – 사용자 결정 (2026-11-25)
##
## 영웅 (이동 → 능력)
##  기사   말을 타면 한 방향으로 2칸 이하, 말이 없으면 1칸 이하(가로 · 세로 일직선, 제자리도 됨) → 셋 중 하나: 움직인 방향의 다음 칸에 있는 적 공격(제자리면 없음 – 사용자 결정),
##         또는 이동 후 상하좌우의 아군 한 명을 기사를 넘어 반대편 칸으로 옮김(제자리도 됨), 또는 이동 전 자리 바로 뒤(판 기준 내 성 쪽 칸)의 아군이
##         기사와 똑같이(같은 방향 · 같은 칸 수) 이동함(제자리면 없음) – 사용자 결정 (2026-11-25)
##         패시브: 공격받으면 말이 대신 죽고, 말이 없을 때 공격받으면 쓰러짐. 내 성 주위 5칸에 가서 멈추면 말이 다시 생김.
##         말을 타고 있을 때 사신의 자동 공격이나 저주가 닿으면 안 다치고 1턴 동안 흑기사로 변신: 그 편의 차례가 한 번 끝날 때까지. 흑기사의 공격은 주위 8칸의 적 모두(제자리도 됨).
##         흑기사가 되면 걸려 있던 저주가 풀리고 흑기사인 동안 저주에 안 걸림 – 사용자 결정 (2026-11-24)
##         포탑에는 말을 타고 있어도 바로 쓰러짐 – 사용자 결정 (2026-11-24)
##  병사   가로 · 세로 2칸 이하(꺾어도 됨, 제자리도 됨) → 둘 중 하나: 상하좌우의 적 한 명 공격, 또는 상하좌우 빈칸 모두에 지뢰.
##         이미 적군 지뢰가 있는 칸에서는 지뢰끼리 터져서 지뢰 없는 칸이 됨(아무도 안 다침). 내 지뢰가 있는 칸은 그대로 – 사용자 결정 (2026-11-25)
##         적 영웅이 지뢰 칸에 멈추면 데미지(목숨 1)
##  천사   상하좌우 한 방향으로 2칸 이하(영웅을 넘을 수 있음, 영웅이 있는 칸에도 내려앉을 수 있음, 성은 못 넘음). 벽에 막히고 지뢰에도 맞음 – 사용자 결정 (2026-11-25)
##         → 아군 유령 칸이면: 내 성 주위 5칸 중 한 칸에 그 영웅을 부활(성 주위 빈칸이 있을 때만 들어감, 들어가면 꼭 부활). 적군 유령 칸이면: 그 유령을 없앰
##         → 아군 또는 적군 칸이면(로봇 · 건축가 · 닌자 X, 적 사신은 됨 – 사용자 결정 2026-11-25): 그 영웅을 조종해 그 상하좌우 적 한 명을 공격하고(적이 없거나 안 해도 됨), 천사는 이동 전 위치로 돌아감 – 사용자 결정 (2026-11-25)
##         패시브: 쓰러지면 유령 대신 십자가가 생기고, 성직자의 희생으로 십자가 자리에서 부활할 수 있음. 무력과 저주에 걸리지 않음 – 사용자 결정 (2026-11-25)
##  마법사 이동 없음 → 둘 중 하나: 아군 한 명 또는 아군 유령과 자리를 바꾼 뒤 주위 8칸의 적 한 명 능력 봉인, 또는 상하좌우 한 방향으로 3칸 파이어볼
##         봉인(사용자 결정 2026-11-24): 1턴(상대의 다음 차례 한 번) 동안 이동만 됨(능력 · 벽 · 성 치기 · 닌자의 따라 하기 · 천사의 내려앉기와 부활 X, 패시브는 그대로).
##         배리어는 상관없음. 봉인은 안 해도 됨. 이동이 없는 마법사가 봉인되면 아무것도 못 함
##         파이어볼은 관통하지 않음: 그 방향 3칸 안에서 처음 만나는 적(또는 상대 성)에 맞음. 적군의 벽(아군 벽은 지나감)과 모든 포탑에 막힘 – 사용자 결정 (2026-11-25)
##  성직자 가로 · 세로 1칸 → 셋 중 하나: 상하좌우 아군 한 명 또는 자기에게 배리어 (벽 상관없음),
##         또는 상하좌우 한 방향의 바로 옆 칸을 십자가로 때림: 적 · 상대 성 · 적 유령,
##         또는 내 성 주위 5칸에 있을 때 자신을 희생해(유령은 남음) 쓰러진 천사를 십자가 자리에서 부활 – 사용자 결정 (2026-11-25)
##         배리어는 목숨을 하나 늘리고(공격 · 지뢰를 한 번 막고 깨짐), 깨질 때까지 유지. 한 편에 하나뿐이라 다른 영웅에게 주면 있던 배리어는 사라짐. 저주를 풀어 주고, 배리어가 있는 동안 저주의 대상이 안 됨 – 사용자 결정 (2026-11-24)
##         사신의 자동 공격은 배리어가 있는 동안 아예 안 통하고 배리어도 안 깨짐. 포탑은 배리어를 뚫고 공격함 – 사용자 결정 (2026-11-24)
##  로봇   가로 · 세로로 막힐 때까지의 아무 칸 → 셋 중 하나: 움직인 방향의 다음 칸에 있는 적 한 명을 한 칸 뒤(로봇 반대편)로 밀면서 1턴 스턴(제자리면 없음. 자리가 없으면 안 밀리지만 스턴은 걸림. 스턴 = 그 편의 다음 차례에 이동도 능력도 못 씀, 아군은 못 밂 – 사용자 결정 2026-11-25), 또는 상하좌우로 한 칸 띄워진 영웅 한 명(적 · 아군, 제자리도 됨)을 자기 쪽으로 한 칸 끌어당김(스턴 X) – 사용자 결정 (2026-11-25), 또는 상하좌우의 벽이나 포탑 하나를 부숨(누구 것이든)
##         공격 · 무력 · 저주 · 조종(천사의 내려앉기)의 대상이 안 됨. 밀기 · 스턴 · 자리 바꾸기 · 데려오기 · 봉인 · 배리어는 통함 – 사용자 결정 (2026-11-24). 멈춘 칸의 지뢰(누구 것이든)를 없앰
##  전사   가로 · 세로 1칸 → 둘 중 하나: 상하좌우의 적 한 명 공격, 또는 1칸 전진(적진 쪽)
##         패시브: 주위 8칸의 적은 무력(이동 · 능력 불가). 멈추는 순간 바로 무력해져서 이동한 뒤의 능력도 못 씀.
##         전사끼리(전사 모습 닌자 포함)는 서로 안 통함 – 사용자 결정
##  닌자   성을 공격할 수 없음. 가로 · 세로로 막힐 때까지의 아무 칸(능력 없음 – 사용자 결정 2026-11-24) 또는, 이동하지 않고 그 자리에서 앞 또는 뒤 세로줄에서 처음 만나는 영웅(적 · 아군, 모두)을 골라 그 영웅의
##         이동과 능력을 따라 해서 씀 – 사용자 결정. 상대 사신과 상대 닌자는 따라 할 수 없음
##         따라 한 모습은 다음 내 차례가 시작될 때까지 유지되고(특성도: 로봇 = 공격 · 무력 · 저주 · 조종이 안 통함, 사신 = 자동 공격 · 벽 통과,
##         기사 = 따라 한 기사의 말, 전사 = 주위 8칸 무력), 그때 닌자로 돌아옴 – 사용자 결정
##  사신   가로 · 세로 1칸 이하 → 둘 중 하나: 상하좌우 한 방향으로 2칸 안에서 처음 만나는 적에게 저주(배리어가 있거나 사신 · 천사면 못 걺, 적군의 벽과 모든 포탑에 막힘 – 사용자 결정 2026-11-25),
##         또는 저주가 걸린 적(적 유령)의 자리로 이동하며 그 적은 흔적도 없이 사라짐 (거리 상관없음, 유령도 안 남음)
##         저주는 적 유령에게도 걸 수 있고(먼저 만난 것 하나, 적 유령이 저주를 막음), 저주에 걸린 영웅이 쓰러져 유령이 되면 저주가 남음 – 사용자 결정 (2026-11-25)
##         저주를 걸 때 이미 걸려 있던 저주(그 편이 건 것 모두, 유령의 것도)는 풀림 – 사용자 결정 (2026-11-25). 말 탄 기사에게 걸어 흑기사로 변신하게 해도 풀림
##         저주는 배리어를 받으면 풀리고, 사신(사신 모습 닌자)이 쓰러지면 적에게 걸린 모든 저주가 사라짐
##         패시브: 주위 대각선 4칸에 적이 있으면 누구의 차례든 자동으로 공격함(행동을 안 씀, 배리어가 있는 적은 안 맞고 말을 탄 기사는 흑기사로 변신): 사신이나 적이 멈춰서
##         대각선에 놓일 때, 그리고 차례가 바뀔 때마다. 지나가기만 하면 X. 성은 자동으로 공격하지 않음 – 사용자 결정
##         이동은 벽을 통과함(누구의 벽이든, 포탑 칸에는 못 섬). 적 닌자가 따라 할 수 없음.
##         저주에는 안 걸림. 무력 · 밀기 · 봉인은 다른 영웅처럼 통함(무력 · 스턴이어도 자동 공격은 함) – 사용자 결정 (2026-11-24)
##  건축가 상하좌우 · 대각선 한 방향으로 막힐 때까지의 아무 칸(제자리도 됨 – 사용자 결정) → 자기 칸 네 변 중 하나에 벽. 성을 공격할 수 없음 – 사용자 결정 (2026-11-25). 벽은 누구의 이동이든(사신은 통과) 막고, 적군의 공격(성 공격 · 십자가 · 파이어볼 · 저주도)을 막음. 아군의 공격은 지나감
##         대각선 공격(사신의 자동 공격, 포탑, 흑기사의 대각선 칸)은 못 막음 – 사용자 결정 (2026-11-25). 벽은 로봇만 부술 수 있음(건축가도 못 허묾) – 사용자 결정 (2026-11-24). 벽의 주인(세운 편)은 색으로만 보임
##         칸의 네 변이 모두 세운 편의 벽이 되면(한 칸짜리 집) 그 칸에 그 편의 포탑이 생김. 적군 벽이 섞이면 안 생김 – 사용자 결정 (2026-11-25)
##         그 칸에 다른 영웅이 있으면 편에 상관없이 배리어를 무시하고 쓰러짐. 로봇도 상대 사신도 쓰러짐. 유령은 안 생김(부활 못 함) – 사용자 결정 (2026-11-24)
##         건축가가 자기 칸을 막으면 그 칸도 포탑이 되고, 건축가는 포탑 상하좌우의 빈칸 하나를 골라 나옴
##         포탑: 자동 공격 – 생길 때, 적이 주위 8칸에 멈출 때 공격 (배리어도 뚫고 말 탄 기사도 바로 쓰러뜨림 – 사용자 결정 2026-11-24)
##         네 벽은 포탑의 일부라 로봇만 능력으로 부숨(누구의 포탑이든, 네 벽이 한꺼번에 깨짐) – 사용자 결정 (2026-11-24)
##  ('2칸 이하'는 0~2칸. 모든 영웅은 제자리도 됨 – 사용자 결정)
##
## 성 공격 범위: 기사 움직인 방향의 다음 칸 · 병사 상하좌우 · 마법사 상하좌우 3칸 · 성직자 상하좌우 · 전사 상하좌우
##   안에 상대 성이 있으면 칠 수 있음
## 상대 성은 로봇 · 건축가 · 닌자가 아닌 영웅이면 누구나 능력 단계에서 상하좌우에 붙어 있을 때 공격 범위와 상관없이 칠 수 있음 (사용자 결정)
##  (닌자는 다른 영웅을 따라 할 때도 성을 못 침 – 사용자 결정 2026-11-25)
##
## 규칙 설명에 없어서 정한 부분 (사용자에게 알림)
##  - 밀기: 밀려나는 길(밀리는 영웅과 뒤 칸 사이)에 벽이 있으면 안 밀림. 로봇과 영웅 사이의 벽은 상관없음. 벽과 영웅이 함께 있으면 무엇을 할지 고름(칸 + SIDE)
##  - 공격 = 능력 공격 · 지뢰 · 사신과 포탑의 자동 공격. 배리어가 먼저 막고, 그다음 말. 기사 모습 닌자도 말이 대신 죽고 흑기사로 변신함(따라 한 기사가 흑기사면 흑기사로). 천사 모습 닌자가 쓰러지면 유령이 남음
##  - 파이어볼은 아군 · 로봇에 막힘. 유령은 파이어볼을 막지 않고, 저주는 적 유령에만 막힘(내 유령은 지나감). 부활하면 저주는 사라짐. 밀기 · 자리 바꾸기 · 봉인 · 배리어 · 무력 · 지뢰 놓기는 공격이 아니라 벽과 상관없음. 저주 걸린 적에게 가는 것은 벽과 상관없음
##  - 사신의 자동 공격: 이동 · 밀기 · 자리 바꾸기 · 데려오기 · 소환 · 부활 등 어떻게 멈췄든 똑같음 (천사가 영웅 칸에 내려앉는 것도 멈춘 것). 
##    두 사신이 서로의 대각선에 놓이면 동시에 공격함. 따라 한 모습이 사신인 닌자도 그 모습인 동안 똑같고, 모습이 바뀌는 순간에도 공격
##  - 로봇의 끌어당기기: 사이 칸이 빈칸일 때만(유령 · 십자가 · 포탑 X). 끌려오는 길(영웅과 사이 칸)에 벽이 있으면 안 되고, 사이 칸과 로봇 사이의 벽은 상관없음. 멈춘 칸의 지뢰 · 사신 · 포탑 · 무력은 밀기와 똑같음
##  - 로봇: 뒤 칸이 막힌 적(영웅 · 벽 · 판 끝 · 성 · 유령 · 십자가 · 포탑)은 밀리지 않고 스턴만. 이미 스턴된 적은 뒤 칸이 막혀 있으면 못 고름
##  - 기사가 아군을 옮기는 길에 벽이나 영웅이 있으면 못 옮김(사신도, 유령 칸은 지나갈 수만 있음). 옮긴 칸의 지뢰 · 사신 · 포탑에는 보통처럼 맞음. 로봇도 옮길 수 있음
##  - 건축가를 따라 한 닌자는 한 번만 행동함. 저주는 적 사신에 막힘. 사신 모습을 따라 한 닌자도 그 모습인 동안 저주에 안 걸림
##  - 지뢰 놓기는 상하좌우 빈칸에 한꺼번에(표시된 칸 아무 데나 누름). 천사가 영웅 칸에 내려앉는 것도 멈춘 것이라 그 칸의 적 지뢰에 맞음. 밀리거나 옮겨져서 멈춰도 터짐. 로봇은 멈춘 칸의 지뢰를 누구 것이든 없앰
##  - 유령: 지뢰 · 사신 · 공격은 유령에게 안 통함. 유령은 남은 영웅 수에 들지 않음. 유령 칸은 빈칸이 아니라서 밀기 · 데려오기 · 지뢰 · 소환 · 복귀 자리도 안 됨
##    겹쳐서 옮겨 생길 때는 쓰러진 칸에서 가까운 빈칸, 거리가 같으면 자기 성에 가까운 칸, 그것도 같으면 왼쪽 칸
##  - 부활 · 성 소환 칸에 적 지뢰가 있으면 그 칸은 고를 수 없음
##  - 십자가: 천사가 쓰러진 칸에 다른 영웅이나 유령이 있으면(내려앉다 쓰러짐 등) 가장 가까운 빈칸(적 지뢰 칸 제외)에 생김. 유령도 못 멈춤.
##    밀기 · 넘기기 · 지뢰 · 성 소환 · 부활 자리도 안 됨. 자리 바꾸기의 대상이 아님
##  - 봉인된 천사는 유령 칸에 못 들어감. 천사 모습을 따라 한 닌자도 무력에 안 걸림
##  - 닌자의 앞 줄 보기는 벽에 막히지 않음. 적 사신과 적 닌자는 따라 할 수 없고, 그 너머의 영웅도 못 고름. 따라 할 때 데려오기 · 지뢰 · 무력 · 배리어 · 부활은 닌자 편 기준
##  - 천사: 적 전사 주위 8칸의 영웅 칸에도 내려앉을 수 있음. 돌아오는 것도 멈춘 것이라 그 자리의 사신 · 포탑에 맞음.
##    로봇 · 건축가 · 닌자(무엇을 따라 하든) 칸에는 못 내려앉음(넘어가기는 됨). 공격은 배리어에 막힘. 유령 칸에서는 부활만 함(성은 못 침)
##  - 사신의 저주: 아군 · 로봇 · 성에 막힘(관통 X). 이미 저주 걸린 적 · 배리어가 있는 적에게는 못 걸고, 그 너머로도 못 걺. 시간 제한 없음
##    저주 걸린 적이 로봇이나 천사 모습(닌자)이면 그동안은 X. 저주는 천사에 막힘(관통 X)
##  - 배리어: 한 편에 하나(성직자와 성직자 모습 닌자가 함께 씀). 이미 배리어가 있는 영웅에게는 또 못 줌
##  - 건축가의 대각선 걸음은 모서리를 돌아가는 두 길이 모두 벽으로 막혔을 때만 막힘
##  - 포탑: 유령이 있는 칸은 벽으로 둘러싸도 포탑이 안 됨(벽을 세운 그 순간에만 확인). 벽을 세운 건축가 자신만 빠져나옴.
##    건축가는 성 쪽 변에도 벽을 세울 수 있음. 건축가가 나올 빈칸이 없으면 건축가 칸은 포탑이 안 됨. 판 가장자리는 벽이 아님.
##    포탑이 되면 네 벽은 모두 포탑 주인의 벽이 됨. 로봇 · 유령은 포탑에 안 맞음. 포탑이 부서져도 옆 포탑과 함께 쓰던 벽은 남음
##  - 결전: COLLAPSE_START 차례가 지나면 COLLAPSE_EVERY 차례마다 두 성의 목숨이 함께 1 줄어듦.
##    결전 때 한쪽의 살아 있는 영웅이 3명 이하이고 두 편 영웅 수가 3명 이상 차이 나면 그 결전은 건너뜀 (사용자 결정)
##  - 할 수 있는 게 없으면 차례를 건너뜀

enum Kind { KNIGHT, SOLDIER, ANGEL, MAGICIAN, PRIEST, ROBOT, WARRIOR, NINJA, REAPER, ARCHITECT }
enum Phase { PLACE, ACT, OVER }
## 한 행동 안의 단계 (SPIRIT = 유령 이동)
## LAND = 천사가 영웅 칸에 내려앉아 상하좌우 적을 공격하거나 그냥 돌아감, EXIT = 포탑이 된 칸에서 건축가가 나올 칸
enum Step { NONE, MOVE, CARRY, STRIKE, MINE, REVIVE, SWAP_FIRE, BARRIER, PUSH, WARRIOR, REAP, WALL, SPIRIT, LAND, EXIT, SEAL }

const W := 11
static var H := 8                     # 세로 줄 수. 규칙 테스트만 set_rows 로 큰 판(11줄)을 씀
const KINDS := 10
const NONE := Vector2i(-1, -1)
const STOP := Vector2i(-9, -9)        # AI 계획에서 '여기까지' 표시
const SIDE := Vector2i(100, 0)        # 같은 칸에 다른 능력 표시가 있을 때, 그쪽 벽 · 성을 치는 선택 = 칸 + SIDE
const BIG := 99
const NAMES := ["기사", "병사", "천사", "마법사", "성직자", "로봇", "전사", "닌자", "사신", "건축가"]
static var CASTLE: Array[Vector2i] = [Vector2i(5, 7), Vector2i(5, 0)]   # 플레이어별 내 성
static var LAST_ROW: Array[int] = [0, 7]                              # 상대 쪽 맨 끝 줄
const FWD := [Vector2i(0, -1), Vector2i(0, 1)]      # 앞쪽 (적진 방향)
const START_LIVES := 3
const MAX_ACTIONS := 2
const SUMMON_LIVES := 2               # 성 소환은 하트가 이만큼 있을 때만 (하트 1개를 씀)
const MAX_TURNS := 300
const ANGEL_STEPS := 2                # 천사: 상하좌우 한 방향 2칸 이하
const FIRE_RANGE := 3                 # 마법사의 파이어볼
const CURSE_RANGE := 2
## 결전 시점: 80차례부터 20차례마다 – 사용자 결정 (2026-11-23, 결전이 너무 빨라 역전이 안 된다고 해서 늦춤)
const COLLAPSE_START := 80
const COLLAPSE_EVERY := 20
const DIRS4 := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIRS8 := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
const DIAG := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

## 끝줄 배치: 왼쪽부터 (가운데 성 칸은 빼고) 영웅 10명. 위쪽은 판 가운데를 기준으로 돌려서 씀
const FORMATIONS := [
	[Kind.ROBOT, Kind.SOLDIER, Kind.ARCHITECT, Kind.ANGEL, Kind.WARRIOR, Kind.REAPER, Kind.PRIEST, Kind.MAGICIAN, Kind.KNIGHT, Kind.NINJA],
	[Kind.NINJA, Kind.KNIGHT, Kind.MAGICIAN, Kind.REAPER, Kind.PRIEST, Kind.WARRIOR, Kind.ANGEL, Kind.ARCHITECT, Kind.SOLDIER, Kind.ROBOT],
	[Kind.KNIGHT, Kind.NINJA, Kind.SOLDIER, Kind.PRIEST, Kind.REAPER, Kind.ANGEL, Kind.WARRIOR, Kind.MAGICIAN, Kind.ROBOT, Kind.ARCHITECT],
]

## 영웅 번호 = 주인 * 10 + 종류
var pos: Array[Vector2i] = []
var grid := PackedInt32Array()          # 칸별 영웅 번호 (-1 = 빈칸)
var barrier := PackedByteArray()        # 1 = 배리어 있음 (깨지거나 다른 아군에게 줄 때까지, 한 편에 하나)
var sealed := PackedByteArray()         # 1 = 능력이 봉인됨 (그 편의 다음 차례가 끝나면 풀림)
var cursed_by := PackedInt32Array()     # 저주를 건 사신(또는 사신 모습 닌자)의 번호 (-1 = 없음)
var horse := PackedByteArray()          # 1 = 말을 탄 기사 (기사 모습 닌자는 따라 한 기사의 말)
var dark := PackedByteArray()           # 1 = 흑기사 (그 편의 차례가 한 번 끝날 때까지)
var stunned := PackedByteArray()        # 1 = 로봇에게 스턴됨 (그 편의 다음 차례가 끝나면 풀림)
var disabled_by := PackedInt32Array()   # 지금 무력하게 만들고 있는 전사 번호 (-1 = 멀쩡, 자리에서 바로 정해짐)
var mines := PackedByteArray()          # 0 없음, 1 = 플레이어 0 지뢰, 2 = 플레이어 1 지뢰
var wall_v := PackedByteArray()         # (x,y) 와 (x+1,y) 사이 벽 (0 = 없음, 주인 + 1)
var wall_h := PackedByteArray()         # (x,y) 와 (x,y+1) 사이 벽 (0 = 없음, 주인 + 1)
var ghost_pos: Array[Vector2i] = []     # 쓰러진 영웅의 유령 자리 (NONE = 유령 없음)
var ghosts := PackedInt32Array()        # 칸별 유령 번호 (-1 = 없음)
var cross := PackedInt32Array([-1, -1]) # 플레이어별 쓰러진 천사의 십자가 칸 번호 (-1 = 없음)
var turret := PackedByteArray()         # 칸별 포탑 (0 없음, 1 = 플레이어 0 포탑, 2 = 플레이어 1 포탑)
var deaths: int = 0
var lives := PackedInt32Array([START_LIVES, START_LIVES])
var first: int = 0
var current: int = 0
var phase: int = Phase.PLACE
var turn: int = 0
var used: int = 0                       # 이번 차례에 쓴 영웅 행동 수
var acted: int = 0                      # 이번 차례에 행동한 영웅 (비트)
var over: bool = false
var winner: int = -1
var end_reason: String = ""             # "castle" / "collapse" / "turns" / "stuck"
var passed: int = -1                    # 직전에 할 게 없어 건너뛴 플레이어
var collapses: int = 0
var collapsed_now: bool = false
var collapse_skipped: bool = false      # 방금 결전 차례였지만 영웅 수 차이로 건너뜀
## 닌자가 따라 한 모습 (플레이어별 영웅 종류, -1 = 닌자 그대로). 그 사람 차례가 다시 시작될 때 풀림
var ninja_form := PackedInt32Array([-1, -1])
## 진행 중인 행동
var act_hero: int = -1                  # 행동하는 영웅
var act_kind: int = -1                  # 지금 쓰는 능력 (닌자는 따라 한 영웅의 종류)
var act_step: int = Step.NONE
var act_copy: int = -1                  # 닌자가 따라 한 영웅
var act_started: bool = false           # 한 단계라도 했는지 (안 했으면 취소 가능)
var act_optional: bool = false          # 지금 단계는 건너뛸 수 있음 (능력은 안 써도 됨)
var act_from := NONE                    # 이동을 시작한 칸
var act_dir := Vector2i.ZERO            # 기사 · 로봇이 움직인 방향 (제자리면 ZERO = 직접 공격 · 밀기 없음)
var act_ghost: bool = false             # 지금 행동이 유령 이동인지
var log_events: bool = true            # AI 계산용 복사본은 끔
var _ev: Array = []


static func owner_of(id: int) -> int:
	return id / KINDS


static func kind_of(id: int) -> int:
	return id % KINDS


static func manh(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 고른 것의 진짜 칸 (칸 + SIDE 이면 그 칸)
static func real_cell(c: Vector2i) -> Vector2i:
	return c - SIDE if c.x >= SIDE.x else c


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## 이동 뒤 쓰는 능력의 첫 단계
static func ability_step(k: int) -> int:
	match k:
		Kind.KNIGHT:
			return Step.STRIKE
		Kind.SOLDIER:
			return Step.MINE
		Kind.ANGEL:
			return Step.REVIVE
		Kind.MAGICIAN:
			return Step.SWAP_FIRE
		Kind.PRIEST:
			return Step.BARRIER
		Kind.ROBOT:
			return Step.PUSH
		Kind.WARRIOR:
			return Step.WARRIOR
		Kind.REAPER:
			return Step.REAP
		Kind.ARCHITECT:
			return Step.WALL
	return Step.NONE


static func can_summon_kind(k: int) -> bool:
	return k != Kind.ROBOT   # 사신도 소환됨 – 사용자 결정 (2026-11-23)


## 공격 능력이 있는 영웅 (적 · 성 · 벽을 칠 수 있음)
static func attacks(k: int) -> bool:
	return k == Kind.KNIGHT or k == Kind.WARRIOR or k == Kind.MAGICIAN or k == Kind.PRIEST or k == Kind.REAPER or k == Kind.SOLDIER


# ══════════════════════════════════════════════════════
#  준비
# ══════════════════════════════════════════════════════
func setup(p_first: int = 0) -> void:
	var n := KINDS * 2
	pos = []
	pos.resize(n)
	pos.fill(NONE)
	grid = PackedInt32Array()
	grid.resize(W * H)
	grid.fill(-1)
	barrier = PackedByteArray()
	barrier.resize(n)
	barrier.fill(0)
	disabled_by = PackedInt32Array()
	disabled_by.resize(n)
	disabled_by.fill(-1)
	sealed = PackedByteArray()
	sealed.resize(n)
	sealed.fill(0)
	horse = PackedByteArray()
	horse.resize(n)
	horse.fill(0)
	for hp in 2:
		horse[hp * KINDS + Kind.KNIGHT] = 1
	dark = PackedByteArray()
	dark.resize(n)
	dark.fill(0)
	stunned = PackedByteArray()
	stunned.resize(n)
	stunned.fill(0)
	cursed_by = PackedInt32Array()
	cursed_by.resize(n)
	cursed_by.fill(-1)
	ghosts = PackedInt32Array()
	ghosts.resize(W * H)
	ghosts.fill(-1)
	ghost_pos = []
	ghost_pos.resize(n)
	ghost_pos.fill(NONE)
	cross = PackedInt32Array([-1, -1])
	mines = PackedByteArray()
	mines.resize(W * H)
	mines.fill(0)
	turret = PackedByteArray()
	turret.resize(W * H)
	turret.fill(0)
	wall_v = PackedByteArray()
	wall_v.resize(W * H)
	wall_v.fill(0)
	wall_h = PackedByteArray()
	wall_h.resize(W * H)
	wall_h.fill(0)
	deaths = 0
	lives = PackedInt32Array([START_LIVES, START_LIVES])
	first = p_first
	current = p_first
	phase = Phase.PLACE
	turn = 0
	used = 0
	acted = 0
	over = false
	winner = -1
	end_reason = ""
	passed = -1
	collapses = 0
	collapsed_now = false
	collapse_skipped = false
	ninja_form = PackedInt32Array([-1, -1])
	_clear_act()
	apply_formation(0, 0)
	apply_formation(1, 0)


func clone() -> HeroLogic:
	var c := HeroLogic.new()
	c.pos = pos.duplicate()
	c.grid = grid.duplicate()
	c.barrier = barrier.duplicate()
	c.disabled_by = disabled_by.duplicate()
	c.sealed = sealed.duplicate()
	c.horse = horse.duplicate()
	c.dark = dark.duplicate()
	c.stunned = stunned.duplicate()
	c.cursed_by = cursed_by.duplicate()
	c.mines = mines.duplicate()
	c.turret = turret.duplicate()
	c.wall_v = wall_v.duplicate()
	c.wall_h = wall_h.duplicate()
	c.ghost_pos = ghost_pos.duplicate()
	c.ghosts = ghosts.duplicate()
	c.cross = cross.duplicate()
	c.deaths = deaths
	c.lives = lives.duplicate()
	c.first = first
	c.current = current
	c.phase = phase
	c.turn = turn
	c.used = used
	c.acted = acted
	c.over = over
	c.winner = winner
	c.end_reason = end_reason
	c.passed = passed
	c.collapses = collapses
	c.collapsed_now = collapsed_now
	c.collapse_skipped = collapse_skipped
	c.ninja_form = ninja_form.duplicate()
	c.act_hero = act_hero
	c.act_kind = act_kind
	c.act_step = act_step
	c.act_copy = act_copy
	c.act_started = act_started
	c.act_optional = act_optional
	c.act_from = act_from
	c.act_dir = act_dir
	c.act_ghost = act_ghost
	c.log_events = false
	return c


## 테스트용: 세로 줄 수 바꾸기 (성은 양 끝줄 가운데)
static func set_rows(h: int) -> void:
	H = h
	CASTLE = [Vector2i(5, h - 1), Vector2i(5, 0)]
	LAST_ROW = [0, h - 1]


## 내 맨 끝줄 칸인지 (성 칸 제외) – 배치하는 곳
func is_back_row(p: int, c: Vector2i) -> bool:
	return in_bounds(c) and not is_castle(c) and c.y == LAST_ROW[1 - p]


func back_row_cells(p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in W:
		var c := Vector2i(x, LAST_ROW[1 - p])
		if is_back_row(p, c):
			out.append(c)
	return out


## 정해진 배치 쓰기. flip = 좌우 뒤집기
func apply_formation(p: int, idx: int, flip: bool = false) -> void:
	for k in KINDS:
		var id := p * KINDS + k
		if pos[id] != NONE:
			grid[_i(pos[id])] = -1
			pos[id] = NONE
	var f: Array = FORMATIONS[idx % FORMATIONS.size()]
	for i in f.size():
		var x: int = i if i < CASTLE[0].x else i + 1   # 성 칸을 건너뜀
		if flip != (p == 1):
			x = W - 1 - x
		_place(p * KINDS + int(f[i]), Vector2i(x, LAST_ROW[1 - p]))


## 온라인 대전: 받은 배치 { 종류: 칸 } 를 그대로 놓음 (내 끝줄 안 · 칸 겹침 없음일 때만). 성공하면 true
func set_formation(p: int, cells: Dictionary) -> bool:
	if phase != Phase.PLACE or cells.size() != KINDS:
		return false
	var seen := {}
	for k in cells:
		var c: Vector2i = cells[k]
		if int(k) < 0 or int(k) >= KINDS or not is_back_row(p, c) or seen.has(c):
			return false
		seen[c] = true
	for k in KINDS:
		var id := p * KINDS + k
		if pos[id] != NONE and grid[_i(pos[id])] == id:
			grid[_i(pos[id])] = -1
		pos[id] = NONE
	for k in cells:
		_place(p * KINDS + int(k), cells[k])
	return true


## 지금 배치: 자기 성을 아래로 놓고 볼 때 왼쪽부터의 영웅 종류 10개 (직전 배치 기억용, 어느 자리에서든 같은 모양)
func place_list(p: int) -> Array:
	var out: Array = []
	for c in _seen_row(p):
		var id := at(c)
		out.append(-1 if id < 0 else kind_of(id))
	return out


## place_list 로 만든 배치를 그대로 놓음 (영웅 10명이 한 번씩일 때만). 성공하면 true
func use_place_list(p: int, list: Variant) -> bool:
	if typeof(list) != TYPE_ARRAY or (list as Array).size() != KINDS:
		return false
	var row := _seen_row(p)
	var cells := {}
	for i in KINDS:
		var k: Variant = list[i]
		if typeof(k) != TYPE_INT:
			return false
		cells[int(k)] = row[i]
	return set_formation(p, cells)


## 자기 성을 아래로 놓고 볼 때 왼쪽부터의 끝줄 칸
func _seen_row(p: int) -> Array[Vector2i]:
	var row := back_row_cells(p)
	if p == 1:
		row.reverse()
	return row


## 판 상태 지문 (온라인 대전에서 두 폰의 계산이 같은지 확인용)
func state_hash() -> int:
	return hash([pos, lives, turn, current, used, acted, over, winner, ghost_pos,
		barrier, disabled_by, sealed, horse, dark, stunned, cursed_by, mines, turret, wall_v, wall_h, ninja_form, collapses, cross])


func random_formation(p: int, rng: RandomNumberGenerator) -> void:
	apply_formation(p, rng.randi() % FORMATIONS.size(), rng.randf() < 0.5)


## 배치 단계: 내 끝줄의 두 칸을 바꿈
func place_swap(p: int, a: Vector2i, b: Vector2i) -> bool:
	if phase != Phase.PLACE or a == b or not is_back_row(p, a) or not is_back_row(p, b):
		return false
	var ha := at(a)
	var hb := at(b)
	if ha < 0 and hb < 0:
		return false
	if (ha >= 0 and owner_of(ha) != p) or (hb >= 0 and owner_of(hb) != p):
		return false
	grid[_i(a)] = hb
	grid[_i(b)] = ha
	if ha >= 0:
		pos[ha] = b
	if hb >= 0:
		pos[hb] = a
	return true


func start_play() -> void:
	phase = Phase.ACT
	current = first
	turn = 0
	used = 0
	acted = 0
	_clear_act()


# ══════════════════════════════════════════════════════
#  판 정보
# ══════════════════════════════════════════════════════
func _i(c: Vector2i) -> int:
	return c.y * W + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < W and c.y >= 0 and c.y < H


func is_castle(c: Vector2i) -> bool:
	return c == CASTLE[0] or c == CASTLE[1]


func at(c: Vector2i) -> int:
	return grid[c.y * W + c.x] if in_bounds(c) else -1


func alive(id: int) -> bool:
	return pos[id] != NONE


func heroes_of(p: int) -> Array[int]:
	var out: Array[int] = []
	for k in KINDS:
		if pos[p * KINDS + k] != NONE:
			out.append(p * KINDS + k)
	return out


func count(p: int) -> int:
	return heroes_of(p).size()


func mine_at(c: Vector2i) -> int:
	## 지뢰 주인 (-1 = 없음)
	return mines[_i(c)] - 1


## 빈칸 (판 안 · 성 · 포탑 아님 · 영웅도 유령도 십자가도 없음)
func is_free(c: Vector2i) -> bool:
	if not in_bounds(c) or is_castle(c):
		return false
	var i := c.y * W + c.x
	return grid[i] < 0 and ghosts[i] < 0 and turret[i] == 0 and i != cross[0] and i != cross[1]


## 영웅이 지나갈 수 있는 칸 (빈칸이거나 유령 · 십자가만 있는 칸)
func is_open(c: Vector2i) -> bool:
	return in_bounds(c) and not is_castle(c) and grid[c.y * W + c.x] < 0 and turret[c.y * W + c.x] == 0


## 그 칸의 포탑 주인 (-1 = 포탑 없음)
func turret_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return -1
	return turret[_i(c)] - 1


## 한 칸짜리 집: 판 안의 칸(유령 · 성 · 포탑 없음, 십자가는 있어도 됨)이고 네 변이 모두 me 의 벽. 영웅이 있어도 됨
## (벽을 세운 건축가는 밖으로 나오고, 다른 영웅은 쓰러짐)
func _house_ready(c: Vector2i, me: int) -> bool:
	if not in_bounds(c) or is_castle(c) or turret[_i(c)] != 0 or ghost_at(c) >= 0:
		return false
	for d in DIRS4:
		var n: Vector2i = c + d
		if not in_bounds(n) or wall_owner(c, n) != me:
			return false
	return true


## 붙어 있는 두 칸 사이 벽
func has_wall(a: Vector2i, b: Vector2i) -> bool:
	return wall_owner(a, b) >= 0


## 붙어 있는 두 칸 사이 벽의 주인 (-1 = 벽 없음)
func wall_owner(a: Vector2i, b: Vector2i) -> int:
	if not in_bounds(a) or not in_bounds(b):
		return -1
	if a.y == b.y:
		return wall_v[a.y * W + mini(a.x, b.x)] - 1
	return wall_h[mini(a.y, b.y) * W + a.x] - 1


## p = 벽 주인 (-1 = 벽 없애기)
func _set_wall(a: Vector2i, b: Vector2i, p: int) -> void:
	var v := p + 1
	if a.y == b.y:
		wall_v[a.y * W + mini(a.x, b.x)] = v
	else:
		wall_h[mini(a.y, b.y) * W + a.x] = v


func wall_count() -> int:
	var n := 0
	for i in W * H:
		n += int(wall_v[i] != 0) + int(wall_h[i] != 0)
	return n


## 적이 공격할 수 있는 영웅인지 (로봇은 공격의 대상이 안 됨)
func _target(id: int, me: int) -> bool:
	return id >= 0 and owner_of(id) != me and not _immune(id)


## 지금 모습의 종류 (닌자가 따라 한 모습이면 그 종류)
func form_of(id: int) -> int:
	var k := kind_of(id)
	if k == Kind.NINJA and ninja_form[owner_of(id)] >= 0:
		return ninja_form[owner_of(id)]
	return k


## 공격 · 무력 · 저주 · 조종의 대상이 안 되는 영웅 (로봇, 로봇 모습의 닌자)
func _immune(id: int) -> bool:
	return form_of(id) == Kind.ROBOT


## 사신(사신 모습의 닌자)
func _reaper_like(id: int) -> bool:
	return form_of(id) == Kind.REAPER


# ── 유령 (쓰러진 영웅) ─────────────────────────────────
func has_ghost(id: int) -> bool:
	return ghost_pos[id] != NONE


## 그 칸의 유령 (-1 = 없음). 한 칸에 유령은 하나뿐
func ghost_at(c: Vector2i) -> int:
	return ghosts[c.y * W + c.x] if in_bounds(c) else -1


## 칸 c 에 있는 플레이어 p 의 유령 (-1 = 없음)
func ghost_of(c: Vector2i, p: int) -> int:
	var g := ghost_at(c)
	return g if g >= 0 and owner_of(g) == p else -1


## 유령 g 를 칸 c 에 둠 (NONE = 없앰)
func _set_ghost(g: int, c: Vector2i) -> void:
	var old: Vector2i = ghost_pos[g]
	if old != NONE and ghosts[_i(old)] == g:
		ghosts[_i(old)] = -1
	ghost_pos[g] = c
	if c != NONE:
		ghosts[_i(c)] = g


## 칸 c 에 있는 십자가의 주인 (-1 = 없음)
func cross_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return -1
	var i := _i(c)
	return 0 if cross[0] == i else (1 if cross[1] == i else -1)


## 플레이어 p 의 쓰러진 천사의 십자가 칸 (없으면 NONE)
func cross_cell(p: int) -> Vector2i:
	return NONE if cross[p] < 0 else Vector2i(cross[p] % W, cross[p] / W)


## 칸 c 에서 쓰러진 편 p 의 유령이 생길 칸: c 가 빈칸이면 c, 아니면 가장 가까운 빈칸 (같으면 자기 성에 가까운 칸, 왼쪽 칸)
## safe = true 면 적 지뢰가 있는 칸은 뺌 (십자가)
func _ghost_cell(c: Vector2i, p: int, safe: bool = false) -> Vector2i:
	if is_free(c):
		return c
	var best := NONE
	var bd := 0
	for x in W:
		for y in H:
			var n := Vector2i(x, y)
			if not is_free(n) or (safe and mine_at(n) == 1 - p):
				continue
			var d := manh(n, c) * 100 + manh(n, CASTLE[p])
			if best == NONE or d < bd:
				best = n
				bd = d
	return best


## 유령이 갈 수 있는 칸 { 도착 칸: [출발, …, 도착] }: 상하좌우 한 칸, 빈칸으로만 (제자리도 됨, 벽에 막힘)
func spirit_paths(id: int) -> Dictionary:
	var start: Vector2i = ghost_pos[id]
	var out := {start: [start]}
	for d in DIRS4:
		var n: Vector2i = start + d
		if is_free(n) and not has_wall(start, n):
			out[n] = [start, n]
	return out


## 내 성 주위 5칸(성을 둘러싼 8칸 중 판 안) 중 빈칸 (부활 · 성 소환 자리, 적 지뢰 칸 제외)
func castle_ring_cells(p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS8:
		var c: Vector2i = CASTLE[p] + d
		if is_free(c) and (mine_at(c) < 0 or mine_at(c) == p):
			out.append(c)
	return out


# ══════════════════════════════════════════════════════
#  이동
# ══════════════════════════════════════════════════════
## 갈 수 있는 칸 { 도착 칸: [출발, …, 도착] }. 제자리도 들어 있음, 마법사는 없음
## k: 이 종류의 이동으로 (닌자가 따라 할 때), -1 = 자기 종류
## paths = false 면 길은 만들지 않고 { 도착 칸: true } 만 (AI 계산용, 빠름)
func move_paths(id: int, k: int = -1, paths: bool = true) -> Dictionary:
	var out := {}
	var p: Vector2i = pos[id]
	if k < 0:
		k = kind_of(id)
	if k == Kind.MAGICIAN:
		return out   # 마법사는 이동 단계가 없음
	out[p] = [p]   # 모든 영웅은 제자리에 있어도 됨 – 사용자 결정
	match k:
		Kind.KNIGHT:
			# 한 방향으로 2칸 이하 (일직선), 말이 없으면 1칸
			for d in DIRS4:
				_line(p, d, 2 if horse[id] != 0 else 1, out, paths)
		Kind.SOLDIER:
			# 자유롭게 2칸 이하 (꺾어도 됨)
			_bfs(p, 2, false, out, paths)
		Kind.ARCHITECT:
			# 상하좌우 · 대각선 한 방향으로 막힐 때까지
			for d in DIRS8:
				_line(p, d, BIG, out, paths)
		Kind.ANGEL:
			# 상하좌우 한 방향으로 2칸 이하, 영웅을 넘을 수 있음 (벽 · 포탑에는 막힘). 영웅 칸에도 내려앉을 수 있음 (봉인되면 X)
			# 유령 칸: 적 유령은 없애러, 아군 유령은 부활시키러 (부활할 성 주위 빈칸이 있을 때). 봉인되면 X
			var room: bool = _home_room(id) > 0
			var land: bool = sealed[id] == 0
			var me := owner_of(id)
			for d in DIRS4:
				var path: Array = [p]
				for i in ANGEL_STEPS:
					var n: Vector2i = p + d * (i + 1)
					if not in_bounds(n) or is_castle(n) or has_wall(n - d, n):
						break
					path.append(n)
					var o := at(n)
					var g := ghost_at(n)
					if g >= 0:
						if sealed[id] == 0 and (room or owner_of(g) != me):
							out[n] = path.duplicate() if paths else true
					elif is_free(n) or (land and o >= 0 and o != id and can_land_on(o, id)):
						out[n] = path.duplicate() if paths else true
		Kind.PRIEST, Kind.WARRIOR:
			_bfs(p, 1, false, out, paths)
		Kind.REAPER:
			_bfs(p, 1, true, out, paths)   # 벽을 통과함 (한 칸이라 영웅을 넘지는 않음)
		Kind.ROBOT, Kind.NINJA:
			# 한 방향으로 막힐 때까지
			for d in DIRS4:
				_line(p, d, BIG, out, paths)
	if not out.has(p):
		out[p] = [p]
	return out


## 곧게 n 칸까지 (벽 · 영웅 · 성에서 멈춤, 유령 칸은 지나가기만)
func _line(p: Vector2i, d: Vector2i, n: int, out: Dictionary, paths: bool = true) -> void:
	var c := p
	var path: Array = [p]
	for i in n:
		var nx: Vector2i = c + d
		if not is_open(nx) or _step_walled(c, nx):
			return
		if paths:
			path.append(nx)
		if ghosts[_i(nx)] < 0 and cross_at(nx) < 0:
			out[nx] = path.duplicate() if paths else true
		c = nx


## 한 걸음(대각선도 됨)이 벽에 막히는지. 대각선은 모서리를 돌아가는 두 길이 모두 벽에 막혔을 때만 막힘
func _step_walled(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x or a.y == b.y:
		return has_wall(a, b)
	var h := Vector2i(b.x, a.y)
	var v := Vector2i(a.x, b.y)
	return (has_wall(a, h) or has_wall(h, b)) and (has_wall(a, v) or has_wall(v, b))


## 천사가 아군 유령을 부활시킬 수 있는 성 주위 빈칸 수 (천사가 떠나는 칸이 성 주위면 그 칸도 셈)
func _home_room(id: int) -> int:
	var me := owner_of(id)
	var n := castle_ring_cells(me).size()
	var p: Vector2i = pos[id]
	if p != NONE and cheb(p, CASTLE[me]) == 1 and at(p) == id and (mine_at(p) < 0 or mine_at(p) == me):
		n += 1
	return n


## 천사(모습) id 가 영웅 o 의 칸에 내려앉을 수 있는지 (로봇 · 건축가 · 닌자 X)
func can_land_on(o: int, id: int) -> bool:
	var k := kind_of(o)
	return o != id and k != Kind.ROBOT and k != Kind.ARCHITECT and k != Kind.NINJA


func _path_of(parent: Dictionary, n: Vector2i) -> Array:
	var path: Array = []
	var x := n
	while x != NONE:
		path.push_front(x)
		x = parent[x]
	return path


## 가로 · 세로로 한 칸씩 steps 칸까지 (꺾어도 됨). jump = 영웅과 벽(포탑도)을 넘을 수 있음 (도착은 빈칸만)
## 지나간 칸들의 { 칸: 앞 칸 } 을 돌려줌
func _bfs(p: Vector2i, steps: int, jump: bool, out: Dictionary, paths: bool = true) -> Dictionary:
	var parent := {p: NONE}
	var frontier: Array[Vector2i] = [p]
	for depth in steps:
		var nxt: Array[Vector2i] = []
		for c in frontier:
			for d in DIRS4:
				var n: Vector2i = c + d
				if parent.has(n) or not in_bounds(n) or is_castle(n) or (not jump and has_wall(c, n)):
					continue
				var occupied := at(n) >= 0
				if occupied and not jump:
					continue
				parent[n] = c
				nxt.append(n)
				if not occupied and turret[_i(n)] == 0 and ghosts[_i(n)] < 0 and cross_at(n) < 0:   # 유령 · 십자가 칸은 지나가기만
					out[n] = _path_of(parent, n) if paths else true
		frontier = nxt
	return parent


# ══════════════════════════════════════════════════════
#  고를 수 있는 것
# ══════════════════════════════════════════════════════
func _could_act(id: int) -> bool:
	if not alive(id):
		return has_ghost(id)   # 쓰러진 영웅은 유령으로 (유령도 제자리가 늘 됨)
	if disabled_by[id] >= 0 or stunned[id] != 0:
		return false
	if kind_of(id) == Kind.MAGICIAN:
		return sealed[id] == 0 and not options_for(id, Kind.MAGICIAN, Step.SWAP_FIRE).is_empty()
	return true   # 마법사가 아니면 제자리가 늘 됨 (move_paths 에 늘 제자리가 들어 있음)


func can_act(id: int) -> bool:
	return phase == Phase.ACT and not over and act_hero < 0 and used < MAX_ACTIONS \
		and owner_of(id) == current and not has_acted(id) and _could_act(id)


## 고를 수 있는 영웅과 유령 (유령은 쓰러진 영웅의 번호)
func selectable() -> Array[int]:
	var out: Array[int] = []
	for k in KINDS:
		var id := current * KINDS + k
		if (alive(id) or has_ghost(id)) and can_act(id):
			out.append(id)
	return out


## 이번 차례에 더 행동할 수 없는지 (건축가는 행동 2개를 모두 쓸 수 있음)
func has_acted(id: int) -> bool:
	return (acted >> id) & 1 == 1 and not (kind_of(id) == Kind.ARCHITECT and alive(id))


## 지금 단계에서 누를 수 있는 칸 { 칸: 표시 종류 }
## move / stay / land / carry / attack / castle / break / turret / fire / mine / rise / return / swap / warp / barrier / exorcise / push /
## advance / curse / doom / wall
func step_options() -> Dictionary:
	if act_hero < 0 or over:
		return {}
	return options_for(act_hero, act_kind, act_step)


func options_for(a: int, k: int, step: int) -> Dictionary:
	var out := _options_for(a, k, step)
	if not _can_siege(a) and out.get(CASTLE[1 - owner_of(a)], "") == "castle":
		out.erase(CASTLE[1 - owner_of(a)])
	return out


## 상대 성을 공격할 수 있는 영웅: 로봇 · 건축가 · 닌자(무엇을 따라 하든)가 아니면 됨
static func _can_siege(a: int) -> bool:
	var k := kind_of(a)
	return k != Kind.ROBOT and k != Kind.ARCHITECT and k != Kind.NINJA


func _options_for(a: int, k: int, step: int) -> Dictionary:
	var out := {}
	var me := owner_of(a)
	if step == Step.SPIRIT:
		var from: Vector2i = ghost_pos[a]
		var paths := spirit_paths(a)
		for c in paths:
			out[c] = "stay" if c == from else "move"
		return out
	var p: Vector2i = pos[a]
	match step:
		Step.MOVE:
			var paths := move_paths(a, k)
			for c in paths:
				if c == p:
					out[c] = "stay"
				elif at(c) >= 0:
					out[c] = "land"   # 천사가 내려앉을 영웅 칸
				elif ghost_at(c) >= 0:
					out[c] = "revive" if owner_of(ghost_at(c)) == me else "exorcise"   # 천사: 아군 유령 부활 · 적 유령 없애기
				else:
					out[c] = "move"
			# 닌자: 이동 대신 앞 · 뒤 줄의 영웅을 눌러 그 영웅의 이동과 능력을 따라 함
			if k == Kind.NINJA and act_copy < 0 and sealed[a] == 0:
				for src in ninja_sources(a):
					out[pos[src]] = "copy"
		Step.CARRY:
			_knight_targets(a, me, out)
			for b: int in carry_moves(a):
				out[pos[b]] = "carry"
		Step.STRIKE:
			_knight_targets(a, me, out)
		Step.MINE:
			# 상하좌우 빈칸 모두에 지뢰 놓기(적 지뢰가 있는 칸은 지뢰끼리 터짐, 내 지뢰가 있는 칸은 그대로) 또는 상하좌우 공격 (둘 중 하나)
			_strike_targets(p, me, out)
			for d in DIRS4:
				var n: Vector2i = p + d
				if is_free(n) and mine_at(n) != me:
					out[n] = "mine" if mine_at(n) < 0 else "mine_off"
		Step.REVIVE:
			if ghost_of(p, me) >= 0:
				for c in castle_ring_cells(me):
					out[c] = "rise"
				return out
		Step.SWAP_FIRE:
			_ball_targets(p, me, FIRE_RANGE, out)
			for b in heroes_of(me):
				if b != a:
					out[pos[b]] = "swap"
			for k2 in KINDS:
				var gid := me * KINDS + k2
				if has_ghost(gid):
					out[ghost_pos[gid]] = "warp"
		Step.SEAL:
			# 자리를 바꾼 뒤: 주위 8칸의 적 한 명의 능력을 봉인
			for d in DIRS8:
				var o := at(p + d)
				if o >= 0 and owner_of(o) != me and sealed[o] == 0:
					out[p + d] = "seal"
			return out
		Step.BARRIER:
			# 배리어: 상하좌우 아군 또는 자기 / 또는 바로 옆 칸을 십자가로 (적 · 성 · 적 유령)
			_strike_targets(p, me, out)
			for d in DIRS4:
				var b := at(p + d)
				if b >= 0 and owner_of(b) == me and barrier[b] == 0:
					out[pos[b]] = "barrier"
			if barrier[a] == 0:
				out[p] = "barrier"
			for d in DIRS4:
				var gn: Vector2i = p + d
				if in_bounds(gn) and ghost_of(gn, 1 - me) >= 0 and not _hit_stopped(p, gn, me):
					out[gn] = "exorcise"
			# 내 성 주위 5칸에서: 자신을 희생해 쓰러진 천사를 십자가 자리에서 부활
			if cross[me] >= 0 and cheb(p, CASTLE[me]) == 1:
				out[cross_cell(me)] = "rise"
		Step.PUSH:
			for m in push_moves(a):
				out[pos[m[0]]] = "push"
			for m in pull_moves(a):
				out[pos[m[0]]] = "pull"
			for d in DIRS4:
				# 로봇만 벽과 포탑을 부술 수 있음 (누구 것이든). 밀 영웅이 있는 쪽의 벽은 칸 + SIDE
				var wn: Vector2i = p + d
				if turret_at(wn) >= 0:
					out[wn] = "turret"
				elif in_bounds(wn) and has_wall(p, wn):
					out[wn + SIDE if out.has(wn) else wn] = "break"
		Step.WARRIOR:
			# 상하좌우 한 명 공격 (적 · 상대 성), 또는 1칸 전진
			_strike_targets(p, me, out)
			var n: Vector2i = p + FWD[me]
			if is_free(n) and not has_wall(p, n) and not out.has(n):
				out[n] = "advance"
		Step.REAP:
			_curse_targets(p, me, out)
			for k2 in KINDS:
				var e := (1 - me) * KINDS + k2
				if cursed_by[e] < 0:
					continue
				if alive(e):
					if _target(e, me) and form_of(e) != Kind.ANGEL:
						out[pos[e]] = "doom"
				elif has_ghost(e):
					out[ghost_pos[e]] = "doom"
		Step.LAND:
			# 천사: 내려앉은 영웅의 상하좌우 적 한 명 공격(공격한 뒤 이동 전 자리로 돌아감), 또는 그냥 돌아감
			_strike_targets(p, me, out)
			out[act_from] = "return"
			return out
		Step.EXIT:
			for d in DIRS4:
				if is_free(p + d):
					out[p + d] = "move"
			return out
		Step.WALL:
			for d in DIRS4:
				var n: Vector2i = p + d
				if in_bounds(n) and not has_wall(p, n):
					out[n] = "wall"
	# 로봇 · 건축가 · 닌자가 아니면 능력 단계에서 상하좌우에 붙은 상대 성을 칠 수 있음
	if step != Step.MOVE and _can_siege(a):
		_siege_targets(p, me, out)
	return out


## 상하좌우에 붙은 상대 성 (적군의 벽이 막고 있으면 X)
func _siege_targets(p: Vector2i, me: int, out: Dictionary) -> void:
	if manh(p, CASTLE[1 - me]) == 1 and not _hit_stopped(p, CASTLE[1 - me], me):
		out[CASTLE[1 - me]] = "castle"


## 기사: 움직인 방향의 다음 칸 공격(제자리에 있었으면 없음). 흑기사: 주위 8칸의 적 모두(sweep, 어느 적을 눌러도 같음)
func _knight_targets(a: int, me: int, out: Dictionary) -> void:
	var p: Vector2i = pos[a]
	if dark[a] != 0:
		for d in DIRS8:
			if _target(at(p + d), me) and not _hit_stopped(p, p + d, me):
				out[p + d] = "sweep"
	elif act_dir != Vector2i.ZERO:
		_strike_dirs(p, me, [act_dir], out)


## me 의 공격이 칸 c 에서 바로 옆(대각선이면 늘 됨) 칸 n 에 못 닿는지 (적군의 벽)
func _hit_stopped(c: Vector2i, n: Vector2i, me: int) -> bool:
	return (c.x == n.x or c.y == n.y) and wall_owner(c, n) == 1 - me


## me 의 파이어볼 · 저주가 칸 c 에서 옆 칸 n 으로 못 가는지 (적군의 벽, 누구의 포탑이든)
func _shot_stopped(c: Vector2i, n: Vector2i, me: int) -> bool:
	return wall_owner(c, n) == 1 - me or turret_at(n) >= 0


## 사신의 저주: 상하좌우로 2칸 안에서 처음 만나는 적이나 적 유령 (아군 · 로봇 · 적 사신 · 성 · 적군의 벽 · 모든 포탑에 막힘. 이미 저주 걸린 적 · 배리어가 있는 적 · 사신은 못 고름)
func _curse_targets(p: Vector2i, me: int, out: Dictionary) -> void:
	for f in DIRS4:
		var c := p
		for i in CURSE_RANGE:
			var n: Vector2i = c + f
			if not in_bounds(n) or is_castle(n) or _shot_stopped(c, n, me):
				break
			var o := at(n)
			if o >= 0:
				if _target(o, me) and cursed_by[o] < 0 and barrier[o] == 0 and dark[o] == 0 and not curse_proof(form_of(o)):
					out[n] = "curse"
				break
			var g := ghost_of(n, 1 - me)
			if g >= 0:
				if cursed_by[g] < 0:
					out[n] = "curse"   # 적 유령에게도 걸 수 있고, 적 유령이 저주를 막음
				break
			c = n


## 상하좌우 공격 (병사 · 전사 · 성직자 · 내려앉은 천사)
func _strike_targets(p: Vector2i, me: int, out: Dictionary) -> void:
	_strike_dirs(p, me, DIRS4, out)


## 정해진 방향의 바로 옆 칸 공격: 적 · 맞닿은 상대 성 (적군의 벽에 막힘)
func _strike_dirs(p: Vector2i, me: int, dirs: Array, out: Dictionary) -> void:
	for d in dirs:
		var n: Vector2i = p + d
		if not in_bounds(n) or _hit_stopped(p, n, me):
			continue
		if n == CASTLE[1 - me]:
			out[n] = "castle"
		elif _target(at(n), me):
			out[n] = "attack"


## 마법사의 파이어볼: 방향마다 reach 칸 안에서 처음 만나는 적 · 상대 성 (관통 X: 아군 · 로봇 · 적군의 벽 · 모든 포탑에 막힘)
func _ball_targets(p: Vector2i, me: int, reach: int, out: Dictionary) -> void:
	for f in DIRS4:
		var c := p
		for i in reach:
			var n: Vector2i = c + f
			if not in_bounds(n) or n == CASTLE[me] or _shot_stopped(c, n, me):
				break
			if n == CASTLE[1 - me]:
				out[n] = "castle"
				break
			var o := at(n)
			if _target(o, me):
				out[n] = "fire"
				break
			if o >= 0:
				break
			c = n


## 기사가 이동한 뒤 옮길 수 있는 아군 { 아군: [지금 칸, …, 도착 칸] } (유령 X)
##  상하좌우의 아군은 기사를 넘어 반대편 칸으로, 이동 전 자리 바로 뒤(내 성 쪽 칸)의 아군은 기사와 똑같이 이동
func carry_moves(a: int) -> Dictionary:
	var out := {}
	if act_from == NONE or not alive(a):
		return out
	var me := owner_of(a)
	var here: Vector2i = pos[a]
	for d: Vector2i in DIRS4:
		var b := at(here + d)
		if b >= 0 and b != a and owner_of(b) == me and is_free(here - d) and not has_wall(here, here + d) and not has_wall(here, here - d):
			out[b] = [here + d, here - d]
	var gone := here - act_from
	if gone == Vector2i.ZERO:
		return out
	var dir := Vector2i(signi(gone.x), signi(gone.y))
	var c: Vector2i = act_from + (Vector2i.DOWN if me == 0 else Vector2i.UP)
	var b := at(c)
	if b < 0 or b == a or owner_of(b) != me:
		return out
	var path: Array = [c]
	for i in maxi(absi(gone.x), absi(gone.y)):
		var n: Vector2i = c + dir
		if not is_open(n) or has_wall(c, n):
			return out
		path.append(n)
		c = n
	if is_free(c):
		out[b] = path
	return out


## 로봇이 밀어낼 수 있는 적(움직인 방향의 다음 칸)과 밀려날 칸 [[영웅, 칸]] (밀려나는 길의 벽에 막힘). 자리가 없는 적은 칸 = NONE (밀리지 않고 스턴만)
func push_moves(a: int) -> Array:
	if act_dir == Vector2i.ZERO:
		return []
	var n: Vector2i = pos[a] + act_dir
	var o := at(n)
	if o < 0 or owner_of(o) == owner_of(a):
		return []
	var dest: Vector2i = n + act_dir
	if is_free(dest) and not has_wall(n, dest):
		return [[o, dest]]
	return [[o, NONE]] if stunned[o] == 0 else []


## 로봇이 끌어당길 수 있는 영웅(상하좌우로 한 칸 띄워진 적 · 아군)과 끌려올 칸 [[영웅, 칸], …] (사이 칸이 빈칸이고 끌려오는 길에 벽이 없을 때)
func pull_moves(a: int) -> Array:
	var out: Array = []
	var p: Vector2i = pos[a]
	for d in DIRS4:
		var mid: Vector2i = p + d
		var n: Vector2i = mid + d
		var o := at(n)
		if o >= 0 and o != a and is_free(mid) and not has_wall(n, mid):
			out.append([o, mid])
	return out


## 닌자가 따라 할 수 있는 영웅: 앞 · 뒤 세로줄에서 각각 처음 만나는 영웅 (적 사신 · 적 닌자 X)
func ninja_sources(a: int) -> Array[int]:
	var out: Array[int] = []
	var f: Vector2i = FWD[owner_of(a)]
	for dir in [f, -f]:
		var c: Vector2i = pos[a] + dir
		while in_bounds(c):
			var o := at(c)
			if o >= 0:
				if owner_of(o) == owner_of(a) or (kind_of(o) != Kind.NINJA and not _reaper_like(o)):
					out.append(o)
				break
			c += dir
	return out


# ══════════════════════════════════════════════════════
#  행동하기
# ══════════════════════════════════════════════════════
func begin_action(id: int) -> bool:
	if not can_act(id):
		return false
	act_hero = id
	act_kind = kind_of(id)
	act_copy = -1
	act_started = false
	act_optional = false
	act_dir = Vector2i.ZERO
	act_ghost = not alive(id)
	if act_ghost:
		act_step = Step.SPIRIT
		act_from = ghost_pos[id]
	else:
		act_step = Step.SWAP_FIRE if act_kind == Kind.MAGICIAN else Step.MOVE
		act_from = pos[id]
	return true


## 아직 한 단계도 안 했으면 고른 영웅 취소
func cancel_action() -> bool:
	if act_hero < 0 or act_started:
		return false
	_clear_act()
	return true


## 능력 안 쓰고 끝내기 (건너뛸 수 있는 단계일 때만)
func stop_action() -> Array:
	_ev = []
	if act_hero >= 0 and act_optional:
		_done()
	return _ev


## 한 단계 고르기. 일어난 일 목록을 돌려줌
func choose(c: Vector2i) -> Array:
	_ev = []
	if phase != Phase.ACT or over or act_hero < 0:
		return _ev
	var opts := step_options()
	if not opts.has(c):
		return _ev
	var a := act_hero
	var me := owner_of(a)
	var mark: String = opts[c]
	c = real_cell(c)
	act_started = true
	match act_step:
		Step.MOVE:
			if mark == "copy":
				_start_copy(a, at(c))
			else:
				_do_move(a, c)
		Step.CARRY:
			if mark == "carry":
				var b := at(c)
				var path: Array = carry_moves(a)[b]
				_relocate(b, path[-1])
				_log({"t": "move", "id": b, "from": c, "to": path[-1], "style": -1, "ride": a, "path": path})
				_arrive(b)
			else:
				_strike(a, c, mark)
			_done()   # 아군 옮기기와 공격 중 하나만
		Step.STRIKE:
			_strike(a, c, mark)
			_done()
		Step.MINE:
			# 지뢰 놓기(표시된 칸 어디를 눌러도 상하좌우 빈칸 모두) 또는 상하좌우 공격 (둘 중 하나)
			if mark == "mine" or mark == "mine_off":
				_lay_mines(a)
			else:
				_strike(a, c, mark)
			_done()
		Step.SPIRIT:
			var gfrom: Vector2i = ghost_pos[a]
			_set_ghost(a, c)
			_log({"t": "ghost_move", "id": a, "from": gfrom, "to": c, "path": [gfrom, c]})
			_done()
		Step.REVIVE:
			if mark == "rise":
				_revive(ghost_of(pos[a], me), c, a)
			else:
				_strike(a, c, mark)
			_done()
		Step.SWAP_FIRE:
			if mark == "swap" or mark == "warp":
				if mark == "swap":
					_do_swap(a, at(c))
				else:
					_swap_ghost(a, c)
				_next(Step.SEAL)   # 옮긴 자리 주위의 적 봉인 (안 해도 됨)
				return _ev
			_strike(a, c, mark)
			_done()
		Step.SEAL:
			var sv := at(c)
			sealed[sv] = 1
			_log({"t": "seal", "by": a, "id": sv, "from": pos[a], "cell": c})
			_done()
		Step.BARRIER:
			if mark == "exorcise":
				# 십자가에 맞은 적 유령은 사라짐
				_log({"t": "holy", "by": a, "from": pos[a], "cell": c})
				_remove_ghost(ghost_of(c, 1 - me), a)
			elif mark == "rise":
				_sacrifice(a)
			elif mark != "barrier":
				_strike(a, c, mark)
			else:
				var b2 := at(c)
				var old: Array = []
				for id in heroes_of(me):   # 한 편에 하나: 있던 배리어는 사라짐
					if barrier[id] != 0:
						barrier[id] = 0
						old.append(id)
				if not old.is_empty():
					_log({"t": "barrier_off", "ids": old})
				barrier[b2] = 1
				_log({"t": "barrier", "id": b2, "by": a})
				if cursed_by[b2] >= 0:
					cursed_by[b2] = -1
					_log({"t": "uncurse", "ids": [b2]})
			_done()
		Step.PUSH:
			if mark == "turret" or mark == "break":
				_strike(a, c, mark)
			elif mark == "pull":
				_do_pull(a, c)
			else:
				_do_push(a, c)
			_done()
		Step.WARRIOR:
			# 공격 또는 1칸 전진 (주위 8칸 무력은 패시브)
			if mark == "advance":
				var start: Vector2i = pos[a]
				_relocate(a, c)
				_log({"t": "move", "id": a, "from": start, "to": c, "style": Kind.WARRIOR, "path": [start, c]})
				_arrive(a)
			else:
				_strike(a, c, mark)
			_done()
		Step.REAP:
			if mark == "curse":
				_curse(a, at(c) if at(c) >= 0 else ghost_at(c))
			elif mark == "doom":
				_doom(a, at(c) if at(c) >= 0 else ghost_at(c))
			else:
				_strike(a, c, mark)
			_done()
		Step.WALL:
			_build_wall(a, c)
		Step.LAND:
			if mark != "return":
				_strike(a, c, mark)
			if not over:
				_go_back(a)
			_done()
		Step.EXIT:
			# 포탑이 된 칸에서 건축가가 나옴
			var from_x: Vector2i = pos[a]
			_relocate(a, c)
			_log({"t": "move", "id": a, "from": from_x, "to": c, "style": Kind.ARCHITECT, "path": [from_x, c]})
			_arrive(a)
			_done()
	return _ev


## 건축가: 자기 칸과 c 사이에 벽. 칸의 네 변이 모두 아군 벽이면 포탑 (건축가 자기 칸이면 포탑 옆 빈칸으로 나오고, c 에 있던 영웅은 쓰러짐)
func _build_wall(a: int, c: Vector2i) -> void:
	var me := owner_of(a)
	var p: Vector2i = pos[a]
	_set_wall(p, c, me)
	_log({"t": "wall", "a": p, "b": c, "on": true, "by": a})
	var other := _house_ready(c, me)
	var mine_cell := false
	if _house_ready(p, me):
		# 건축가가 나올 빈칸이 있어야 함 (함께 포탑이 되는 옆 칸 제외)
		for d in DIRS4:
			var n: Vector2i = p + d
			if is_free(n) and not (other and n == c):
				mine_cell = true
				break
	var made: Array[Vector2i] = []
	if mine_cell:
		made.append(p)
	if other:
		made.append(c)
	if other and at(c) >= 0:
		_kill(at(c), "house", false)   # 안에 있던 다른 영웅은 배리어 · 로봇 · 사신과 상관없이 쓰러짐
	for x in made:
		turret[_i(x)] = me + 1
		mines[_i(x)] = 0
		for d in DIRS4:
			_set_wall(x, x + d, me)   # 네 벽은 포탑의 일부
		_log({"t": "turret", "cell": x, "p": me, "by": a})
		var cp := cross_at(x)
		if cp >= 0:   # 십자가가 있던 칸: 십자가도 사라짐 (그 천사는 부활 못 함)
			cross[cp] = -1
			_log({"t": "cross_gone", "p": cp, "cell": x, "by": a})
	# 생기자마자 주위 8칸의 적 공격
	for x in made:
		if over:
			break
		_turret_fire(x)
	_update_disabled()
	if mine_cell and alive(a) and not over:
		act_step = Step.EXIT
		act_optional = false
		if not step_options().is_empty():
			return
	_done()


## 포탑의 자동 공격: 방금 멈춘 영웅을 주위 8칸의 적 포탑이 공격
func _turrets_around(id: int) -> void:
	for d in DIRS8:
		if not alive(id):
			return
		var t: Vector2i = pos[id] + d
		if turret_at(t) >= 0:
			_turret_hit(t, id)


## 포탑 하나가 주위 8칸의 적을 공격 (로봇 · 유령은 안 맞음, 배리어는 뚫음)
func _turret_fire(t: Vector2i) -> void:
	var tp := turret_at(t)
	if tp < 0:
		return
	for d in DIRS8:
		var n: Vector2i = t + d
		var v := at(n)
		if v >= 0:
			_turret_hit(t, v)


func _turret_hit(t: Vector2i, v: int) -> void:
	var tp := turret_at(t)
	if tp < 0 or owner_of(v) == tp or _immune(v):
		return
	_log({"t": "turret_fire", "cell": t, "target": pos[v], "id": v, "p": tp})
	_hurt(v, "turret")


## 천사: 영웅 칸에서 이동 전 자리로 돌아감
func _go_back(a: int) -> void:
	var from: Vector2i = pos[a]
	_relocate(a, act_from)
	_log({"t": "home", "id": a, "from": from, "to": act_from, "by": a})
	_arrive(a)


## 천사: 내려앉은 영웅의 상하좌우를 공격하거나 그냥 돌아가는 단계 (꼭 돌아가야 함)
func _land_step() -> void:
	act_step = Step.LAND
	act_optional = false


## 사신: 적이나 적 유령 v 에게 저주 걸기 (말 탄 기사는 저주에 걸리지 않고 흑기사로 변신)
func _curse(a: int, v: int) -> void:
	var c: Vector2i = pos[v] if alive(v) else ghost_pos[v]
	_log({"t": "curse", "by": a, "id": v, "from": pos[a], "cell": c})
	var lifted: Array = []   # 이미 걸려 있던 저주는 풀림 (한 편에 하나)
	for k in KINDS:
		var e := owner_of(v) * KINDS + k
		if cursed_by[e] >= 0:
			cursed_by[e] = -1
			lifted.append(e)
	if not lifted.is_empty():
		_log({"t": "uncurse", "ids": lifted})
	if horse[v] != 0:
		_darken(v)
		return
	cursed_by[v] = a
	_log({"t": "cursed", "id": v, "cell": c})


## 사신: 저주가 걸린 적이나 적 유령의 자리로 이동하며 흔적도 없이 없앰 (유령도 안 남음)
func _doom(a: int, v: int) -> void:
	var c: Vector2i = pos[v] if alive(v) else ghost_pos[v]
	_log({"t": "doom", "by": a, "victim": v, "from": pos[a], "to": c})
	if alive(v):
		_kill(v, "curse", false)
	else:
		_remove_ghost(v, a)
	_relocate(a, c)
	_arrive(a)


## 차례 시작: 그 사람의 닌자는 닌자로 돌아오고, 사신은 대각선의 적을 공격. 그 뒤에 방금 차례가 끝난 사람의 봉인 · 스턴이 풀림
func _turn_start(p: int) -> void:
	if ninja_form[p] >= 0:
		ninja_form[p] = -1
		var nid := p * KINDS + Kind.NINJA
		horse[nid] = 0
		dark[nid] = 0
		if alive(nid):
			_log({"t": "ninja_back", "id": nid, "cell": pos[nid]})
	var faded: Array = []
	for id in heroes_of(1 - p):
		if dark[id] != 0:
			dark[id] = 0   # 흑기사는 그 편의 차례가 한 번 끝나면 돌아옴 (사신 대각선에 남아 있으면 바로 다시 변신)
			faded.append(id)
	if not faded.is_empty():
		_log({"t": "dark_off", "ids": faded})
	_update_disabled()
	_reap_around()   # 차례가 바뀔 때마다 사신의 대각선에 남아 있는 적을 공격 (배리어가 있으면 안 맞음)
	_update_disabled()
	var unsealed: Array = []
	for id in heroes_of(1 - p):
		if sealed[id] != 0:
			sealed[id] = 0   # 봉인된 편의 차례가 끝나면 풀림
			unsealed.append(id)
	if not unsealed.is_empty():
		_log({"t": "seal_off", "ids": unsealed})
	var woke: Array = []
	for id in heroes_of(1 - p):
		if stunned[id] != 0:
			stunned[id] = 0
			woke.append(id)
	if not woke.is_empty():
		_log({"t": "stun_off", "ids": woke})


## 성의 능력(행동 1개와 하트 1개): 불러올 수 있는 내 영웅 (판 위에 살아 있는 영웅, 로봇 제외)
func summon_ids() -> Array[int]:
	var out: Array[int] = []
	if phase != Phase.ACT or over or used >= MAX_ACTIONS or act_hero >= 0:
		return out
	return _summonable(current)


func _summonable(p: int) -> Array[int]:
	var out: Array[int] = []
	if lives[p] < SUMMON_LIVES:
		return out
	for id in heroes_of(p):
		if can_summon_kind(kind_of(id)):
			out.append(id)
	return out


## 소환한 영웅이 나타날 수 있는 칸: 내 성 주위 5칸 중 빈칸 (적 지뢰 칸 제외)
func summon_cells() -> Array[Vector2i]:
	return castle_ring_cells(current)


func do_summon(id: int, c: Vector2i) -> Array:
	_ev = []
	if not summon_ids().has(id) or not summon_cells().has(c):
		return _ev
	var from: Vector2i = pos[id]
	lives[current] -= 1
	_relocate(id, c)
	_log({"t": "summon", "id": id, "from": from, "cell": c, "p": current, "left": lives[current]})
	_arrive(id)
	used += 1
	_update_disabled()
	if not over and _turn_spent():
		_end_turn()
	return _ev


## 영웅 한 명만 쓰고 차례 끝내기 (차례가 바뀌며 생긴 일 – 포탑 공격 등 – 은 last_events())
func end_turn() -> bool:
	_ev = []
	if phase != Phase.ACT or over or act_hero >= 0 or used == 0:
		return false
	_end_turn()
	return true


## 아무것도 안 하고 차례 넘기기 (AI 계획이 어긋났을 때 멈추지 않게)
func pass_turn() -> void:
	_ev = []
	if phase == Phase.ACT and not over:
		_clear_act()
		_end_turn()


## 마지막으로 한 일(end_turn · pass_turn 포함)에서 일어난 일 목록
func last_events() -> Array:
	return _ev


# ── 단계별 처리 ───────────────────────────────────────
func _do_move(a: int, c: Vector2i) -> void:
	var from: Vector2i = pos[a]
	var k := act_kind   # 닌자가 따라 할 때는 따라 한 영웅의 이동
	act_from = from
	if c != from:
		var paths := move_paths(a, k)
		var path: Array = paths[c] if paths.has(c) else [from, c]
		if k == Kind.KNIGHT or k == Kind.ROBOT:
			act_dir = Vector2i(signi(c.x - from.x), signi(c.y - from.y))
		var o := at(c)
		if o >= 0:
			# 천사가 영웅 칸에 내려앉음 (잠시 둘이 함께 있음 – 칸의 주인은 원래 있던 영웅)
			if grid[_i(from)] == a:
				grid[_i(from)] = -1
			pos[a] = c
			_log({"t": "move", "id": a, "from": from, "to": c, "style": k, "path": path})
			if _step_mine(a):   # 내려앉은 것도 멈춘 것 (지뢰 · 사신 · 포탑)
				_reap_landing(a)
			if alive(a):
				_turrets_around(a)
			_update_disabled()
			if over or not alive(a):
				_done()
			else:
				_land_step()
			return
		else:
			_relocate(a, c)
			_log({"t": "move", "id": a, "from": from, "to": c, "style": k, "path": path})
			_arrive(a)
	_after_move(a)


func _after_move(a: int) -> void:
	if over or not alive(a):
		_done()
		return
	var k := act_kind
	if k == Kind.NINJA:
		_done()   # 닌자의 이동에는 능력이 없음
		return
	if k == Kind.ANGEL:
		var g := ghost_at(pos[a])
		if g >= 0 and owner_of(g) != owner_of(a):
			_remove_ghost(g, a)
		elif g >= 0:
			act_step = Step.REVIVE   # 아군 유령 칸: 꼭 부활시킴
			act_optional = false
			if step_options().is_empty():
				_done()
			return
	if k == Kind.KNIGHT and not carry_moves(a).is_empty():
		_next(Step.CARRY)
		return
	_next(ability_step(k))


## 닌자: 앞 줄 영웅(src)을 따라 함 → 그 영웅의 이동(마법사는 없음) → 그 영웅의 능력
func _start_copy(a: int, src: int) -> void:
	act_copy = src
	act_kind = form_of(src)
	var me := owner_of(a)
	horse[a] = horse[src] if act_kind == Kind.KNIGHT else 0
	dark[a] = dark[src] if act_kind == Kind.KNIGHT else 0
	ninja_form[me] = act_kind   # 다음 내 차례가 시작될 때까지 이 모습
	_update_disabled()
	_log({"t": "copy", "id": a, "src": src})
	if act_kind == Kind.REAPER:
		_reap_around(a, true)   # 사신 모습이 된 순간 대각선에 있는 적
	if act_kind == Kind.MAGICIAN:
		act_from = pos[a]
		_next(Step.SWAP_FIRE)
		return
	act_step = Step.MOVE
	act_optional = false


## 포탑 부수기: 네 벽이 한꺼번에 깨지고 포탑도 없어짐 (a = 부순 영웅)
func _break_turret(c: Vector2i, a: int) -> void:
	var tp := turret_at(c)
	turret[_i(c)] = 0
	for d in DIRS4:
		if turret_at(c + d) < 0:   # 옆 포탑과 함께 쓰던 벽은 남음
			_set_wall(c, c + d, -1)
	_log({"t": "turret_gone", "cell": c, "p": tp, "by": a, "style": act_kind, "from": pos[a]})


## 공격 하나: castle = 성 목숨 -1, break = 벽 부수기(로봇), turret = 포탑 부수기(로봇), 나머지 = 그 칸의 적 공격
func _strike(a: int, c: Vector2i, mark: String) -> void:
	var me := owner_of(a)
	var from: Vector2i = pos[a]
	match mark:
		"castle":
			lives[1 - me] = maxi(0, lives[1 - me] - 1)
			_log({"t": "castle", "by": a, "style": act_kind, "p": 1 - me, "left": lives[1 - me], "from": from, "cell": c})
			if lives[1 - me] <= 0:
				_finish(me, "castle")
		"break":
			_set_wall(from, c, -1)
			_log({"t": "wall", "a": from, "b": c, "on": false, "by": a, "style": act_kind})
		"turret":
			_break_turret(c, a)
		"sweep":
			# 흑기사: 주위 8칸의 적 모두
			_log({"t": "sweep", "by": a, "cell": from})
			for d in DIRS8:
				var sv := at(from + d)
				if _target(sv, me) and not _hit_stopped(from, from + d, me):
					_log({"t": "attack", "by": a, "style": act_kind, "victim": sv, "cell": from + d, "from": from, "sweep": true})
					_hurt(sv, "attack")
		_:
			var v := at(c)
			if v < 0:
				return
			_log({"t": "attack", "by": a, "style": act_kind, "victim": v, "cell": c, "from": from})
			_hurt(v, "attack")


func _do_swap(m: int, b: int) -> void:
	var pm: Vector2i = pos[m]
	var pb: Vector2i = pos[b]
	pos[m] = pb
	pos[b] = pm
	grid[_i(pb)] = m
	grid[_i(pm)] = b
	_log({"t": "swap", "a": m, "b": b, "pa": pm, "pb": pb})
	_arrive(m)
	if alive(b):
		_arrive(b)


## 병사: 상하좌우 빈칸 모두에 지뢰. 적 지뢰가 있는 칸은 지뢰끼리 터져서 지뢰 없는 칸이 되고, 내 지뢰가 있는 칸은 그대로
func _lay_mines(a: int) -> void:
	var me := owner_of(a)
	var cells: Array[Vector2i] = []
	var off: Array[Vector2i] = []
	for d in DIRS4:
		var n: Vector2i = pos[a] + d
		if not is_free(n) or mine_at(n) == me:
			continue
		if mines[_i(n)] == 0:
			mines[_i(n)] = me + 1
			cells.append(n)
		else:
			mines[_i(n)] = 0
			off.append(n)
	_log({"t": "mine", "cells": cells, "off": off, "p": me, "by": a})


## 로봇: 고른 적 한 명(칸 c)을 한 칸 뒤로 밀면서 스턴, 밀 자리가 없으면 스턴만
func _do_push(a: int, c: Vector2i) -> void:
	for m in push_moves(a):
		var v: int = m[0]
		if pos[v] != c:
			continue
		var dest: Vector2i = m[1]
		if dest != NONE:
			_relocate(v, dest)
			_log({"t": "push", "id": v, "from": c, "to": dest, "by": a})
			_arrive(v)
		if alive(v):
			stunned[v] = 1   # 1턴 스턴 (자리가 없어 안 밀려도)
			_log({"t": "stun", "id": v, "by": a})
		return


## 로봇: 한 칸 띄워진 영웅(칸 c)을 자기 쪽으로 한 칸 끌어당김
func _do_pull(a: int, c: Vector2i) -> void:
	for m in pull_moves(a):
		var v: int = m[0]
		if pos[v] != c:
			continue
		_relocate(v, m[1])
		_log({"t": "pull", "id": v, "from": c, "to": m[1], "by": a})
		_arrive(v)
		return


## 어떤 영웅이 새 칸에 멈췄을 때: 말 없는 기사가 내 성 주위면 말이 생김 → 적 지뢰 (로봇은 지뢰를 없앰)
## → 사신(또는 사신 모습의 닌자)과 적이 대각선에 놓였으면 사신의 자동 공격 → 전사 주위 8칸이면 바로 무력
func _arrive(id: int) -> void:
	var c: Vector2i = pos[id]
	var i := _i(c)
	if horse[id] == 0 and form_of(id) == Kind.KNIGHT and cheb(c, CASTLE[owner_of(id)]) == 1:
		horse[id] = 1
		_log({"t": "horse_on", "id": id, "cell": c})
	if mines[i] != 0 and _immune(id):
		mines[i] = 0   # 로봇은 자기 칸의 지뢰를 누구 것이든 없앰
		_log({"t": "defuse", "cell": c, "id": id})
	elif not _step_mine(id):
		_update_disabled()
		return
	_reap_around(id)
	_turrets_around(id)
	_update_disabled()


## 멈춘 칸의 적 지뢰에 맞음 (쓰러지면 false)
func _step_mine(id: int) -> bool:
	var i := _i(pos[id])
	if mines[i] == 0 or mines[i] - 1 == owner_of(id):
		return true
	mines[i] = 0
	_log({"t": "boom", "cell": pos[id], "id": id})
	return _hurt(id, "mine")


## 마법사: 아군 유령(칸 c)과 자리 바꾸기
func _swap_ghost(a: int, c: Vector2i) -> void:
	var g := ghost_of(c, owner_of(a))
	var from: Vector2i = pos[a]
	_set_ghost(g, from)
	_relocate(a, c)
	_log({"t": "warp", "id": a, "from": from, "to": c, "ghost": g})
	_arrive(a)


## 사신의 자동 공격: 대각선 4칸에 있는 적을 공격 (벽과 상관없음, 로봇 · 성 · 배리어가 있는 적은 X, 말 탄 기사는 흑기사로 변신). 여럿이면 동시에
## only >= 0 이면 그 영웅이 사신이거나 맞는 쪽인 것만 (방금 멈춘 영웅), -1 이면 판 전체 (차례가 바뀔 때)
## form = true 면 그 영웅이 사신인 것만 (닌자가 사신 모습이 된 순간 – 멈춘 게 아니라 맞지는 않음)
func _reap_around(only: int = -1, form: bool = false) -> void:
	var hits: Array = []   # [사신, [맞는 영웅들], [칸들]]
	var riders: Array = []
	for p in 2:
		for r in _reapers_of(p):
			var victims: Array = []
			var cells: Array = []
			for d in DIAG:
				var n: Vector2i = pos[r] + d
				var v := at(n)
				if _target(v, p) and (only < 0 or only == r or (only == v and not form)):
					if barrier[v] != 0:
						_log({"t": "guard", "id": v, "cell": n, "by": r})   # 배리어가 자동 공격을 막음 (안 깨짐)
						continue
					if horse[v] != 0:
						riders.append(v)   # 말 탄 기사는 안 다치고 흑기사로 변신
						continue
					victims.append(v)
					cells.append(n)
			if not victims.is_empty():
				hits.append([r, victims, cells])
	for h in hits:
		_log({"t": "reap", "by": h[0], "at": pos[h[0]], "victims": h[1], "cells": h[2]})
	for h in hits:
		for v in h[1]:
			_hurt(v, "aura")
	for v in riders:
		if alive(v):
			_darken(v)


## 흑기사로 변신 (걸려 있던 저주는 풀림)
func _darken(v: int) -> void:
	if dark[v] == 0:
		dark[v] = 1
		_log({"t": "dark", "id": v, "cell": pos[v]})
	if cursed_by[v] >= 0:
		cursed_by[v] = -1
		_log({"t": "uncurse", "ids": [v]})


## 영웅 칸에 내려앉은 천사가 적 사신의 대각선에 있으면 자동 공격받음
func _reap_landing(a: int) -> void:
	for r in _reapers_of(1 - owner_of(a)):
		var d: Vector2i = pos[a] - pos[r]
		if absi(d.x) == 1 and absi(d.y) == 1:
			if barrier[a] != 0:
				_log({"t": "guard", "id": a, "cell": pos[a], "by": r})
				continue
			_log({"t": "reap", "by": r, "at": pos[r], "victims": [a], "cells": [pos[a]]})
			if not _hurt(a, "aura"):
				return


## 그 편의 사신과, 사신 모습을 따라 한 닌자 (사신에게는 무력이 안 통함)
func _reapers_of(p: int) -> Array[int]:
	var out: Array[int] = []
	var r := p * KINDS + Kind.REAPER
	if alive(r):
		out.append(r)
	var n := p * KINDS + Kind.NINJA
	if alive(n) and ninja_form[p] == Kind.REAPER:
		out.append(n)
	return out


func _remove_ghost(g: int, by: int) -> void:
	var c: Vector2i = ghost_pos[g]
	_set_ghost(g, NONE)
	cursed_by[g] = -1
	_log({"t": "ghost_gone", "id": g, "cell": c, "by": by})


## 성직자(성직자 모습 닌자)가 자신을 희생해(유령은 남음) 쓰러진 천사를 십자가 자리에서 부활시킴
func _sacrifice(a: int) -> void:
	var me := owner_of(a)
	var an := me * KINDS + Kind.ANGEL
	var c := cross_cell(me)
	_log({"t": "sacrifice", "id": a, "cell": pos[a], "angel": an, "cross": c})
	_kill(a, "sacrifice")
	cross[me] = -1
	_place(an, c)
	_log({"t": "revive", "id": an, "cell": c, "by": a, "cross": me})
	_arrive(an)


## 천사가 유령 g 를 칸 c 에 부활시킴
func _revive(g: int, c: Vector2i, by: int) -> void:
	_set_ghost(g, NONE)
	cursed_by[g] = -1
	_place(g, c)
	_log({"t": "revive", "id": g, "cell": c, "by": by})
	_arrive(g)


## 피해: 로봇은 무시, 배리어는 한 번 막고 깨짐(포탑은 배리어를 뚫음), 말을 탄 기사는 말이 대신 죽음(포탑에는 바로 쓰러짐). 살아남으면 true
func _hurt(id: int, cause: String) -> bool:
	if not alive(id) or _immune(id):
		return true
	if barrier[id] != 0 and cause != "turret":
		barrier[id] = 0
		_log({"t": "shield", "id": id, "cell": pos[id], "cause": cause})
		return true
	if horse[id] != 0 and form_of(id) == Kind.KNIGHT and cause != "turret":
		horse[id] = 0
		_log({"t": "horse_off", "id": id, "cell": pos[id], "cause": cause})
		return true
	_kill(id, cause)
	return false


## ghost = false 면 유령도 십자가도 안 생김 (포탑에 갇히거나 저주로 쓰러짐, 부활 못 함)
func _kill(id: int, cause: String, ghost: bool = true) -> void:
	var c: Vector2i = pos[id]
	var curse: int = cursed_by[id]
	_log({"t": "die", "id": id, "cell": c, "cause": cause})
	_leave(id)
	deaths += 1
	if ghost and kind_of(id) == Kind.ANGEL:   # 천사는 유령 대신 십자가
		var to := _ghost_cell(c, owner_of(id), true)
		if to != NONE:
			cross[owner_of(id)] = _i(to)
			_log({"t": "cross", "p": owner_of(id), "cell": to})
	elif ghost:
		_rise_ghost(id, c)
		if has_ghost(id):
			cursed_by[id] = curse   # 저주는 유령에게 남음


## 영웅이 판에서 빠짐 (상태도 모두 사라짐)
func _leave(id: int) -> void:
	var c: Vector2i = pos[id]
	if grid[_i(c)] == id:
		grid[_i(c)] = -1
	pos[id] = NONE
	barrier[id] = 0
	disabled_by[id] = -1
	sealed[id] = 0
	cursed_by[id] = -1
	horse[id] = 0
	dark[id] = 0
	stunned[id] = 0
	var was_reaper := form_of(id) == Kind.REAPER
	if kind_of(id) == Kind.NINJA:
		ninja_form[owner_of(id)] = -1
	# 사신(사신 모습의 닌자)이 쓰러지면 적에게 걸린 모든 저주가 사라짐
	if was_reaper:
		var lifted: Array = []
		for k in KINDS:
			var e := (1 - owner_of(id)) * KINDS + k   # 유령에게 걸린 것도
			if cursed_by[e] >= 0:
				cursed_by[e] = -1
				lifted.append(e)
		if not lifted.is_empty():
			_log({"t": "uncurse", "ids": lifted})


## 칸 c 에서 쓰러진 영웅의 유령이 생김 (겹치면 가장 가까운 빈칸에)
func _rise_ghost(id: int, c: Vector2i) -> void:
	var to := _ghost_cell(c, owner_of(id))
	if to == NONE:
		return
	_set_ghost(id, to)
	_log({"t": "ghost", "id": id, "cell": to})


## 그 편 전사(전사 모습의 닌자 포함)들이 선 칸
func _aura_cells(p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var w := p * KINDS + Kind.WARRIOR
	if alive(w):
		out.append(pos[w])
	var n := p * KINDS + Kind.NINJA
	if ninja_form[p] == Kind.WARRIOR and alive(n):
		out.append(pos[n])
	return out


## 칸 c 가 전사 주위 8칸 안인지
static func _in_aura(c: Vector2i, auras: Array[Vector2i]) -> bool:
	for w in auras:
		if cheb(c, w) == 1:
			return true
	return false


## 저주가 안 통하는 모습: 사신 · 천사 (로봇은 공격의 대상도 아님)
static func curse_proof(k: int) -> bool:
	return k == Kind.REAPER or k == Kind.ANGEL


## 전사의 무력이 안 통하는 모습: 로봇 · 천사 · 전사(전사끼리는 서로 안 통함 – 사용자 결정)
static func aura_proof(k: int) -> bool:
	return k == Kind.ROBOT or k == Kind.WARRIOR or k == Kind.ANGEL


## 전사의 패시브: 주위 8칸의 적은 무력 (자리에서 바로 정해짐). 새로 무력해지거나 풀린 영웅을 알림
func _update_disabled() -> void:
	var freed: Array = []
	for p in 2:
		var foes: Array[int] = []   # 상대 편 전사(전사 모습 닌자)
		var w := (1 - p) * KINDS + Kind.WARRIOR
		if pos[w] != NONE:
			foes.append(w)
		var nj := (1 - p) * KINDS + Kind.NINJA
		if ninja_form[1 - p] == Kind.WARRIOR and pos[nj] != NONE:
			foes.append(nj)
		for k in KINDS:
			var id := p * KINDS + k
			var by := -1
			if pos[id] != NONE and not foes.is_empty() and not aura_proof(form_of(id)):
				for f in foes:
					if cheb(pos[id], pos[f]) == 1:
						by = f
						break
			if by == disabled_by[id]:
				continue
			if by >= 0 and disabled_by[id] < 0:
				_log({"t": "disable", "by": by, "ids": [id]})
			elif by < 0 and pos[id] != NONE:
				freed.append(id)
			disabled_by[id] = by
	if not freed.is_empty():
		_log({"t": "free", "ids": freed})


## 다음 능력 단계 (능력은 안 써도 되므로 건너뛸 수 있음). 고를 게 없으면 끝
func _next(step: int) -> void:
	if over or not alive(act_hero) or step == Step.NONE or disabled_by[act_hero] >= 0 or sealed[act_hero] != 0:
		_done()   # 전사 주위 8칸에 멈췄으면 바로 무력해져 능력을 못 씀 (사용자 결정). 봉인도 이동만 됨
		return
	act_step = step
	act_optional = true
	if step_options().is_empty():
		_done()


## 영웅 행동 하나 끝
func _done() -> void:
	if act_hero >= 0:
		used += 1
		acted |= 1 << act_hero
	_clear_act()
	_update_disabled()
	if over:
		return
	if _turn_spent():
		_end_turn()


## 이번 차례에 더 할 것이 없는지 (행동 2개를 다 썼거나, 움직일 영웅도 성 소환도 없음)
func _turn_spent() -> bool:
	return used >= MAX_ACTIONS or (selectable().is_empty() and (summon_ids().is_empty() or summon_cells().is_empty()))


func _clear_act() -> void:
	act_hero = -1
	act_kind = -1
	act_step = Step.NONE
	act_copy = -1
	act_started = false
	act_optional = false
	act_from = NONE
	act_dir = Vector2i.ZERO
	act_ghost = false


func _log(e: Dictionary) -> void:
	if log_events:
		_ev.append(e)


func _place(id: int, c: Vector2i) -> void:
	pos[id] = c
	grid[_i(c)] = id


func _relocate(id: int, c: Vector2i) -> void:
	var from: Vector2i = pos[id]
	if from != NONE and grid[_i(from)] == id:
		grid[_i(from)] = -1
	_place(id, c)


# ══════════════════════════════════════════════════════
#  차례 · 끝
# ══════════════════════════════════════════════════════
func _has_moves(p: int) -> bool:
	for k in KINDS:
		var id := p * KINDS + k
		if (alive(id) or has_ghost(id)) and _could_act(id):
			return true
	if not _summonable(p).is_empty() and not castle_ring_cells(p).is_empty():
		return true
	return false


func _end_turn() -> void:
	_clear_act()
	used = 0
	acted = 0
	turn += 1
	passed = -1
	collapsed_now = false
	collapse_skipped = false
	if over:
		return
	if _collapse():
		return
	if turn >= MAX_TURNS:
		_finish_by_compare("turns")
		return
	current = 1 - current
	_turn_start(current)
	if not _has_moves(current):
		passed = current
		current = 1 - current
		turn += 1
		_turn_start(current)
		if not _has_moves(current):
			_finish_by_compare("stuck")


func _finish(w: int, reason: String) -> void:
	over = true
	winner = w
	end_reason = reason
	phase = Phase.OVER
	_clear_act()


func _finish_by_compare(reason: String) -> void:
	var w := -1
	if lives[0] != lives[1]:
		w = 0 if lives[0] > lives[1] else 1
	elif count(0) != count(1):
		w = 0 if count(0) > count(1) else 1
	_finish(w, reason)


## 결전을 멈추는 때: 한쪽의 살아 있는 영웅이 3명 이하이고 두 편 영웅 수가 3명 이상 차이 남 (사용자 결정)
func collapse_paused() -> bool:
	var a := count(0)
	var b := count(1)
	return mini(a, b) <= 3 and absi(a - b) >= 3


## 결전: 정해진 차례가 되면 두 성의 목숨이 함께 1 줄어듦 (멈추는 때엔 건너뜀). 게임이 끝나면 true
func _collapse() -> bool:
	if turn < COLLAPSE_START + collapses * COLLAPSE_EVERY:
		return false
	collapses += 1
	if collapse_paused():
		collapse_skipped = true
		return false
	collapsed_now = true
	lives[0] = maxi(0, lives[0] - 1)
	lives[1] = maxi(0, lives[1] - 1)
	if lives[0] == 0 and lives[1] == 0:
		_finish_by_compare("collapse")
		return true
	if lives[0] == 0 or lives[1] == 0:
		_finish(0 if lives[0] > 0 else 1, "collapse")
		return true
	return false


## 다음 결전까지 남은 차례
func turns_to_collapse() -> int:
	return COLLAPSE_START + collapses * COLLAPSE_EVERY - turn
