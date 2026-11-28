# VOXHAVEN agent checkpoint

**Owner-designated development branch:** `game/colony-foundation`. Do not redirect development to `development` or `game/asset-integration` without a newer explicit instruction. Preserve `main`, do not merge or release without approval.

## 2026-11-28 current checkpoint

- Verified the `game/colony-foundation` Git tree already contains 107 Quaternius Cube World GLTF models and `Atlas.png` / `Blocks_PixelArt.png`. This is the complete original Cube World asset pack subset in this branch.
- Commit `81fd63e9d7d5564dabb9262e503cf6ce3f93b91d`: render four existing Cube World colonist variants rather than a single character. The GLTF files embed `Idle` and `Walk` clips (source JSON inspection).
- Commit `29e72e6d73b4a389a10d53fcdafd273a20bce54c`: procedural terrain lookup and runtime material use Cube World Pixel Blocks and `Blocks_PixelArt.png`; reuses tinted pixels for missing sand/deep-stone/mineral tiles; strengthens atlas source file test.
- At the initial asset integration checkpoint, validation was pending. Later Godot and Android CI runs passed; see the verified November 28 checkpoint at the end of this file.
- Historical baseline before Phase 4 job features. Block designation, autonomous mining, woodcutting and hauling were subsequently implemented on this same branch; see later checkpoints.
- Historical integration note: later test runs verified these features. Continue on the owner-designated branch and verify physical Android behavior separately.

## 2026-11-28 Phase 4.1/4.2 implementation (pending CI)
- Branch: game/colony-foundation. New colony/mining_jobs.gd: solid-block mining designations, exclusive colonist reservations, bounded path-to-adjacent-work-cell selection, cancellation, completion, basic unhauled drops.
- Integrated jobs into colony fixed-step simulator and world_view: mining targets are highlighted, tapped again to cancel, completed jobs trigger chunk remeshing via a simulation signal.
- World save version 1 remains backward-compatible; optional mining_designations records persist queued work, restored on game load. Added tests/mining_jobs_test.gd and validation workflow step.
- Scope: this is a first autonomous mining vertical slice, not woodcutting, hauling, physical resource entities, or construction. No Godot runtime/Android build success claim until CI verifies the commit. Previously-running CI for 8e4de7d does not validate these changes.

## Autonomous agent continuity policy
- Owner reiterated game/colony-foundation as the sole active development branch. The mandatory development skill has been installed here from the previous reference branch and updated for Phase 4 continuation. The separately scheduled hourly VOXHAVEN development task now targets game/colony-foundation and Phase 4.0–4.9, preserving its schedule.

## 2026-11-28 Phase 4.3/4.4 logistics implementation — pending validation
- Added `colony/resource_logistics.gd`: bounded hauling reservations from mining drops, pathfinding to available pickup/depot stand positions, carried state, depot inventory, recoverable dropped items on worker failure, and resource delivery signals. Gameplay and inventory state remain offline and independent of renderer.
- Integrated logistics after mining in fixed-step colony simulation and UI; in-world status displays pending drops and stored units. Saves now optionally include pending drops, inventory, depot and recovery of carried items into stock while retaining world save format version 1 compatibility.
- Added `tests/resource_logistics_test.gd` to the Godot CI workflow, covering mining→pickup→delivery, persisted stock and unhauled drops, and dropped inventory when a worker is released. CI is pending; no claim of successful Godot or Android runtime tests.
- This first storage vertical slice has no visual warehouse building, physical pickup animation, crafting or construction, and does not finish Phase 4.4.

## 2026-11-28 visual cohesion update — pending CI / Android rebuild
- Owner supplied a screenshot showing noisy pixel-art terrain beside low-poly Cube World humanoids and oversized flat-canopy trees.
- Root cause in code: terrain used `Pixel Blocks/` and the `Blocks_PixelArt.png` (80×80) while character and environment GLTFs use the regular `Atlas.png` 32×32 color palette.
- `world/terrain_atlas.gd` now samples regular Cube World `Blocks/Block_*.gltf` face colors using one source triangle UV per face (prevents gradients between palette swatches). All ten terrain block IDs remain mapped; sand/ores use tinted low-poly placeholder variants.
- `world/terrain_decor.gd` now scales three approved tree models to 0.56× so canopies are less oversized relative to characters. Source model/texture files are untouched.
- Atlas/decor regression tests verify style asset paths, swatch sampling and scale bounds. CI and physical Android appearance are not yet validated for this commit; compare screenshots after a new debug APK build.

