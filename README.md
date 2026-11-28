# Voxhaven

**Build a world. Grow a civilization.**

Voxhaven is a **work-in-progress, fully offline 3D colony simulator for Android**, developed with Godot 4 and GDScript. The goal is a seeded, Minecraft-inspired voxel world where humanoid colonists independently gather resources, build a settlement, and manage their needs.

> **Development preview — not a finished game.** The unified Mine/woodcut workflow, one-job-per-colonist occupations, tree-support protection, and compact toolbar passed [Godot validation #46152304537](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46152304537) on commit `83cc578`. The [Android ARM64 debug APK build #46152358440](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46152358440) succeeded from the same gameplay code; the later commit only updates its workflow trigger. Actual Android touch input, layout, framerate and animation smoothness still need device verification.

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


### Mining protection (no gravity) and 3D-viewer camera

- **Strict top-down mining:** the planner queues the highest remaining terrain first.
- **Mining safety instead of gravity:** there is no automatic falling physics. A block cannot be designated, reserved or removed if a living colonist stands anywhere above it in the same column. Standing Cube World trees likewise protect the supporting block and deeper column until they are chopped. Previously queued jobs recheck protection at the moment of mining, so moving onto a target mid-job does not remove the floor.
- **Camera ON:** a 3D-object-viewer style camera. One-finger drag orbits (yaw/pitch), a tap sets the fixed orbit pivot, two-finger drag pans and pinch zooms. There is **no automatic follow** of a colonist.
- **Camera OFF:** gameplay tap commands and Select gestures are active; dragging pans the camera when not selecting.
- Desktop: right-drag orbit, left-drag pan or select, mouse wheel zoom. Reset via Tools → Reset Camera.
- **Camera-lag regression fix:** original zoom limits 12–48 restored; pinch uses absolute two-finger distance so two-finger translation does not repeatedly zoom, and camera transforms plus chunk-window checks are coalesced to at most once per rendered frame instead of every input event. Camera ON still orbits and OFF keeps normal game tools. Idle camera follow remains removed.
- **Original 16 × 16 chunk streaming retained:** the prior zoom-based loading/unloading radius 2–4 (5×5–9×9 chunks) is intact. No mobile-only cap, mesher or unload-policy change. Only independent FPS reductions—4 Hz HUD refresh and event-driven excavation updates—are applied. Phone FPS remains unmeasured; compare in-game FPS before/after with the same save, position, zoom and simulation speed.

### Idle FPS diagnostics (gravity removed)

The HUD shows **FPS, Chunks, Queue, Mesh busy/idle and AI/s**. Gravity/s has been removed because the game no longer runs support probes or falling physics.

- **Queue > 0 / Mesh BUSY:** 16×16 chunk meshes/collisions are being generated, potentially affecting FPS.
- **Queue 0 / Mesh idle, but FPS still low:** investigate rendering, GPU or other simulation work.
- **AI/s:** number of worker job searches per real-time second.

The separate 16×16 chunk-generation optimization retains the same deterministic voxel output, and the original zoom-based 2–4 chunk loading/unloading radius remains unchanged. Physical-device FPS gains remain unverified.

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
