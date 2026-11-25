# Functional AI Office — debug batch

All commits in this development batch use [skip ci]. Do not merge or run Actions until the owner authorizes the build.

## Implemented in source
- Task dashboard, queue retry/cancellation, task completion status, text/image preview, static Godot RAM and free storage counters.
- Native data-only TXT, MD, JSON, CSV, PDF, DOCX, XLSX, constrained SVG, source text and primitive OBJ writers; existing fixed PNG sample remains. New permissions default to denied and can be enabled per Cubot. The AI still needs explicit player approval.
- Artifact display rename, private export copies, confirmed deletion. Existing canonical task identifiers and paths remain stable.
- SQLite snapshot storage for tasks, profiles, skills, chats, team history and office layout. Legacy data is retained for migration where applicable. This is not a normalized relational schema.
- Gemini group chat with separate bounded requests, @mentions, local history, one permission-checked proposal per round, real worker routing and task completion report. No autonomous unbounded agent loops.
- Restricted skill dependency metadata, SKILL.md export and native multi-step workflow with up to eight player-approved payloads. Queue insertion is atomic; execution stops on first failure. Remaining queued steps may be reviewed manually.
- Static-obstacle AStar grid, workstation travel, blink and idle/sleep/thinking/working/success/error visual states, lane-limited desk moves, workstation swap, body colors, saved layout, camera pan/pinch zoom, fixed modal dialogs and Android back handling.
- Opt-in experimental Android Keystore AES-GCM vault through JavaClassWrapper, with explicit save/load/forget actions. No plaintext credential fallback. Session-only remains the default.
- Regression suite in game/tests/test_workspace.gd and existing task/skill/AI tests. CI configuration is ready but has not been run for this batch.

## Limits and verification gates
The code has not been compiled or executed on Godot or Android in this batch. Test all new source and native bridge before packaging, then verify migration, Gemini team requests, key vault round trip, touch/back gestures, layout and actual generated artifacts on a device. The Java bridge is especially device-dependent and may fail closed. No external provider or native image generation was added. PDF is plain ASCII text; DOCX is plain paragraphs; XLSX uses inline text cells; SVG is one validated rectangle; OBJ supports cube/pyramid; code is saved as .code.txt and never executed. Document/3D previews and Android shared-storage export are not implemented. Local export is app-private. RAM is Godot static allocation, not total process memory. Pathfinding handles static furniture but not dynamic robot avoidance or complex interaction animations. Build mode is lane-limited, not freeform construction. No production-grade resource profiling, final office assets or autonomous multi-agent task planning.

## Next debug validation
1. Build the Linux native bridge and run every headless test plus scene smoke.
2. Build and sign the Android debug APK only after CI authorization.
3. Test on an existing install without uninstalling; check signing compatibility and back up data where possible.
4. Confirm migration, permissions, Gemini group chat, actual file bytes, navigation and secure vault. Keep Gemini session-only if vault validation fails.
