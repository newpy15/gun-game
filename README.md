# Team Gun Game

**▶ 바로 플레이: https://newpy15.github.io/gun-game/**

# 로블록스 PvP 총게임 (무기 4종)

> 웹 브라우저 버전은 `index.html` 입니다 (아래 "웹 버전" 참고). 로블록스 설치 안내는 그대로 아래에 있어요.

## 웹 버전 (index.html)
- 설치 없이 위 링크에서 바로 플레이하거나, `index.html`을 크롬/엣지로 열면 됩니다 (인터넷 연결 필요: three.js를 CDN에서 불러옴)
- 1인칭 3D 팀 데스매치: RED(나 + 봇 3) vs BLUE(봇 4), 20킬 먼저 달성하면 승리
- 조작: WASD 이동, Shift 달리기, C 앉기(꾹), Space 점프, 좌클릭 발사, 우클릭 조준(줌), R 재장전, 1~4/휠 무기 교체, Tab 점수판, Esc 일시정지, [ ] 감도
- FPS 요소: 마우스 고정, 가속/감속 이동, 조준 줌(스나이퍼 스코프), 탄퍼짐(이동/점프/연사/조준에 따라 변하고 조준선이 벌어짐),
  반동 + 회복, 총기 교체/재장전 모션, 발소리, 방향 있는 피격 표시, 체력 자동 회복, 킬캠, 레이더, 점수판, 탄흔
- 봇: 시야(LOS) 확인, 발견 후 반응 지연, 점사, 무기별 교전 거리, 끼임 탈출
- 멀티플레이는 없고 봇과 대전해요 (온라인 PvP는 별도 서버가 필요)
- 마우스 고정이 안 되는 환경이면 일반 마우스 모드로 전환되고, 방향키로도 시점을 돌릴 수 있어요


## 설치 방법 (Roblox Studio)
1. Roblox Studio → Baseplate 템플릿으로 새 프로젝트 열기
2. **ServerScriptService** 우클릭 → Insert Object → **Script**, 이름 `GunServer`
   → `roblox/ServerScriptService_GunServer.server.lua` 내용 붙여넣기
3. **StarterPlayer > StarterPlayerScripts** 우클릭 → Insert Object → **LocalScript**, 이름 `GunClient`
   → `roblox/StarterPlayerScripts_GunClient.client.lua` 내용 붙여넣기
4. Play(F5)로 테스트. Test 탭 → Clients and Servers에서 2명 이상으로 PvP 확인

## 조작
- 마우스 왼쪽 버튼: 발사 (소총은 누르고 있으면 연사, 나머지는 클릭당 1발)
- R: 재장전
- 1~4 또는 마우스 휠: 무기 교체

## 무기
| 무기 | 데미지 | 특징 |
|---|---|---|
| Pistol | 25 | 12발, 정확, 단발 |
| Rifle | 20 | 30발, 연사 |
| Shotgun | 12 x 8발 | 근거리 강력, 탄퍼짐 큼 |
| Sniper | 90 | 5발, 사거리 1000, 느린 발사 |

헤드샷은 모든 무기 2배 데미지.

## 팀 데스매치
- Red / Blue 두 팀, 접속 시 인원이 적은 팀에 자동 배정
- 아군 사격 없음, 먼저 30킬을 달성한 팀 승리 (`KILL_TARGET`)
- 승리 후 8초 뒤 점수 초기화하고 전원 재스폰 (`ROUND_END_DELAY`)
- 팀 스폰(RedSpawn/BlueSpawn)은 스크립트가 (-50,1,0), (50,1,0)에 자동 생성
  → 맵에 맞게 옮기거나, Workspace에 같은 이름의 SpawnLocation을 직접 두면 그걸 사용
- 스폰 보호 3초, 기존 중립 SpawnLocation은 자동 비활성화

## 킬 피드
- 화면 오른쪽 위에 "킬러 [무기] 희생자" 표시 (이름은 팀 색, 헤드샷은 💀)
- 내가 관련된 킬은 노란 테두리, 최대 5줄, 5초 후 사라짐 (`MAX_FEED`, `FEED_TIME`)

## 발사음 / 반동
- 발사 시 카메라가 위로 튀었다가 부드럽게 복귀 (무기별 `Recoil`, `Kick`, 복귀 속도 `RECOIL_RECOVERY`)
- 내 발사음 + 300 스터드 이내 다른 플레이어의 발사음(3D)
- **발사음은 임시 효과음입니다.** 클라이언트 `FX` 표의 `SoundId`를 `rbxassetid://숫자`로 바꾸세요
  (Creator Store의 Audio에서 "gun shot"을 검색해 사용)

## 무기 수정/추가 방법
- 서버 `WEAPONS` 표에서 수치 수정
- 새 무기는 서버 `WEAPONS`와 클라이언트 `WEAPONS`에 **같은 이름**으로 추가
  (클라이언트 값은 화면 효과용이고, 실제 판정은 서버 값이 기준)
