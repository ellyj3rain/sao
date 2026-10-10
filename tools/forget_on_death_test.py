#!/usr/bin/env python3
r"""Border 72 - a per-id cache that outlives the id.

`Identity.markDead` says it plainly:

    Death is durable: the record stays (a person existed and died
    there), the body's corpse belongs to the engine, and the world does
    not refill the loss immediately.

That is a design decision and a good one. The county remembers its
dead. **Nothing else was told to forget them.**

[B51] found `SAO.Perception.forget` and `SAO.Voice.forget` already
written - the exactly-right functions, nilling the exactly-right
tables - and called from ONE place: `SAO_Harness` tearing down a test
id. So every survivor who ever died left their beliefs about the whole
world and their last spoken line in memory for the rest of the
session, and two pair-keyed cooldown tables kept an entry for every
pair they had ever met or argued with, entries nothing would read
again.

That is the written-but-never-reached class, and it is invisible to
every other border here: the code is correct, the tables are right,
the functions exist. The only thing missing is a caller.

WHAT THIS CHECKS
----------------
Every module-scope table indexed by a survivor id is declared with the
function that clears it. Living caches must be reachable from a death:
either `Identity.markDead` names it, or its clearing function calls
`Identity.markDead`. Return ownership starts after death and has a separate,
checked lifetime ending at acknowledged cancellation or completed return.

Two directions, so the list describes the tree rather than the tree of
some earlier batch:

  * a declared cache whose table or forget has gone is a fault
  * a per-id cache nobody declared is a fault

The second is what makes this hold up. A new cache keyed by id is the
easiest thing in the world to add, and the day it is added is the only
day anybody is thinking about who clears it.

WHY NOT JUST DELETE THE DEAD
----------------------------
Because the record staying is the point - graves, causes of death, the
memorial in the UI and `diedAtHours` all read it, and [B41] already
paid for one field in that record. The dead are kept; the caches that
were only ever about the living are not.
"""
import contextlib
import io
import pathlib
import re
import sys
from functools import lru_cache

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lua_read import function_body as read_function_body, strip_lua

# Controls replace one exact source text at a time. Reading unchanged modules
# again does not add evidence; source text is the cache key, so a mutation can
# never borrow the original module's body or cache-index census.
function_body = lru_cache(maxsize=512)(read_function_body)

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
IDENTITY = "SAO_Identity.lua"
MARK_DEAD = "markDead"

