#!/usr/bin/env python3
"""
아담 프레임 정규화 스크립트
- 그룹별 배율로 캐릭터 키 ~860px 통일
- 공통 캔버스 848x1264
- 지상 애니: 발 y≈1070 정렬
- 공중 애니(jump_up/fall): 점프 아크 보존 (발 기준선 강제 금지)

사용법: python normalize_adam_frames.py
입력: assets/characters/adam/frames/ (원본)
출력: assets/characters/adam/normalized/ (정규화)
"""

import os
import json
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow 필요: pip install Pillow")
    exit(1)

# 프로젝트 루트 (이 스크립트는 tools/ 에 있음)
PROJECT_ROOT = Path(__file__).parent.parent
FRAMES_DIR = PROJECT_ROOT / "assets" / "characters" / "adam" / "frames"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "characters" / "adam" / "normalized"
ANIM_MAP_PATH = PROJECT_ROOT / "assets" / "characters" / "adam" / "adam_animation_map.json"

# 공통 캔버스 (single 그룹 기준)
TARGET_CANVAS = (848, 1264)
TARGET_STAND_HEIGHT = 860
GROUND_BASELINE_Y = 1070

# 스케일 그룹 정의 (animation_map.json에서 가져옴)
SCALE_GROUPS = {
    "single":   {"scale": 1.0,  "native": (848, 1264)},
    "walk":     {"scale": 1.94, "native": (372, 500)},
    "run":      {"scale": 1.90, "native": (372, 500)},
    "turn":     {"scale": 1.29, "native": (500, 1012)},
    "backstep": {"scale": 1.90, "native": (372, 500)},
}

# 파일명 → 논리 프레임명 매핑 (animation_map.json 기준)
FILENAME_TO_FRAME = {
    # idle (single)
    "1_adam_idle.png": "idle",
    "2_adam_idle_breath.png": "idle_breath",
    # walk (walk) - animation_map uses frame2,3,6,7 but actual files are walk_1~4
    "3_adam_walk_1.png": "walk_frame2",
    "4_adam_walk_2.png": "walk_frame3",
    "5_adam_walk_3.png": "walk_frame6",
    "6_adam_walk_4.png": "walk_frame7",
    # run (run)
    "7_adam_run_1.png": "run_frame1",
    "8_adam_run_2.png": "run_frame2",
    "9_adam_run_3.png": "run_frame3",
    "10_adam_run_4.png": "run_frame4",
    "11_adam_run_5.png": "run_frame5",
    "12_adam_run_6.png": "run_frame6",
    "13_adam_run_7.png": "run_frame7",
    "14_adam_run_8.png": "run_frame8",
    # dash (single)
    "15_adam_dash.png": "dash",
    # turn (turn)
    "16_adam_left_look_turn_1.png": "turn_frame1",
    "17_adam_right_turn_2.png": "turn_frame2",
    "18_adam_right_turn_3.png": "turn_frame3",
    # backstep (backstep)
    "19_adam_step_back_1.png": "backstep_frame1",
    "20_adam_step_back_2.png": "backstep_frame2",
    "21_adam_step_back_3.png": "backstep_frame3",
    "22_adam_step_back_4.png": "backstep_frame4",
    "23_adam_step_back_5.png": "backstep_frame5",
    "24_adam_step_back_6.png": "backstep_frame6",
    "25_adam_step_back_7.png": "backstep_frame7",
    "26_adam_step_back_8.png": "backstep_frame8",
    # crouch (single)
    "27_adam_crouch.png": "crouch",
    # jump/air (single, type: air)
    "28_adam_jump_takeoff.png": "jump_takeoff",
    "29_adam_air_up.png": "air_up",
    "30_adam_air_apex.png": "air_apex",
    "31_adam_air_down.png": "air_down",
    # land (single)
    "32_adam_land.png": "land",
    # pose variants (not core anim)
    "33_adam_R_look_idle.png": "R_look_idle",
    "34_adam_L_look_idle.png": "L_look_idle",
    "35_adam_L_side_45.png": "L_side_45",
    "36_adam_look_down.png": "look_down",
    "37_adam_look_up.png": "look_up",
    "38_adam_back.png": "back",
    # attack (single)
    "39_adam_L_facing_draw_charge.png": "draw_charge",
    "40_adam_L_facing _slash_h.png": "slash_h",  # note: space in filename
    "41_adam_face_angry.png": "face_angry",  # ui portrait
    "42_adam_L_facing_draw_charge.png": "draw_charge_alt",  # duplicate?
    "43_left-facing_sheath.png": "sheath",
    "44_adam_parry.png": "parry",
    "45_adam_attack_up.png": "attack_up",
    "46_adam_attack2.png": "attack2",
    # ui portraits
    "47_adam_face_idle.png": "face_idle",
    "48_adam_face_smile.png": "face_smile",
    # combat idle (use as guard?)
    "49_adam_combat_idle.png": "guard",
    # pose variants
    "50_adam_surprise.png": "surprise",
    "51_adam_crossarm.png": "crossarm",
    # damage (single)
    "52_adam_hurt.png": "hurt",
    "53_adam_dizzy.png": "dizzy",
    "54_adam_die.png": "die",
    "55_adam_victory.png": "victory",
    # extra
    "56_adam_dodge.png": "dodge",
}

