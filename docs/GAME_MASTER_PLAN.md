# Voxhaven — Master game plan

Current approved design; implementation and balance remain unverified. Historical robot plans are preserved in Git history, not active requirements.

## Current approved direction — 2026-11-26
Voxhaven is a fully offline Minecraft-inspired 3D colony simulator for Android. KayKit humanoid characters replace Cubots as the primary colonists; exact character selection follows rig and animation tests. Preserve legacy branches and plans for reference, but do not treat robot batteries, charging, robot manufacturing or mechanical slots as current requirements. No Gemini, cloud AI, API keys, external LLM or mandatory network service. Use Godot 4 and local deterministic simulation.

### Living colony AI
- Perception: bounded spatial queries and event-driven awareness.
- Memory: bounded local records of locations, events, relationships and task outcomes; persist relevant records.
- Personality and needs: hunger, thirst, stamina, health, happiness, traits, preferences, skills, experience, goals and relationships.
- Utility AI: score feasible goals from needs, danger, personality and colony priorities; use hysteresis and emergency overrides.
- GOAP: bounded planning for multi-step goals; reserve resources and jobs, replan on invalidation, avoid infinite retries.
- Behavior trees and state machines: execute movement, gathering, hauling, crafting, construction, eating, resting and combat with explicit failure/cancellation handling.
- Local navigation: chunk-aware A* or suitable Godot navigation, invalidate routes after terrain edits, stagger path requests.
- Procedural dialogue and skill progression: local templates and gameplay rules, not an LLM.
- Performance: stagger decision ticks, cap planning work, simplify distant agents, keep simulation independent of rendering. Profile on Android before increasing population.

### Gameplay and assets
Start with a proposed three colonists and storage area in a safe seeded world. Assign mining and woodcutting, haul resources, build a house, then expand to farming, crafting, survival, exploration and technology. Replace battery-centric needs with biological needs. Adapt equipment to humanoid rigs (head, body, primary tool, secondary tool, footwear and backpack proposed); retain offline crafting, rarity and enhancement concepts subject to balance. Fantasy Town and Furniture Bits are initial building candidates; Space Base and Factory Kit are later technology candidates. Exact asset mapping remains pending audit. Do not generate new GLBs yet.

### Current asset inventory
Commit 90e266103900ee7bdb2942d49d154896eb26a517 uploaded 485 additional model files: Mini-Game Variety 134, Adventurers 39, Character Animations 16, Furniture 53, Skeletons 19, Space Base 57, Fantasy Town 167. Total 1,076 GLB/glTF files across 14 packs, approximately 50 MB on disk. User's Termux import reported zero dependency errors and included CC0 license checks. These counts include animation files and are not necessarily unique meshes. Godot import, rig compatibility and runtime performance are unverified. 45 standalone models and Holiday Bits remain local/pending provenance or license verification.

### Implementation order (supersedes historical roadmap)
1. Create a clean Godot 4 project from main on a development branch. Audit the asset catalog only; do not reuse legacy project code, scenes, UI, AI or build configuration.
2. Create data-driven asset registry and Godot smoke scene; validate representative terrain, humanoid rigs, animation clips, tools and buildings, materials, scale and pivots.
3. Implement deterministic voxel chunks, block registry, edits, collision, navigation invalidation and save/load tests.
4. Implement small offline colony vertical slice: three colonists, job reservations, utility selection, bounded planning and execution, mining/woodcutting, hauling and storage.
5. Add construction and needs, then farming, crafting, equipment, relationships, exploration and progression incrementally.
6. Test headless logic, smoke scenes, Android build and physical-device performance separately. Initial target 30 FPS; 60 FPS optional subject to profiling. No implementation or test success claims without evidence.

