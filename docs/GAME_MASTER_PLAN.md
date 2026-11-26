# Cubyte — Master game plan
Status: approved offline humanoid colony direction (2026-11-26); implementation and balance not verified. The latest direction below takes precedence over all historical robot-specific sections.
This document supersedes legacy AI-office product specifications where they conflict. Read it before any gameplay work.

## Historical robot product direction (superseded)
Offline-first native Android 3D robot colony simulator. No real project generation, AI providers, API keys, terminal execution, accounts or mandatory servers. References: The Colonists (colony management), Autonauts (automation), Pocket Build (touch building). Original assets; verify third-party licenses.

## Technical foundation
Godot 4 / GDScript, Compatibility renderer initially. Existing game source is on stable/debug-85; game/colony-simulator is the earlier direction branch. Audit and reuse stable code where suitable; isolate legacy AI, artifact and productivity systems. Separate simulation, persistence and presentation. Graybox first, deterministic local simulation, touch camera, placement grid, job reservations, navigation/collision, local save/load and recovery. Android target initially 30 FPS, optional 60 FPS subject to device profiling.

## Core loop
Start with a small base and one Cubot. Collect energy, ore and mechanical parts; mine, haul, charge, manufacture, build and expand. Craft new robots, assign simulated jobs, upgrade equipment, unlock technology and explore new areas. Include missions and rewards, autonomous behavior, personality, emotions and relationships. Modular buildings, charging stations, storage, manufacturing and resource nodes. Isometric rotatable zoomable camera, stylized low-poly 3D, smooth animation, dynamic lighting and sound.

## Approved Cubot design
Latest user image 74134.jpg supersedes floating/rolling designs: rounded cube body, recessed/flush digital face with animated expressions, two articulated mechanical arms with functional hands, two mechanical legs and feet. Walking and running, no rocket propulsion. Shared modular rigged GLB with interchangeable colors, accessories and equipment. Classes: Miner, Builder, Engineer, Transporter, Explorer. Equipment visible on model; work animations use equipped tools. Reference image is not yet a rigged asset and is not embedded in this document.

## Equipment
Six slots: head module, body armor, primary tool, secondary tool, leg module, backpack/battery.
Stats: Power (mining/tool strength), Speed (movement), Efficiency (work speed), Capacity (carry), Energy (battery capacity), Durability (damage/wear resistance), Luck (rare materials), Intelligence (simulated advanced automation).
Provisional examples:
- Titanium Drill (Rare): +25 mining power, +15% mining speed, +10% energy consumption.
- Quantum Battery (Epic): +100 energy capacity, +20% charging speed.
- Hydraulic Legs (Uncommon): +15% movement speed, +10 carry capacity.
- Titan Exoshell (Legendary): +80 durability, +30 carry capacity, -5% movement speed.
- Quantum Processor (Mythic): +40 intelligence, +25% work efficiency.
Rarity multipliers (provisional): Common 1.0, Uncommon 1.2, Rare 1.5, Epic 1.8, Legendary 2.2, Mythic 2.8. Avoid double-counting rarity bonuses; balance via playtesting.
Sample loadout baseline: mining power 20, energy 100, movement speed 100%, carry 20. Basic Pickaxe +5 power; Plasma Drill +45; Advanced Battery +50 energy; Turbo Legs +30% movement and +5 carry. Examples are not final balance.
Crafting, enhancement up to +10, repair, rare material drops, set bonuses, technology tree. All equipment obtainable offline through gameplay.

## Implementation roadmap
1. Audit stable branch and assets, migrate reusable Godot foundation into development branch.
2. Implement tested resource transactions, simulation ticks, inventory, energy and save/load.
3. Implement Cubot navigation, jobs, reservations, charging and visual state.
4. Implement construction, placement validation, modular buildings and touch UI.
5. Implement equipment slots, stat calculations, crafting, enhancement, repair and progression.
6. Add exploration, missions, personalities, relationships and technology unlocks.
7. Build approved modular walking GLB, animations and visible equipment; polish UI, sound and graphics.
8. Run headless tests, smoke scene, Android APK build and physical-device profiling; report each separately.
Do not claim features complete without verification. Use development branches for code; main contains approved planning reference. Update this plan when owner approves changes.

