# AI Handoff

## 2026-06-04: Reduced First-Game Direction

- Read `docs/PROJECT_DIRECTION.md` before planning large new systems.
- The first-game target is now a smaller top-down survival-horror action game with connected handcrafted dungeon areas.
- Cut first-game scope: player levels, skill trees, hub/base progression, vendor/task progression, large procedural dungeon generation, open-ended extraction-loop progression, and looter-shooter item flood.
- Keep first-game focus: magazine/chamber/ammo handling, grid inventory, survival-horror combat, NPC dialogue, interactables, keys/doors/shortcuts, bosses, and reusable systems.
- Next major technical step should be a separate `top_down_3d_test_level` prototype to test whether top-down 3D movement, aiming, shooting, collision, and existing inventory UI reuse feel viable.
- Do not delete the current 2D top-down prototype until the 3D prototype proves the core feel.

## 2026-06-04: Top-down enemy AI simplification

- `scripts/enemies/top_down_enemy_base.gd` is the shared enemy AI base for the top-down prototype.
- `scripts/enemies/top_down_chaser_enemy.gd` and `scripts/enemies/top_down_ranged_enemy.gd` inherit from this base.
- Current AI goal is readable action-game behavior, not advanced tactical simulation.
- Shared state flow is `IDLE -> ALERT -> COMBAT -> SEARCH -> IDLE`.
- Shared stimuli are vision, noise, shared sighting, and hit reaction.
- Shared systems include detection gauge, last-known target memory, short search at remembered position, wall-clipped debug vision, last-seen marker, enemy separation, damage flash, death VFX, and corpse loot container spawning.
- Chaser behavior is pursue, wind up, lunge, apply melee damage, and recover.
- Gunner behavior is keep preferred range, retreat if too close, track target, show laser warning, fire enemy projectile, and recover.
- Enemy tuning values such as move speed, detection range, view angle, and search timing are set on each enemy scene so they remain easy to adjust in Godot's Inspector.

## Design Notes

- Prefer clear and stable behavior over advanced tactics.
- Add enemy variety through parameters and small derived behaviors before adding complex squad logic.
- If enemies feel too weak, first tune detection time, search memory time, movement speed, and attack cadence.
- If enemies feel noisy or unfair, reduce view angle, alert sharing range, or search memory time.
