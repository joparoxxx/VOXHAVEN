# Voxhaven development instructions

Read docs/GAME_MASTER_PLAN.md before changing gameplay. The current humanoid colony design is authoritative.

- Use fresh Godot 4 / GDScript code; never reuse legacy project code or robot mechanics.
- Preserve existing asset files, catalog and bundled licenses. Do not generate new GLBs without owner approval.
- Keep gameplay fully offline; no external AI, API keys or mandatory servers.
- Separate simulation, presentation and persistence. Bound planning, navigation and chunk workloads.
- Target Android ARM64 and Compatibility rendering; profile before claiming performance.
- Use development branches for gameplay. Do not merge or release without owner approval.
- Run relevant tests and report actual outcomes; never hide errors or claim unverified builds.
- Keep README and current documentation accurate. Preserve historical branches.
