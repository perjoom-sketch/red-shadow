# 사운드트랙 / Suno 프롬프트 (Red Shadow / 붉은 그림자)

> 게임 OST 제작용 Suno 프롬프트 모음. 모든 곡은 보컬 없음(Instrumental) 기준.
> 분위기 레퍼런스: **Hollow Knight, Ori** — 다크 판타지, 신비롭고 고독하지만 영웅적.
> (전체 무드 기준은 `ART_DIRECTION.md` 참고)

| # | 트랙 | 용도 | 파일명 | 상태 |
|---|------|------|--------|------|
| 1 | 메인 타이틀 | 첫 실행 화면 | `01_main_title.ogg` | 대기 |
| 2 | 붉은 그림자 메인 테마 | 주인공 전용 | `02_red_shadow_theme.ogg` | 대기 |
| 3 | 종탑 도시 | 첫 지역 | `03_tower_city.ogg` | 대기 |
| 4 | 수직 탐험 맵 | 올라가는 맵 | `04_vertical_ascent.ogg` | 대기 |
| 5 | 심연 하강 | 내려가는 맵 | `05_abyss_descent.ogg` | 대기 |
| 6 | AI 몬스터 전투 | 일반 전투 | `06_ai_battle.ogg` | 대기 |
| 7 | 보스전 | 첫 보스 | `07_boss.ogg` | 대기 |
| 8 | 붉은 달 ⭐ | 대표곡 후보 | `08_red_moon.ogg` | 대기 |
| 9 | 엔딩 | 엔딩 크레딧 | `09_ending.ogg` | 대기 |
| - | Blade Thunder | 현재 임시 메인 BGM | `blade_thunder.mp3` | **적용됨** |

---

## 1. 메인 타이틀
게임 실행 첫 화면

```
Dark fantasy adventure theme.
Lonely wandering cat swordsman beneath moonlit towers.
Emotional orchestral soundtrack with cello, piano, soft choir and distant bells.
Mysterious yet heroic atmosphere.
Slow build, cinematic, melancholic but hopeful.
Hollow Knight and Ori inspired mood.
No vocals.
```

## 2. 붉은 그림자 메인 테마
주인공 전용

```
Legendary masked cat swordsman theme.
Flowing red scarf in the wind.
Fast violin, emotional cello, taiko drums, subtle choir.
Mysterious traveler with unknown past.
Heroic but lonely.
Dark fantasy action soundtrack.
Instrumental.
```

## 3. 종탑 도시
첫 지역

```
Ancient tower city at twilight.
Blue fog drifting through rooftops and clock towers.
Gentle piano, music box, distant bells, soft strings.
Peaceful but mysterious.
Exploration focused.
Dark fantasy atmosphere.
No vocals.
```

## 4. 수직 탐험 맵
올라가는 재미

```
Vertical ascent through forgotten towers.
Wind sweeping across rooftops.
Light percussion, strings, soft choir.
Feeling of climbing higher into the unknown.
Adventure, curiosity and freedom.
Instrumental fantasy soundtrack.
```

## 5. 심연 하강
내려가는 맵

```
Descending into an ancient abyss.
Dark ambient fantasy soundtrack.
Deep cello drones, low choir, echoing bells.
Mysterious and unsettling.
Feeling of endless depth.
No vocals.
```

## 6. AI 몬스터 전투
일반 전투

```
Adaptive enemy battle theme.
Fast strings, taiko drums, aggressive cello.
Constant tension and unpredictability.
Dark fantasy action soundtrack.
Hero versus intelligent hunters.
Instrumental.
```

## 7. 보스전
첫 보스

```
Epic dark fantasy boss battle.
Massive orchestra, choir, taiko drums, powerful strings.
A legendary duel beneath a blood moon.
Heroic, intense and dramatic.
Instrumental.
```

## 8. 붉은 달 ⭐ (대표곡 후보)
게임 대표곡으로 밀 만한 트랙

```
Red Moon over a forgotten kingdom.
A mysterious cat swordsman walks alone.
Emotional dark fantasy soundtrack.
Piano, cello, violin, distant choir, bells.
Beautiful, melancholic and unforgettable.
Main theme quality.
No vocals.
```

## 9. 엔딩
엔딩 크레딧

```
The journey is over.
A lone cat swordsman disappears into the horizon.
Emotional orchestral ending theme.
Warm piano, cello, gentle choir.
Bittersweet, peaceful and hopeful.
Dark fantasy ending credits music.
Instrumental.
```

---

## 통합 사용 메모

- **포맷** — Suno 곡은 `.ogg`(루프용) 또는 `.mp3`로 받아 `assets/audio/`에 저장. (현재 `Blade Thunder`는 mp3로 적용됨)
- **루프 처리** — 탐험/전투 곡은 루프 가능하게(.ogg + Import의 Loop 체크). 타이틀·엔딩은 원샷.
- **모티프 통일** — 8번 "붉은 달"의 멜로디를 메인 테마(2번)·타이틀(1번)에 변주로 재사용하면 정체성 강화.
- **연결** — `MusicManager`(Autoload `Music`)에서 `Music.play("키")`로 전환. 트랙 등록은 `scripts/MusicManager.gd`의 `TRACKS`.

*문서 버전: v0.1 — 프롬프트 초안 9곡.*