# Every module-scope table keyed by a survivor id, the function that
# clears one id out of it, and how that function is reached from a
# death.
#
#   "named"  - Identity.markDead names the forget in its own body
#   "calls"  - the clearing function calls Identity.markDead itself,
#              so the clear and the death are the same event
CACHES = {
    ("SAO_Gesture.lua", "yielding"): (
        "G.releaseConflict", "gesture-retirement",
        "a selected response retains only its exact pending optional-action "
        "handback; detach releases it and an independent tick retires ended "
        "owners or fully removed Lua and native actions. The action-keyed "
        "optional registry retires explicitly while callback tombstones stay "
        "on the exact action, without relying on weak-table collection"),
    ("SAO_Animals.lua", "A.careRuntime"): (
        "A.forget", "named",
        "exact native feeding work retains a living actor, animal, material "
        "and callback until completion or interruption; death cancels and "
        "clears that runtime while durable outcomes remain on the record"),
    ("SAO_ModMechanics.lua", "runtime"): (
        "M.forget", "named",
        "off-slot cooler observation retains the exact living inventory "
        "body; death drops that handle while corpse items and unresolved "
        "physical intervals remain with their native and durable owners"),
    ("SAO_ModMechanics.lua", "lastFailures"): (
        "M.forget", "named",
        "a living person's cooler log deduplication has no reader after "
        "death; the durable partial-pass proof remains on the record"),
    ("SAO_WindowRepair.lua", "offers"): (
        "retireOffer", "window-offer-retirement",
        "one latest decision-local offer per person is consumed or replaced, "
        "death reaches Controller.forget, and a bounded tick/reset disposes abandoned native handles"),
    ("SAO_WindowRepair.lua", "runtime"): (
        "retireAcknowledged", "window-retirement",
        "death reaches Controller.forget and the exact native cancellation owner; "
        "its independent bounded retry survives agent removal and world reset, "
        "retaining the old body only until native stop and original queue acknowledgement"),
    ("SAO_Needs.lua", "recoveries"): (
        "N.stopRecovery", "recovery-retirement",
        "the exact living recovery receiver is cleared by stopRecovery; "
        "retireRecovery delegates to it on controller drop, adoption, death "
        "and forget. World reset and module reload retire the disposable map "
        "while a detached person's paused intent remains durable"),
    ("SAO_Study.lua", "runtime"): (
        "S.forget", "named",
        "native reading retains a living body and exact book only while work "
        "is active; death interrupts its queue owner and clears runtime "
        "while durable purposes and native page history remain"),
    ("SAO_Animals.lua", "A.travelJobs"): (
        "A.forget", "named",
        "a mounted route retains the living rider, horse and native route "
        "handles; death cancels that runtime job while the durable purpose "
        "and mount history remain on the person record"),
    ("SAO_Posture.lua", "P.jobs"): (
        "P.forget", "named",
        "a native posture holds one living body and exact procedure claim; "
        "death interrupts that result owner and releases the body handle"),
    ("SAO_Cooking.lua", "runtime"): (
        "C.detach", "named",
        "native cooking actions and appliance handles exist only while their "
        "person is living; death retires the exact runtime owner while the "
        "durable interrupted work receipt remains on the person record"),
    ("SAO_ResourceProduction.lua", "runtime"): (
        "R.interrupt", "production-detach",
        "native vessel-fill actions and fixture handles belong to the living "
        "body; detach reaches the exact interrupt owner and releases runtime "
        "while canonical outcomes remain durable"),
    ("SAO_ResourceProduction.lua", "sourceRefresh"): (
        "retireRefresh", "production-detach",
        "a bounded pending handled-source observation retains native handles "
        "only until exact self refresh or detach before and after interruption"),
    ("SAO_Orienting.lua", "states"): (
        "O.forget", "named",
        "native head and body orientation state is bound to one living body; "
        "death clears both the Lua state and its native actuator"),
    ("SAO_Perception.lua", "soundPulses"): (
        "P.forgetSoundCues", "named",
        "short-lived private native sound occurrences have no reader after "
        "their listener dies"),
    ("SAO_Body.lua", "Body.unloaded"): (
        "Body.discard", "named",
        "unloaded bodies retained while interrupted owners reconcile; death "
        "reaches discard, external deaths retain their existing body owner, "
        "and failed SAO teardown is retried by Population recovery"),
    ("SAO_Body.lua", "Body.returning"): (
        "Body.discardReturn", "return",
        "a staged return body created after death, retained through failed "
        "cleanup and cleared by acknowledged discard or completed return"),
    ("SAO_Body.lua", "Body.discarding"): (
        "Body.discard", "named",
        "teardown ownership, retained across failure even after death. "
        "markDead attempts cleanup only for an existing transition; "
        "Population recovery retries dead transitions until removal succeeds"),
    ("SAO_Body.lua", "Body.failedRestore"): (
        "Body.discard", "named",
        "a partial shell retained until teardown succeeds. Death reaches "
        "the same cleanup without removing ordinary corpses; recovery retries"),
    ("SAO_Perception.lua", "P.beliefs"): (
        "P.forget", "named",
        "everything one survivor believes about the world - zombies, "
        "people, factions and places, four tables per believer. The "
        "largest of these by far, and the one that had a forget "
        "nobody called"),
    ("SAO_Voice.lua", "lastSpokeMs"): (
        "V.forget", "named",
        "the wall clock of a survivor's last line, for the ten-second "
        "cooldown"),
    ("SAO_Voice.lua", "lastLine"): (
        "V.forget", "named",
        "the last thing a survivor said, so they do not say it twice "
        "in a row"),
    ("SAO_DormantPopulation.lua", "dormantLastMet"): (
        "D.forgetPairs", "named",
        "a PAIR-keyed meeting clock - one entry per pair of dormant "
        "survivors who have crossed paths, quadratic in the county and "
        "unreadable by anybody once either of them is dead"),
    ("SAO_Standing.lua", "politickAt"): (
        "S.forgetPolitics", "named",
        "a PAIR-keyed doctrine clock, the same shape and the same "
        "problem"),
    ("SAO_Conditions.lua", "Cn.asserted"): (
        "Cn.forget", "named",
        "the conditions a trait asserts onto a person rather than the "
        "draw giving them ([C39]) - the player's own, and any survivor "
        "another mod's trait speaks for. A drawn condition is computed "
        "from the id and costs nothing to keep; an assertion is a "
        "table, and the dead assert nothing"),
    ("SAO_Habits.lua", "Hb.asserted"): (
        "Hb.forget", "named",
        "the habits a trait asserts onto a person rather than the "
        "draw giving them ([C51]) - the player's own. Same shape and "
        "same reason as the conditions' assertion above"),
    ("SAO_Habits.lua", "Hb.bound"): (
        "Hb.forget", "named",
        "a stand-in record for a key that has none ([C51]). The "
        "player's is their own modData and is rebound at every "
        "creation; a survivor never gets one, because a survivor has "
        "a real record. Cleared on death with the assertion it "
        "accompanies"),
    ("SAO_Disposition.lua", "D.assertedSmoker"): (
        "D.forgetSmoker", "named",
        "whether the player took vanilla's own SMOKER trait ([C51]). "
        "Smoking is drawn from the hash for everyone else and costs "
        "nothing to keep; an assertion is an entry"),
    ("SAO_Controller.lua", "Ctl.agents"): (
        "updateAgent", "calls",
        "the live agent registry. Cleared on both death branches "
        "INLINE rather than through markDead, which is correct - this "
        "is the controller's own teardown order and moving it into a "
        "shared module would be worse. It is declared so the census is "
        "the whole census"),
    ("SAO_Controller.lua", "agentFaults"): (
        "Ctl.forget", "named",
        "a per-agent fault counter. It clears itself at three, so a "
        "survivor who faulted twice and then died kept their count "
        "forever - one integer, and the reason to fix it is that "
        "\"one integer\" is how every one of these starts"),
    ("SAO_Controller.lua", "Ctl.agents"): (
        "updateAgent", "calls",
        "the live agent registry. Cleared on both death branches "
        "INLINE rather than through markDead, which is correct - this "
        "is the controller's own teardown order and moving it into a "
        "shared module would be worse. Declared so the census is the "
        "whole census"),
    ("SAO_Body.lua", "Body.active"): (
        "SAO_Controller.lua:updateAgent", "calls",
        "the engine handle for a spawned body. [B51] made both death "
        "branches clear BOTH handle tables: the passive branch cleared "
        "only `knox` and the other only `active`, which is very "
        "probably right about which agents are in which - and nilling "
        "an absent key costs nothing, while being very probably right "
        "costs a batch the day it stops being true"),
    ("SAO_Body.lua", "Body.foreign"): (
        "SAO_Controller.lua:updateAgent", "calls",
        "the engine handle for a body another system drives, cleared on "
        "both death branches for the same reason. [C81] renamed it off "
        "one mod's name and moved nothing"),
    ("SAO_Locomotion.lua", "Loco.jobs"): (
        "Loco.cancel", "named",
        "a survivor's queued move, holding a reference to their body. "
        "`Loco.cancel` was reached only from `Ctl.drop`, and death "
        "clears the agent registry inline without going through it - "
        "so every dead survivor's job stayed, holding their corpse"),
    ("SAO_Controller.lua", "Ctl.pendingCorpses"): (
        "Ctl.forget", "named",
        "[C8] the corpse net's hold - the ONE table whose whole "
        "population is dead by design. Its own sweep clears an entry "
        "when native corpse creation acknowledges completion (after its "
        "grace period), and the death funnel's forget clears it too as "
        "belt-and-braces, so a re-fired markDead can never leave a "
        "stale hold on a body"),
    ("SAO_Controller.lua", "Ctl.coordinationRuntime"): (
        "Ctl.forget", "named",
        "runtime route/body scratch used only while a person driven by an "
        "external execution owner is alive; the durable commitment and "
        "outcome remain in Organization"),
    ("SAO_Driving.lua", "Drv.jobs"): (
        "Drv.cancel", "named",
        "[C114] a drive in progress, holding the driver's body handle "
        "and the Java-side drive it ordered. `Drv.cancel` was reached "
        "only from the drop path, exactly `Loco.cancel`'s shape one "
        "entry up - so every dead driver's job stayed, wheels for "
        "feet, and the car went on being driven by a corpse's handle"),
    ("SAO_Material.lua", "Material.stores"): (
        "Material.forget", "named",
        "[C105] what a LIVING person holds in the provisioning "
        "economy - the model, not the corpse's actual items, which "
        "belong to the engine's body. No trade ever asks a grave, so "
        "a dead person's stock was a table nothing would read again"),
    ("SAO_CoordinationInference.lua", "Inference.pending"): (
        "Inference.forgetPerson", "named",
        "a request-id keyed runtime map whose immutable snapshot owns one "
        "living person; death cancels and removes every matching Lua and "
        "Java task while durable Organization decisions remain untouched"),
}

