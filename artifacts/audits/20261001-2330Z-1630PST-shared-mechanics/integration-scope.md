# Shared mechanics and source integration

| Field | Current state |
|---|---|
| Decision | DR-053, 2026-10-01 23:30 UTC / 16:30 PST |
| Owner | SAO's canonical person, knowledge, planning, Standing and persistence services |
| Source discovery | Whole installed collection and subsequently supplied sources |
| Engine | Installed Build 42.21; jar SHA-256 `e1a69eb743ede60b213a0fe7f8b83d4fcab773036d256cc4543a336f3b058a33` |
| Current implementation | Native feeding completion and loaded carried-cooler checkpoint integration |
| Broader integration | Open; discovery and a source review do not activate or complete a mechanic |

The player and NPC use the same physical rules, materials, native actions and
completed effects. SAO owns how a person acquires a reason to act, current
permission, exact attribution, private learning and durable state. An installed
physical module can remain the native mechanic owner. A licensed source can
become owned implementation with attribution and a recorded revision.

Named examples identify useful concerns within the whole collection. New or
unnamed installed sources remain candidates. The trait catalogue presents
curated effects: overlapping definitions map to a canonical owner, aliases and
save migration; each imported trait does not become another selectable entry.
Weapon integration uses the actual world date, item definitions, ammunition,
attachments, skills, loot and scarcity, with one owner for each action.

## Discovery

`installed-candidates.json` records metadata and hashes for 235 Workshop
packages and 312 resolved mod roots. All 312 remain candidates; 286 were
uncatalogued in the existing 27-entry study collection. The scan retains every
payload variant, metadata-incompatible entries and unresolved entries. This
snapshot has zero unresolved roots. Metadata compatibility does not establish
native compatibility, an active configuration or a source redistribution grant.

Duplicate IDs are `ImprovisedSilencers`, `TchernoLib`, `TrueCrawl`,
`VFExpansion1` and `newclothesmodelsshoes`. Payload resolution compares numeric
versions and selects the greatest compatible version. Historical study
configurations, evaluation partitions and approvals retain their original bytes.

## Implemented joins

| Mechanic | Producer and native authority | Persistence and private consequence | Verification boundary |
|---|---|---|---|
| Hand-feeding livestock | Existing animal-care selection queues installed `ISFeedAnimalFromHand`; current Standing, exact actor, animal, carried feed and native effect are rechecked | Bounded durable completion outbox retries until cognition acknowledges; own consumed feed and performed care reach both cognitive models once | Native bodies, animals, inventory and all six Baby Animal Food feeds; controlled action scheduling, admission and animation; crafting and acquisition remain open |
| Carried coolers | Installed shared cooler processor handles an authenticated loaded body or its final canonical unload checkpoint | Existing strict inventory codec preserves nested items, charge, clocks and food age; a partial processor failure leaves a durable unresolved interval and withholds a fresh checkpoint | Installed source, native item aging and snapshot/wake; dormant meal selection, multiplayer inventory ownership and loaded gameplay remain open |
| Existing foreign body ownership | ZAO retains the exact registered living shell after SAO hands it over | The native owner retains physical execution; SAO feeding experience requires an ordinary SAO admission | An action already admitted by SAO must refuse after ownership changes; native foreign pass-through receives no SAO learning |

Food age after wake is reconciled from the carried item's saved clock. The native
dormant meal selector currently runs before that reconciliation. Cooler-aware
dormant eating needs its own producer join before a retained meal can be called
correctly selected or consumed.

## Candidate concerns and next joins

