# VOXHAVEN agent checkpoint

**Owner-designated development branch:** `game/colony-foundation`. Do not redirect development to `development` or `game/asset-integration` without a newer explicit instruction. Preserve `main`, do not merge or release without approval.

## 2026-11-28 current checkpoint

- Verified the `game/colony-foundation` Git tree already contains 107 Quaternius Cube World GLTF models and `Atlas.png` / `Blocks_PixelArt.png`. This is the complete original Cube World asset pack subset in this branch.
- Commit `81fd63e9d7d5564dabb9262e503cf6ce3f93b91d`: render four existing Cube World colonist variants rather than a single character. The GLTF files embed `Idle` and `Walk` clips (source JSON inspection).
- Commit `29e72e6d73b4a389a10d53fcdafd273a20bce54c`: procedural terrain lookup and runtime material use Cube World Pixel Blocks and `Blocks_PixelArt.png`; reuses tinted pixels for missing sand/deep-stone/mineral tiles; strengthens atlas source file test.
- Pending CI validation: model imports, atlas face UVs, scene smoke, animation playback and Android package export. Godot 4.5.1 binary is not installed in assistant's current working container; workflows have not yet been observed passing on these new commits.
- Current roadmap: Phase 4.0 asset integration in progress. Phase 4.1 block designation and Phase 4.2 autonomous mining are NOT implemented on this branch; do not imply other branches' gameplay code was merged.
- Continue on this branch, inspect Godot validation logs and repair failing import/UV/animation code before starting mining. Verify actual APK artifact and physical-device performance separately.

## 2026-11-28 Phase 4.1/4.2 implementation (pending CI)
- Branch: game/colony-foundation. New colony/mining_jobs.gd: solid-block mining designations, exclusive colonist reservations, bounded path-to-adjacent-work-cell selection, cancellation, completion, basic unhauled drops.
- Integrated jobs into colony fixed-step simulator and world_view: mining targets are highlighted, tapped again to cancel, completed jobs trigger chunk remeshing via a simulation signal.
- World save version 1 remains backward-compatible; optional mining_designations records persist queued work, restored on game load. Added tests/mining_jobs_test.gd and validation workflow step.
- Scope: this is a first autonomous mining vertical slice, not woodcutting, hauling, physical resource entities, or construction. No Godot runtime/Android build success claim until CI verifies the commit. Previously-running CI for 8e4de7d does not validate these changes.

## Autonomous agent continuity policy
- Owner reiterated game/colony-foundation as the sole active development branch. The mandatory development skill has been installed here from the previous reference branch and updated for Phase 4 continuation. The separately scheduled hourly VOXHAVEN development task now targets game/colony-foundation and Phase 4.0–4.9, preserving its schedule.
