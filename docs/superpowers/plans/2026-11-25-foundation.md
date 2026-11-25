# Foundation vertical slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development. Steps use checkbox syntax.

**Goal:** Create a testable offline Godot project, deterministic local task runner, and graybox robot office.
**Architecture:** RefCounted task engine owns state and artifacts; scene consumes results. No network or external runtime.
**Tech Stack:** Godot 4.4.1, GDScript, GitHub Actions.
**Spec:** docs/superpowers/specs/2026-11-25-cubyte-design.md

## Global constraints
Offline core, native Android target, primitive shapes, no fake work, no arbitrary script execution, no Termux dependency. No external addons for this slice.

## Review focus
Unknown tool rejected; file path derived only from generated task ID; invalid input fails; cancelled job never executes; running job recovered as interrupted. Check persistence and real output bytes. Device export and performance are separate checks.

## Task 1: project and tests
- [ ] Create game/project.godot, main scene, headless runner tests in game/tests/test_tasks.gd.
- [ ] Test actual TXT/PNG output, reject unsupported tool, cancel queued task, reload state.
- [ ] Run Godot headless test before implementation; expect failure because engine not yet implemented.
- [ ] Add CI on PR, pinned Godot release, headless import and test plus scene smoke.

## Task 2: task engine
- [ ] Implement game/core/task_engine.gd: enqueue(robot_id, tool, payload) -> String; cancel(id) -> bool; run_next() -> bool; get_task(id) -> Dictionary; load_state() -> bool.
- [ ] Use bounded text payload, fixed-size PNG, generated numeric IDs, private artifact folder, persisted JSON state, validated outputs. Mark persistence failure honestly. No external execution.
- [ ] Run full test suite; expect exit 0.

## Task 3: graybox scene
- [ ] Build game/scenes/office.gd: primitive room, three color variants, eyes, articulated arm placeholders, rolling base; UI selects robot and runs structured TXT/PNG job; display actual status and artifact path.
- [ ] Smoke scene in CI; visual and Android interaction need physical testing.
- [ ] Review diff and open draft PR; do not merge.

## Deferred
Full SKILL.md importer, PNG preview/share, local AI, Android export/signing, free movement and navigation, and final models remain separate tasks. This slice is not a complete APK.