# Module-scope tables this border's shape rule matches and that are
# NOT keyed by a survivor id. Declared rather than quietly narrowed,
# because the rule that catches them is the same rule that catches the
# real ones and loosening it would cost more than it saves.
NOT_A_SURVIVOR_ID = {
    ("SAO_Sandbox.lua", "SOURCE_PAGES"):
        "keyed by exact source sandbox page id; registerSourcePage stores one renderer rule per installed source page",
    ("SAO_SourceIntegration.lua", "S.loadReport"):
        "keyed by installed source family id, not a person; available verifies that source family's sentinel",
    ("SAO_SourceIntegration.lua", "verified"):
        "keyed by installed source family id and its sealed package SHA; one current source verification per family",
    ("ProjectArcade_PaymentServer.lua", "clawAttempts"):
        "keyed by a source-owned player network attempt id; native claw payment/result correlation is independent of SAO survivor death",
    ("MountedDirection.lua", "visualAngles"): (
        "keyed by an IsoAnimal body, not a survivor id; dismount and animal "
        "removal clear the physical interpolation entry"),
    ("Mounts.lua", "mountPlayerMap"): (
        "keyed by the engine animal id; removeMount clears both sides of the "
        "physical rider-animal relation"),
    ("Mounts.lua", "mountedAnimalLockTicks"): (
        "keyed by the engine animal id; unlock/removal clears the movement "
        "lock cadence"),
    ("Mounts.lua", "onlinePlayerScratch"): (
        "a reused numeric array indexed while scanning the engine online-player "
        "list, not a durable survivor-id cache"),
    ("PlayerDamage.lua", "allowedDamagePartIndices"): (
        "keyed by native BodyPartType index, not a person id; it is the static "
        "set of horse-fall damage locations"),
    ("client.lua", "commandHandlers"): (
        "keyed by source-owned network command name, not a survivor id"),
    ("client.lua", "idCommandMap"): (
        "keyed by source-owned numeric network command id, not a survivor id"),
    ("server.lua", "commandHandlers"): (
        "keyed by source-owned network command name, not a survivor id"),
    ("server.lua", "idCommandMap"): (
        "keyed by source-owned numeric network command id, not a survivor id"),
    ("commands.lua", "commands.clientList"): (
        "keyed by source-owned client command name, not a survivor id"),
    ("commands.lua", "commands.serverList"): (
        "keyed by source-owned server command name, not a survivor id"),
    ("netmetrics.lua", "commandMetrics"): (
        "keyed by source-owned network command name, not a survivor id; metrics "
        "are bounded by the static command registry"),
    ("SAO_Integration.lua", "Integration.extensions"): (
        "keyed by a stable RUNTIME EXTENSION id, not a survivor id. "
        "The installer is code registered once per Lua environment and "
        "reused when each world's callback graph is rebuilt; "
        "unregisterExtension removes one id explicitly"),
    ("SAO_Integration.lua", "Integration.installedExtensions"): (
        "keyed by a stable RUNTIME EXTENSION id, not a survivor id. It is "
        "only the current graph's installation receipt and ensure replaces "
        "the entire table before rebuilding a world"),
    ("SAO_Places.lua", "Pl.cache"): (
        "keyed by `def:getID()` - a BUILDING id out of the engine's "
        "own grid, not a person. Its own comment says so: \"the cache "
        "is keyed by building id and origin, both of which belong to "
        "one world\", and `Pl.reset()` drops the whole thing on a "
        "world change, which is the right lifetime for it. The shape "
        "rule matched a local named `id`; being keyed by an id is not "
        "the same as being keyed by a survivor"),
    ("SAO_Organization.lua", "Org.organizations"): (
        "keyed by an ORGANIZATION id - the county's durable group "
        "records, outliving their members by design, the way "
        "Identity's store outlives its dead. The shape rule matched "
        "the local named `id` in `createOrganization`. What is "
        "per-person lives INSIDE each record, `organization.members`, "
        "and [C90] made the death funnel shed that: markDead walks "
        "`organizationsOf` and `Org.leave` drops the member row and "
        "the office-holdings"),
    ("SAO_Organization.lua", "Org.processes"): (
        "keyed by a durable PROCESS id, not a survivor id. Participant ids "
        "are evidence inside the bounded record and survive death by design; "
        "resolved processes are evicted only by trimProcesses retention"),
    ("SAO_Communication.lua", "Communication.executionOwners"): (
        "keyed by a stable EXECUTION OWNER id such as ZAO, not a survivor "
        "id. The owner registers one adapter for the Lua environment and "
        "unregisterExecutionOwner removes that adapter"),
    ("SAO_SourceUse.lua", "SU.nativeUseOwners"): (
        "keyed by a stable NATIVE-USE ADAPTER id such as ZAO.Diet, not a "
        "survivor id. One adapter is registered for the Lua environment and "
        "is reused for every actor whose bounded reservation names that owner"),
    ("SAO_Settlement.lua", "Settlement.bases"): (
        "keyed by an ORGANIZATION id - the shape rule matched the "
        "local named `organizationId` in `claim`. A base belongs to a "
        "group, not to a person, and the group's ground outlives any "
        "one occupant. The per-person part is `base.members`, and the "
        "same [C90] death-funnel walk reaches `Settlement.leave`, "
        "which drops the occupancy row and - by its own count rule - "
        "dissolves the base when the last member is gone, so no "
        "settlement is held open by graves"),
    ("SAO_Material.lua", "Material.reconciliations"): (
        "keyed by a completed world-source RESERVATION id, not a survivor id. "
        "It is a durable replay decision retained through downstream or "
        "acknowledgement failure; successful acknowledgement cleanup removes "
        "it, while house dissolution removes that group from affected rows"),
    ("SAO_Material.lua", "Material.sourceOwners"): (
        "keyed by an exact native SOURCE id, not a survivor id. It enforces "
        "one projected house owner per physical source; replacement, removal, "
        "projection trimming and house dissolution clear or replace entries"),
    ("SAO_Handover.lua", "runtime"): (
        "keyed by a HANDOVER id, not a survivor id. Every terminal path drops "
        "that exact entry, world rebind clears the table, and H.forgetPerson "
        "releases pending records involving a dead participant through the "
        "Identity.markDead funnel"),
    ("SAO_Handover.lua", "retiring"): (
        "keyed by a HANDOVER id, not a survivor id. It retains the exact "
        "native attempt after a durable terminal result until cancelAttempt "
        "or reconcile witnesses queue and native-action detachment. "
        "H.forgetPerson removes rows involving either dead participant; "
        "world rebind clears all rows, and terminal trimming clears the "
        "same handover key"),
    ("SAO_Treatment.lua", "runtime"): (
        "keyed by a TREATMENT id, not a survivor id. Effective, ineffective, "
        "interrupted, released and queue-refused paths drop the exact entry; "
        "world rebind clears all live handles, and T.forgetPerson releases "
        "pending records involving a dead participant through Identity.markDead"),
    ("SAO_Treatment.lua", "restoredPending"): (
        "keyed by a TREATMENT id, not a survivor id. Runtime-only provenance "
        "marks pending receipts restored from the durable treatment owner; "
        "terminal transitions and trimming drop the exact entry, while world "
        "rebind clears the map before rebuilding it from pending receipts. "
        "T.forgetPerson releases pending records involving a dead participant "
        "through Identity.markDead and the same terminal cleanup"),
}

# What an index has to look like to be a survivor id. `subFaults[name]`
# is keyed by subsystem name, of which there are eight, and is not one
# of these.
ID_INDEX = re.compile(
    r"^(id[A-Za-z0-9]*|[a-z][A-Za-z0-9]*Id|rec\.id|pairKey"
    r"|tostring\(\s*id[A-Za-z0-9]*\s*\))$")

DECL = re.compile(
    r"^(?:local\s+([A-Za-z_]\w*)\s*=\s*\{\}"
    r"|([A-Za-z_]\w*\.[A-Za-z_]\w*)\s*=\s*(?:\2\s*or\s*)?\{\})", re.M)


def indexed(table):
    """`table[` in either spelling.

    A declaration reads `P.beliefs` and the code that clears it reads
    `P.beliefs[id] = nil`, so the qualified form has to match. A bare
    local reads `dormantLastMet[key]` and must NOT match somebody
    else's `other.dormantLastMet`. The first draft used one negative
    lookbehind for both and so rejected every qualified name - it
    reported that `P.forget` does not clear `P.beliefs`, of a function
    whose entire body is `P.beliefs[id] = nil`.
    """
    short = table.split(".")[-1]
    if "." in table:
        return r"(?:" + re.escape(table) + r"|(?<![\w.])"             + re.escape(short) + r")\["
    return r"(?<![\w.])" + re.escape(short) + r"\["


