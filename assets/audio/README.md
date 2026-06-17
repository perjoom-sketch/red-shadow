# 오디오 폴더 (assets/audio)

게임 음악(BGM)을 여기에 넣는다. Godot이 자동으로 임포트한다.

## 파일 이름 규칙 (MusicManager.gd 의 TRACKS 와 일치해야 자동 재생됨)

| 트랙 키 | 파일 이름 | 용도 |
|---|---|---|
| `title`   | `01_main_title.ogg`        | 메인 타이틀 |
| `theme`   | `02_red_shadow_theme.ogg`  | 주인공 테마 |
| `city`    | `03_tower_city.ogg`        | 종탑 도시 (메인 씬 기본 BGM) |
| `ascent`  | `04_vertical_ascent.ogg`   | 상승 맵 |
| `abyss`   | `05_abyss_descent.ogg`     | 심연 하강 |
| `battle`  | `06_ai_battle.ogg`         | 일반 전투 |
| `boss`    | `07_boss.ogg`              | 보스전 |
| `redmoon` | `08_red_moon.ogg`          | 붉은 달 (대표곡) |
| `ending`  | `09_ending.ogg`            | 엔딩 |

## 사용법

- 지금 메인 씬은 `city` 트랙을 재생하도록 설정됨 → **첫 BGM 파일을 `03_tower_city.ogg` 로 저장**하면 실행 시 바로 울린다.
- 다른 이름이면 `scenes/Main.tscn` 의 `bgm_track` 값만 바꾸면 됨.
- 권장 포맷: `.ogg` (루프 가능). 임포트 후 Import 탭에서 **Loop 체크 → Reimport**.
- 어디서든 호출: `Music.play("city")`, `Music.stop()`, `Music.set_volume_db(-6.0)`.
