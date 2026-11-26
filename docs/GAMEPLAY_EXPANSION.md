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


## Approved HQ concept — visual pass and Android validation
The approved concept is the art-direction reference, not an in-game render. The procedural 18 × 12 HQ includes warm ATLAS management, cool production desks, a project display, a separate right-side three-Cubot charging bay plus ATLAS's private dock, a lounge with rounded seating, a glowing upgrade console, a central planter, edge planters, rounded zone flooring, and cutaway perimeter walls. Geometry and materials are designed for the mobile renderer rather than duplicating all illustrated details.

Idle charging starts after 40 seconds of project inactivity when a Cubot is at or below 75% simulated charge. Full Cubots leave their own docks and resume ambient social activity. Player tasks and meetings take priority. Charge is simulated in the running scene, not a real battery or task execution restriction. Static grid validation covered three- and four-member movement between spawn, meeting and charging locations; runtime behavior and visual fidelity still require device validation.

This commit requests the Godot CI headless regression and Android debug export pipeline on the development branch. Main remains unchanged.


## HQ V3 — expanded office and chat redesign
- Actual floor footprint 30 × 22 (formerly 18 × 12), with larger manager suite, production lanes, meeting area, lounge, lab and charging bay. Navigation limits and camera framing expanded; desk and meeting table widths increased while retaining Cubot-fit height. Charging pads 1.8 × 1.8. Imported Kenney CC0 furniture uses individual assets, not a scaled global scene.
- Private, team and meeting chat share a mobile timeline: selectable plain-text bubbles, sender accents, compact header and composer, prompt-fill quick actions, collapsible participant/privacy controls and project controls. Existing permission, history, billing/context and approval logic retained. Quick actions do not send requests automatically.
- Static route checks covered three and four workers moving between spawn, meeting and docking positions. Automated Godot tests now include the furniture imports and chat timeline. Device visuals, keyboard behavior and animation fit remain unverified. The edited Cubot GLB is optional and must be present at its documented path; otherwise procedural fallback remains active.
- This commit requests headless validation and Android debug export; no merge to main.
