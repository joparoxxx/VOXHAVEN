# Voxhaven

**Build a world. Grow a civilization.**

Voxhaven is an in-development, offline-first 3D colony simulator for Android, built with Godot 4. Explore a Minecraft-inspired procedural voxel world and grow a settlement of autonomous humanoid colonists.

> Early development: the asset library and initial Godot foundation are available. Gameplay, Android builds and runtime performance are not yet verified.

## Game vision

- Seed-based voxel worlds with six biome types, caves and mineral deposits.
- Mining, woodcutting, hauling, storage, construction, farming and crafting.
- Colonists with biological needs, personalities, memories, skills and relationships.
- Offline equipment crafting, rarity, enhancement and technology progression.
- Touch-friendly 3D camera and mobile-oriented rendering.

These are planned features, not a list of completed gameplay systems.

## Living Colony Engine

The planned local AI architecture combines bounded perception and memory, Utility AI goal selection, GOAP planning, behavior trees and state machines, chunk-aware navigation and procedural dialogue. Simulation work will be staggered and bounded for mobile performance.

No cloud AI, Gemini, external LLM, API key or mandatory network connection is required by the game design.

## Technology

| Component | Direction |
| --- | --- |
| Engine | Godot 4.5.1 (initial validation version) |
| Language | GDScript |
| Rendering | Compatibility |
| Platform | Android ARM64 |
| World | Deterministic 16×16 horizontal voxel chunks |
| Performance | Initial 30 FPS target; optional 60 FPS after profiling |
| Application ID | com.urfavxbf.voxhaven |

## Development status

| Milestone | Status |
| --- | --- |
| Asset library | 1,076 GLB/glTF files across 14 packs uploaded; Cube World subset includes 107 GLTF models and two atlases |
| Clean Godot project and asset registry | Implemented on game/colony-foundation; validation pending |
| Asset lab and smoke tests | Implemented; validation pending |
| Android export preset | Configured; APK build unverified |
| Procedural world and colony simulation | Prototype implemented on game/colony-foundation; runtime validation pending |
| Gameplay and device profiling | Phase 4.1 mining designations and autonomous mining prototype implemented; CI pending |

The asset count includes animation files and does not represent unique meshes. See the [asset catalog](assets/ASSET_CATALOG.txt) and [credits](assets/CREDITS.md) for inventory and attribution. Preserve bundled third-party licenses; the asset licenses do not establish a license for the entire game.

## Getting started

The playable foundation is not yet merged into main. To inspect the current development project:

```bash
git clone --branch game/colony-foundation https://github.com/joparoxxx/VOXHAVEN.git
cd VOXHAVEN
```

Open project.godot in Godot 4.5.1 and allow asset imports to finish. The main scene now opens the voxel world prototype; the asset lab is still available for smoke validation.

See the [foundation notes](https://github.com/joparoxxx/VOXHAVEN/blob/game/colony-foundation/docs/FOUNDATION.md) for test commands and [GitHub Actions](https://github.com/joparoxxx/VOXHAVEN/actions) for validation results.

## Current Cube World integration

The `game/colony-foundation` branch contains all 107 Cube World GLTF files and both atlas textures. Colonists now cycle through four humanoid variants with embedded Idle and Walk animations. Terrain meshes reference Cube World's pixel block atlas; terrain variants without dedicated texture tiles reuse and tint verified Cube World pixels. This is a visual prototype, not final biome or ore artwork.

Godot import, scene smoke, animation runtime and APK output for these new commits are pending workflow validation; do not treat code inspection as a completed build.

A first mining-job vertical slice now lets players designate solid blocks for colonists to mine. Work reservations, safe-adjacent stand positions, pending designation persistence and unhauled drops are in progress and require CI verification. Woodcutting, hauling and storage are not implemented.

## Roadmap

1. Validate assets, rigs, materials and Android export.
2. Implement procedural terrain, chunk streaming, block edits and persistence.
3. Implement autonomous colonists, job reservations, gathering and storage.
4. Add construction, needs, farming and crafting.
5. Expand equipment, relationships, exploration and technology.
6. Profile and polish on physical Android devices.

## Repository organization

- **main** — approved design documentation and asset library.
- **game/colony-foundation** — fresh Godot implementation and tests.
- Historical branches — preserved for reference; legacy game code is not reused.

Read the [Game Master Plan](docs/GAME_MASTER_PLAN.md) before contributing. Its latest approved humanoid direction and clean-slate decision supersede historical robot-specific sections.
