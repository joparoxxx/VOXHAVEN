# Cubyte — Master game plan
Status: approved product direction; implementation and balance not verified.
This document supersedes legacy AI-office product specifications where they conflict. Read it before any gameplay work.

## Product
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
