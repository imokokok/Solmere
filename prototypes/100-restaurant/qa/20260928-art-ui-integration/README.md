# 2D polish and Solmere integration — 2026-09-28

## Scope

The production game stays 2D. The rejected toon/3D experiment is outside this repository and is not shipped.

- Keep all supplied paintings and their original bytes. Replace 64 supplemental images with four separately identified flat painted atlases; source prompts and SHA-256 are in `docs/ART_GENERATION_PROMPTS_20260928.json` and the runtime manifest. Region selection preserves the generated files unchanged.
- Original Solmere procurement art for herbs, sea beans and star salt is copied byte-for-byte from `art/ui/handmade/`. These are existing project assets, not newly licensed external assets.
- Remove hard shelf-label/outline clutter; use the same warm paper for the opening, pause and settlement pages. Four bottom actions, shorter Chinese text, and contextual next-step prompts.
- The knife preserves each fragment's scale, material state and mass. Only real interior cut edges get thickness. Degenerate vertical edge polygons are skipped to avoid a renderer error.
- Board release retains limited hand momentum. Firm whole round foods roll a short distance; cut, softened and irregular food settles through higher friction. This is a perspective support-plane approximation, separate from native free-fall contacts.
- Tools remain outside when released. A deliberate return near the cup now follows a 0.65-second eased target through the same force controller, rotates smoothly, then settles before docking. The cup front masks the entering handle during the motion; its depth no longer changes in one visible jump. Picking up preserves orientation; the wheel changes wrist angle. A quiet existing CC0 contact recording plays only at final seating.
- Solmere cooking routes to `scenes/restaurant_host.tscn`. The kitchen uses a separate World2D/viewport, preserves 120 Hz, and restores the main game's engine/audio state on leaving.
- Real served meals, elapsed time and exact share cents are saved transactionally. Failed saves restore all game state; receipt IDs prevent duplicate payments. Scheduled shifts pay the actual fraction worked. Procurement is paid/consumed only when its ingredients occur in served meals. The public trace displays actual served ingredients and feedback. Recipe/letter files are isolated by journey, slot and character.
- `tools/sync_restaurant_module.py --check` verifies the root runtime is identical to the standalone source. CI checks both the shared suite and main-game settlement.

## Validation evidence

This directory retains the September 28 visual review. Final validation and delivery evidence for this work and the subsequent bug fixes are consolidated in [September 29 precision review](../20260929-precision/README.md), including `checks/summary.json` and `RELEASE.json`. Earlier failed runs are preserved separately and are not represented as passing. The main bridge has 25 headless assertions; its GPU run has one additional capture assertion. `solmere-entrance.png` is the actual mounted main-game viewport; `packaged-intro.png` comes from the exported EXE at this earlier stage.

Native Windows checks and package manifest are in the September 29 review. A screenshot or headless pass is not a claim that every free-form recipe, Windows IME sequence or audio mix was manually tested.

## Model limits

Godot 4.7.2 native 2D rigid-body contacts plus the existing MIT GodotSpringDamper helpers; no replacement physics engine was installed. Board depth, coating, heat, pressure and finite-volume water are game approximations, not 3D soft-body simulation or CFD. New audio is not synthesized; this revision reuses the existing documented CC0 recordings. Subjective human listening remains distinct from technical audio tests.