### Clean-slate development decision (owner approved)
Start a new Godot 4 project from main. Do not migrate or reuse any legacy Godot source, scenes, project settings, UI, AI, persistence or robot mechanics from stable/debug-85 or other old branches. Preserve those branches untouched as historical archives. Reuse only the approved asset library, asset catalog, credits/licenses and current game design documentation. This decision supersedes every earlier instruction to audit or reuse legacy code. Build fresh tests and Android configuration. No new GLB generation at this stage.

## Official branding
Game title: Voxhaven. Repository: joparoxxx/VOXHAVEN. Proposed Android application ID: com.urfavxbf.voxhaven. AI architecture name: Living Colony Engine. Tagline: Build a world. Grow a civilization. Historical Cubyte references refer to this same project before rebranding. Trademark availability has not been verified.

## Approved procedural voxel world and terrain
Use Minecraft-inspired deterministic seed-based procedural generation, not a prebuilt map. Voxhaven is a colony management game: autonomous colonists mine, haul, excavate, level terrain, build roads and factories. Use Godot FastNoiseLite for elevation, temperature, moisture, cave and ore fields; generate contiguous biomes and deposits using world coordinates. Start in a safe accessible grassland with reachable resources. Use 16×16 horizontal chunks with bounded vertical sections, streaming and background data generation; apply mesh/physics updates safely on the main thread. Render exposed faces in chunk meshes (greedy meshing where compatible with texture UVs), not one node per block. Use MultiMesh for suitable decorations, shared materials, chunk-local collision and navigation, and rebuild affected chunks and neighbors after edits. Preserve seed, generator version and modified blocks in local saves. Keep offscreen simulation bounded and profile on Android.

### Existing block inventory (40 models)
Source: assets/ASSET_CATALOG.txt and assets/library/KayKit_BlockBits_1.0_FREE; all names below are .gltf files.
- Natural terrain (18): grass, dirt, dirt_with_grass, dirt_with_snow, grass_with_snow, gravel, gravel_with_grass, gravel_with_snow, sand_A, sand_B, sand_with_grass, sand_with_snow, snow, stone, stone_dark, tree, tree_with_snow, wood.
- Mineral deposits (3): stone_with_copper, stone_with_silver, stone_with_gold.
- Liquids (2): water, lava.
- Construction (4): bricks_A, bricks_B, glass, metal.
- Industrial (12): colored_block_blue/green/red/yellow, decorative_block_blue/green/red/yellow, striped_block_blue/green/red/yellow.
- Development (1): prototype (testing and placement previews).
Use a stable block ID registry with properties for solidity, mining hardness, required tool, drops, hazard and rendering. Inspect actual geometry, scale, pivots, textures and licenses before integration. Trees may be separate decorations rather than solid terrain cubes.

### Biomes and underground
Six approved biome directions: grasslands (grass/dirt), forest (grass/tree/wood), desert (sand variants), frozen lands (snow and snowy variants), rocky mountains (stone/gravel), volcanic lands (dark stone/lava). Water for lakes and rivers; blend boundaries using available mixed blocks. Underground layers: surface, soil, stone, deep dark stone; caves and clustered ore deposits. Proposed progression: copper common, silver uncommon, gold rare, with harder/deeper deposits requiring upgraded tools. Exact depths, rarity and hardness remain provisional. Iron, titanium, coal and energy crystal lack dedicated terrain ore models; reuse existing stone geometry with material variations after inspection, without generating new GLBs at this stage. Existing iron resource models can represent drops. Liquid flow is not required for the initial prototype.

### Gameplay and acceptance
Mining removes blocks and yields physical resources through inventory transactions; colonists reserve jobs, navigate to reachable faces, haul drops, and update paths after terrain edits. Construction places blocks with occupancy and support checks as appropriate. Use existing KayKit Resource Bits and RPG Tools Bits for drops and equipment, Kenney Factory Kit for production lines. Test deterministic seeds, chunk seams, ore distribution, safe spawn, mining/placement, save/load round trips, collision and navigation invalidation, and mobile frame time/memory. Implement a small playable graybox before expanding world size. Integrate terrain foundation before construction and exploration roadmap stages.