| Concern | Current evidence and owner | Work still required |
|---|---|---|
| Human life stages and child proportions | SAO History supplies demographic age and adult-mesh scale; Zombie Children uses an adult zombie skeleton with uniform post-skin scale | Birth date and elapsed age, genuine human proportions, animation, clothing, reach and physiological continuity; child and Crossed bodies remain living humans |
| Early learning | Academic and cultural knowledge belongs to acquired personal history and Speakeasy's education pipeline | Real K-to-college corpus, regional propagation, outsider background, automatic assessment, retention, tutoring, cross-learning and age/usage decay; mod fixtures grant no educational credit |
| Vitality and Dan's Traits | MIT upstream `1a169c8e785c55368399b510c9dc5390881ac604`; a separately frozen private candidate has native and metadata controls | One clinical owner across Conditions, Habits, Pharmacology, loaded Body and dormant physiology; curated traits, dose and wound attribution, migration and supported player/NPC presentation; candidate is not activated or shipped |
| Windows | Repairable Windows 2.1.0 exposes actor-specific native actions; missing-pane control reproduces mutation before material confirmation | Join perceived damaged windows and exact carried panes to the existing fortification purpose; recheck current material and permission before completion, then verify exact window and item poststate; source redistribution grant unestablished |
| Fitness and exercise with gear | FWO supplies actor-parametrized exercise and machines; native Build 42.21 constructor expects an exercise definition | Repair API argument compatibility, machine identity and material/position checks, per-actor scheduling, exercised-body result and private practice; FWO source explicitly restricts redistribution without permission |
| Electricity, power and plumbing | Native world services and installed actor-parametrized wiring/plumbing actions; existing native water action receives the plumbing wrapper | Existing private work producers, exact wiring/pipe materials, reach/floor/Standing and physical completion receipts; successful return alone does not prove world mutation; source grant unestablished |
| Preservation, dried fruit, canning, jerky, animal feeds and horticulture | Installed recipes, foods, animals and plant affordances | Native acquisition, recipe/tool/material checks, shared aging and conservation, actual craft/harvest result, private knowledge and loaded/dormant continuity |
| Archery, crossbows, silencers and weapon packs | Installed weapon/item/attachment definitions and current engine actions | Normalize era, names and aliases, ammo/attachment families, rarity and loot, skill/action ownership, duplicate IDs and mod-order races; verify the same native use for player and NPC |
| Stealth, True Crawl, Lean and Lie, Over the Shoulder | SAO Posture, Orientation and Senses own per-person state; several installed sources use player-slot globals | Native per-actor stance, animation, collision, detection and weapon handling without shared-player state leaking to NPCs or other players |
| Throwing zombies through windows and climbing | Native window, crossing, body and collision seams | Exact actor/target/window admission, current reach and Standing, a real physical transition and private result; preserve human body ownership |
| Skating, cycling and exercising with equipment | Installed vehicles/items/actions and SAO locomotion/inventory ownership | Native mounting, equipment and effort, route/collision continuity, interruption, exact completion and saved state |
| Hygiene, serving plates, smoking and Smokes and Guns | Native inventory, physiology and timed-action seams | Actual carried materials, dose/meal ownership and persistence, private consequences and consistent actor handling; avoid duplicating existing health or consumable owners |
| Plysken sources | Installed solar, frost, irrigation, survival, attachment, underground and weather packages | Map each world/material producer to the canonical owner, source terms, supported engine API and completed physical effect |
| Miscellaneous objects and QoL | Every discovered source remains in the candidate snapshot | Resolve object affordances and conflicts from actual source; exact Misc Objects and True Smoking metadata were not identified in this snapshot |

The current human `History.ageOf` is derived from identity hashes and does not
advance with the county clock. Scaled adult geometry establishes the existing
demographic representation, while biological growth and infant anatomy remain
implementation work. Baby Animal Food means juvenile livestock feed; it does
not supply human infant bodies.

## Verification and protected state

The three new gate entry points execute native animal completion, installed
cooler mechanics and whole-collection discovery. Known-bad controls mutate the
production sources or invoke the motivating failure. Tests report absent
optional sources explicitly; local `--required` runs refuse missing native
evidence. Source and installed-input hashes accompany retained receipts.

The loaded R84 model trial, its six answers, model/evaluation files and native
save remain unchanged. Mod tests provide mechanical evidence, not training
admission or a new model answer. No game, deployment or unattended study is
started by this integration batch.

Markdown is the current scope record. The generated DOCX is a readable draft;
package verification and visual verification have separate statuses.
