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
| Engine | Godot 4.4.1 (initial validation version) |
| Language | GDScript |
| Rendering | Compatibility |
| Platform | Android ARM64 |
| World | Deterministic 16×16 horizontal voxel chunks |
| Performance | Initial 30 FPS target; optional 60 FPS after profiling |
| Application ID | com.urfavxbf.voxhaven |

## Development status

| Milestone | Status |
| --- | --- |
| Asset library | 1,076 GLB/glTF files across 14 packs uploaded |
| Clean Godot project and asset registry | Implemented on development branch; validation pending |
| Asset lab and smoke tests | Implemented; validation pending |
| Android export preset | Configured; APK build unverified |
| Procedural world and colony simulation | Planned |
| Gameplay and device profiling | Pending |

The asset count includes animation files and does not represent unique meshes. See the [asset catalog](assets/ASSET_CATALOG.txt) and [credits](assets/CREDITS.md) for inventory and attribution. Preserve bundled third-party licenses; the asset licenses do not establish a license for the entire game.

## Getting started

The playable foundation is not yet merged into main. To inspect the current development project:

```bash
git clone --branch game/colony-foundation https://github.com/joparoxxx/VOXHAVEN.git
cd VOXHAVEN
```

Open project.godot in Godot 4.4.1 and allow asset imports to finish. The initial scene is an asset lab, not a complete game.

See the [foundation notes](https://github.com/joparoxxx/VOXHAVEN/blob/game/colony-foundation/docs/FOUNDATION.md) for test commands and [GitHub Actions](https://github.com/joparoxxx/VOXHAVEN/actions) for validation results.

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
