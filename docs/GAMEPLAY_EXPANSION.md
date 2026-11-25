# Gameplay expansion checkpoint

Stable baseline: branch stable/debug-85 (c8bd82f), verified CI and initial device testing reported by owner. Development remains on feat/offline-ai; all gameplay commits skip CI.

## Phase 1
Company HQ, local in-game credits (100 initial, 10 per successful task), upgrades, multi-Cubot native workflow builder with up to eight sequential steps, saved templates. Rewards are deduplicated by task ID. No real-money economy.

## Phase 2
- Level increases every five successful rewarded jobs (cap 20). Hire NOVA (Analyst) for 100 credits from level 2. The new Cubot has a fourth workstation, separate chat history, identity, permission-controlled native execution, Team Chat and workflow participation. Locked NOVA cannot execute via the application's permission checker. Group rounds can make up to four Gemini requests after hiring.
- Autonomous local patrols: one unselected active robot at a time, static furniture and other robot cells avoided on the ambient route, short visual greeting when near a teammate. No automatic model calls; ambient movement pauses during work or modal screens.
- Added procedural shell, vents and status details to robot meshes; bookshelves and whiteboard purchasable and visible in office.
- Limited construction: desk nudges within lanes, wall-decoration swap, saved preferences. NOVA has a dedicated fixed station.
- Short synthesized completion, error and cancellation tones, optional; battery saver limits FPS to 30, normal mode to 60. Box meshes reused and face updates throttled.

## Validation
New regression tests cover progression, hiring, locked worker rejection, persisted credits and hire, analyst routing and XLSX task execution. All are registered for the next authorized CI run. New gameplay source has not been compiled or device-tested yet. No CI started or merge performed.

## Remaining
Freeform grid placement, unrestricted construction, dynamic collision avoidance for task movement, more hireable Cubots, advanced task planning, full production-quality character assets and actual device performance profiling are not complete. The visual greeting is a local animation state, not an AI-to-AI conversation.

## Debug build authorization
Owner authorized the next debug build. Run existing Godot CI, gameplay regression tests, and Android APK export on the development branch. Keep stable/debug-85 and main unchanged.
