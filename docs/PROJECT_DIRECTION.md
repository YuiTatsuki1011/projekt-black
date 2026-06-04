# Projekt Black Direction

Last updated: 2026-06-04

## Purpose

This document defines the reduced first-game scope for `Projekt Black`.

The current priority is completion. The game should keep the strongest survival-horror combat and inventory ideas, but avoid RPG-scale systems that would make the first project too large.

## Core Game

`Projekt Black` is now a top-down survival-horror action game with dense dungeon exploration.

The player starts the game, explores a small number of large connected dungeon areas, fights through fixed encounters, talks to NPCs, manages ammunition and inventory pressure, defeats mid-bosses, and finally defeats the last boss.

The intended structure is closer to one continuous handcrafted campaign than a looter-shooter or extraction RPG.

## Keep

- Top-down combat.
- Survival-horror pacing.
- Heavy resource management.
- Magazine, chamber, ammo, and reload handling.
- Grid inventory.
- Weapon inspection and weapon parts as a long-term extension point.
- NPC interaction with `F`.
- Character portraits and dialogue scenes.
- Exploration, keys, shortcuts, locked doors, item containers, and readable world objects.
- Mid-bosses and a final boss.
- Systems that can later become a reusable template for a sequel.

## Cut From The First Game

These are not part of the first-game target unless explicitly restored later.

- Player levels.
- Skill trees.
- Hub/base progression.
- Task/vendor progression.
- Open-ended extraction-loop progression.
- Large procedural dungeon generation.
- Looter-shooter item flood.
- Broad hack-and-slash stat scaling.
- Long-term economy or stash management.

The current extraction and run-result systems are still useful prototypes, but they should not define the final game loop unless the design changes again.

## World Structure

The first complete version should aim for about three large connected dungeon zones.

The zones may behave like stages internally, but the player should not see a hard "stage clear" result after each zone. The intended feeling is one continuous hostile place with major gates, bosses, and shortcuts.

Suggested structure:

1. Outer dungeon area: onboarding, basic combat, first locked routes.
2. Inner dungeon area: stronger enemies, more resource pressure, NPC/dialogue events.
3. Deep dungeon area: final escalation, mid-boss rematches or variants, final boss.

## 3D Direction

The next major technical question is whether the top-down game should become 3D.

The preferred test is a separate 3D prototype scene, not a direct replacement of the current 2D scene.

The 3D prototype must prove:

- WASD movement on a 3D floor.
- Top-down camera readability.
- Mouse aiming.
- Gun muzzle direction and delayed aim reticle behavior.
- Projectile or hitscan collision against 3D walls and enemies.
- One enemy that can be killed.
- One interactable object.
- Existing inventory UI can still be opened and used.

Only after this feels good should the 2D top-down prototype be deprecated.

## Reusable Systems

These systems should be built with sequel reuse in mind:

- Inventory and item definitions.
- Weapon, magazine, ammo, and chamber logic.
- Dialogue data and portrait presentation.
- Interaction system.
- Enemy data.
- Stage object placement helpers.
- Internal authoring/editor tools.

The editor should be created after the runtime format stabilizes. Building the editor too early risks editing a data model that will change.

## First Vertical Slice

The first serious milestone should be a small but complete dungeon section:

- One 3D test area.
- One player weapon.
- One magazine and ammo type.
- One melee/sub-weapon behavior if needed.
- One item container.
- One NPC conversation.
- One locked door or key item.
- Two enemy types.
- One mid-boss-style encounter.
- A beginning and an ending condition.

This slice is the proof that the reduced game can actually be completed.

## Immediate Next Step

Create a small `top_down_3d_test_level` prototype.

The goal is not visual quality. The goal is to answer whether top-down 3D movement, aiming, shooting, collision, and inventory reuse feel viable before more 2D-specific work is added.
