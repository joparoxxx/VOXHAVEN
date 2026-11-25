# Android debug build and skills metadata
Goal: produce a downloadable ARM64 debug APK and provide a safe first SKILL.md import/equip flow.
1. Add Android preset, pinned engine templates, Android SDK/JDK setup, debug signing, APK verification and artifact upload.
2. Write skill tests for valid metadata, unsafe names, duplicate metadata, size bounds, persistence, explicit tool binding and rejected unknown tools.
3. Implement bounded single-file SKILL.md import with a documented YAML subset; never execute body or scripts. Equip per robot with explicit native TXT/PNG tool selection.
4. Add UI dialog to paste/import metadata, assign and inspect skills. Keep existing real task buttons; equipped skill runs only the selected native tool, not arbitrary instructions.
5. Run headless tests and export in CI. Device installation and full Agent Skills package support remain separate.
