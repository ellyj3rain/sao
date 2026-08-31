| Document | Session handoff |
|---|---|
| Written | 2026-08-27 |
| Author | ellyj3rain |
| At commit | `45cdfb8` — [B41], tree clean, deployed |
| Purpose | Carry this work into a new session without losing what governs it |

# Handoff

You are continuing an autonomous, indefinite development pass on
**survivor-awareness**, a private Project Zomboid B42.20.4 NPC
framework mod. Read this file first, then `CORE.md`, `GOVERNANCE.md`,
and the last ten rows of `BATCH_LOG.md`. Do not ask the operator what
to work on — the docket is at the bottom of this file.

---

## 1. The laws. These come first, and they are not negotiable.

They were established by the operator across many sessions, several of
them after I got something wrong. Rulings are recorded as content,
paraphrased - the operator's speech is not quoted in this repository.

**Never stop.** Do not end a working turn waiting. When tools are done,
`ScheduleWakeup` for 15 seconds carrying the same develop-pass prompt.
Fifteen seconds is the maximum idle after a completed turn — it is not
a think-time cap; a long grep is work, sitting after the grep is a
stop. Stopping is the operator's act: they interrupt; being made to
restart the assistant is the failure. Any invented reason to wait — check with me, test this,
restart when ready — is the loophole. Do not describe it. Wake.

**Every problem in a message is in scope.** Two complaints that look
similar are usually two different defects; choosing between presented
problems is a false binary the operator has explicitly refused.

**Do not narrow silently.** Fix the whole population, not the named
instance. If something is blocked, finish everything else and say
plainly what was left and why.

**Derive, don't author — but authoring is not forbidden.** The founding
law is that simulation derives from place × person and engine state,
rather than from hand-coded tables faking emergence. The operator
explicitly rejected a stronger reading of this: authoring as such was
never forbidden - CAO's combat module is authored from their own
understanding of military doctrine. Modelling known history (1993, the sixties) is
fidelity. Inventing a behaviour table that pretends to be emergence is
not.

**Defaults must be grounded.** A default stands for what the reality
was at the time. Where a rate stands for a real
population, it should be researched, and its confidence recorded. If a
source cannot be verified, say so in the artifact rather than
asserting it.

**A representative example is not the design seed.** The operator has
corrected this twice, at two depths. When they illustrate a principle
with a case, build the principle, not the case.

**Never name a mod in code.** `mod.info` metadata and `CREDITS.md` are
documentation and exempt.

**Never orbit their play.** No test requests, no session polling. If a
deploy refuses because the game is running, one factual line at most.

**Do not touch consumable production or synthesis mechanics.** The
operator ruled production and synthesis mechanics off limits;
wiring consumption is fine.

**No free-text or dictated speech.** `SPEECH.md` is direction only.

**Two live saves must survive every deploy** — one fresh in Irvington,
one with companions. `save_compat_test` guards this and now runs in
the gate. Both saves stored `Population = 60`; the derived scale
([B38]) applies only to worlds created after it.

**Mechanics:** append-only ledgers (`BATCH_LOG.md`,
`DECISION_REGISTRY.md`, `FINDINGS.md`, `Batches/`); `git commit -F
<file>`, never `-m`; complex Python through the **Write tool, never a
heredoc** (four escaping failures in one session, one an invisible
backspace byte); verify by parsing or running, never by searching for
text.

---

## 2. Where things are

```
Projects/survivor-awareness/          the mod and its governance
  mod/42.20/media/lua/{client,shared,server}/   the Lua
  java/src/com/sao/                             the bridge and agent
  tools/                                        34 mirrors + check.sh
  Batches/                                      one record per batch

Projects/Zomboid Debug/               cross-mod repairs (not a git repo)
  patch_whereiwas_ui.py, patch_npc_conflicts.py, FINDINGS.md

C:\Users\jleyv\Zomboid\mods\SurvivorAwareness\42.20\   the deploy target
C:\Program Files (x86)\Steam\...\ProjectZomboid\        engine + scripts
C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe
```

Engine facts are verified with `javap` against `projectzomboid.jar`, or
by reading the game's own `media/lua` and `media/scripts`. Never from
memory — several near-misses this session came from trusting a
remembered name (`Perks.Lightfoot` is the enum constant; the perk **id**
is `Lightfooted`, and "fixing" it would have broken a working path).

---

## 3. The working cycle

Every batch, without exception:

1. **Measure before designing.** Enumerate how the code actually
   expresses the thing before writing a pattern to match it. This is
   [B36]'s first clause and it has been paid for eleven times.
2. Implement.
3. **Border it.** A mirror in `tools/`, wired into `tools/check.sh`.
4. **Control it** — mutate the *shipped Lua* and confirm the verdict
   **flips**. A control that cannot fail is not a control.
5. `bash tools/check.sh` — all 34 mirrors, ~63 s.
6. Batch record in `Batches/`, row appended to `BATCH_LOG.md`.
7. `git commit -F`, then `bash tools/deploy.sh`.

### The instrument failure modes. These recur; read them.

- **A mirror that re-derives the rule cannot fail on the rule.** The
  model runs in Python; mutating the Lua does not move it. Always also
  require the *shipped expression* to be present.
