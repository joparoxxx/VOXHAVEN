# Voxhaven

**Build a world. Grow a civilization.**

Voxhaven is a **work-in-progress, fully offline 3D colony simulator for Android**, developed with Godot 4 and GDScript. The goal is a seeded, Minecraft-inspired voxel world where humanoid colonists independently gather resources, build a settlement, and manage their needs.

> **Development preview — not a finished game.** Core gameplay, autonomous woodcutting, hauling and visible stockpile passed [Godot validation #46147714951](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46147714951) on commit `3215bcc`. The [Android debug APK build #46147531755](https://github.com/joparoxxx/VOXHAVEN/actions/runs/46147531755) succeeded for the same gameplay code (the subsequent commit changed only a test). Physical Android gameplay, visuals and performance still need testing.

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
| Mining and excavation | Single-block Mine, drag/two-tap Select, bounded Dig Depth (1–8), staged shallow-first area mining with save/load | Deep pits may require accessible ramps or stairs; full underground pathfinding is not implemented |
| Resources | Mining and tree chopping create distinct stone/block and wood resource records | Resource drops are still logical records rather than world item meshes |
| Hauling and storage | Autonomous pickup/delivery to a visible Cube World crate stockpile with relocatable ground pad and per-resource counts | Initial prototype has one stockpile and no capacity, building, or full inventory UI |
| Save/load | Seed, terrain edits, mining/woodcut designations, felled-tree state, unhauled items, stock and stockpile position | Colonist state and full simulation recovery remain pending |

These entries describe **prototype functionality**, supported by passing automated checks. CI validation does not substitute for Android device gameplay, touch controls, screenshots or performance testing.

## Roadmap — current Phase 4 focus

| Phase | Milestone | Status |
| --- | --- | --- |
| 4.0 | Cube World terrain, characters and asset integration | Implemented in source; validation pending |
| 4.1 | Block selection and mining designations | Prototype implemented; validation pending |
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
```

These are commands to **run**, not claims that the latest commit has passed them. The full [Godot validation workflow](.github/workflows/godot-validation.yml) also checks registry, mesh generation, decoration, Cube World textures, character animation imports and a rendered world smoke scene.

### Prototype controls

- **Mine:** tap a solid block (or right-click with a mouse) to designate it for autonomous mining; tap again to cancel a designation.
- **Place:** tap a surface to place a dirt block.
- **Chop:** tap the ground directly beneath a Cube World tree to mark/unmark a woodcutting job. Colonists navigate, chop, produce wood, and autonomously haul it.
- **Stockpile:** tap walkable ground to place or relocate the visible storage area (the existing stock moves with it in this prototype). Colonists carry drops here; the crate label shows total stock and wood count.
- **Save:** write terrain edits, mining/woodcut tasks, harvested trees, stockpile location and stored/unhauled items to local user storage.
- **Camera:** drag to pan, pinch or use +/− to zoom; buttons provide rotation and focus.
- **Colonists:** cycle the selected colonist and inspect basic needs/status; use the simulation-speed button to pause or accelerate time.

The UI and multitouch input are prototypes; physical Android device testing remains outstanding.

## Select, Dig and editing tools

The mobile toolbar now includes **Pan, Select, Dig, Chop Area, Mine, Chop, Stockpile, Place, Inspect, Cancel, Save**, and camera zoom controls.

1. Tap **Select**, then touch two top-face corners of the area, or drag one finger across the ground. The translucent preview shows the footprint; amber warns when too large.
2. Use **Depth - / Depth +** to choose **1–8 block layers downward**. Tap **Dig** to queue the selected ground columns. Each selection is capped at **64 cells** (and at most 64 managed columns total); only 12 mining jobs are active simultaneously.
3. The planner queues accessible surface layers before deeper ones. Mining remains a physical colonist activity—**it does not instantly remove terrain**. Deep/vertical pits can pause when no walkable route exists. A future stair/ramp tool is required for guaranteed deep excavation.
4. **Chop Area** designates trees within a selection; **Inspect** shows block coordinates/type; **Cancel** cancels tasks across a selection, or lets you tap an individual designation. **Pan** restores single-finger camera drag. Existing Mine, Chop, Stockpile, Place, Save and camera controls remain.
5. Excavation goals and current mining designations are saved in the local version-1-compatible world file. The visual selection itself is temporary.

## Continuous colonist movement (development)

The colony now advances one navigable cell every 0.25 simulation seconds instead of one cell per second, with matching render interpolation and eased facing. Miners play their available Punch clip during a 0.75-second work phase, and carriers use the existing Walk_Hold animation. The simulation remains deterministic, offline, grid-based and collision-aware, with brief yielding when another colonist occupies the next cell. These changes are committed for validation and Android visual review; they do not alter the imported humanoid GLTF models.

## CI and Android APK

[GitHub Actions](https://github.com/joparoxxx/VOXHAVEN/actions) contains two separate workflows:

1. **Godot validation** — automatically runs on selected gameplay/asset/test changes to `game/colony-foundation`; imports assets and executes scene/data/AI tests. [View workflow runs](https://github.com/joparoxxx/VOXHAVEN/actions/workflows/godot-validation.yml).
2. **Android prototype APK** — manually dispatched debug export using Godot 4.5.1 and Android ARM64. [View APK runs](https://github.com/joparoxxx/VOXHAVEN/actions/workflows/android-build.yml).

**Validation snapshot (November 28, 2026):** The latest gameplay commit inspected was `3ea8f55` (mining/resource logistics); its Godot validation was **in progress**, not passed. An older Android APK workflow succeeded on commit `993916f` on November 27, **not** on the latest gameplay commit. Check the linked workflow history for newer outcomes. An APK from an older commit does not validate current features.

For a trustworthy release candidate, require passing Godot imports/tests for the exact commit, a successful Android debug export for that same commit, verified artifact availability, and separate physical-device performance/interaction testing.

## Design, assets and contribution rules

The approved direction is an offline humanoid colony simulator—not the older Cubot/battery-based concept. The included Cube World subset contains **107 GLTF models plus `Atlas.png` and `Blocks_PixelArt.png`**. Gameplay terrain uses the owner's preferred **`Pixel Blocks/` + `Blocks_PixelArt.png`** tiles. A small spatial shader softens hard pixel edges with mipmap filtering and lowers color contrast/saturation while preserving the texture. Trees retain adjusted scale and character models remain unchanged. The repository's wider asset catalog reports **1,076 GLB/glTF files across 14 packs**; counts include animation assets and do not necessarily indicate unique models.

See [assets/ASSET_CATALOG.txt](assets/ASSET_CATALOG.txt) and [assets/CREDITS.md](assets/CREDITS.md) for provenance and credits. Retain bundled third-party licensing files. Asset licenses do not automatically license the complete game.

Anyone continuing development should read [AGENTS.md](AGENTS.md), [the autonomous development skill](.agents/skills/voxhaven-development/SKILL.md), [the current checkpoint](docs/AGENT_STATE.md) and [the master plan](docs/GAME_MASTER_PLAN.md). Work **only in `game/colony-foundation`**, preserve unrelated changes, validate actual outcomes, and do not merge to `main` or publish a release without explicit owner authorization.
