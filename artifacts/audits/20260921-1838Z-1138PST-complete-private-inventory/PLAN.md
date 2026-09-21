# C71 complete private inventory

| Field | Value |
|---|---|
| Timestamp | 2026-09-21 18:38 UTC / 11:38 PST |
| Authority | ROADMAP continuation after C70; SUBSTRATE R6, R7 and R9; CAO native-inventory precedent |
| Target | One current person-private view of every carried and loaded world holder consulted by decisions, without a second inventory owner or inferred house total |
| Baseline | SAO C70, `64fe77c`; CAO observes native items recursively with direct-holder and root-location identity while native hauling remains authoritative |

## Mechanism inventory

| Contract | Current producer and caller | Persistence and observation | Gap and completion evidence |
|---|---|---|---|
| Carried items | Native `ItemContainer`; `SAONativeSnapshot` recursively preserves items and equipment | v4 manifest preserves exact item ID, direct parent and type; dormant metabolism already searches nested containers | Loaded decisions mostly scan only the root container. One recursive reader must expose the same identities to every carried-item decision and agree with the v4 dormant manifest. |
| Static containers | Loaded `IsoObject` containers; `SAOWorldSources` assigns persistent `C:` identities | Source observations preserve item IDs, revisions and contents, but legacy Needs scans rediscover anonymous containers | The private view must reuse the native source identity, retain exact direct holders and refresh from the current body and loaded cell. Replacement and removal must change the view rather than leave a stale match. |
| Vehicle containers | Native vehicle SQL ID and part index; current `canAccessContainer` check | `SAOWorldSources` observes `V:` identities; legacy searches hold runtime container references | The private view must name the exact part holder and record current actor access. A different person may receive a different access result from the same vehicle. |
| Placed items | `IsoWorldInventoryObject` and its native item; `SAOWorldSources` assigns persistent `G:` identities | Existing offered-item code retains only a runtime object and display name | The private view must preserve ground-holder identity, native item identity and current square, and must drop or replace the row when the native object changes. |
| Corpse containers | Native dead-body container and inherited person mark where present | Corpse-loot decisions scan the current square directly and retain no inventory identity | Treat the corpse as a current container surface with a distinct holder; taking from it remains an action concern and does not turn the inventory view into an executor. |
| Person privacy | Callers pass a live body or that person's hibernation envelope | WorldSources beliefs are person-private; legacy container scans and `rec.hasRadio` can become stale or global | Every view is constructed for one named body or one exact dormant envelope. No global cache or durable projection may answer another person. |
| Coverage | None; callers interpret bounded nearby scans as if they were complete | Quartermaster larder and cook appraisal consume anonymous radius scans | The view reports `carried=complete`, `world=loaded-bounded` for a live body and `world=unknown` for a dormant person. It emits item rows, not household totals. Aggregate house claims cannot cite it as complete coverage. |
| Mutation authority | Native timed actions, SourceUse, Handover and Treatment own their respective mutations | Exact action owners revalidate identities and publish results | The inventory layer is read-only. Existing direct legacy mutations remain separately named R7/R9 action gaps; this batch does not reclassify observation as completion. |

## Consumer migration

| Consumer family | Current defect | C71 route |
|---|---|---|
| Food, drink, medicine, bandage, cloth, smoke, drugs, weapons, ammunition, books and keepsakes | Separate root-only Java scans disagree with dormant nested inventory | All carried selection traverses the shared recursive reader. |
| Reading gifts, disinfectant gifts, light, radio, animal tools and controller equipment checks | Direct Lua root-container loops bypass holder identity | Bridge queries resolve through the same reader; executors still receive the exact native object. |
| Nearby static, vehicle and ground searches | Separate square loops omit holder identity, nested contents or actor-specific vehicle access | Search helpers consume holder rows from the live private view and retain exact holder/item references until current execution revalidation. |
| House larder and work appraisal | A bounded radius count is promoted to a house total | Remove complete-house claims from the bounded view. Preserve item-level opportunity for decisions and leave complete claim-wide stock to a later producer with proved coverage. |

## Ownership and verification

Project Zomboid remains the inventory owner. `SAOPrivateInventory` is a fresh,
read-only view assembled at the call site. It stores no ModData, makes no item,
moves no item and creates no house stock. `SAONativeSnapshot` exposes exact v4
dormant manifest rows without materializing a body. `SAOWorldSources` supplies
the same static, vehicle and placed-holder identities already used by source
actions.

Border 184 will execute real nested native items in the installed engine. It
will cover root and nested carriage, direct parent identity, loaded/dormant
agreement, remove, replace, holder transfer, repeated reads, v3/legacy refusal,
and one recursion mutation that must fail for the named nested item. Static
checks will require all decision-facing carried scans and the radio possession
path to use the shared reader, and will reject aggregate totals from the private
view. Existing C61, C62, C66, C68 and C70 borders continue to prove source,
transfer, handover and treatment mutation boundaries.

## Completion boundaries

This batch closes inventory observation and decision-input coverage. It does not
claim that every legacy direct transfer has acquired a durable result owner,
that a bounded loaded view is a complete household store, or that possessing a
radio proves reception. Dormant spoken access, radio acquisition and the R12
example remain the next named obligations.
