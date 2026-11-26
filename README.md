# Cubyte

Offline-first 3D Android robot colony simulation game.

## Game direction
Build a colony, collect resources, assign Cubots to simulated jobs, manufacture new robots, upgrade equipment and unlock new areas. No real project generation, AI providers, API keys or terminal execution are required.

## MVP
- Preserve existing Cubot assets: rounded cube bodies, flush digital faces, small arms and hovering thrusters.
- Isometric touch camera, placement grid and modular buildings.
- Energy, ore and parts economy; mining, hauling, manufacturing and charging jobs.
- Deterministic local simulation, autonomous movement, job reservations and local save/load.
- Android performance settings and offline play.

## Implementation order
1. Audit existing renderer and assets; isolate legacy productivity features.
2. Implement simulation state and resource transactions with tests.
3. Connect Cubot navigation, jobs and visual states to simulation.
4. Add construction, progression and touch UI.
5. Verify offline gameplay, save recovery and Android performance.

References: The Colonists (colony management), Autonauts (automation), Pocket Build (touch building). Use original assets and mechanics; verify licenses before reusing third-party code.

This branch defines the new direction; gameplay implementation is not yet complete.
