# C63 provisioning-result consumption evidence

| Field | Value |
|---|---|
| Timestamp | 2026-09-20 20:39 UTC / 13:39 PST |
| Runtime authority | Installed Project Zomboid Build 42.20.4 jar, Lua and bundled JRE |
| Canonical contracts | `ROADMAP.md` R7/R9; `SUBSTRATE.md` material, standing and settlement producer boundaries |
| Implementation boundary | Completed exact native food/water result through bounded house projection, derived claims, optional existing-settlement storage and terminal acknowledgement |

## Resulting behavior

C62 leaves one durable exact-source result after a person reaches a currently
accessible source, transfers the exact item and completes native eating or
drinking. C63 gives that result one consumer. The action binds its group and
claim incarnation only while the source is on currently held ground, then
publishes the completed result with the event-time Material choice and the
source observation time. Personal use and use outside held ground remain
personal.

The consumer revalidates the claim incarnation and reconciles the exact native
source at its current revision. `SAO_Material` replaces that source's bounded
projection for one house, including a first empty/spent observation or proved
ground absence. A source-owner index prevents one physical source from
belonging to two houses. Every real aggregate change advances a projection
generation; source observation time orders completed-source evidence against a
live quartermaster scan. Older retries therefore cannot reverse newer material,
Standing or settlement-storage truth.

Standing derives larder and water claims from that projected aggregate.
Recognition may synchronize storage only when a settlement already exists and
is grounded by completed place-development evidence. This path does not create
a settlement, organization, office, membership, room, supply or historical
success. Standing and Recognition each persist their completed phase before
acknowledgement. A crash, reload or refused acknowledgement resumes the same
decision without re-dating evidence or repeating a downstream write.

Claim movement, release, dissolution or same-named reincarnation retire the
house projection and its derived authority. Claim identity is checked before a
compacted non-ground source can wait, so released ground terminates instead of
leaving an eternal pending result. When Material is off, current readers hide
retained material facts and quartermaster writers refuse current replacement.
An already-applied transaction may finish its durable phases; a later toggle
does not reinterpret the completed event.

## False producers retired

Elapsed dormant consumption, accepted `depositSpareFood` queue work and
Standing setters no longer manufacture provisioning success. The graph-schema
upgrade retires pre-C63 house stores and settlement bases without native source
or place-development evidence, and sanitizes linked provisioning-only social
shells. Standing's schema upgrade clears legacy larder, water and hearth output
and assigns claim incarnations. Future schemas refuse without mutation.

Performed shelving, acquisition, carrying, storage, sharing, hoarding, trade,
conservation and place development remain separate action-result families.
This batch supplies a trustworthy completed-use projection seam; it does not
stand in for those producers.

## Review and repairs

The first correctness pass blocked the batch. It found stale stock surviving a
first empty observation, owner leakage through material views, Material-off
reader and writer leaks, acknowledgement retry re-dating Standing, an older
applied transaction able to reverse a newer derivation, compacted-source wait
after claim retirement, and ambiguous ordering between result projections and
quartermaster scans. The architecture text also misstated when attribution was
captured.

The repairs add zero-truth projection, detached owner-correct access views,
central reader/writer option gates, durable per-group phases, per-house
projection generations, source-observation ordering, older-generation refusal
in Settlement and claim-incarnation revalidation before source lookup. Group
and incarnation bind at final action binding; the Material choice binds when
the completed result is published. `review.json` records every finding and its
disposition. The final correctness and structural reviews found no remaining
Critical, High, Medium, structural or coherence blocker.

## Mechanical receipts

`gate-final.txt` exits 0 with `[check] all borders clean`: 178 gated test files,
13 supporting Python entry points and 191 distinct scripts with labels through
Border 180. The gate privately compiles 35 Java inputs into 64 classes and 76
Lua files in normal and debug modes for 152 Lua verdicts. The shipped jar has
64 classes from 34 source files. Its SHA-256 is
`4160841299C724EA4BE125854CA8A660FDC7E763875446D0D367A0A7CE8025A2`.
All 309 Lua bridge call sites resolve to 201 called methods, and bridge safety
passes 207/207 public source paths.

Border 180 executes 52 production cases in the installed Kahlua VM and rejects
all 68 named mutation controls. It covers exact replacement, empty/spent truth,
source ownership, claim lapse/reincarnation, bounded storage, option behavior,
durable phases, crash/reload/acknowledgement recovery, projection generations,
cross-producer evidence ordering, schema upgrades and false-producer removal.
Borders 178 and 179 remain clean beside it.

## Installed startup

The deployed install contains 258 files with no missing, extra or differing
content. The installed jar matches the gated jar. All 44,092 pre-existing save
paths, sizes and modification times remain unchanged across deployment and
startup. ZAO A37's 29-file content and metadata manifests also remain unchanged.

The final Project Zomboid window is responsive and lists SurvivorAwareness and
ZombieAwareness among four active Java mods. The agent verified `IsoPlayer`,
installed the three-call melee patch and loot-density weave, loaded
`com.sao.Main`, exposed `SAOJavaBridge`, and loaded the Harness, Population and
Sandbox Lua markers. One bridge reflection attempt preceded Lua readiness; the
watchdog exposed the bridge two seconds later. The captured startup prefixes
contain no SAO error, exception, Kahlua stack or load refusal. Existing
third-party workshop and engine warnings remain outside SAO. The process is
left open.

No save was loaded during this receipt. Save-backed provisioning consumption
and the feel of the behavior in play remain observations rather than claims
made by this startup record.