# 파일명 → 그룹 매핑
def get_frame_group(filename: str) -> str:
    """파일명에서 그룹 추정"""
    name = filename.lower()
    if "walk" in name:
        return "walk"
    elif "run" in name:
        return "run"
    elif "turn" in name:
        return "turn"
    elif "step_back" in name or "backstep" in name:
        return "backstep"
    else:
        return "single"

# 공중 프레임 여부
AIR_FRAMES = {"jump_takeoff", "air_up", "air_apex", "air_down"}

def is_air_frame(filename: str) -> bool:
    """공중 프레임인지 확인"""
    name = filename.lower()
    for air in AIR_FRAMES:
        if air.replace("_", "") in name.replace("_", ""):
            return True
    return False

def get_character_bbox(img: Image.Image):
    """알파 채널 기준 캐릭터 바운딩 박스 반환"""
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    alpha = img.split()[3]
    bbox = alpha.getbbox()
    return bbox  # (left, top, right, bottom) or None

def normalize_frame(img_path: Path, group: str, is_air: bool) -> Image.Image:
    """프레임 정규화: 스케일 + 정렬"""
    img = Image.open(img_path).convert("RGBA")
    original_size = img.size

    scale = SCALE_GROUPS[group]["scale"]

    # 1. 스케일 적용 (Lanczos 리샘플링)
    if scale != 1.0:
        new_w = int(img.width * scale)
        new_h = int(img.height * scale)
        img = img.resize((new_w, new_h), Image.LANCZOS)

    # 2. 캐릭터 bbox 계산
    bbox = get_character_bbox(img)
    if bbox is None:
        print(f"  경고: {img_path.name} - 투명 이미지")
        # 빈 캔버스 반환
        return Image.new("RGBA", TARGET_CANVAS, (0, 0, 0, 0))

    char_left, char_top, char_right, char_bottom = bbox
    char_width = char_right - char_left
    char_height = char_bottom - char_top
    char_center_x = (char_left + char_right) // 2

    # 3. 공통 캔버스 생성
    canvas = Image.new("RGBA", TARGET_CANVAS, (0, 0, 0, 0))

    # 4. 수평 정렬: 캐릭터 중심을 캔버스 중심에
    canvas_center_x = TARGET_CANVAS[0] // 2
    paste_x = canvas_center_x - char_center_x

    # 5. 수직 정렬
    if is_air:
        # 공중: 점프 아크 보존 - 원본 상대 위치 유지
        # 캐릭터 중심을 캔버스 중앙 근처에 배치 (위로 약간 올림)
        char_center_y = (char_top + char_bottom) // 2
        # 공중 프레임은 지상 기준선보다 위에 있어야 함
        # 기준: 원본에서 발 위치가 캔버스 하단에서 얼마나 떨어져 있는지 보존
        original_foot_offset = img.height - char_bottom
        paste_y = TARGET_CANVAS[1] - img.height + int(original_foot_offset * 0.3)  # 약간 위로
    else:
        # 지상: 발(최하단)을 기준선 y≈1070에 맞춤
        paste_y = GROUND_BASELINE_Y - char_bottom

    # 6. 붙여넣기
    canvas.paste(img, (paste_x, paste_y), img)

    return canvas

def check_clipping(img_path: Path, group: str) -> dict:
    """클리핑 여부 확인"""
    img = Image.open(img_path).convert("RGBA")
    bbox = get_character_bbox(img)

    if bbox is None:
        return {"clipped": False, "reason": "empty"}

    left, top, right, bottom = bbox

    result = {
        "clipped": False,
        "top_margin": top,
        "bottom_margin": img.height - bottom,
        "left_margin": left,
        "right_margin": img.width - right,
    }

    # 상하 여백이 5px 미만이면 클리핑 의심
    if top < 5:
        result["clipped"] = True
        result["reason"] = "top"
    if img.height - bottom < 5:
        result["clipped"] = True
        result["reason"] = result.get("reason", "") + " bottom"

    return result

