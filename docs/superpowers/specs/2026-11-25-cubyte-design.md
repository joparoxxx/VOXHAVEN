# CUBYTE — Project Foundation (draft v0.1)
Date: 2026-11-25. Status: proposed for review, not implemented.

## Product
Native Android 3D robot office game, offline-first. The user manages customizable cube robot employees and assigns simulated or real local production tasks. Core gameplay must not require an account, external hosting, internet or Termux. Optional model downloads and external integrations must be clearly labeled.

## Agreed direction
- Robots: cube shell, digital expressive face, two mechanical arms, no torso or legs, rolling locomotion. Color, face, accessories, personality and optional gender expression are independently customizable.
- Office: primitive graybox shapes first; final assets replace visuals without changing behavior. Start with one room, workstations and charging area.
- Backend-first: prioritize real task completion, local artifacts, skill loading, persistence and security before graphical polish.
- Support standard Agent Skills SKILL.md packages; actual tool availability determines compatibility.
- Native runtime by default; optional Termux adapter for advanced users. No mandatory hosting.
- Simulated and real work must be clearly distinguishable.

## Approaches
1. Standalone Godot game with native modules (recommended and consistent with user direction): simplest end-user installation, but Android-specific integration work.
2. Godot + Termux as mandatory worker: useful for advanced scripts, rejected as baseline because other users may not have Termux.
3. Cloud-based worker: optional future extension only; incompatible with required offline baseline.

## Proposed technical decisions
Godot 4 + GDScript, Compatibility renderer initially; Android ARM64 first. Native integrations via Kotlin or GDExtension/C++ only when required. Begin with built-in Godot processing and app-private persistence, then adopt SQLite when persistent queries require it. One shared local inference engine later; per-agent identities, skills, memory and context. No assumption that a model can execute scripts or that every skill is portable. Prefer a single active processing worker initially; profile before increasing concurrency.

Layer boundaries: presentation -> gameplay/application services -> task/skill/tool domain -> runtime adapters and persistence. Domain emits typed events with stable task/robot IDs. UI observes events; graphics do not own execution state. Runtime interface supports capability discovery, execution, cancellation, and result validation. Artifacts are app-private by default with explicit Android export/share.

## MVP vertical slice
A small 3D office with three colored cube robots. Tap a robot, assign a structured task to a compatible skill, run a deterministic local tool (TXT or PNG), validate the actual saved artifact, and preview/export it. Test offline and after save/reload. Digital face and work animation reflect actual task states. PDF, general natural-language inference, arbitrary scripts, complex build mode, video rendering and optional Termux are separate later milestones.

Task states: queued, running, succeeded, failed, cancelled, interrupted. Progress is determinate only when the tool reports measurable progress. Persist transitions; on restart reconcile unfinished work rather than claiming success. Provide error details and cancellation where supported.

## Skill and security
Import SKILL.md with required name/description metadata, optional references/assets/scripts. Validate schema, archive paths, size, symlinks and dependencies; no execution during import. Discover metadata first; load relevant instructions when needed. A skill is untrusted data, not authorization. Scripts are disabled unless a separately supported sandboxed runtime and explicit permissions are available. Tools use typed input/output schemas and least privilege. Do not store secrets in public Git history. Termux bridge must authenticate, bind locally by default, and not expose unrestricted command execution.

## Development sequence
1. Project standards, pinned engine/build tooling, architecture decisions, CI smoke checks.
2. Headless tests for task lifecycle, tool registry, local file output and save/reload.
3. Graybox room, robot variants, camera/touch interactions and real task event visualization.
4. SKILL.md import, compatible tool binding, permissions and artifact previews.
5. Android APK smoke test and physical-device profiling.
6. Optional local AI/model manager, collaboration and Termux bridge.
7. Expanded tools, workflows, build mode, final art, sound and optimization.

## Acceptance gates
- Core app works without internet or Termux.
- A task creates a genuine validated file; cancellation/failure never reported as success.
- Imported skill cannot escape its allowed workspace or execute arbitrary code by default.
- Game save survives restart; interrupted tasks have an honest status.
- CI builds and tests with pinned dependencies; Android device tests are separate from desktop headless checks.
- Target 30 FPS initially, optional 60 FPS; benchmark on actual Android hardware. No performance guarantees before tests.

## Deferred decisions and risks
Exact Godot patch version, Android SDK target, package ID, local model licenses, distribution mechanism for models, native library licensing, thermal/memory budget, foreground/background processing, and final art pipeline need verification. Proposed package ID com.urfavxbf.cubyte. Public repository exposes source; project license is not yet selected. Standard hosted runners are suited to CPU builds and tests, not guaranteed GPU rendering. Do not treat this draft as an implemented or tested game.