## Approved structure asset direction
Use existing KayKit Space Base Bits as the primary structure and environment asset pack: https://kaylousberg.itch.io/kaykit-space-base-bits . Do not generate new GLB models at this stage. Obtain original free pack, verify bundled license, inspect actual model inventory, scale, pivots, materials and Android performance before importing. Preserve original license and provenance. Proposed structures: Command Center, Charging Station, Storage Depot, Mining Station, Refinery, Cubot Factory, Equipment Workshop, Solar Generator, Fusion Reactor, Energy Bank, Power Relay, Research Lab, Radar Tower, Maintenance Bay, Recreation Hub. Target five upgrade levels with visual progression; map available assets to functions before commissioning missing models. Asset selection approved; binary import and testing pending.

## Equipment enhancement and asset reuse
All equipment slots support enhancement +0 through +10 independently of rarity. Use Equipment Workshop and offline mined/crafted resources. Proposed positive-stat bonus percentages by level: 0,5,10,15,20,30,40,50,65,80,100. Do not automatically amplify penalties or energy consumption. Proposed material progression: iron (+1–2), copper (+3–4), steel (+5), steel (+6), titanium (+7–8), energy crystal (+9), quantum core (+10). No real-money purchases or destruction on upgrade. Visual milestones: standard +0–2, reinforced +3–4, mechanical attachments +5–6, energy accents +7–9, animated energy effects +10. Reuse existing free models, materials and attachments rather than generating separate GLBs per level. Candidate packs: KayKit RPG Tools Bits, KayKit Resource Bits, kernelCAD Tools & Equipment; verify original licenses and model inventory before import. Exact stat curves and costs are provisional pending playtesting; implementation and asset import pending.

## Approved procedural voxel world and terrain
Use Minecraft-inspired deterministic seed-based procedural generation, not a prebuilt map. Cubyte remains a colony management and factory automation game: autonomous Cubots mine, haul, excavate, level terrain, build roads and factories. Use Godot FastNoiseLite for elevation, temperature, moisture, cave and ore fields; generate contiguous biomes and deposits using world coordinates. Start in a safe accessible grassland with reachable resources. Use 16×16 horizontal chunks with bounded vertical sections, streaming and background data generation; apply mesh/physics updates safely on the main thread. Render exposed faces in chunk meshes (greedy meshing where compatible with texture UVs), not one node per block. Use MultiMesh for suitable decorations, shared materials, chunk-local collision and navigation, and rebuild affected chunks and neighbors after edits. Preserve seed, generator version and modified blocks in local saves. Keep offscreen simulation bounded and profile on Android.

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
Mining removes blocks and yields physical resources through inventory transactions; Cubots reserve jobs, navigate to reachable faces, haul drops, and update paths after terrain edits. Construction places blocks with occupancy and support checks as appropriate. Use existing KayKit Resource Bits and RPG Tools Bits for drops and equipment, Kenney Factory Kit for production lines. Test deterministic seeds, chunk seams, ore distribution, safe spawn, mining/placement, save/load round trips, collision and navigation invalidation, and mobile frame time/memory. Implement a small playable graybox before expanding world size. Integrate terrain foundation before construction and exploration roadmap stages.

### Asset library status
Main commit abed57f added 591 catalogued models across seven packs: Block Bits 40, Dungeon 211, Fantasy Weapons 31, Mixed Bag 41, RPG Tools 49, Resource Bits 76, Kenney Factory Kit 143. This supersedes earlier statements that all asset imports are pending: repository upload is complete, Godot integration and runtime validation remain pending. Holiday Bits excluded pending license verification; Space Base Bits not yet uploaded. Preserve licenses and original dependencies. No new GLBs commissioned. This section records approved direction, not completed implementation.


## Current approved direction — 2026-11-26
Cubyte is a fully offline Minecraft-inspired 3D colony simulator for Android. KayKit humanoid characters replace Cubots as the primary colonists; exact character selection follows rig and animation tests. Preserve legacy robot code and plans for reference, but do not treat robot batteries, charging, robot manufacturing or mechanical slots as current requirements. No Gemini, cloud AI, API keys, external LLM or mandatory network service. Use Godot 4 and local deterministic simulation.

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
