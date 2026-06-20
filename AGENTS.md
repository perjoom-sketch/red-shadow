# AGENTS.md — Red Shadow (붉은 그림자)

Godot 4.6.3 2D side-scroller. This file is the operating contract for **all** coding agents
(Devin, Claude Code, Codex, SWE-1.x). Read it fully before any task. Follow every rule.

## Project
- Engine: Godot 4.6.3, Forward+ renderer.
- Repo: `perjoom-sketch/red-shadow` (public). Deploy: red-shadow.vercel.app (serves static `build/web/`).
- Character: black cat swordsman. Palette `#111111 #333333 #666666 #E53935` (red = eyes + scarf).
- Design reference lives in `docs/` (`GAME_DESIGN.md`, `ART_DIRECTION.md`, `AI_MONSTER_DESIGN.md`,
  `MUSIC_PROMPTS.md`). Read the relevant one when needed; do not duplicate it here.

## Source of truth & git
- **GitHub is the source of truth.** The local working tree is a checkout, not the truth.
- **`git fetch && git pull` before starting any work.** Stale checkouts cause re-created/duplicate work.
- **Base every edit on `origin/main`, not on a possibly-drifted local tree.** For a surgical file edit,
  run `git checkout origin/main -- <path>` first so local drift cannot contaminate the change.
- **Commit AND push every change.** Uncommitted local work effectively does not exist — it is wiped
  on the next sync. (This repo has lost HUD edits and rules files exactly this way.)
- Never upload files through the GitHub web UI; it diverges from local.
- **One PR = one concern.** One PR is owned end-to-end by one tool — no mid-handoff between tools.
- Stage only the explicit files for the current PR (`git add <paths>`). Never `git add -A` / `git add .` — it sweeps unrelated working-tree files into the commit.
- **Agents do NOT merge.** The owner is the merge gate. Push the PR and stop.
- **After a PR is merged, `git checkout main && git pull` immediately** to keep local in sync before starting the next task.

## Godot scene (.tscn / .tres) hygiene — CRITICAL
- **Edit `.tscn` / `.tres` files as TEXT only.**
- **NEVER open, re-import, or re-save a scene through the Godot editor to make an edit.** Godot
  re-serialization regenerates `uid://` identifiers across the resource graph and breaks cross-scene
  references. (A 1-line HUD-text change once became a 188-line uid rewrite this way.)
- **The `uid://` graph is sacred.** A clean edit changes ZERO uid lines.
- `godot --headless --import` is allowed for **verification only** (catches parse errors). Do not commit
  its output if it churns uids or re-serializes scenes.

## Rig / animation specifics
- Player visual = `PlayerRig.tscn` instanced under `Player → Visual → Rig`. The old `player.png` Sprite2D
  is kept but `visible = false` (instant fallback). Do not delete it.
- `ClothSway.gd` drives `rotation` of **Tail, CoatTails, Scarf** every frame. **NEVER add rotation
  keyframes to those three nodes** — the script overwrites them, animations will fight it.
- Animations live in `PlayerRig.tscn`'s AnimationPlayer. Agents author tracks as text from a spec;
  visual feel is verified by the owner in the editor anim panel, not by the agent.

## Build & deploy
- `build/web/` is a **manual Godot export artifact**, committed to the repo and served statically by Vercel.
- **The Vercel preview is NOT the source.** It shows the last exported build, not current `.tscn`/`.gd`.
  Source changes do not appear on the web until re-export. To verify source, use the Godot editor (F5).
- Re-export only at milestones (it churns large binaries), as a separate "build PR":
  `godot --headless --export-release "Web" build/web/index.html`, then commit `build/web/`.

## Web build (build/web) — manual export artifact
- `build/web/` is the static export Vercel serves as the live site. It does NOT auto-update from source.
- After merging any change that should appear on the deployed game (scenes, scripts, assets, `project.godot` display/rendering), re-export and open a SEPARATE PR with build/web only:
  `godot --headless --export-release "Web" build/web/index.html`
- That PR must change `build/web/*` only — 0 source/scene/`uid://` changes (verify: `git diff origin/main`).
- Skip re-export for PRs that don't affect the game (CI, docs, tooling, AGENTS.md edits).

## Model routing
- **Godot work (`.tscn`, GDScript, scene structure) → use a top model (Claude Opus 4.6+).** It does
  surgical edits and self-checks its diff; weaker models miss sync/uid hygiene and corrupt scenes.
- Plain mechanical, mainstream edits → SWE-1.x is acceptable **only if** the spec is complete and the
  verification gate below is enforced. **Do not use SWE-1.x for scene-structure (`.tscn`) work.**
- Devin is the primary executor; on quota exhaustion, fall back to Claude Code. Godot itself runs fine on
  the AVX-less dev PC, but Claude Code must stay pinned to `v2.0.62` with `DISABLE_AUTOUPDATER=1`.

## Verification gate — run before every commit
1. `git diff origin/main` shows **only the intended change**.
2. **ZERO `uid://` lines changed** (unless intentionally adding a genuine new resource).
3. No unexpected files touched; no `load_steps` / whole-scene re-serialization.

If any check fails → **STOP and report. Do not commit.** A passing diff is the success criterion,
not the agent's own "done" claim.

## Session procedure (every task)
1. START  — `git fetch && git pull`. Never start on a stale tree.
2. STAGE  — explicit paths only: `git add <path1> <path2>`. Never `git add -A` / `git add .`.
3. VERIFY — `git diff origin/main`: only intended files, 0 `uid://` removals. Anything unexpected → STOP.
4. COMMIT & PUSH. Never merge — owner merges.
