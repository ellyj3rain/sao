# C124 - Combat perception compatibility

| Field | Record |
| --- | --- |
| Batch | `C124` |
| Date | 2026-09-14 |
| Name | Combat perception compatibility |
| Status | Closed append-only batch - combat perception compatibility |
| Threads | [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

Combat perception operates across the engine and mod ecosystem without
duplicating or fighting other systems:

1. **Acoustic attenuation under suppressors**: weapon sound events are
   emitted through `WorldSoundManager` using the weapon's own `soundRadius`.
   Suppressor mods rewrite or scale this radius. The county's perception
   scanner queries the engine sound list and scales reach by weather
   hearing (`sound.radius * weatherHearing()`), so a suppressed firearm
   shot naturally reaches fewer county ears for free without custom hooks.
2. **Floor targeting for crawlers, tripping dead, and prone targets**:
   melee attacks previously evaluated only `target.isOnFloor()`, which risked
   swinging high in the air above crawler zombies or modded prone targets.
   C124 checks `isOnFloor()`, crawler state (`zombie.isCrawling()`), and
   mod-authored prone/crawling stances, directing `setAimAtFloor(true)` and
   `setAuthorizeShoveStomp(true)` so survivors strike downward.
3. **Prone and crawl perception**: bodies in prone or crawl stances
   (engine crawler/onFloor, mod animation variables `isProne`, `Prone`,
   `isCrawling`, `Crawling`, `Crawl`, or modData) present a reduced visual
   silhouette. Beyond near-sense distance, visual perception range is
   reduced to 60% of normal. Stance is communicated to Lua through `+p`
   in person conditions and `:prone` in zombie rows, parsed onto beliefs.
4. **Stealth mods**: mods that deactivate zombie AI by marking zombies
   useless (`zombie.isUseless()`) are left alone. The perception scanner,
   bridge combat, and zombie director skip useless zombies so deactivated
   threats are not perceived or targeted while inactive.
5. **Zombie-motivation mods & non-duplication of aggro**: the director
   and bridge combat check whether a zombie is already targeted on another
   entity (`zed.getTarget() != null && zed.getTarget() != shell`). They do
   not usurp or double-apply aggro over another mod's motivation.
6. **Weapons and clothing by construction**: verified line-by-line that
   melee scoring reads the weapon's own script stats (`minDamage`, `maxDamage`,
   `maxRange`, `baseSpeed`, `criticalChance`, `condition`), reloading uses
   the vanilla `ISReloadWeaponAction:new`, and clothing is never inspected
   or modified.

## What changed

- `SAOCombat.java` targets the floor for crawlers, tripping dead, and prone
  targets, and respects deactivated useless zombies.
- `SAOPerceptionScanner.java` introduces `isProneOrCrawling`, bounds visual
  range by reduced silhouette for prone/crawling entities, appends `+p` / `:prone`,
  and skips useless zombies.
- `SAOBridge.java` and `SAOZombieDirector.java` skip useless zombies and
  refuse to usurp existing targets from zombie-motivation mods.
- `SAO_Perception.lua` parses `:prone` and `+p` into `belief.prone`.
- `SAO_Controller.lua` annotates downed/prone targets in engagement status.
- `combat_perception_test.py` establishes Border 157; `check.sh` includes it.
- `FINDINGS.md` records combat perception compatibility as F-070.

## Honest limits

- This is not a play receipt. Nobody has watched a survivor fight a crawler
  in a live save or evade a useless zombie under a stealth mod.
- Prone and crawl stance detection relies on standard engine methods,
  common animation variables, and modData conventions; unshared private
  mod variables cannot be read.

## Verification

- Border 157 exercises acoustic reach attenuation, floor targeting for crawlers
  and prone targets, silhouette range reduction, useless zombie skipping,
  and aggro non-duplication.
- Border 157 mutates combat floor targeting, scanner useless skipping, and
  bridge target usurpation to confirm controlled failure.
- The Java agent rebuilt from source and all jars deployed and verified.
