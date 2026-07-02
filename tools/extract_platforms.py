"""
Platform Collision Extractor
=============================
Scans a background PNG for bright horizontal ledges (stone platforms)
and outputs collision positions + sizes for Main.tscn.

Usage:
    python tools/extract_platforms.py assets/bg/rooftop_climb.png

Optional args:
    --threshold 200    brightness threshold (0-255, default 200)
    --min-width 80     minimum platform width in px (default 80)
    --height 22        collision shape height (default 22)
    --preview          save a debug preview image

Output:
    Prints platform data (center_x, center_y, width) sorted top-to-bottom,
    and optionally a .tscn snippet ready to paste.
"""

import sys
import argparse
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print("Required: pip install pillow numpy")
    sys.exit(1)


def extract_platforms(image_path, threshold=200, min_width=80, shape_height=22, preview=False):
    img = Image.open(image_path).convert("L")  # grayscale
    arr = np.array(img)
    h, w = arr.shape

    print(f"Image size: {w}x{h}")
    print(f"Threshold: {threshold}, Min width: {min_width}px")
    print()

    # Binary mask: bright pixels
    mask = arr >= threshold

    # Find horizontal runs per row
    platforms = []

    # For each row, find contiguous bright runs
    visited = np.zeros_like(mask, dtype=bool)

    # Strategy: scan top-to-bottom, find the TOP edge of each platform
    # A platform top edge = row where mask is True but row above is False (or row 0)
    top_edge = np.zeros_like(mask, dtype=bool)
    top_edge[0] = mask[0]
    top_edge[1:] = mask[1:] & ~mask[:-1]

    # For each top-edge row, find horizontal extents
    raw_platforms = []

    for y in range(h):
        if not np.any(top_edge[y]):
            continue

        # Find contiguous runs in this row
        row = top_edge[y].astype(np.uint8)
        diffs = np.diff(np.concatenate(([0], row, [0])))
        starts = np.where(diffs == 1)[0]
        ends = np.where(diffs == -1)[0]

        for s, e in zip(starts, ends):
            run_width = e - s
            if run_width >= min_width:
                # Verify it's a substantial platform: check depth (how many rows below are also bright)
                depth = 0
                for dy in range(min(50, h - y)):
                    mid = (s + e) // 2
                    if mask[y + dy, mid]:
                        depth += 1
                    else:
                        break

                if depth >= 5:  # at least 5px tall platform
                    # Now find the actual full width by scanning the brightest row within the platform
                    best_width = run_width
                    best_s, best_e = s, e
                    for dy in range(min(depth, 10)):
                        row_check = mask[y + dy]
                        # Find the run containing our midpoint
                        mid = (s + e) // 2
                        ls = mid
                        while ls > 0 and row_check[ls - 1]:
                            ls -= 1
                        re = mid
                        while re < w - 1 and row_check[re + 1]:
                            re += 1
                        if (re - ls) > best_width:
                            best_width = re - ls + 1
                            best_s, best_e = ls, re + 1

                    raw_platforms.append({
                        "top_y": y,
                        "left": best_s,
                        "right": best_e,
                        "width": best_e - best_s,
                        "depth": depth,
                    })

    # Merge overlapping/nearby platforms (within 20px vertical, overlapping horizontal)
    merged = []
    used = [False] * len(raw_platforms)

    for i, p in enumerate(raw_platforms):
        if used[i]:
            continue
        group = [p]
        used[i] = True
        for j in range(i + 1, len(raw_platforms)):
            if used[j]:
                continue
            q = raw_platforms[j]
            # Same vertical band (within 15px) and overlapping horizontal
            if abs(q["top_y"] - p["top_y"]) < 15:
                overlap = min(p["right"], q["right"]) - max(p["left"], q["left"])
                if overlap > 0 or abs(p["left"] - q["left"]) < 30:
                    group.append(q)
                    used[j] = True

        # Merge group
        top_y = min(g["top_y"] for g in group)
        left = min(g["left"] for g in group)
        right = max(g["right"] for g in group)
        depth = max(g["depth"] for g in group)
        merged.append({
            "top_y": top_y,
            "left": left,
            "right": right,
            "width": right - left,
            "depth": depth,
        })

    # Filter: remove very small detections
    platforms = [p for p in merged if p["width"] >= min_width]

    # Sort top to bottom
    platforms.sort(key=lambda p: p["top_y"])

    # Calculate collision centers
    # Collision shape center_y = top_y + shape_height/2 (shape centered on position)
    print(f"Found {len(platforms)} platforms:\n")
    print(f"{'#':<4} {'Center X':<10} {'Center Y':<10} {'Width':<8} {'Top Y':<8} {'Depth':<6}")
    print("-" * 50)

    results = []
    for i, p in enumerate(platforms):
        cx = (p["left"] + p["right"]) // 2
        cy = p["top_y"] + shape_height // 2
        width = p["width"]
        results.append({"cx": cx, "cy": cy, "width": width, "top_y": p["top_y"]})
        print(f"{i:<4} {cx:<10} {cy:<10} {width:<8} {p['top_y']:<8} {p['depth']:<6}")

    # Generate .tscn snippet
    print("\n\n# ===== .tscn SNIPPET =====")
    print("# Paste these as sub_resources and nodes in Main.tscn\n")

    print("# --- Sub Resources (RectangleShape2D) ---")
    for i, r in enumerate(results):
        print(f'[sub_resource type="RectangleShape2D" id="plat_{i}"]')
        print(f'size = Vector2({r["width"]}, {shape_height})')
        print()

    print("# --- Nodes ---")
    for i, r in enumerate(results):
        print(f'[node name="P{i}" type="StaticBody2D" parent="LevelCollision"]')
        print(f'position = Vector2({r["cx"]}, {r["cy"]})')
        print()
        print(f'[node name="C" type="CollisionShape2D" parent="LevelCollision/P{i}"]')
        print(f'shape = SubResource("plat_{i}")')
        print()

    # Preview image
    if preview:
        from PIL import ImageDraw
        preview_img = Image.open(image_path).convert("RGB")
        draw = ImageDraw.Draw(preview_img)
        for i, r in enumerate(results):
            # Draw rectangle at collision position
            top = r["cy"] - shape_height // 2
            left = r["cx"] - r["width"] // 2
            right = r["cx"] + r["width"] // 2
            bottom = top + shape_height
            draw.rectangle([left, top, right, bottom], outline="red", width=2)
            draw.text((left + 4, top - 12), f"P{i}", fill="yellow")

        out_path = Path(image_path).with_suffix(".preview.png")
        preview_img.save(out_path)
        print(f"\nPreview saved: {out_path}")

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract platform collision data from background image")
    parser.add_argument("image", help="Path to background PNG")
    parser.add_argument("--threshold", type=int, default=200, help="Brightness threshold (0-255)")
    parser.add_argument("--min-width", type=int, default=80, help="Minimum platform width in pixels")
    parser.add_argument("--height", type=int, default=22, help="Collision shape height")
    parser.add_argument("--preview", action="store_true", help="Save debug preview image")
    args = parser.parse_args()

    extract_platforms(args.image, args.threshold, args.min_width, args.height, args.preview)