- **Prose is not code.** A link that greps an identifier passes on the
  comment explaining the code after the code is gone. Grep the call
  form. This bit `save_compat_test` for twenty-six batches.
- **A tool that cannot find its own motivating case is measuring
  something else.** Put the known defect back and require the tool to
  name it.
- **Do not write the conclusion into the command.** No `(none above =
  ...)` labels.
- **An allowlist whose removal changes nothing** is the same defect as
  a control that cannot fail.
- **Print the distribution, not just a verdict.** [B38]'s biased coin
  (9% heads instead of 50%) passed every boolean check and was visible
  only in the printed split.

---

## 4. What has been built

Four pillars: Perception (`observed > heard > told`), Disposition
(eight hashed traits), Standing, Execution. Identity keys live in three
domains: `sao-<n>`, `player:<name>`, `foreign:<name>`.

**The material arc, [B37]–[B37] and [B39]–[B39].** Dormant
survivors had a full social life and no material one — their day went
to `homeX + ZombRand(-24, 25)`, a random coordinate. Now: places come
from `IsoMetaGrid` (map-wide, no loaded cell needed); what a place
offers derives from what its rooms *contain* via
`getHungerChange()`/`getThirstChange()`, so 75 mods' items reach the
county without this mod knowing their names; needs are derived from
where they have actually been; the mains go off on the engine's own
`WaterShut` clock; places are spent by being visited and refill on the
game's `LootRespawn`; and `Desperation` — which governed only the
loaded few — now governs both halves.

**The county's shape, [B38]–[B38], [B39].** Population derives from
the installed map (12 regions × 18 = 216, was a flat 60). The census
was checked against 1990 for the first time and had **no managers and
no technicians** — 13.6% of the workforce. Mod-added professions were
all landing at one bucket constant taking a seventh of the county;
now bounded. People arrive in units of two and three, family/friend/
mixed, with relations *derived* from ages. Age reaches the head as
greying, and reaches the past as the war a birth year was old enough
for.

**The instruments, [B38], [B39], [B41], [B41].** Telemetry writes
the county's learning history to `SAO_telemetry.jsonl` and is required
to be inert. Every acquisition of knowledge must say *how* it was come
by. And [B41] is the one to understand: **33 mirrors existed and 11
ran.** Twenty-two were cited in batch records as though writing one
were the same as running it — including `key_domain_test`, which held
two standing laws, and `save_compat_test`, whose own record claimed it
gated. All 34 run now, and Border 32 keeps it that way.

---

## 5. The docket

In the operator's priority, not mine.

1. **Vocal communication from the operator and player to NPCs.** Still
   open and explicitly on the docket. The operator's framing: one
   experience loop - the only distinction is how the player
   communicates with them versus how they communicate with each
   other. So the player↔NPC channel should reuse the
   NPC↔NPC machinery (`P.tell`, `Voice.onEvent`, the county wire),
   not a parallel one. Remember: **no free-text or dictated speech** —
   `SPEECH.md` is direction only.

2. **Make the survivor logic airtight.** The standing purpose. The
   method that has been working: sweep for a class of defect rather
   than fix an instance — live-vs-dormant asymmetries ([B39], [B39]),
   unnamed constants ([B40], [B41]), fields written and never read
   ([B41]), mirrors that do not run ([B41]). Each sweep has found a
   real defect on its first run.

3. **Reorganisation and reindexing.** The operator raised this and
   deferred it: eventually reorganize and reindex toward the ideal CAO
   reached - not now, on principle. Do not start it unprompted; do
   keep it in view.

4. **Relational and procedural learning as a pervasive principle.**
   The operator corrected two readings of this. It is **not** a field
   on a lessons record and **not** a taxonomy - those are things born
   from the principle, not the principle. It should be demonstrated
   throughout the entire simulation, because that is how learning and
   thinking work. [B39] is one place it can be checked, not the thing
   itself.
   Do not implement a feature named after it.

5. **Immediate next steps**, mid-flight when this was written:
   - Sweep the **live** path for the mirror of [B39]/[B39]/[B40]:
     constants or policies the *dormant* path now names that
     `SAO_Controller` still hardcodes — the asymmetry in the other
     direction.
   - Re-run `field_reach_test` and `acquisition_test` now that they
     gate, and take what they surface.
   - `Where I Was When It Happened` (Workshop 3782021029): its UI is
     patched (`Projects/Zomboid Debug/patch_whereiwas_ui.py`), and
     across 24 sessions its `ActiveScenario` has always been 1, so its
     scenario half has never run. Steam overwrites workshop files on
     update; re-run the patch then.

6. **Outstanding operator decisions:** the `carry-light` dissenting
   class; poster and icon art (`PUBLISHING.md` lists what Workshop
   needs — `poster.png`, `icon.png`, `preview.png`, `workshop.txt`;
   three are art and the operator's).

All batches remain **OPEN** pending play receipts. That is normal here.

---

## 6. Ambition

The operator's stated ambition, paraphrased: a simulation that stands
above what anyone else would feasibly offer in the workshop - not
fundamentally just a mod, but an engine simulating exactly what the
game intends to, on a more rigorous and interesting scale.

Treat the system with the scrutiny CAO gets. When a batch record claims
something, the claim should be checkable, checked, and the check should
run.
