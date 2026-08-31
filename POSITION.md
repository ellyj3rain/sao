| Document | Position against the public field |
|---|---|
| Author | ellyj3rain |
| Repository | `POSITION.md` |
| Source | Operator-supplied prior-art survey, 2026-08-26 |

# Position

The operator commissioned an independent survey of every public PZ
NPC project (Grok, 2026-08-26). Its verdict: *"There is no public
project that implements independent Knox County civilians as
persistent people with epistemic knowledge, off-screen schedules,
household search politics, and player influence as one stack."*

That is a description of this project. The survey's own eight
requirements, checked against our tree, with commits:

| # | Requirement | Field status (survey) | SAO |
|---|---|---|---|
| 1 | Lives while the player is elsewhere | official plan + KEE intent; everyone else "exists when loaded" | **BUILT** - dormantLife / dormantAttrition / dormantEncounters, hibernation packs v2 |
| 2 | Needs, work, rest, errands, leisure; idle time expensive | HDX copy, KEE roadmap; SS/Remnants only if ordered | **BUILT and load-bearing** - DR-011, the four answers, no goalless tick |
| 3 | Knowledge = seen/told/lived, months-since-Knox ceiling, isolation freezes | **GAP** ("nobody implements knowledge as propositions stamped with source") | **BUILT** - the provenance ladder, contactMonths ceiling, told-never-outranks-observed |
| 4 | Meeting = two schedules crossing; moodles colour it | **GAP** ("no stack applies them as social modifiers") | schedules **BUILT**; the colouring **BUILT [B9]** the day the survey landed |
| 5 | Inventory from cell + notice-given-identity | **GAP** ("nobody does cell-and-profession noticing") | **BUILT** - [A28] place provides, person spots |
| 6 | Groups after contact | usually "spawned already in a clan" | **BUILT** - companies form from meetings, gated by trust AND circle |
| 7 | The late person as a house matter | **GAP** ("does not appear as a shipped system in anything named above") | **BUILT** - [A28] search, [A28] felt clock, [B1] the departure argument, seats, terms, briefings |
| 8 | Player talks, joins, petitions, influences | several do a version; "petition/influence on an off-screen polity does not" | **BUILT** - Talk, join, counsel, the chair, the wire's call verbs |

## The survey's warnings, and our standing answers

- **"Do not stack engines. One body representation per save."**
  Ours is DR-009: KnoxSurvivors' store is read-only, their bodies are
  never driven, and our people are IsoPlayer shells only. The warning
  describes a discipline we already hold.
- **"Java patches die on every IWBUMS bump"** (why KEE froze). Our
  Java surface is deliberately thin, javap-verified per version, and
  carries a self-check that reports when a patch is UNNECESSARY
  ([A24]) rather than assuming. ENGINE_CONTRACT Addendum C is the
  version evidence ledger.
- **"Loose files were a dead end"** (why PZNS rewrote). Our state is
  ModData with claims, and the B-era housekeeping audit caps the
  growing ones.
- **"B42 animals are the only shipped virtual-then-instantiate
  pattern."** Ours is the same shape, built independently: records
  drift and die in unloaded cells, bodies materialize with the right
  inventory when the player's path crosses theirs.

## The coexistence audit ([B10], 2026-08-26)

The survey's hardest warning - *one body representation per save* -
was audited rather than asserted:

- **Bodies: clean.** Every driving verb guards on our own shell type;
  the broader guards are player-facing and every call site passes our
  shell or the real player. Nothing here can drive another mod's
  character.
- **Zombie-backed NPCs (Bandits and kin): clean by construction.**
  They read as zombies to our people, which is honest.
- **Keys: were leaking, now fixed.** Another mod's IsoPlayer NPCs
  landed in the `player:` key domain by username; they now carry
  their own `foreign:` domain. See [B10].

## What this does NOT mean

The survey measures published features, not verified play. Every
batch in this repo still carries its own honest pending-receipt list.
Being alone in a design space is not the same as being finished in
it.
