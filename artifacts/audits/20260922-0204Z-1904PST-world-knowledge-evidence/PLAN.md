# C74 producer and evidence matrix

Timestamp: 2026-09-22 02:04 UTC / 19:04 PST.

## Measured problem

Speakeasy's approved `who-knows-what.md` contract requires a carrier match, a
dated personal acquisition path and retained access before a protected claim can
condition a decision. Its authoring compiler can join that evidence, but it does
not produce or adjudicate it. Survivor Awareness currently has no general
producer for protected world-knowledge acquisitions. Existing age, occupation,
origin and radio state cannot establish that a person learned a particular
claim.

The first example uses the protected July 2, 1993 Knox Telecommunications
outage. The source itself says that anyone in the county carries July 1-6 as
`lived` days. This makes county presence the required personal event. It does
not turn the article, a radio receiver or a county origin label into an
acquisition by itself. The selected extraction is the source's exact provider
and area-wide outage claim, so this first record uses the same source's adult
detail slice; a child's lived but vaguer memory is a different claim.

## Contract to producer matrix

| Contract | Producer | Durable state | Read/export evidence | Defect/control |
|---|---|---|---|---|
| Exact county calendar | `SAORecord` maps the county-hour axis to a complete local Gregorian instant using the save start and the same history offset as `SAO_History.countyHours` | The save's start calendar and history offset remain owned by the existing clock | A read-only calendar record binds an anchor hour, ISO instant, owner and source hashes | A save-start-only mapping is rejected because mature saves would date county hour zero years late |
| County presence | Population genesis records an explicit interval only after a person's origin ground is selected; later arrivals begin at their actual arrival hour | Person record carries interval, origin region and producer | Reader returns the interval and its provenance | Origin text alone is rejected; newcomers cannot inherit July 1-6 |
| Lived acquisition | World-knowledge producer admits the exact adult claim only when its event hour falls inside that person's presence interval and is no later than the county's current hour | Person-private claim record carries claim/source binding, source event, acquisition hour and path | Detached acquisition snapshot names the supporting presence record | Age, occupation, elapsed time and global county state cannot create the record without the dated presence path |
| Access | The lived path itself supplies direct sensory access to an area-wide outage; no literacy, receiver or teller is asserted | Claim record preserves the exact modality and carrier check | Export separates carrier and access checks and points both at the producing records | C73 radio state is not accepted because this protected claim was not transmitted by County Wire |
| Retention | Read-only observation at the decision hour checks that the same immutable acquisition remains on the same person's record and has not been superseded or removed | Original acquisition remains append-only; observation is a separate record | Export names both acquisition and observation hours | Reconstructing acquisition at export time or changing its original time fails |
| Decision event | Production `WorldSources` / `SourceUse` executes a selected source action while `SAODecisionCapture` freezes the pre-choice person, situation and executable options | Capture envelope keeps event, runtime choice and terminal immediate result separate | Evidence bundle contains the native capture and its hashes | Hand-authored option rows and unavailable county-sweep coverage do not qualify |
| Protected extraction | Speakeasy selects a literal bounded claim from its protected `knox-event.md` bytes | Speakeasy owns claim text, standing and protected manifest | Source path, full-document hash, line and excerpt hash reproduce | Document approval alone does not review the claim boundary |
| Adjudication and ratification | Speakeasy verifies the SAO bundle, records reviewer findings and presents the hash-bound candidate to the operator | Append-only review and ratification receipts; no status toggle | Training admission requires exact proposal, review and ratification hashes | SAO cannot approve data; compilation cannot make a row eligible |

## Implementation boundary

SAO will add a small person-private world-knowledge store and a detached reader.
The runtime data port carries claim and protected-source identifiers and hashes,
not protected prose. Initial county residents receive an explicit July 1
presence start; post-genesis arrivals receive only their actual arrival start.
The daily county pass advances dated claims so a July 1 start cannot know the
July 2 event early. Mature starts can preserve the same lived acquisition as
prehistory because the explicit interval covers it. A person saved before C74
has no such interval and remains unknown; origin text is not used to backfill
one.

The evidence generator will use the installed Project Zomboid Kahlua runtime and
the production decision/action modules. Its controlled world ground is evidence
for the bounded mechanism, not a claim of loaded-save acceptance or a sampled
natural county distribution. Mutations must independently break calendar
anchoring, presence admission, personal storage, retention and the native
decision binding.

Speakeasy remains the owner of extraction review, acquisition adjudication,
choice authorship, ratification and training eligibility. No existing protected
choice or document changes through the SAO batch.
