# Voxhaven

**Build a world. Grow a civilization.**

Voxhaven is a **work-in-progress, fully offline 3D colony simulator for Android**, developed with Godot 4 and GDScript. The goal is a seeded, Minecraft-inspired voxel world where humanoid colonists independently gather resources, build a settlement, and manage their needs.

> **Development preview — not a finished game.** Cached colonist gravity and falling animations have been restored while mining continues to protect living workers and trees. A saved-world mesh-snapshot cache and non-destructive New World (Backup) action have been implemented. [Android ARM64 debug APK build #46166843218](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46166843218) passed import, export and package checks. [Godot validation #46166814959](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46166814959) is still being checked. The user's reported idle FPS improvement after clearing app data suggests a persisted-state issue but does not yet prove the source or show improvement in this APK.

## Current development branch

**Active implementation:** [`game/colony-foundation`](https://github.com/joparoxxx/VOXHAVEN/tree/game/colony-foundation)

- `main` remains the protected project/reference entry point; gameplay changes are not merged there without owner approval.
- Historical branches, including `development` and `game/asset-integration`, are **not** the active development target.
- Continue from the actual branch HEAD and [agent checkpoint](docs/AGENT_STATE.md), not from an old chat report or a fixed commit SHA.
- The roadmap and approved design are in [docs/GAME_MASTER_PLAN.md](docs/GAME_MASTER_PLAN.md).

## Current playable prototype (implementation status)

| Area | Implemented in source | Limitations / validation |
| --- | --- | --- |
| Procedural terrain | Deterministic seed, 16 × 16 horizontal chunks, six biome classifications, caves and ore distribution | Visual seams, biome balance, collision and mobile frame times still need runtime checks |
| World streaming | Exposed-face chunk meshes, collision, bounded chunk loading, background CPU mesh generation, terrain edits | Threading and rendering need full Godot / Android testing |
| Cube World art | 107 GLTF models and two atlas images; four humanoid character variants; softened Cube World pixel-textured blocks; scaled low-poly forest trees | Godot CI passed; device screenshot comparison remains pending |
| Colonists | Three simulated colonists with health, hunger, thirst, stamina, local memory, bounded navigation and simple utility-driven behavior | Needs/AI are prototypes, not a complete survival system |
| Mining and excavation | Unified Mine command auto-selects chopping vs terrain dig; Select + depth for area; living tree support is protected | Deep shafts still require routes/ramps; physical Android input must be tested |
| Resources | Mining and tree chopping create distinct stone/block and wood resource records | Resource drops are still logical records rather than world item meshes |
| Hauling and storage | Autonomous pickup/delivery to a visible Cube World crate stockpile with relocatable ground pad and per-resource counts | Initial prototype has one stockpile and no capacity, building, or full inventory UI |
| Save/load | Seed, terrain edits, mining/woodcut designations, felled-tree state, unhauled items, stock and stockpile position | Colonist state and full simulation recovery remain pending |

These entries describe **prototype functionality**, supported by passing automated checks. CI validation does not substitute for Android device gameplay, touch controls, screenshots or performance testing.

## Roadmap — current Phase 4 focus

| Phase | Milestone | Status |
| --- | --- | --- |
| 4.0 | Cube World terrain, characters and asset integration | Imported and validated in Godot CI; device visual QA pending |
| 4.1 | Block selection and mining designations | Implemented and passed Godot CI; device input QA pending |
| 4.2 | Autonomous mining and woodcutting | Implemented, automated integration tests passed; Android QA pending |
| 4.3 | Resource drops and inventory | Basic resource records and stock counts implemented |
| 4.4 | Hauling and storage | Visible stockpile and hauling tests passed; capacity/building pending |
| 4.5 | Construction and blueprints | Pending |
| 4.6 | Colonist equipment and tools | Pending |
| 4.7 | Farming, food and drinking | Pending |
| 4.8 | Day/night cycle | Pending |
| 4.9 | Animals and wildlife | Pending |

After this vertical slice, continue with crafting, relationships, exploration, technology progression, optimization and physical-device QA. See the [master game plan](docs/GAME_MASTER_PLAN.md) for design principles and the [checkpoint](docs/AGENT_STATE.md) for the most recent verified work and blockers.

## Technology and architecture

| Component | Current target |
| --- | --- |
| Engine | Godot 4.5.1 |
| Scripting | GDScript |
| Renderer | Compatibility / `gl_compatibility` |
| Device | Android ARM64 |
| App ID | `com.urfavxbf.voxhaven` |
| World | Deterministic 16 × 16 horizontal chunks, bounded vertical height |
| Performance goal | 30 FPS initially; 60 FPS only after actual profiling |
| Online services | None required; no cloud AI, API key or mandatory network connection |

Core implementation is separated into:

- `world/` — terrain data, chunk meshing, streaming/view, visual decoration, atlas extraction and persistence.
- `colony/` — colonist state, pathfinding, decision-making, mining jobs and resource logistics.
- `core/` and `scenes/` — asset registry and representative model/scene validation.
- `tests/` — deterministic simulation, data, asset and scene checks.
- `assets/` — third-party source models, catalog and attribution.
- `.github/workflows/` — Godot validation and on-demand Android debug APK export.

## Run locally

Clone **the active development branch**, not `main`:

```bash
git clone --branch game/colony-foundation https://github.com/joparoxxx/VOXHAVEN.git
cd VOXHAVEN
```

Use Godot **4.5.1** to open `project.godot` and allow imports to finish. The main scene is `world/world_view.tscn`; an asset lab is also included for model checks.

Import and run the code-level checks with an installed `godot` executable:

```bash
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/voxel_world_test.gd
godot --headless --path . --script res://tests/world_save_test.gd
godot --headless --path . --script res://tests/colony_ai_test.gd
godot --headless --path . --script res://tests/mining_jobs_test.gd
godot --headless --path . --script res://tests/resource_logistics_test.gd
godot --headless --path . --script res://tests/woodcut_stockpile_test.gd
godot --headless --path . --script res://tests/stockpile_view_test.gd
godot --headless --path . --script res://tests/role_and_mine_tool_test.gd
```

These are commands to **run**, not claims that the latest commit has passed them. The full [Godot validation workflow](.github/workflows/godot-validation.yml) also checks registry, mesh generation, decoration, Cube World textures, character animation imports and a rendered world smoke scene.

### Prototype controls

- **Mine:** tap a solid block (or right-click with a mouse) to designate it for autonomous mining; tap again to cancel a designation.
- **Place:** tap a surface to place a dirt block.
- **Chop:** tap the ground directly beneath a Cube World tree to mark/unmark a woodcutting job. Colonists navigate, chop, produce wood, and autonomously haul it.
- **Stockpile:** tap walkable ground to place or relocate the visible storage area (the existing stock moves with it in this prototype). Colonists carry drops here; the crate label shows total stock and wood count.
- **Save:** write terrain edits, mining/woodcut tasks, harvested trees, stockpile location and stored/unhauled items to local user storage.
- **Camera:** Camera ON enables drag-to-orbit and tap-to-set pivot; Camera OFF enables normal work selection and free pan; pinch/zoom remains available. Fixed rotate/follow buttons were removed.
- **Colonists:** cycle the selected colonist and inspect basic needs/status; use the simulation-speed button to pause or accelerate time.

The UI and multitouch input are prototypes; physical Android device testing remains outstanding.


### Restored gravity, safe mining and 3D-viewer camera

- **Gravity restored:** colonists fall to the next standable lower block if terrain disappears beneath them, with cached support probes and interpolated falling animations.
- **Prevent unsafe mines:** living colonists and standing trees protect all blocks below their vertical column. The Mine command checks protection when creating, reserving and completing work; unsafe jobs remain pending instead of deleting the floor.
- **3D-viewer Camera ON/OFF:** one-finger orbit when ON, free pan and gameplay tools when OFF, pinch zoom and two-finger pan in both modes. No follow button.
- **Original streaming unchanged:** horizontal chunks remain 16×16, zoom-based loading/unloading radius 2–4.
- **Saved data performance fix:** the renderer caches a read-only snapshot of world edits across chunk meshes, rebuilding that snapshot only when terrain actually changes. Previously, all saved edits were duplicated for every queued chunk, potentially expensive on older saves.
- **Save recovery:** Tools → **New World (Backup)** asks for confirmation, archives the old `world.json` inside app storage and restarts fresh. It never silently clears the player's save. Legacy version-1 saves still load, and invalid saves cannot be auto-overwritten.

### Idle FPS diagnostics

The HUD shows **FPS, Chunks, Queue, Mesh, Gravity/s and AI/s**. A busy mesh queue may indicate rendering work; high gravity/AI readings indicate simulation work. The actual idle FPS impact needs testing with both the old save and a fresh world on the same phone.

## Compact tools and single Mine workflow

The Android toolbar now keeps **Mine**, **Select**, **Tools**, **Worker**, **Job**, a **Camera ON/OFF switch**, and **Save** together, with smaller controls for depth, zoom and simulation speed. Secondary actions (**Pan, Place, Stockpile, Inspect, Cancel**) live in the Tools menu; camera reset lives in Tools → Reset Camera. Independent Dig/Chop/Chop Area buttons have been removed.

- **Mine** is the only resource work order: tap exposed terrain to excavate the block or the chosen depth (1–8). Tap the ground supporting a standing Cube World tree to designate **woodcutting instead**. Tap again to cancel that one order.
- **Select** uses two ground taps or one-finger drag to outline up to 64 columns. Press **Mine** to automatically designate mining on suitable columns and chopping on standing trees in the area. Blocks under **living colonists or standing trees** are never mined. Once a tree is cut or a colonist moves away, the block can be designated again. Any already-queued job rechecks protection before mining.
- The three in-game colonists start with distinct occupations: **Miner, Woodcutter, Hauler**. Tap **Worker** to cycle the selected character; choose a role in the adjacent **Job** menu. A role change clears their previous reservation and returns any carried resources to the work queue. Each worker is limited to one active job at a time.
- Worker roles, excavation requests, felling history, mine/chop orders, stockpile and terrain remain locally saveable. Old saves without a worker-roles field get the default roles.
- This is a prototype: if no walkable path exists, deep excavations can remain blocked until an access/ramp system is implemented. Godot CI and physical Android UX are tracked separately.

## Continuous colonist movement (development)

The colony now advances one navigable cell every 0.25 simulation seconds instead of one cell per second, with matching render interpolation and eased facing. Miners play their available Punch clip during a 0.75-second work phase, and carriers use the existing Walk_Hold animation. The simulation remains deterministic, offline, grid-based and collision-aware, with brief yielding when another colonist occupies the next cell. These changes are committed for validation and Android visual review; they do not alter the imported humanoid GLTF models.

## CI and Android APK

[GitHub Actions](https://github.com/joparoxxx/VOXHAVEN/actions) contains two separate workflows:

1. **Godot validation** — automatically runs on selected gameplay/asset/test changes to `game/colony-foundation`; imports assets and executes scene/data/AI tests. [View workflow runs](https://github.com/joparoxxx/VOXHAVEN/actions/workflows/godot-validation.yml).
2. **Android prototype APK** — manually dispatched debug export using Godot 4.5.1 and Android ARM64. [View APK runs](https://github.com/joparoxxx/VOXHAVEN/actions/workflows/android-build.yml).

**Validation snapshot (November 28, 2026):** Godot validation for `83cc578` (unified Mine, job roles, protected roots) passed [run #46152304537](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46152304537): assets, terrain, mining/hauling, woodcutting, excavation depth, role persistence and rendered smoke tests. Android ARM64 debug export passed [run #46152358440](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46152358440) on `caf5396`, which changes only the APK workflow trigger after the validated gameplay commit. The debug artifact is `voxhaven-android-debug`. Physical device behavior and performance remain unverified.

For a trustworthy release candidate, require passing Godot imports/tests for the exact commit, a successful Android debug export for that same commit, verified artifact availability, and separate physical-device performance/interaction testing.

## Design, assets and contribution rules

The approved direction is an offline humanoid colony simulator—not the older Cubot/battery-based concept. The included Cube World subset contains **107 GLTF models plus `Atlas.png` and `Blocks_PixelArt.png`**. Gameplay terrain uses the owner's preferred **`Pixel Blocks/` + `Blocks_PixelArt.png`** tiles. A small spatial shader softens hard pixel edges with mipmap filtering and lowers color contrast/saturation while preserving the texture. Trees retain adjusted scale and character models remain unchanged. The repository's wider asset catalog reports **1,076 GLB/glTF files across 14 packs**; counts include animation assets and do not necessarily indicate unique models.

See [assets/ASSET_CATALOG.txt](assets/ASSET_CATALOG.txt) and [assets/CREDITS.md](assets/CREDITS.md) for provenance and credits. Retain bundled third-party licensing files. Asset licenses do not automatically license the complete game.

Anyone continuing development should read [AGENTS.md](AGENTS.md), [the autonomous development skill](.agents/skills/voxhaven-development/SKILL.md), [the current checkpoint](docs/AGENT_STATE.md) and [the master plan](docs/GAME_MASTER_PLAN.md). Work **only in `game/colony-foundation`**, preserve unrelated changes, validate actual outcomes, and do not merge to `main` or publish a release without explicit owner authorization.
