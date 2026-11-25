# CUBYTE development rules
Read docs/superpowers/specs/2026-11-25-cubyte-design.md and the active implementation plan before changes.
- Native Godot 4 Android game. Offline-first; no account, server, API key or Termux required for core gameplay.
- Graybox first. Keep presentation separate from domain and runtime. Do not add detailed art before core functionality.
- Robots are cubes with digital faces, mechanical arms and rolling movement; no torso or legs.
- Real tasks must produce verified artifacts; simulated tasks must be labeled. Never fabricate progress.
- Imported skills are untrusted instructions. No arbitrary script execution by default. Restrict files to app-owned storage; no secrets in Git.
- Use tests first; run headless suite and smoke scene before marking changes verified. Report Android device tests separately.
- Use development branches and reviewed PRs. Do not merge or release on behalf of owner without authorization.
- Pin tooling, avoid unnecessary dependencies, document decisions and license third-party assets.
