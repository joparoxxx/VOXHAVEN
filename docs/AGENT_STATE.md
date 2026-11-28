# VOXHAVEN agent checkpoint

Active development branch: game/asset-integration (verify actual HEAD before work).
Current assigned milestone: Phase 4.0–4.9.
Last owner-supplied gameplay checkpoint: 585be97c8ba3b77b86b722f08b4cb6fd31ddd5a2 (Cube World colonist idle/walk integration, commit inspected).
Instruction installation commits: 5635f38bd7f2c9fba40b258077b58928b77afb68, 19ad570c77402f9dfc95eb47d03a0c7faf525486.
Owner reports 107 Cube World GLTF assets, two atlases, updated catalog and trees; full runtime integration not verified.

## Remaining acceptance criteria (audit before marking complete)
- 4.0 Cube World terrain and asset integration
- 4.1 Block selection and mining designation
- 4.2 Autonomous mining and woodcutting
- 4.3 Resource drops and inventory
- 4.4 Hauling and storage
- 4.5 Construction and blueprints
- 4.6 Colonist equipment and tools
- 4.7 Farming, food and drinking
- 4.8 Day/night cycle
- 4.9 Animals and wildlife

Tests/build: NOT RUN for documentation installation. No gameplay changes in this batch. CI workflows are manual; inspect current workflow and available runner access. No verified APK or physical-device performance results in this batch.
Next exact task: inspect current development HEAD, terrain registry, atlas mapping, world renderer, asset references and existing tests; finish outstanding 4.0 integration before advancing. Update this checkpoint after each meaningful batch; main is the entry point, development branch holds live implementation state.

## 2026-11-28 implementation checkpoint
- Commit deb20fa7e8fd818a9844eb6ed21dbd8f10f2ee7f on game/asset-integration: Mine taps now create or cancel highlighted block designations instead of instantly deleting terrain; placement clears a designation at the edited position; UI reports queued designation count.
- Static code inspection only. Godot parse, scene smoke, automated tests, Android build and physical device tests: NOT RUN. Mining designations are currently session-only and are not yet consumed by colony AI. Phase 4.1 is partial, not complete.
- Next: persist mining designations, implement bounded colonist job reservation and path-to-work execution, then resource drops/hauling. Validate Godot parsing and runtime before declaring functionality verified.

## 2026-11-28 Cube World asset audit
- Verified Quaternius_Cube_World/Environment/Tree_1.gltf, Tree_2.gltf, Tree_3.gltf exist on game/asset-integration. Registered all three in assets/ASSET_CATALOG.txt at commit 54be5d7d8101655122f5d0e088b66d5274ef6314.
- Current colony/colonist_view.gd still uses KayKit Adventurers. Historical commit 585be97 references Quaternius_Cube_World/Characters/Character_Male_1.gltf, but that exact file returned NOT_FOUND on current branch. Do not restore its preload until asset path is verified.
- world/terrain_atlas.gd and world/world_view.gd still use KayKit BlockBits textures and models. Replacement terrain atlas/UV mapping requires verifying actual Cube World texture files and mapping before switching.
- Static repository inspection only; Godot imports, runtime rendering, Android builds: NOT RUN. Asset replacement remains incomplete.

## 2026-11-28 Colonist character loader update
- Commit edbecc1f34c9055d2beb53d4f318cf086c1e8516 updates colony/colonist_view.gd to discover importable Cube World GLTF/GLB character scenes from res://assets/library/Quaternius_Cube_World/Characters, choose by colonist ID, and detect idle/walk animation clips.
- Retains KayKit character fallback if no valid Cube World character resources exist, and preserves name/activity labels and movement interpolation.
- Important: verified historical Character_Male_1.gltf path was missing from active branch; actual Cube World character model files have not been confirmed. No claim of successful Cube World character rendering. Godot runtime/import tests and Android build NOT RUN.

## 2026-11-28 Phase 4.0 continuation — character discovery
- Commit d84c4aaf6c591ae3ca5d5e3e0ddddb3d39c48f96 changes Cube World colonist asset discovery to recursively scan nested directories under Characters; previously only the top-level folder was scanned.
- No new GLTF models generated; no legacy assets deleted. Existing fallback remains until verified character scenes import successfully.
- Phase 4.0 remains in progress: terrain atlas still points at KayKit BlockBits; character visual replacement and Godot import/runtime/APK tests are not verified.