def namespace_of(src, alias):
    """`local P = SAO.Perception` -> "SAO.Perception".

    The declarations name a forget the way its own module writes it -
    `P.forget`, `Pop.forgetPairs` - and `markDead` calls it the way
    every other module has to, through `SAO.`. Without this mapping
    the check degenerates: the first draft asked whether the string
    "forget" appeared in markDead's body, which is true of that body
    the moment ANY module's forget is called. Control A - remove the
    Perception call, the exact defect this border exists for - passed
    it, and that is the only reason this function exists.
    """
    m = re.search(r"^local\s+" + re.escape(alias) + r"\s*=\s*(SAO\.\w+)\s*$",
                  src, re.M)
    return m.group(1) if m else None


LEISURE_ROUTES = {
    'SAO_Leisure.lua': ('Leisure', 'L.detach'),
    'SAO_LeisureArt.lua': ('LeisureArt', 'A.detach'),
    'SAO_LeisureExercise.lua': ('LeisureExercise', 'E.detach'),
    'SAO_LeisureGames.lua': ('LeisureGames', 'G.interrupt'),
    'SAO_LeisureMusic.lua': ('LeisureMusic', 'M.interrupt'),
    'SAO_LeisureLifestyle.lua': ('LeisureLifestyle', 'L.interrupt'),
    'SAO_LeisureRadio.lua': ('LeisureRadio', 'R.interrupt'),
    'SAO_LeisureMusicSupply.lua': ('LeisureMusicSupply', 'S.interrupt'),
    'SAO_LeisurePreparation.lua': ('LeisurePreparation', 'Q.interrupt'),
    'SAO_LeisureSeating.lua': ('LeisureSeating', 'S.interrupt'),
}
for filename in LEISURE_ROUTES:
    CACHES[(filename, 'runtime')] = (
        'finish', 'leisure-retirement',
        'exact native hobby handles end through the existing controller detach/death route and captured source terminal owner')
CACHES.update({
    ('SAO_Perception.lua', 'conceptObservers'): ('P.forget', 'named', 'current native conceptual observation body owner'),
    ('SAO_Perception.lua', 'weekOneNativeSignals'): ('P.forgetSoundCues', 'named', 'listener-private current source native sound witnesses'),
    ('SAO_LeisureRadio.lua', 'sources'): ('R.onNativeTick', 'native-radio-sweep', 'live native radio source callbacks expire with their exact body/token'),
    ('SAO_LeisureSkill.lua', 'inFlight'): ('S.consume', 'synchronous-guard', 'non-reentrant native XP application guard cleared after the protected call'),
    ('SAO_WeekOneContinuity.lua', 'sourceInquiryBodies'): ('W.observePendingSourceInquiries', 'source-inquiry-retirement', 'pending exact source execution receiver retained only until acknowledged terminal settlement'),
    ('SAO_WeekOneContinuity.lua', 'fastSoundObserved'): ('W.poll', 'tick-ephemeral', 'one county tick of exact native sound observation, reset before the next tick and removed on dead/source-owner-ended polls'),
    ('SAO_WeekOneContinuity.lua', 'staged'): ('clearStage', 'source-stage', 'a native return destination retained until acknowledged discard, with independent retries continuing after death'),
})


@lru_cache(maxsize=256)
def cache_body(source, name):
    body = function_body(source, name)
    if body is None:
        # Several captured action terminal owners are forward-declared locals
        # assigned a function later; the same block reader reads that body.
        transformed = re.sub(r'^(\s*)(?:local\s+)?' + re.escape(name) + r'\s*=\s*function\s*\(',
                             r'\1function ' + name + '(', source, flags=re.M)
        body = function_body(transformed, name)
    return body


@lru_cache(maxsize=2048)
def cache_index_sites(source):
    sites = []
    for name in {a or b for a, b in DECL.findall(source)}:
        lines = tuple(source.count('\n', 0, match.start()) + 1
                      for match in re.finditer(indexed(name) + r'\s*([^\][]+?)\s*\]', source)
                      if ID_INDEX.match(match.group(1)))
        if lines:
            sites.append((name, lines))
    return tuple(sites)