def main():
    print("=" * 60)
    print("아담 프레임 정규화 시작")
    print(f"입력: {FRAMES_DIR}")
    print(f"출력: {OUTPUT_DIR}")
    print("=" * 60)

    # 출력 디렉토리 생성
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 모든 PNG 파일 처리
    png_files = sorted(FRAMES_DIR.glob("*.png"))

    if not png_files:
        print("PNG 파일이 없습니다!")
        return

    print(f"\n총 {len(png_files)}개 프레임 발견\n")

    # 클리핑 체크 대상 (walk_frame3/7)
    clipping_report = []

    # 크기 비교용 idle 프레임 저장
    idle_bbox = None
    idle_normalized = None

    # 처리된 프레임 정보
    processed = []

    for png_path in png_files:
        filename = png_path.name
        group = get_frame_group(filename)
        is_air = is_air_frame(filename)

        # 논리 프레임명 가져오기
        frame_name = FILENAME_TO_FRAME.get(filename, filename.replace(".png", ""))

        print(f"[{group:8}] {filename} → {frame_name}")

        # 클리핑 체크 (walk_frame3/7 → 4_adam_walk_2.png, 6_adam_walk_4.png)
        if "walk_2" in filename or "walk_4" in filename:
            clip_info = check_clipping(png_path, group)
            if clip_info["clipped"]:
                clipping_report.append({
                    "file": filename,
                    "frame": frame_name,
                    "info": clip_info
                })
                print(f"  ⚠️ 클리핑 감지: {clip_info['reason']}")

        # 정규화
        normalized = normalize_frame(png_path, group, is_air)

        # idle 프레임 저장 (비교용)
        if frame_name == "idle":
            idle_normalized = normalized
            idle_bbox = get_character_bbox(normalized)

        # 논리 프레임명으로 저장
        output_path = OUTPUT_DIR / f"{frame_name}.png"
        normalized.save(output_path, "PNG")

        processed.append({
            "original": filename,
            "frame": frame_name,
            "group": group,
            "is_air": is_air
        })

    print("\n" + "=" * 60)
    print("정규화 완료!")
    print("=" * 60)

    # 클리핑 리포트
    if clipping_report:
        print("\n⚠️ 클리핑 감지된 프레임:")
        for item in clipping_report:
            print(f"  - {item['file']} ({item['frame']}): {item['info']}")
    else:
        print("\n✅ walk_frame3/7 클리핑 없음")

    # 크기 비교 리포트 (idle vs walk/run 첫 프레임)
    print("\n크기 비교 (정규화 후):")
    if idle_bbox:
        idle_height = idle_bbox[3] - idle_bbox[1]
        print(f"  idle 캐릭터 높이: {idle_height}px")

        # walk/run 첫 프레임 체크
        for check_frame in ["walk_frame2", "run_frame1"]:
            check_path = OUTPUT_DIR / f"{check_frame}.png"
            if check_path.exists():
                check_img = Image.open(check_path).convert("RGBA")
                check_bbox = get_character_bbox(check_img)
                if check_bbox:
                    check_height = check_bbox[3] - check_bbox[1]
                    diff = abs(check_height - idle_height)
                    status = "✅" if diff < 50 else "⚠️ 조정 필요"
                    print(f"  {check_frame} 높이: {check_height}px (차이: {diff}px) {status}")

    # 발 정렬 확인 (지상 프레임들의 발 y 좌표)
    print("\n발 정렬 확인 (지상 프레임):")
    ground_frames = ["idle", "walk_frame2", "run_frame1", "crouch", "land"]
    for frame in ground_frames:
        frame_path = OUTPUT_DIR / f"{frame}.png"
        if frame_path.exists():
            img = Image.open(frame_path).convert("RGBA")
            bbox = get_character_bbox(img)
            if bbox:
                foot_y = bbox[3]
                diff = abs(foot_y - GROUND_BASELINE_Y)
                status = "✅" if diff < 10 else f"⚠️ 차이 {diff}px"
                print(f"  {frame}: 발 y={foot_y} (기준 {GROUND_BASELINE_Y}) {status}")

    print(f"\n출력 위치: {OUTPUT_DIR}")
    print(f"처리된 프레임: {len(processed)}개")

if __name__ == "__main__":
    main()
