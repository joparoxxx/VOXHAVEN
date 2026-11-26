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


## HQ redesign and project meeting room
- Enlarged 14 × 12 office floor with distinct executive suite (ATLAS), production desks, conference room, social corridor, lounge and upgrade lab.
- Rounded procedural geometry, shared meshes, matte finishes, coordinated lighting and tinted low partitions. No external assets or real glass shader; automatic door animation remains future work.
- Layout v2 intentionally resets incompatible graybox coordinates and old station assignments, preserves existing robot colors, company purchases, preferences, tasks and progression. ATLAS keeps a fixed executive desk.
- Meeting button gathers active Cubots sequentially via navigation; blocked routes abort instead of teleporting. Player can cancel attendance, submit brief, select participants, or watch the 3D discussion.
- Dedicated project transcript and up to eight archived meetings. Actual Gemini specialist discussion is bounded to one request per selected participant per send, ATLAS last by default. Explicit draft-plan button requests one additional ATLAS response. No unattended calls.
- Plans are validated against active worker permissions and native writer payload rules, then presented as editable workflow rows. Only player approval enqueues tasks. Sequential execution stops on failure; actual task states and artifacts are accessible for review. Project review shows task engine states, and can optionally be sent to Gemini for discussion.
- Current limitations: native file tools only, not arbitrary external project automation; no automatic plan execution, no independently autonomous AI conversation, no literal voice audio, no dynamic collision guarantees or fully polished glass doors. The new 3D scene and meeting code have not been compiled or device tested. Static grid check confirms initial three- and four-Cubot seating and return paths; added Godot tests await an authorized CI run.