def check_files(files, preserved=None):
    faults = []
    print("=" * 74)
    print("A PER-ID CACHE THAT OUTLIVES THE ID")
    print("=" * 74)

    if not files:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so no cache was examined - a "
              "verdict about an empty set")
        return 1

    ident = files.get(IDENTITY)
    if ident is None:
        print()
        print("VERDICT:")
        print(f"  FAULT: {IDENTITY} is gone, and with it the one funnel "
              "every death path reaches")
        return 1
    dead_body = function_body(ident, "Identity." + MARK_DEAD)
    if not dead_body:
        print()
        print("VERDICT:")
        print(f"  FAULT: {IDENTITY} has no `Identity.{MARK_DEAD}` - either "
              "it was renamed, in which case every entry below is stale, or "
              "death no longer funnels anywhere")
        return 1

    # THE CENSUS: module-scope tables actually indexed by an id.
    found = set()
    for fname, src in sorted(files.items()):
        for name, lines in cache_index_sites(src):
            known = (fname, name) in CACHES or (fname, name) in NOT_A_SURVIVOR_ID
            if any(known or preserved is None or not preserved(fname, src, line) for line in lines):
                found.add((fname, name))

    print(f"  Lua files read      : {len(files)}")
    print(f"  per-id caches found : {len(found)}")
    print(f"  declared            : {len(CACHES)}")
    print(f"  matched but not a person: {len(NOT_A_SURVIVOR_ID)}")

    for key, why in sorted(NOT_A_SURVIVOR_ID.items()):
        if key in CACHES:
            faults.append(
                f"{key[0]}:{key[1]} is declared both as a per-id cache and "
                "as not being one. One of the two entries is false")
        elif key not in found:
            faults.append(
                f"{key[0]}:{key[1]} is declared as matching this border's "
                "shape rule without being a survivor cache, and it no "
                "longer matches - so the exemption is protecting nothing "
                f"and hiding whatever replaces it ({why[:40]}...)")

    for key in sorted(found - set(CACHES) - set(NOT_A_SURVIVOR_ID)):
        faults.append(
            f"{key[0]} has a module-scope `{key[1]}` keyed by a survivor id "
            "and nobody declared who clears it. The county keeps its dead on "
            "purpose and this table was only ever about the living, so every "
            "death leaves an entry nothing will read again. Say which "
            "function forgets one id, and make a death reach it")

    for (fname, table), (forget, how, what) in sorted(CACHES.items()):
        src = files.get(fname)
        if src is None:
            faults.append(
                f"a cache is declared in {fname} and no such file exists")
            continue
        short = table.split(".")[-1]
        if not re.search(indexed(table), src):
            faults.append(
                f"{fname} no longer has `{table}` - the entry describes a "
                "table that is gone, so this border has been checking "
                "nothing about it")
            continue

        # A forget may live in another module - the two body handles
        # are cleared by the controller's own death branches, in the
        # file that owns the teardown order rather than the file that
        # owns the table. Declared as `File.lua:function` when so.
        home, fname_fn = src, forget
        if ":" in forget:
            where, fname_fn = forget.split(":", 1)
            home = files.get(where)
            if home is None:
                faults.append(
                    f"{table}'s forget is declared to live in {where} and "
                    "no such file exists")
                continue
        fbody = cache_body(home, fname_fn)
        if fbody is None:
            faults.append(
                f"{fname} has no `{forget}`, and it is what was supposed to "
                f"clear `{table}` on death")
            continue
        if how != "self" and not re.search(
                indexed(table) + r".*?\]\s*=\s*nil", fbody):
            faults.append(
                f"{fname}:{forget} is declared as what clears `{table}` and "
                "nothing in it sets an entry to nil. Either it stopped "
                "clearing or the entry names the wrong function")
            continue

        if how == 'leisure-retirement':
            controller = files.get('SAO_Controller.lua', '')
            retire = function_body(controller, 'Ctl.retireLeisureWork') or ''
            death = function_body(controller, 'retireDeadBodyWork') or ''
            module, method = LEISURE_ROUTES[fname]
            entry = function_body(src, method) or ''
            if module == 'LeisureMusicSupply':
                owner = function_body(files.get('SAO_LeisureMusic.lua', ''), 'M.interrupt') or ''
                reached = 'SAO.LeisureMusicSupply.interrupt' in owner
            elif module in ('LeisurePreparation', 'LeisureSeating'):
                reached = '"' + module + '"' in retire
            else:
                reached = 'module="' + module + '"' in re.sub(r'\s+', '', controller)
            if not reached or not re.search(r'\bfinish\s*\(', entry):
                faults.append(fname + ': controller retirement no longer reaches its captured finish owner')
            if (not re.search(r'Ctl\.retireLeisureWork\s*\(\s*id\s*,\s*Ctl\.agents\[id\]\s*,\s*body\s*,\s*"death"\s*\)', death)
                    or 'owner.detach or owner.interrupt' not in retire
                    or 'pcall(close,id,body,reason)' not in retire):
                faults.append('native death no longer reaches exact leisure retirement')
        elif how == 'native-radio-sweep':
            if not all(token in fbody for token in ('not live(id,body)', 'SAOExternalToken~=source.bodyToken', 'sources[id]=nil')):
                faults.append('native radio source liveness/token sweep is incomplete')
            compact = re.sub(r'\s+', '', src)
            if ('R.eventCallback=function()R.onNativeTick()end;Events.OnTick.Add(R.eventCallback)' not in compact
                    or 'sources={}' not in re.sub(r'\s+', '', function_body(src, 'R.reset') or '')):
                faults.append('native radio source sweep/reset is unreachable')
        elif how == 'synchronous-guard':
            if not re.search(r'inFlight\[id\]\s*=\s*true\s+local\s+\w+\s*=\s*pcall\(function\(\).*?end\)\s+inFlight\[id\]\s*=\s*nil',
                             strip_lua(fbody, strings=False), re.S):
                faults.append('native XP application guard is not cleared immediately after its protected call')
        elif how == 'source-inquiry-retirement':
            if not all(token in fbody for token in ('rec.dead', 'result = "interrupted"', 'planner.finishSourceSituationInquiry', 'if ok and recorded == true then', 'sourceInquiryBodies[personId] = nil')):
                faults.append('source inquiry retirement no longer acknowledges and clears ended native execution')
            compact = re.sub(r'\s+', '', src)
            if not re.search(r'W\.onTick=function\(\).*?W\.observePendingSourceInquiries\(\).*?endEvents\.OnTick\.Add\(W\.onTick\)', compact):
                faults.append('source inquiry retirement is unreachable from the independent poll')
        elif how == 'tick-ephemeral':
            tick = function_body(src, 'W.onBudgetTick') or ''
            reset = tick.find('fastSoundObserved = {}')
            short = tick.find('if queuedCount == 0')
            if not (0 <= reset < short and 'if budgetTick ~= tick then' in tick
                    and 'rec.dead or rec.weekOne.status ~= "external"' in fbody
                    and 'W.onBudgetTick()' in src and 'Events.OnTick.Add(W.onTick)' in src):
                faults.append('native sound sampling does not expire independently of the scan queue and dead actors')
        elif how == 'source-stage':
            poll = function_body(src, 'W.poll') or ''
            retry = poll.find('if rec.weekOne.stageToken then clearStage(rec) end')
            living = poll.find('if rec and rec.weekOne and not rec.dead then')
            if not (0 <= retry < living
                    and 'discardReturnBody(body) ~= true then return false end' in fbody
                    and 'not rec.weekOne.stageToken' in poll):
                faults.append('source staged-body discard does not retain acknowledgement and retry after death')
        elif how == "named":
            alias, _, fn = fname_fn.partition(".")
            ns = namespace_of(home, alias) if fn else None
            if ns is None:
                faults.append(
                    f"`{fname_fn}` is declared as a forget markDead calls by "
                    f"name, and `local {alias} = SAO.Something` is not in "
                    "its file - so there is no way to know what the rest of "
                    "the tree has to write to reach it")
            elif (ns + "." + fn) not in dead_body:
                # C58 preserves the public Population API as a forwarding
                # function. Prove both calls instead of treating the old
                # module name as the cache owner.
                compatibility = {
                    "SAO.DormantPopulation.forgetPairs":
                        ("SAO_Population.lua", "Pop.forgetPairs",
                         "SAO.Population.forgetPairs"),
                }.get(ns + "." + fn)
                forwarded = False
                if compatibility:
                    owner, method, public = compatibility
                    wrapper = function_body(files.get(owner, ""), method) or ""
                    forwarded = (re.search(re.escape(public) + r"\s*,", dead_body) is not None
                                 and re.search(r"return\s+" + re.escape(ns + "." + fn)
                                               + r"\s*\(\s*id\s*\)", wrapper) is not None)
                if forwarded:
                    continue
                faults.append(
                    f"`{ns}.{fn}` clears {table} ({what}) and "
                    f"Identity.{MARK_DEAD} does not name it. The function is "
                    "correct and nothing calls it on a death - which is the "
                    "exact shape [B51] found, where two forgets had been "
                    "written and were reached only by the test harness")
        elif how == "calls":
            if MARK_DEAD not in fbody:
                faults.append(
                    f"`{forget}` is declared as clearing {table} inline at "
                    f"the death itself, and it no longer calls {MARK_DEAD}. "
                    "So the clear and the death are now two events, and "
                    "there is nothing left tying them together")
        elif how == "return":
            return_src = files.get("SAO_AfflictedReturn.lua", "")
            owner = strip_lua(function_body(return_src, "step") or "")
            recover = strip_lua(function_body(src, "Body.recover") or "")
            if not re.search(r"SAO\.Body\.discardReturn\s*\(\s*rec\s*\)", owner):
                faults.append("return cancellation no longer reaches Body.discardReturn")
            completion = owner
            if re.search(r"\breturn\s+commit\s*\(\s*rec\s*,", owner):
                completion += strip_lua(function_body(return_src, "commit") or "")
            if not re.search(r"SAO\.Body\.returning\[rec\.id\]\s*=\s*nil", completion):
                faults.append("completed return no longer clears its staged body handle")
            if not re.search(r"SAO\.AfflictedReturn\.resume\s*\(\s*rec\s*\)", recover):
                faults.append("body recovery no longer reaches the durable return owner")
        elif how == "production-detach":
            detach = function_body(src, "R.detach") or ""
            if "SAO.ResourceProduction.detach" not in dead_body:
                faults.append("native production refresh retirement is absent from markDead")
            if len(re.findall(r"retireRefresh\s*\(\s*id\s*,", detach)) != 2 or "R.interrupt" not in detach:
                faults.append("production detach must retire handled-source references before and after interrupt")
        elif how == "gesture-retirement":
            def body(source, method):
                return re.sub(r"\s+", "", strip_lua(function_body(source, method) or "", strings=False))

            release = body(src, "G.releaseConflict")
            retire = body(src, "retireHandbacks")
            owner = body(src, "currentOwner")
            optional_owner = body(src, "optionalOwner")
            stop = body(src, "stopGesture")
            perform = body(src, "performGesture")
            public_play = body(src, "G.play")
            play = body(src, "queueGesture")
            reset_instruments = body(src, "G.resetInstruments")
            stop_sound = body(src, "stopOwnedSound")
            queue_owner = body(src, "ownsMaterialQueue")
            detach = body(files.get("SAO_ConflictResponse.lua", ""), "R.detach")
            code = re.sub(r"\s+", "", strip_lua(src, strings=False))
            absent = ("ISTimedActionQueue.hasAction(action)~=trueandnot(action.actionand"
                      "work.body:getCharacterActions():contains(action.action))")
            owner_checks = {
                "public gesture admission reaches the private queue owner":
                    'returnqueueGesture(id,body,name,ticks,planReceipt,requiredItem)' in public_play,
                "instrument sound cleanup prunes ended person and body owners":
                    'forstate,ownerinpairs(soundCleanup)doifnotcurrentOwner(owner.id,owner.body,owner.rec,owner.token)thensoundCleanup[state]=nil' in retire,
                "instrument sound cleanup uses only its exact retained handle":
                    'state.emitter:stopSound(state.sound)' in stop_sound
                    and 'returnstate.emitter:isPlaying(state.sound)==false' in stop_sound,
                "instrument reset retires all native sound references":
                    'forstate,ownerinpairs(soundCleanup)doifcurrentOwner(owner.id,owner.body,owner.rec,owner.token)thenstopOwnedSound(state)endsoundCleanup[state]=nilend' in reset_instruments,
                "instrument pending cleanup prevents unbounded successor ownership":
                    'for_,ownerinpairs(soundCleanup)doifowner.body==bodyandcurrentOwner(owner.id,owner.body,owner.rec,owner.token)thenreturnfalseendend' in play,
                "gesture release keeps exact body and drops retained action":
                    'ifnotworkorwork.body~=bodythenreturnfalseend' in release
                    and 'yielding[id]=nilwork.action=nil' in release,
                "response detach reaches gesture reference release":
                    'SAO.Gesture.releaseConflict(id,body)' in detach,
                "gesture retirement runs independently of another decision":
                    'Events.OnTick.Add(retireHandbacks)' in code,
                "gesture retirement recognizes ended canonical owners":
                    'current~=recorcurrent.deadorcurrent.bodyOwner' in owner
                    and 'SAO.Body.get(id)~=body' in owner
                    and 'data.SAOExternalToken==tokenandcurrent.bodyOwnerToken==token' in owner
                    and 'notbody:isDead()' in owner
                    and 'currentOwner(work.id,work.body,work.rec,work.token)' in optional_owner,
                "gesture handback waits for both Lua and native removal or owner end":
                    ('forid,workinpairs(yielding)dolocalaction=work.action'
                     'ifnotactionornotoptionalOwner(action,work)or'+absent+
                     'thenG.releaseConflict(id,work.body)endend') in retire,
                # optional[action] is deliberately outside the survivor-ID
                # census. Its exact-action lifetime is checked here instead
                # of adding an exemption for a shape the census never found.
                "gesture live action registry prunes ended owners and removed actions":
                    ('foraction,workinpairs(optional)doifnotoptionalOwner(action,work)or'+absent+
                     'thenoptional[action]=nilwork.retired=true') in retire,
                "gesture terminal callbacks remove their exact registry entries":
                    'optional[self]=nilwork.retired=true' in stop
                    and 'optional[self]=nil;work.retired=true;work.action=nil' in perform,
                "gesture failed queue admission retires its registry entry":
                    'ifnotokthenoptional[action]=nil;work.retired=true;work.action=nilend' in play,
                "gesture late callbacks retain private exact-action tombstones":
                    'action.stop=function(self)ifself==actionthenstopGesture(self,work)endend' in play
                    and 'action.perform=function(self)ifself==actionthenperformGesture(self,work)endend' in play
                    and 'work.retiredornotoptionalOwner(action,work)' in queue_owner
                    and 'ifnotownsMaterialQueue(self,work)thenreturnend' in stop
                    and 'ifnotownsMaterialQueue(self,work)thenreturnend' in perform,
            }
            faults.extend(name for name, present in owner_checks.items() if not present)
        elif how == "window-offer-retirement":
            def body(source, method):
                return strip_lua(function_body(source, method) or "", strings=False)

            controller = files.get("SAO_Controller.lua", "")
            owner_checks = {
                "offer death reaches exact indirect forget":
                    re.search(r"pcall\s*\(\s*SAO\.Controller\.forget\s*,\s*rec\.id\s*\)", strip_lua(dead_body))
                    and 'SAO.WindowRepair.forget(id)' in body(controller, "Ctl.forget")
                    and 'retireOffer(id)' in body(src, "W.forget"),
                "offer replacement and consumption retire the old slot":
                    'retireOffer(id)' in body(src, "W.offer") and 'retireOffer(id)' in body(src, "W.begin")
                    and 'slot.offer == offer' in body(src, "W.begin"),
                "offer admission has finite native capacity":
                    'offerCount >= MAX_OFFERS' in body(src, "W.offer")
                    and 'offers[id] = { offer = offer, binding = b }' in body(src, "W.offer"),
                "abandoned offers expire at tick and world boundaries":
                    'offers = {}' in body(src, "W.expireOffers")
                    and 'Events.OnTick.Add(W.expireOffers)' in strip_lua(src, strings=False)
                    and 'W.expireOffers()' in body(src, "W.reset"),
            }
            faults.extend(name for name, present in owner_checks.items() if not present)
        elif how == "window-retirement":
            def body(source, method):
                return strip_lua(function_body(source, method) or "", strings=False)

            controller = files.get("SAO_Controller.lua", "")
            retire = body(src, "retireAcknowledged")
            interrupt = body(src, "W.interrupt")
            retry = body(src, "W.retryCancellations")
            stop = body(src, "base:stop")
            reset = body(src, "W.reset")
            owner_checks = {
                "window death reaches indirect controller forget":
                    re.search(r"pcall\s*\(\s*SAO\.Controller\.forget\s*,\s*rec\.id\s*\)", strip_lua(dead_body)),
                "controller forget reaches window cancellation owner":
                    'SAO.WindowRepair.forget(id)' in body(controller, "Ctl.forget"),
                "window forget retains exact old receiver":
                    'return W.interrupt(id, active and active.binding.body, "controller-forget")' in body(src, "W.forget"),
                "window retirement requires exact owner and queue acknowledgement":
                    'if runtime[id] ~= active then' in retire and 'queued(action)' in retire
                    and 'b.cancelled and action.action and not b.stopAcknowledged' in retire
                    and 'releaseBinding(action, b)' in retire,
                "window cancellation requests native stop and retains a retry":
                    'scheduleCancellation(active)' in interrupt and 'action.action:forceStop()' in interrupt
                    and 'return retireAcknowledged(id, active)' in interrupt,
                "native window stop acknowledges its captured queue and retires":
                    'local q = b.queue' in stop and 'b.stopAcknowledged = true' in stop
                    and 'retireAcknowledged(b.personId, active)' in stop,
                "window stop preserves current successor custody":
                    'ownsCurrent = q.current == self and q:indexOf(self) == 1' in stop
                    and 'ISTimedActionQueue.getTimedActionQueue(b.body) == q' in stop
                    and 'if not ownsCurrent then' in stop
                    and 'if ownsCurrent then\n            b.body:setIsFarming(false)\n            q:onCompleted(self)\n        else' in stop,
                "window retries are bounded independently of living agents":
                    'math.min(#cancellationOrder, MAX_CANCELLATIONS_PER_TICK)' in retry
                    and 'table.remove(cancellationOrder, 1)' in retry and 'W.interrupt(b.personId, b.body,' in retry
                    and 'Events.OnTick.Add(W.retryCancellations)' in strip_lua(src, strings=False),
                "world reset preserves the exact pending window cancellations":
                    'for id, active in pairs(runtime) do W.interrupt(id, active.binding.body,' in reset
                    and 'Events.OnInitGlobalModData.Add(W.reset)' in strip_lua(src, strings=False)
                    and 'W.reset("world-reset")' in strip_lua(src, strings=False),
                "module reload retains the previous window cancellation closure":
                    'pcall(W.reset, "module-reload")' in strip_lua(src, strings=False)
                    and re.search(r'if\s+W\.runtimeCount\s+then.*?return\s+W', strip_lua(src), re.S),
            }
            faults.extend(name for name, present in owner_checks.items() if not present)
        elif how == "recovery-retirement":
            def body(source, method):
                return strip_lua(function_body(source, method) or "", strings=False)

            retire = body(src, "N.retireRecovery")
            reset = body(src, "N.resetRecoveries")
            controller = files.get("SAO_Controller.lua", "")
            owner_checks = {
                "recovery retirement reaches exact receiver clearing":
                    re.search(r"return\s+N\.stopRecovery\s*\(\s*id\s*,\s*work\.body\s*,\s*reason\s*,\s*true\s*\)", retire),
                "death reaches controller recovery retirement":
                    re.search(r"pcall\s*\(\s*SAO\.Controller\.forget\s*,\s*rec\.id\s*\)",
                              strip_lua(dead_body)),
                "controller forget retires recovery":
                    'SAO.Needs.retireRecovery(id, "controller-forget")' in body(controller, "Ctl.forget"),
                "controller drop retires recovery":
                    'SAO.Needs.retireRecovery(id, "controller-drop")' in body(controller, "Ctl.drop"),
                "controller adoption retires the old recovery receiver":
                    'SAO.Needs.retireRecovery(rec.id, "controller-adopt")' in body(controller, "Ctl.adopt"),
                "native death retires recovery":
                    'SAO.Needs.retireRecovery(id, "death")' in body(controller, "retireDeadBodyWork"),
                "both native death branches reach recovery retirement":
                    len(re.findall(r"retireDeadBodyWork\s*\(\s*id\s*,\s*body\s*,\s*agent\.rec\s*\)",
                                   body(controller, "updateAgent"))) == 2,
                "world reset retires every recovery receiver":
                    re.search(r"for\s+id\s+in\s+pairs\(recoveries\)\s+do\s+N\.retireRecovery\s*\(\s*id\s*,", reset),
                "world start reaches recovery reset":
                    'N.resetRecoveries("world-reset")' in strip_lua(src, strings=False)
                    and re.search(r"Events\.OnGameStart\.Add\s*\(\s*N\.recoveryResetHandler\s*\)", strip_lua(src)),
                "module reload retires the previous recovery map":
                    re.search(r'pcall\s*\(\s*N\.resetRecoveries\s*,\s*"module-reload"\s*\)',
                              strip_lua(src, strings=False)),
            }
            faults.extend(name for name, present in owner_checks.items() if not present)
        elif how != "self":
            faults.append(f"{table} has an unknown lifetime rule {how!r}")
        print(f"     {fname}:{table:<18} <- {forget} ({how})")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  72) person cache lifetime: all {len(CACHES)} per-id caches "
          "have reachable death or return cleanup")
    return 0


