# Robot intelligence v0.2 — implementation plan
Goal: offline deterministic robot profiles and management before adding an LLM.
- Add a bounded persistent roster for the existing three robots. Store editable personality, private user notes and per-tool allowlist. Default existing tools remain enabled. Specialization is a routing preference, not a hard-coded restriction.
- Add tests before implementation for isolated memory, permission revocation, unknown tools, persistence and manager routing.
- Add task history from the existing authoritative task store; enforce optional permission callback on enqueue and execution. A revoked queued task fails without creating output.
- Add a robot management dialog and explicit manager dispatch action. Manager chooses an allowed worker deterministically; no inference, autonomous execution or hidden permissions.
- Keep existing active skill per robot; add persistent inventory of explicitly equipped skills, with migration from existing bindings. No arbitrary code.
- Verify headless suite and Android export. Existing v0.1 build passed; new build and physical device testing remain pending. Debug builds may require uninstall due to ephemeral signing; avoid deleting user data without backup.