## 2026-11-28 owner-directed softer pixel terrain — pending CI
- Owner prefers the original textured Cube World terrain but reports eye strain from overly sharp/high-contrast grass and dirt; regular flat-color blocks from prior commit were not the desired direction.
- Restored `Pixel Blocks/` + `Blocks_PixelArt.png` UV extraction and texture while retaining previously scaled Quaternius trees. Added a lightweight Godot spatial shader with bilinear/mipmap sampling, mild saturation reduction (0.76) and contrast reduction (0.78), without touching source atlases/characters.
- The shader's uniforms are adjustable without reauthoring terrain meshes. Updated atlas regression test to enforce the intended pixel-texture source rather than low-poly palette swatches.
- Visual improvement is provisional until Godot CI and a new physical-device APK screenshot confirm readability, texture filtering and terrain/tree/character cohesion. No claim of an Android build or passing validation for this change.

## 2026-11-28 continuous colonist locomotion and work (pending CI)
- Root cause of stop-start walking: the simulation previously advanced one grid cell per 1.0-second tick while the renderer moved 3 cells/s and reached the next waypoint in about 0.33 seconds, then idled for the remaining tick.
- Shortened the deterministic step to 0.25 s with the same maximum 4 seconds per advance call (MAX_STEPS=16). Visual interpolation now matches 4 cells/s and honors the 1x/2x/3x simulation speed multiplier. Logical navigation, collision checks and offline simulation remain grid-based.
- Mining takes a continuous 0.75-second work phase with the existing Punch animation; hauling uses existing Walk_Hold when carrying. Workers briefly yield for occupied path tiles rather than immediately canceling their job; stamina movement cost is normalized per simulated second.
- Added deterministic movement/work test and updated existing fixed-step test and test workflow. Models/terrain assets and mining/resource ownership remain unchanged. CI and Android-device motion quality still need validation.

## 2026-11-28 Phase 4.2 woodcutting + Phase 4.4 visible storage — pending CI
- Implemented `colony/woodcut_jobs.gd`: deterministically checks existing Quaternius forest tree positions, player designations with cancellation, exclusive worker reservations, path to adjacent standable tree cells, 1.5 s chopping action and chopped signal. Woodcutting permanently records harvested trees and yields 3 units of dedicated wood item ID 100 into the existing hauling drop registry; terrain block IDs are unchanged.
- Extended `world/terrain_decor.gd` to suppress felled trees during deterministic chunk population; the world refreshes affected chunks after chopping. Existing glTF models and atlas art remain untouched.
- Added physically visible `world/stockpile_view.gd` with original Cube World crate and highlighted ground pad; new Stockpile mode places/relocates the depot on reachable walkable ground and displays aggregate stock/wood. Existing hauling routes now deliver to the stockpile location, and stored resources survive relocation. This is a single stockpile prototype, not a constructed warehouse or multi-zone logistics system.
- Retained backwards-compatible world-save version 1: optional woodcut harvesting/designations and existing logistics depot/inventory (including wood item) persist. Existing saves without the new section still load.
- Added deterministic end-to-end woodcut/hauling/relocation/persistence test plus visual stockpile scene test, updated terrain decoration regression and CI workflow. PENDING CI: do not claim feature validated or APK built until new commit runs pass. Check physical device tap targeting and actual movement separately.

## 2026-11-28 verified Phase 4.2 + 4.4 implementation
- **GitHub branch:** `game/colony-foundation`; no merge to `main`. The final source/test commit `3215bccda3793ab53344943c711e94e42bdf9838` passed Godot validation: https://github.com/joparoxxx/VOXHAVEN/actions/runs/46147714951
- CI **PASS**: full asset import, terrain decoration and UV tests, Cube World character import/animation checks, colony simulation, navigation, continuous movement, mining, resource logistics, deterministic woodcut→wood drop→haul→stockpile round trip, persisted felled trees/designations, relocated stockpile, and stockpile display test. World rendering smoke test also **PASS**.
- Android debug APK export, archive integrity, signing and package verification **PASS** in https://github.com/joparoxxx/VOXHAVEN/actions/runs/46147531755 at `4ec5f069d0e3f08bcf790ab22ac6e54fd50199ec`. Later change `3215bcc` only corrected a headless test lifecycle issue, not runtime gameplay. The artifact is `voxhaven-android-debug`.
- Remaining limitations: physical-device install, touch designation and forest selection usability, smooth work/haul animation, stockpile label visibility, actual framerate/memory and old-save compatibility on a device are NOT YET VERIFIED. Stockpile is a single relocatable marked storage area, not a constructed warehouse or capacity-limited logistics network. Phase 4.5 construction is still pending.