def main():
    from source_scanner_baseline import Baseline
    baseline = Baseline()
    paths = {p.name: p for p in baseline.inventory.structural_lua()}
    files = {name: p.read_text(encoding="utf-8", errors="ignore") for name, p in paths.items()}
    def preserved(name, source, line):
        return source == files.get(name) and baseline.preserved(paths[name], line)
    status = check_files(files, preserved)
    if status:
        return status
    controls = [
        ('SAO_Leisure.lua', 'runtime[id] = nil', 'runtime[id] = runtime[id]', 'nothing in it sets an entry to nil'),
        ('SAO_Controller.lua', 'Ctl.retireLeisureWork(id,Ctl.agents[id],body,"death")', 'do end', 'native death no longer reaches exact leisure retirement'),
        ('SAO_LeisureSkill.lua', 'inFlight[id]=nil', 'inFlight[id]=true', 'nothing in it sets an entry to nil'),
        ('SAO_LeisureRadio.lua', 'sources[id]=nil', 'sources[id]=source', 'nothing in it sets an entry to nil'),
        ('SAO_WeekOneContinuity.lua', 'budgetTick, budgetUsed = tick, 0\n        fastSoundObserved = {}', 'budgetTick, budgetUsed = tick, 0\n        do end', 'native sound sampling does not expire'),
        ('SAO_WeekOneContinuity.lua', 'if rec.weekOne.stageToken then clearStage(rec) end', 'do end', 'source staged-body discard does not retain acknowledgement'),
        ("SAO_WindowRepair.lua", "q.current == self and q:indexOf(self) == 1", "true",
         "window stop preserves current successor custody"),
        ("SAO_WindowRepair.lua", "if ownsCurrent then\n            b.body:setIsFarming(false)", "if true then\n            b.body:setIsFarming(false)",
         "window stop preserves current successor custody"),
        ("SAO_WindowRepair.lua", "offers[id] = nil", "offers[id] = offers[id]",
         "nothing in it sets an entry to nil"),
        ("SAO_WindowRepair.lua", "offerCount >= MAX_OFFERS", "false",
         "offer admission has finite native capacity"),
        ("SAO_WindowRepair.lua", "Events.OnTick.Add(W.expireOffers)", "do end",
         "abandoned offers expire at tick and world boundaries"),
        ("SAO_WindowRepair.lua", "local observed = slot and slot.offer == offer and slot.binding", "local observed = slot and true and slot.binding",
         "offer replacement and consumption retire the old slot"),
        ("SAO_WindowRepair.lua", "    releaseBinding(action, b)\n    if c then releasePreparation(c) end", "    do end\n    if c then releasePreparation(c) end",
         "window retirement requires exact owner and queue acknowledgement"),
        ("SAO_WindowRepair.lua", "runtime[id] = nil", "runtime[id] = active",
         "nothing in it sets an entry to nil"),
        ("SAO_Controller.lua", "SAO.WindowRepair.forget(id)", "do end",
         "controller forget reaches window cancellation owner"),
        ("SAO_WindowRepair.lua", 'return W.interrupt(id, active and active.binding.body, "controller-forget")', "return true",
         "window forget retains exact old receiver"),
        ("SAO_WindowRepair.lua", "b.cancelled and action.action and not b.stopAcknowledged", "false",
         "window retirement requires exact owner and queue acknowledgement"),
        ("SAO_WindowRepair.lua", "action.action:forceStop()", "do end",
         "window cancellation requests native stop and retains a retry"),
        ("SAO_WindowRepair.lua", "if active and active.binding == b then retireAcknowledged(b.personId, active) end", "do end",
         "native window stop acknowledges its captured queue and retires"),
        ("SAO_WindowRepair.lua", "Events.OnTick.Add(W.retryCancellations)", "do end",
         "window retries are bounded independently of living agents"),
        ("SAO_WindowRepair.lua", "Events.OnInitGlobalModData.Add(W.reset)", "do end",
         "world reset preserves the exact pending window cancellations"),
        ("SAO_WindowRepair.lua", 'pcall(W.reset, "module-reload")', "do end",
         "module reload retains the previous window cancellation closure"),
        ("SAO_Needs.lua", "recoveries[id] = nil", "recoveries[id] = recoveries[id]",
         "nothing in it sets an entry to nil"),
        ("SAO_Needs.lua", "return N.stopRecovery(id, work.body, reason, true)", "return false",
         "recovery retirement reaches exact receiver clearing"),
        ("SAO_Identity.lua", "pcall(SAO.Controller.forget, rec.id)", "pcall(function() end)",
         "death reaches controller recovery retirement"),
        ("SAO_Controller.lua", 'SAO.Needs.retireRecovery(id, "controller-forget")', "do end",
         "controller forget retires recovery"),
        ("SAO_Controller.lua", 'SAO.Needs.retireRecovery(id, "controller-drop")', "do end",
         "controller drop retires recovery"),
        ("SAO_Controller.lua", 'SAO.Needs.retireRecovery(rec.id, "controller-adopt")', "do end",
         "controller adoption retires the old recovery receiver"),
        ("SAO_Controller.lua", 'SAO.Needs.retireRecovery(id, "death")', "do end",
         "native death retires recovery"),
        ("SAO_Controller.lua", "retireDeadBodyWork(id, body, agent.rec)", "do end",
         "both native death branches reach recovery retirement"),
        ("SAO_Needs.lua", 'N.retireRecovery(id, reason or "world-reset")', "do end",
         "world reset retires every recovery receiver"),
        ("SAO_Needs.lua", "Events.OnGameStart.Add(N.recoveryResetHandler)", "do end",
         "world start reaches recovery reset"),
        ("SAO_Needs.lua", 'pcall(N.resetRecoveries, "module-reload")', "pcall(function() end)",
         "module reload retires the previous recovery map"),
        ("SAO_ConflictResponse.lua", 'SAO.Gesture.releaseConflict(id,body)', 'do end',
         "response detach reaches gesture reference release"),
        ("SAO_Gesture.lua", 'return queueGesture(id, body, name, ticks, planReceipt, requiredItem)',
         'return false', "public gesture admission reaches the private queue owner"),
        ("SAO_Gesture.lua", 'if not currentOwner(owner.id, owner.body, owner.rec, owner.token) then soundCleanup[state] = nil',
         'if false then soundCleanup[state] = nil', "instrument sound cleanup prunes ended person and body owners"),
        ("SAO_Gesture.lua", 'state.emitter:stopSound(state.sound)',
         'state.emitter:stopSound(0)', "instrument sound cleanup uses only its exact retained handle"),
        ("SAO_Gesture.lua", 'if currentOwner(owner.id, owner.body, owner.rec, owner.token) then stopOwnedSound(state) end\n        soundCleanup[state] = nil',
         'if currentOwner(owner.id, owner.body, owner.rec, owner.token) then stopOwnedSound(state) end',
         "instrument reset retires all native sound references"),
        ("SAO_Gesture.lua", 'if owner.body == body and currentOwner(owner.id, owner.body, owner.rec, owner.token) then return false end',
         'if false then return false end', "instrument pending cleanup prevents unbounded successor ownership"),
        ("SAO_Gesture.lua", 'Events.OnTick.Add(retireHandbacks)', 'do end',
         "gesture retirement runs independently of another decision"),
        ("SAO_Gesture.lua", 'if not work or work.body ~= body then return false end',
         'if not work then return false end', "gesture release keeps exact body and drops retained action"),
        ("SAO_Gesture.lua", 'yielding[id] = nil\n    work.action = nil\n    return true\nend\n\n-- A pending',
         'yielding[id] = work\n    work.action = nil\n    return true\nend\n\n-- A pending',
         "nothing in it sets an entry to nil"),
        ("SAO_Gesture.lua", 'current ~= rec or current.dead or current.bodyOwner',
         'current ~= rec or current.bodyOwner', "gesture retirement recognizes ended canonical owners"),
        ("SAO_Gesture.lua", 'if not action or not optionalOwner(action, work)\n            or ISTimedActionQueue.hasAction(action) ~= true\n                and not (action.action and work.body:getCharacterActions():contains(action.action)) then',
         'if not action or not optionalOwner(action, work) or ISTimedActionQueue.hasAction(action) ~= true then',
         "gesture handback waits for both Lua and native removal or owner end"),
        ("SAO_Gesture.lua", 'optional[action] = nil\n            work.retired = true',
         'work.retired = true', "gesture live action registry prunes ended owners and removed actions"),
        ("SAO_Gesture.lua", 'optional[self] = nil\n        work.retired = true',
         'work.retired = true', "gesture terminal callbacks remove their exact registry entries"),
        ("SAO_Gesture.lua", 'if work then optional[self] = nil;work.retired = true;work.action = nil end',
         'if work then work.retired = true;work.action = nil end',
         "gesture terminal callbacks remove their exact registry entries"),
        ("SAO_Gesture.lua", 'if not ok then optional[action] = nil;work.retired = true;work.action = nil end',
         'if not ok then work.retired = true;work.action = nil end',
         "gesture failed queue admission retires its registry entry"),
        ("SAO_Gesture.lua", 'action.stop = function(self) if self == action then stopGesture(self, work) end end',
         'action.stop = function(self) if self == action then stopGesture(self, nil) end end',
         "gesture late callbacks retain private exact-action tombstones"),
    ]
    for filename, before, after, expected in controls:
        source = files.get(filename, "")
        want = 2 if before == "retireDeadBodyWork(id, body, agent.rec)" else 1
        if source.count(before) != want:
            print(f"  FAULT: recovery control anchor drift: {filename}: {expected}")
            return 1
        mutated = dict(files)
        mutated[filename] = source.replace(before, after, 1)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = check_files(mutated, preserved)
        if exit_code != 1 or "  FAULT: " not in output.getvalue() or expected not in output.getvalue():
            print(f"  FAULT: recovery control did not reject its defect: {expected}")
            return 1
        print(f"  CONTROL rejected: {expected}")
    print(f"  72) person lifetime controls: {len(controls)} rejected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
