#!/usr/bin/env python3
r"""Border 180 - exact results and private delivery response remain causal.

The dynamic probe runs the shipped WorldSources, Material, Settlement,
Recognition, Provisioning and GraphPersistence modules in Project Zomboid's
Kahlua VM. It exercises upgrade, retry/reload, ownership transfer, claim lapse,
personal access and acknowledgement order. Its delivery seams also execute
private transfer/request acquisition and listener-owned testimony appraisal.
Static mutation controls keep the surrounding action, scheduling and
false-producer boundaries attached.
"""
from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
LUA = ROOT / "mod/42.20/media/lua"
WORLD = LUA / "shared/SAO_WorldSources.lua"
MATERIAL = LUA / "shared/SAO_Material.lua"
SETTLEMENT = LUA / "shared/SAO_Settlement.lua"
RECOGNITION = LUA / "shared/SAO_Recognition.lua"
PROVISIONING = LUA / "shared/SAO_Provisioning.lua"
GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
WORLD_GENESIS = LUA / "shared/SAO_WorldGenesis.lua"
STANDING = LUA / "shared/SAO_Standing.lua"
DORMANT = LUA / "client/SAO_DormantPopulation.lua"
NEEDS = LUA / "client/SAO_Needs.lua"
SOURCE_USE = LUA / "client/SAO_SourceUse.lua"
POPULATION = LUA / "client/SAO_Population.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
INSPECT = LUA / "client/SAO_Inspect.lua"
INTEGRATION = LUA / "shared/SAO_Integration.lua"
LABOR = LUA / "shared/SAO_Labor.lua"
COUNTY_SWEEP = TOOLS / "county_sweep.py"
CHECK = TOOLS / "check.sh"
SANDBOX = LUA / "shared/Translate/EN/Sandbox.json"
RUNNER = TOOLS / "luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
)
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


def snapshot(cx: int, cy: int, revision: str, sources: list[dict]) -> str:
    lines = [
        "H|protocol=SAOWS1|status=OBSERVED|detail=|mode=border180"
        f"|cx={cx}|cy={cy}|revision={revision}|sources={len(sources)}"
    ]
    for source in sources:
        quantities = "".join(
            f"|q:{name}={quantity:.6f}"
            for name, quantity in source.get("quantities", {}).items()
        )
        lines.append(
            "S|id={id}|fp={fp}|rev={rev}|kind={kind}|x={x}|y={y}|z=0"
            "|building={building}|explored=1|state={state}|access=unknown"
            "|container={container}{quantities}".format(
                id=source["id"], fp=source["fp"], rev=source["rev"],
                kind=source.get("kind", "container"), x=source["x"],
                y=source["y"], building=source.get("building", -1),
                state=source.get("state", "available"),
                container=source.get("container", "counter"),
                quantities=quantities,
            )
        )
        for item in source.get("items", []):
            lines.append(
                "I|source={source}|id={id}|type={type}|uses={uses}"
                "|amount={amount:.6f}|fluid={fluid}|poison=0|rotten=0"
                "|cats={cats}".format(
                    source=source["id"], id=item["id"], type=item["type"],
                    uses=item.get("uses", 1), amount=item.get("amount", 0),
                    fluid=item.get("fluid", ""), cats=item["cats"],
                )
            )
    lines.append("E")
    return "\n".join(lines) + "\n"


PANTRY_1 = snapshot(1, 1, "chunk-1", [{
    "id": "C:pantry:0", "fp": "pantry-fp", "rev": "pantry-r1",
    "x": 10, "y": 10, "building": 42,
    "quantities": {"food": 2, "water": 1},
    "items": [
        {"id": 101, "type": "Base.Apple", "uses": 1, "cats": "food"},
        {"id": 102, "type": "Base.Soup", "uses": 1, "amount": 1,
         "fluid": "Water", "cats": "food,water"},
    ],
}])
PANTRY_2 = snapshot(1, 1, "chunk-2", [{
    "id": "C:pantry:0", "fp": "pantry-fp", "rev": "pantry-r2",
    "x": 10, "y": 10, "building": 42,
    "quantities": {"food": 1},
    "items": [
        {"id": 103, "type": "Base.Banana", "uses": 1, "cats": "food"},
    ],
}])
PANTRY_MOVED = snapshot(3, 1, "chunk-3", [{
    "id": "C:pantry:0", "fp": "pantry-fp", "rev": "pantry-r3",
    "x": 26, "y": 10, "building": 84,
    "quantities": {"food": 1},
    "items": [
        {"id": 104, "type": "Base.Banana", "uses": 1, "cats": "food"},
    ],
}])
PANTRY_REPLACED = snapshot(1, 1, "chunk-4", [{
    "id": "C:pantry:0", "fp": "replacement-fp", "rev": "pantry-r4",
    "x": 10, "y": 10, "building": 42,
    "quantities": {"food": 1, "water": 1},
    "items": [
        {"id": 105, "type": "Base.Orange", "uses": 1,
         "cats": "food,water"},
    ],
}])
SPENT = snapshot(3, 1, "spent-1", [{
    "id": "C:spent:0", "fp": "spent-fp", "rev": "spent-r1",
    "state": "spent", "x": 26, "y": 10, "building": 84,
    "quantities": {}, "items": [],
}])
GROUND = snapshot(2, 2, "ground-1", [{
    "id": "G:crate", "fp": "ground-fp", "rev": "ground-r1",
    "kind": "ground", "x": 18, "y": 18, "building": 77,
    "quantities": {"food": 1},
    "items": [
        {"id": 201, "type": "Base.Crisps", "uses": 1, "cats": "food"},
    ],
}])
GROUND_EMPTY = snapshot(2, 2, "ground-2", [])


PRELUDE = r'''
SAO = { History = { countyHours = function() return 240 end },
  Log = { line = function() end } }
_G.__stores, _G.__handlers = {
  ['SurvivorAwareness_Graph'] = {
    material={ stores={
      ['house:legacy']={ owner='house:legacy', items={ food=4 }, claims={} },
      ['personal-legacy']={ owner='personal-legacy',
        items={ keepsake=1 }, claims={} },
    } },
    organization={
      organizations={
        legacy={ id='legacy', boundary={ rooms=4 }, governance='localist',
          members={ a={ person='a' } }, offices={}, customs={} },
        elected={ id='elected', boundary={ rooms=8 }, governance='localist',
          members={ e={ person='e' } }, offices={}, customs={} },
      },
      offices={
        ['elected:chair']={ id='chair', organization='elected',
          legitimacy='election', succession='election', holders={ e=true } },
      }, claims={}, decisions={},
    },
    settlement={ bases={
      legacy={ organization='legacy', building={ rooms=4, food=true,
        water=true }, members={}, storage={ food=4 } },
      elected={ organization='elected', building={ rooms=8, food=true,
        water=true }, members={}, storage={ food=8 } },
    } },
  },
}, {}
ModData = { getOrCreate = function(key)
  __stores[key] = __stores[key] or {}; return __stores[key]
end }
Events = setmetatable({}, { __index = function(t, key)
  local slot = { Add = function(fn) __handlers[key] = fn end,
    Remove = function() end }
  rawset(t, key, slot); return slot
end })
SandboxVars = { SurvivorAwareness = { Settlement = true, Material = true } }
SAO.Identity = { get = function() return nil end }
SAO.Organization = { organizations = {}, offices = {} }
SAO.Communication = {}
_G.__larder, _G.__water, _G.__standingWrites = {}, {}, 0
_G.__standingAvailable, _G.__refuseStanding = true, false
_G.__groups = { a='g', b='g', c='h' }
_G.__members = { g={'a','b'}, h={'c','d'} }
_G.__claims = {
  g={ minX=8, minY=8, maxX=16, maxY=16, claimIncarnation=1 },
  h={ minX=24, minY=8, maxX=32, maxY=16, claimIncarnation=1 },
}
SAO.Standing = {
  groupOf = function(id) return __groups[tostring(id)] end,
  mayEngageZombie = function() return false end,
  provisioningMembers = function(group)
    if not __standingAvailable then return nil end
    return __members[tostring(group)] or {}
  end,
  provisioningClaimOf = function(group)
    if not __standingAvailable then return false, nil end
    return true, __claims[tostring(group)]
  end,
  setLarder = function(group, word, count, basis, evidence)
    if __refuseStanding or not __standingAvailable then return false end
    __standingWrites = __standingWrites + 1
    __larder[tostring(group)] = {
      group=group, word=word, count=count, basis=basis,
      atHours=evidence and evidence.at or nil,
      reservationId=evidence and evidence.reservationId or nil,
      resultOrder=evidence and evidence.order or nil }
    return true
  end,
  setWaterStore = function(group, word, units, basis, evidence)
    if __refuseStanding or not __standingAvailable then return false end
    __standingWrites = __standingWrites + 1
    __water[tostring(group)] = {
      group=group, word=word, units=units, basis=basis,
      atHours=evidence and evidence.at or nil,
      reservationId=evidence and evidence.reservationId or nil,
      resultOrder=evidence and evidence.order or nil }
    return true
  end,
}
SAO.Census = { skillOf = function(id, skill)
  if skill == 'Cooking' then return 1 end
  return 0
end }
SAO.Lessons = { has = function(id, work) return work == 'quartermaster' end }
'''


PROBE = r'''(function()
  local checks = {}
  local WORLD_STORE = 'SurvivorAwareness_WorldSources'
  local function check(name, value)
    checks[#checks+1] = name .. '=' .. tostring(value and true or false)
  end
  local function empty(value)
    for _ in pairs(value or {}) do return false end
    return true
  end
  local function apply(text)
    return SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(text))
  end
  local sequence = 0
  local function receipt(id, sourceId, fingerprint, group, options)
    options = options or {}
    sequence = sequence + 1
    local context = options.context
    if context == nil then context = group and 'held-group' or 'personal' end
    local value = {
      reservationId=id, actorId=options.actor or 'a',
      placeId=options.placeId or 42,
      placeX=options.minX or 8, placeY=options.minY or 8, placeZ=0,
      placeMinX=options.minX or 8, placeMinY=options.minY or 8,
      placeMaxX=options.maxX or 16, placeMaxY=options.maxY or 16,
      sourceId=sourceId, sourceFingerprint=fingerprint,
      sourceKind=options.kind or 'container',
      sourceX=options.sourceX or options.minX or 10,
      sourceY=options.sourceY or options.minY or 10, sourceZ=0,
      itemId=900+sequence, itemType='Base.Test', category='food',
      provisioningGroup=group, provisioningContext=context, quantity=1,
      provisioningClaimIncarnation=options.claimIncarnation
        or (group and __claims[tostring(group)]
          and __claims[tostring(group)].claimIncarnation or nil),
      materialProjectionEnabled=options.materialEnabled ~= false,
      preRevision='pre', postRevision=options.revision or 'post',
      status='completed', detail='native-complete',
      at=240+sequence, order=sequence, acknowledgements={},
    }
    local world = __stores[WORLD_STORE]
    world.results[id] = value
    world.resultSequence = sequence
    return value
  end
  local function delivered(id)
    for _, candidate in ipairs(
        SAO.WorldSources.completedResults('provisioning')) do
      if candidate.reservationId == id then return candidate end
    end
    return nil
  end
  local function process(id)
    return SAO.Provisioning.processReceipt(delivered(id))
  end
  local function acknowledged(raw)
    return type(raw.acknowledgements.provisioning) == 'table'
  end

  local legacyGraph = __stores['SurvivorAwareness_Graph']
  local legacyBound = SAO.GraphPersistence.bind()
  local migration = legacyGraph.migrations
    and legacyGraph.migrations.c63FalseOutputRetirement or nil
  local partialMigration = migration
    and legacyGraph.migrations.c64PartialMaterialCorrection or nil
  check('legacy_false_outputs_retired_on_upgrade', legacyBound
    and legacyGraph.schema == 3
    and legacyGraph.material.stores['house:legacy'] == nil
    and legacyGraph.material.stores['personal-legacy'] ~= nil
    and legacyGraph.settlement.bases.legacy == nil
    and migration and migration.retiredHouseStores == 1
    and migration.retiredSettlementBases == 2
    and migration.fromSchema == 0 and migration.toSchema == 2
    and partialMigration and partialMigration.toSchema == 3
    and migration.provenance ==
      'initialized at C63 upgrade from represented C62 state; no earlier history inferred')
  local elected = legacyGraph.organization.organizations.elected
  check('legacy_provisioning_organizations_retired_or_sanitized',
    legacyGraph.organization.organizations.legacy == nil
    and elected and elected.id == 'elected' and elected.governance == 'unsettled'
    and elected.members.e == nil and elected.boundary.rooms == nil
    and elected.offices.chair == legacyGraph.organization.offices['elected:chair']
    and migration.retiredProvisioningOrganizations == 1
    and migration.sanitizedElectionOrganizations == 1)
  apply(%(pantry1)s)
  SandboxVars.SurvivorAwareness.Material = false
  local disabledRaw = receipt('material-off','C:pantry:0','pantry-fp','g',
    { materialEnabled=false })
  SandboxVars.SurvivorAwareness.Material = true
  local disabledOk, disabledWhy = process('material-off')
  check('material_dial_skips_all_projections', disabledOk
    and disabledWhy == 'material-disabled' and acknowledged(disabledRaw)
    and disabledRaw.acknowledgements.provisioning.reason == 'material-disabled'
    and SAO.Material.storeOf('house:g') == nil and __larder.g == nil
    and __water.g == nil and SAO.Settlement.bases.g == nil)
  local firstRaw = receipt('r1','C:pantry:0','pantry-fp','g')
  local firstOk = process('r1')
  local houseG = SAO.Material.storeOf('house:g')
  local isolated = SAO.WorldSources.sourceProjection('C:pantry:0')
  isolated.items['101'].type = 'mutated-copy'
  local fresh = SAO.WorldSources.sourceProjection('C:pantry:0')
  check('exact_source_projection', firstOk and houseG
    and houseG.nativeSources['C:pantry:0'].revision == 'pantry-r1'
    and houseG.nativeSources['C:pantry:0'].items['101'].type == 'Base.Apple')
  check('source_projection_isolated', fresh.items['101'].type == 'Base.Apple')
  check('finite_categories_not_item_double_counted',
    houseG.items['Base.Apple'] == 1 and houseG.items['Base.Soup'] == 1
    and houseG.categories.food == 2 and houseG.categories.water == 1)
  check('partial_projection_publishes_no_house_claim',
    houseG.coverage and houseG.coverage.complete == false
    and houseG.coverage.basis == 'selected-native-sources'
    and __larder.g == nil and __water.g == nil and __standingWrites == 0)
  check('ack_last_records_reason', acknowledged(firstRaw)
    and firstRaw.acknowledgements.provisioning.reason == 'reconciled')
  check('provisioning_does_not_found_settlement', SAO.Settlement.bases.g == nil)
  local enabledWork = SAO.Labor.choose('a', 240, 0)
  SandboxVars.SurvivorAwareness.Material = false
  local disabledWork = SAO.Labor.choose('a', 240, 0)
  SandboxVars.SurvivorAwareness.Material = true
  check('material_toggle_hides_house_stock_from_labor',
    enabledWork == 'quartermaster' and disabledWork == 'cook')

  local refusedBase = SAO.Settlement.claim('refused', { rooms=99 })
  local groundedBase = SAO.Settlement.claim('g',
    { rooms=7, water=false, food=false },
    { producer='place-development', status='completed',
      resultId='place:g', at=239 })
  check('settlement_claim_requires_completed_place_result', refusedBase == nil
    and groundedBase and SAO.Settlement.isGrounded(groundedBase))
  apply(%(pantry2)s)
  local ambientRefreshed, ambientPending =
    SAO.Provisioning.refreshProjectedSources(32)
  check('ambient_native_change_refreshes_exact_projection_without_credit',
    ambientRefreshed == 1 and ambientPending == 0
    and houseG.items['Base.Apple'] == nil and houseG.items['Base.Soup'] == nil
    and houseG.items['Base.Banana'] == 1 and houseG.categories.food == 1
    and houseG.coverage.complete == false
    and __larder.g == nil and __water.g == nil
    and empty(groundedBase.storage))
  local secondRaw = receipt('r2','C:pantry:0','pantry-fp','g',
    { revision='pantry-r2' })
  local second = delivered('r2')
  local secondOk = SAO.Provisioning.processReceipt(second)
  local baseG = SAO.Settlement.bases.g
  check('replacement_not_addition', secondOk
    and houseG.items['Base.Apple'] == nil and houseG.items['Base.Soup'] == nil
    and houseG.items['Base.Banana'] == 1 and houseG.categories.food == 1)
  check('partial_projection_does_not_replace_settlement_storage',
    baseG.building.rooms == 7
    and baseG.building.water == false and baseG.building.food == false
    and empty(baseG.storage) and baseG.storageProjection == nil
    and baseG.storageEvidence == nil)
  local repeated = SAO.Provisioning.processReceipt(second)
  check('redelivery_idempotent', repeated
    and houseG.items['Base.Banana'] == 1 and empty(baseG.storage))

  local durableGraph = __stores['SurvivorAwareness_Graph']
  SAO.Material.stores, SAO.Material.reconciliations, SAO.Material.sourceOwners = {}, {}, {}
  SAO.Settlement.bases = {}
  local rebound = SAO.GraphPersistence.bind()
  houseG, baseG = SAO.Material.storeOf('house:g'), SAO.Settlement.bases.g
  check('projection_indexes_survive_rebind', rebound
    and houseG == durableGraph.material.stores['house:g']
    and SAO.Material.sourceOwners == durableGraph.material.sourceOwners
    and SAO.Material.projectedOwner('C:pantry:0','pantry-fp') == 'g'
    and baseG == durableGraph.settlement.bases.g)

  local retryRaw = receipt('retry','C:pantry:0','pantry-fp','g')
  __refuseStanding = true
  local retryOk, retryWhy = process('retry')
  __refuseStanding = false
  local world = __stores[WORLD_STORE]
  houseG = SAO.Material.storeOf('house:g')
  check('partial_projection_skips_aggregate_writer_refusal', retryOk
    and retryWhy == 'reconciled' and acknowledged(retryRaw)
    and houseG.items['Base.Banana'] == 1
    and __standingWrites == 0 and empty(baseG.storage))

  apply(%(pantry2)s)
  local ackRetryRaw = receipt('ack-retry','C:pantry:0','pantry-fp','g',
    { revision='pantry-r2' })
  local savedAcknowledge = SAO.WorldSources.acknowledgeResult
  SAO.WorldSources.acknowledgeResult = function() return false end
  local ackRetryOk, ackRetryWhy = process('ack-retry')
  SAO.WorldSources.acknowledgeResult = savedAcknowledge
  local persistedAckDecision = SAO.Material.reconciliations['ack-retry']
  local ackWrites = __standingWrites
  SAO.Material.stores, SAO.Material.reconciliations, SAO.Material.sourceOwners = {}, {}, {}
  SAO.Settlement.bases = {}
  SAO.GraphPersistence.bind()
  world.conflictBySource['C:pantry:0'] = { id='C:pantry:0' }
  local ackRetryCompleted, ackRetryOutcome = process('ack-retry')
  world.conflictBySource['C:pantry:0'] = nil
  check('ack_refusal_reload_uses_persisted_decision_before_source_conflict',
    not ackRetryOk and ackRetryWhy == 'ack-refused'
    and persistedAckDecision and persistedAckDecision.applied == true
    and persistedAckDecision.outcome == 'reconciled'
    and persistedAckDecision.derivations.g.standing == true
    and persistedAckDecision.derivations.g.recognition == true
    and ackRetryCompleted and ackRetryOutcome == 'reconciled'
    and __standingWrites == ackWrites and __larder.g == nil and __water.g == nil
    and empty(SAO.Settlement.bases.g.storage)
    and acknowledged(ackRetryRaw)
    and SAO.Material.reconciliations['ack-retry'] == nil
    and SAO.Material.projectedOwner('C:pantry:0','pantry-fp') == 'g')

  apply(%(pantry2)s)
  local olderRaw = receipt('derived-order-a','C:pantry:0','pantry-fp','g',
    { revision='pantry-r2' })
  SAO.WorldSources.acknowledgeResult = function() return false end
  local olderFirst, olderWhy = process('derived-order-a')
  SAO.WorldSources.acknowledgeResult = savedAcknowledge
  local olderDecision = SAO.Material.reconciliations['derived-order-a']
  local newerRaw = receipt('derived-order-b','C:pantry:0','pantry-fp','g',
    { revision='pantry-r2' })
  local newerOk = process('derived-order-b')
  local newerWrites = __standingWrites
  local olderRetry = process('derived-order-a')
  check('older_applied_retry_cannot_reverse_newer_derivations',
    not olderFirst and olderWhy == 'ack-refused'
    and olderDecision.derivations.g.standing == true
    and olderDecision.derivations.g.recognition == true
    and newerOk and olderRetry and acknowledged(olderRaw)
    and acknowledged(newerRaw) and __standingWrites == newerWrites
    and SAO.Settlement.bases.g.storageEvidence == nil
    and __larder.g == nil and __water.g == nil)

  local cleanupRaw = receipt('cleanup-after-ack','C:pantry:0','pantry-fp','g',
    { revision='pantry-r2' })
  local savedFinish = SAO.Material.finishReconciliation
  SAO.Material.finishReconciliation = function() return false end
  local cleanupOk, cleanupWhy = process('cleanup-after-ack')
  local cleanupLingering = SAO.Material.reconciliations['cleanup-after-ack'] ~= nil
  local cleanupStillDelivered = delivered('cleanup-after-ack') ~= nil
  SAO.Material.finishReconciliation = savedFinish
  SAO.Material.stores, SAO.Material.reconciliations, SAO.Material.sourceOwners = {}, {}, {}
  SAO.Settlement.bases = {}
  SAO.GraphPersistence.bind()
  SAO.Provisioning.consumeCompleted(1)
  check('acknowledged_crash_window_cleans_durable_transaction', cleanupOk
    and cleanupWhy == 'reconciled' and acknowledged(cleanupRaw)
    and cleanupLingering and not cleanupStillDelivered
    and SAO.Material.reconciliations['cleanup-after-ack'] == nil)

  local spentBase = SAO.Settlement.claim('h', { rooms=2 },
    { producer='place-development', status='completed',
      resultId='place:h:spent', at=250 })
  spentBase.storage['Base.Stale'] = 3
  apply(%(spent)s)
  local spentRaw = receipt('spent-first','C:spent:0','spent-fp','h', {
    actor='c', placeId=84, minX=24, minY=8, maxX=32, maxY=16,
    sourceX=26, sourceY=10, revision='spent-r1' })
  local spentOk = process('spent-first')
  local spentHouse = SAO.Material.storeOf('house:h')
  check('first_spent_source_records_partial_zero_without_house_claim', spentOk
    and acknowledged(spentRaw) and spentHouse
    and spentHouse.projection == 'native-sources'
    and empty(spentHouse.nativeSources)
    and empty(spentHouse.items) and empty(spentHouse.categories)
    and spentHouse.coverage.complete == false
    and __larder.h == nil and __water.h == nil
    and spentBase.storage['Base.Stale'] == 3
    and spentBase.storageEvidence == nil)

  apply(%(moved)s)
  local movedRaw = receipt('move','C:pantry:0','pantry-fp','h', {
    actor='c', placeId=84, minX=24, minY=8, maxX=32, maxY=16,
    sourceX=26, sourceY=10, revision='pantry-r3' })
  local movedOk = process('move')
  local houseH = SAO.Material.storeOf('house:h')
  check('one_source_has_one_house_owner', movedOk
    and houseG.nativeSources['C:pantry:0'] == nil
    and houseH.nativeSources['C:pantry:0'] ~= nil
    and SAO.Material.projectedOwner('C:pantry:0','pantry-fp') == 'h'
    and baseG.storage['Base.Banana'] == nil)

  SAO.Settlement.claim('h', { rooms=3 },
    { producer='place-development', status='completed',
      resultId='place:h', at=250 })
  local olderRaw = receipt('older-order','C:pantry:0','pantry-fp','g', {
    sourceX=10, sourceY=10 })
  local newerRaw = receipt('newer-order','C:pantry:0','pantry-fp','h', {
    actor='c', placeId=84, minX=24, minY=8, maxX=32, maxY=16,
    sourceX=26, sourceY=10, revision='pantry-r3' })
  local newerOk = process('newer-order')
  local olderOk = process('older-order')
  check('older_same_source_result_cannot_reverse_owner', newerOk and olderOk
    and acknowledged(newerRaw) and acknowledged(olderRaw)
    and SAO.Material.projectedOwner('C:pantry:0','pantry-fp') == 'h'
    and houseG.nativeSources['C:pantry:0'] == nil
    and houseH.nativeSources['C:pantry:0'] ~= nil
    and SAO.Settlement.bases.h.storageEvidence == nil)

  apply(%(replaced)s)
  apply(%(replaced)s)
  local replacement = SAO.WorldSources.sourceProjection('C:pantry:0')
  local replacementRaw = receipt('replacement','C:pantry:0',
    'replacement-fp','g',{ revision='pantry-r4' })
  local replacementOk = process('replacement')
  houseG, houseH = SAO.Material.storeOf('house:g'), SAO.Material.storeOf('house:h')
  check('replacement_fingerprint_retires_old_owner', replacement
    and replacement.fingerprint == 'replacement-fp' and replacementOk
    and houseH.nativeSources['C:pantry:0'] == nil
    and houseG.nativeSources['C:pantry:0'].fingerprint == 'replacement-fp'
    and SAO.Material.projectedOwner('C:pantry:0','replacement-fp') == 'g')
  local oldRaw = receipt('old-receipt','C:pantry:0','pantry-fp','h', {
    actor='c', placeId=84, minX=24, minY=8, maxX=32, maxY=16,
    sourceX=26, sourceY=10 })
  local oldOk, oldWhy = process('old-receipt')
  check('old_receipt_cannot_remove_replacement', oldOk
    and oldWhy == 'source-replaced' and acknowledged(oldRaw)
    and houseG.nativeSources['C:pantry:0'].fingerprint == 'replacement-fp'
    and baseG.storageEvidence == nil
    and SAO.Settlement.bases.h.storageEvidence == nil)

  local personalRaw = receipt('personal','C:pantry:0','replacement-fp',nil)
  local personalOk = process('personal')
  check('personal_use_refreshes_owner_without_house_credit', personalOk
    and acknowledged(personalRaw)
    and SAO.Material.projectedOwner('C:pantry:0','replacement-fp') == 'g'
    and SAO.Material.storeOf('house:nil') == nil)
  local noOwnerRaw = receipt('personal-none','C:none','none-fp',nil)
  local noOwnerOk, noOwnerWhy = process('personal-none')
  check('absent_personal_no_owner_is_terminal_noop', noOwnerOk
    and noOwnerWhy == 'personal-use' and acknowledged(noOwnerRaw))
  world.sources['C:pantry:0'] = nil
  local absentOwnerRaw = receipt('personal-owned-absent','C:pantry:0',
    'replacement-fp',nil)
  local absentOwnerOk, absentOwnerWhy = process('personal-owned-absent')
  check('absent_personal_owner_waits', not absentOwnerOk
    and absentOwnerWhy == 'source-unobserved' and not acknowledged(absentOwnerRaw)
    and SAO.Material.projectedOwner('C:pantry:0','replacement-fp') == 'g')
  apply(%(replaced)s)

  local retiredRaw = receipt('retired','C:pantry:0','replacement-fp','g')
  __claims.g = nil
  world.sources['C:pantry:0'] = nil
  local retiredOk, retiredWhy = process('retired')
  check('released_claim_downgrades_without_resurrection', retiredOk
    and retiredWhy == 'held-ground-retired' and acknowledged(retiredRaw)
    and SAO.Material.storeOf('house:g').nativeSources['C:pantry:0'] == nil
    and SAO.Material.projectedOwner('C:pantry:0','replacement-fp') == nil)
  __claims.g = { minX=8, minY=8, maxX=16, maxY=16,
    claimIncarnation=2 }
  local reincarnatedRaw = receipt('reincarnated','C:pantry:0',
    'replacement-fp','g')
  __claims.g = { minX=8, minY=8, maxX=16, maxY=16,
    claimIncarnation=3 }
  local reincarnatedOk, reincarnatedWhy = process('reincarnated')
  check('same_group_key_new_incarnation_gets_no_old_credit', reincarnatedOk
    and reincarnatedWhy == 'held-ground-retired'
    and acknowledged(reincarnatedRaw)
    and SAO.Material.projectedOwner('C:pantry:0','replacement-fp') == nil)
  apply(%(replaced)s)

  local recognitionRaw = receipt('recognition-missing','C:pantry:0',
    'replacement-fp','g')
  local savedRecognition = SAO.Recognition
  SAO.Recognition = nil
  local recognitionOk, recognitionWhy = process('recognition-missing')
  SAO.Recognition = savedRecognition
  check('partial_projection_needs_no_settlement_recognition', recognitionOk
    and recognitionWhy == 'reconciled' and acknowledged(recognitionRaw))

  local refusedRaw = receipt('recognition-refused','C:pantry:0',
    'replacement-fp','g')
  local savedOnProvisioned = SAO.Recognition.onProvisioned
  SAO.Recognition.onProvisioned = function() return nil end
  local refusedOk, refusedWhy = process('recognition-refused')
  SAO.Recognition.onProvisioned = savedOnProvisioned
  check('partial_projection_does_not_call_recognition', refusedOk
    and refusedWhy == 'reconciled' and acknowledged(refusedRaw))

  SAO.Material.add('a','Base.Personal',2)
  local view = SAO.Material.storeForPerson('a')
  check('personal_and_house_ownership_remain_distinct', view
    and view.projection == 'person-and-house'
    and view.owner == nil
    and view.personal.owner == 'a' and view.personal.items['Base.Personal'] == 2
    and view.house.owner == 'house:g' and view.house.items['Base.Orange'] == 1
    and view.items['Base.Personal'] == 2 and view.items['Base.Orange'] == 1)
  SandboxVars.SurvivorAwareness.Material = false
  local hiddenView = SAO.Material.storeForPerson('a')
  SandboxVars.SurvivorAwareness.Material = true
  local restoredView = SAO.Material.storeForPerson('a')
  check('material_toggle_hides_access_view_without_erasing',
    hiddenView == nil and restoredView
    and restoredView.personal.owner == 'a'
    and restoredView.house.owner == 'house:g'
    and restoredView.items['Base.Personal'] == 2
    and restoredView.items['Base.Orange'] == 1)
  view.items['Base.Personal'] = 90
  view.personal.items['Base.Personal'] = 80
  view.house.items['Base.Orange'] = 70
  view.house.categories.food = 60
  SAO.Material.add('solo','Base.Solo',1)
  local soloView = SAO.Material.storeForPerson('solo')
  check('personal_only_view_keeps_owner_and_access', soloView
    and soloView.owner == 'solo' and soloView.accessibleBy == 'solo'
    and soloView.projection ~= 'person-and-house')
  soloView.items['Base.Solo'] = 50
  check('person_access_views_are_detached',
    SAO.Material.storeOf('a').items['Base.Personal'] == 2
    and SAO.Material.storeOf('house:g').items['Base.Orange'] == 1
    and SAO.Material.storeOf('house:g').categories.food == 1
    and SAO.Material.storeOf('solo').items['Base.Solo'] == 1)

  local dissolved = SAO.Recognition.onHouseDissolved('g')
  check('dissolution_retires_all_house_projections', dissolved
    and SAO.Material.storeOf('house:g') == nil
    and SAO.Material.projectedOwner('C:pantry:0','replacement-fp') == nil
    and SAO.Settlement.bases.g == nil)

  __claims.g = { minX=16, minY=16, maxX=24, maxY=24,
    claimIncarnation=4 }
  local emptyBase = SAO.Settlement.claim('g', { rooms=1 },
    { producer='place-development', status='completed',
      resultId='place:g:empty-ground', at=260 })
  emptyBase.storage['Base.Stale'] = 2
  apply(%(ground_empty)s)
  local firstGroundRaw = receipt('ground-first-empty','G:crate','ground-fp','g', {
    kind='ground', placeId=77, minX=16, minY=16, maxX=24, maxY=24,
    sourceX=18, sourceY=18 })
  local firstGroundOk = process('ground-first-empty')
  local firstGroundHouse = SAO.Material.storeOf('house:g')
  check('first_ground_absence_records_partial_zero', firstGroundOk
    and acknowledged(firstGroundRaw) and firstGroundHouse
    and firstGroundHouse.projection == 'native-sources'
    and empty(firstGroundHouse.nativeSources)
    and firstGroundHouse.coverage.complete == false
    and emptyBase.storage['Base.Stale'] == 2
    and emptyBase.storageEvidence == nil)

  apply(%(ground)s)
  local groundRaw = receipt('ground-add','G:crate','ground-fp','g', {
    kind='ground', placeId=77, minX=16, minY=16, maxX=24, maxY=24,
    sourceX=18, sourceY=18 })
  local groundAdded = process('ground-add')
  apply(%(ground_empty)s)
  local ambientGroundRefresh = SAO.Provisioning.refreshProjectedSources(32)
  check('ambient_source_removal_retires_exact_projection',
    ambientGroundRefresh >= 1
    and SAO.Material.projectedOwner('G:crate','ground-fp') == nil
    and SAO.Material.storeOf('house:g').nativeSources['G:crate'] == nil)
  world.sources['G:crate'] = nil
  world.conflictBySource['G:crate'] = nil
  local removedRaw = receipt('ground-remove','G:crate','ground-fp','g', {
    kind='ground', placeId=77, minX=16, minY=16, maxX=24, maxY=24,
    sourceX=18, sourceY=18 })
  local groundRemoved = process('ground-remove')
  houseG = SAO.Material.storeOf('house:g')
  check('proved_ground_absence_removes_projection', groundAdded and groundRemoved
    and acknowledged(groundRaw) and acknowledged(removedRaw)
    and houseG.nativeSources['G:crate'] == nil)

  __stores[WORLD_STORE] = { schema=3, results={
    legacy={ reservationId='legacy', actorId='a', sourceId='legacy-source',
      status='completed', order=1, acknowledgements={} } },
    reservations={ post={ id='post', actorId='a', sourceId='legacy-source',
      fingerprint='legacy-fp', status='reserved', phase='using' } } }
  SAO.WorldSources.source('migration-probe')
  world = __stores[WORLD_STORE]
  local legacyResult = delivered('legacy')
  local legacyOk, legacyWhy = SAO.Provisioning.processReceipt(legacyResult)
  check('schema3_results_migrate_unattributed', world.schema == 6
    and legacyResult.provisioningContext == 'legacy-unattributed'
    and world.reservations.post.provisioningContext == 'legacy-unattributed'
    and legacyOk and legacyWhy == 'legacy-unattributed'
    and acknowledged(world.results.legacy))

  __claims.g = { minX=8, minY=8, maxX=16, maxY=16,
    claimIncarnation=4 }
  for i = 1, 32 do
    receipt('blocked-' .. tostring(i),'C:blocked-' .. tostring(i),
      'blocked-fp-' .. tostring(i),'g')
  end
  local tailRaw = receipt('tail','C:tail','tail-fp',nil)
  local firstConsumed, firstPending = SAO.Provisioning.consumeCompleted(32)
  local secondConsumed = SAO.Provisioning.consumeCompleted(32)
  check('rotating_cursor_prevents_retry_starvation', firstConsumed == 0
    and firstPending == 32 and secondConsumed >= 1 and acknowledged(tailRaw))

  local corruptRaw = receipt('corrupt-context','C:corrupt','corrupt-fp',nil,
    { context='unavailable' })
  local corruptOk, corruptWhy = process('corrupt-context')
  check('unknown_context_never_downgrades_to_personal', not corruptOk
    and corruptWhy == 'invalid-provisioning-context'
    and not acknowledged(corruptRaw))

  local missingIdRaw = receipt('missing-id','', 'missing-id-fp',nil)
  local missingIdOk, missingIdWhy = process('missing-id')
  local missingFingerprintRaw = receipt('missing-fingerprint','C:missing-fp','',nil)
  local missingFingerprintOk, missingFingerprintWhy = process('missing-fingerprint')
  check('current_receipt_requires_exact_source_identity',
    not missingIdOk and missingIdWhy == 'invalid-result'
    and not acknowledged(missingIdRaw) and not missingFingerprintOk
    and missingFingerprintWhy == 'invalid-result'
    and not acknowledged(missingFingerprintRaw))

  __claims.g = { minX=8, minY=8, maxX=16, maxY=16,
    claimIncarnation=5 }
  for i = 1, 257 do
    local id, fp = 'C:bound:' .. tostring(i), 'bound-fp:' .. tostring(i)
    local rec = {
      reservationId='bound-' .. tostring(i), actorId='a', sourceId=id,
      sourceFingerprint=fp, provisioningGroup='g',
      provisioningContext='held-group', provisioningClaimIncarnation=5,
      placeId=42, status='completed',
      at=300+i, order=1000+i,
    }
    SAO.Material.reconcileSource('g', rec, {
      id=id, fingerprint=fp, revision='r' .. tostring(i),
      state='available', x=10, y=10, z=0,
      quantities={}, items={}, itemOrder={},
    }, 'held-group')
    SAO.Material.finishReconciliation(rec.reservationId)
  end
  houseG = SAO.Material.storeOf('house:g')
  local projectedCount = 0
  for _ in pairs(houseG.nativeSources) do projectedCount = projectedCount + 1 end
  check('material_projection_and_owner_index_bounded', projectedCount == 256
    and houseG.nativeSources['C:bound:257'] ~= nil
    and SAO.Material.projectedOwner('C:bound:257','bound-fp:257') == 'g'
    and SAO.Material.projectedOwner('C:bound:1','bound-fp:1') == nil)

  local currentGraph = __stores['SurvivorAwareness_Graph']
  local futureRaw = receipt('future-consumer','C:future','future-fp','g')
  __stores['SurvivorAwareness_Graph'] = { schema=4, marker='unchanged' }
  local futureConsumed, futureConsumeWhy = process('future-consumer')
  local integrationReady = SAO.Integration.rebuild()
  local worldApplied = SAO.WorldGenesis.applyDay(1)
  local futureBound, futureWhy = SAO.GraphPersistence.bind()
  local futureGraph = __stores['SurvivorAwareness_Graph']
  check('future_graph_schema_refuses_without_mutation', not futureBound
    and futureWhy == 'future-schema' and futureGraph.schema == 4
    and futureGraph.marker == 'unchanged' and futureGraph.material == nil)
  check('future_graph_callers_stop_and_detach_prior_world',
    not futureConsumed and futureConsumeWhy == 'graph-future-schema'
    and not acknowledged(futureRaw) and not integrationReady
    and worldApplied == 0 and SAO.Integration.ready == false
    and SAO.Material.stores['house:g'] == nil
    and SAO.Settlement.bases.g == nil
    and SAO.Organization.organizations.elected == nil
    and __larder.future == nil)
  __stores['SurvivorAwareness_Graph'] = currentGraph
  SAO.GraphPersistence.bind()

  return table.concat(checks,'|')
end)()''' % {
    "pantry1": json.dumps(PANTRY_1),
    "pantry2": json.dumps(PANTRY_2),
    "moved": json.dumps(PANTRY_MOVED),
    "replaced": json.dumps(PANTRY_REPLACED),
    "spent": json.dumps(SPENT),
    "ground": json.dumps(GROUND),
    "ground_empty": json.dumps(GROUND_EMPTY),
}


STANDING_PROBE = r'''(function()
  local checks = {}
  local function check(name, value)
    checks[#checks+1] = name .. '=' .. tostring(value and true or false)
  end
  _G.__historyHours = 240
  SAO.History = { countyHours = function() return __historyHours end }
  local key = 'SurvivorAwareness_Standing'
  __stores[key] = {
    groupMeta={ old={
      larder={ word='lean', count=0, atHours=240 },
      waterStore={ word='dry', units=0, atHours=240 },
      hearth={ burning=false, atHours=240 },
      motorPool={ atHours=240, cars={} },
    } },
    groupClaims={ old={ minX=1, minY=1, maxX=2, maxY=2, z=0 } },
  }
  SAO.Standing.larderOf('old')
  local migrated = __stores[key]
  local receipt = migrated.migrations
    and migrated.migrations.c63LegacyMaterialClaims or nil
  check('standing_legacy_false_claims_retired', migrated.schema == 3
    and migrated.groupMeta.old.larder == nil
    and migrated.groupMeta.old.waterStore == nil
    and migrated.groupMeta.old.hearth == nil
    and migrated.groupMeta.old.motorPool ~= nil
    and receipt and receipt.retiredLarders == 1
    and receipt.retiredWaterStores == 1 and receipt.retiredHearths == 1
    and receipt.provenance ==
      'initialized at C63 upgrade from represented C62 state; no earlier history inferred')
  local incarnation = migrated.groupClaims.old.claimIncarnation
  SAO.Standing.waterStoreOf('old')
  check('standing_migration_is_idempotent',
    migrated.migrations.c63LegacyMaterialClaims == receipt
    and receipt.migratedGroupClaims == 1
    and incarnation and incarnation > 0
    and migrated.groupClaims.old.claimIncarnation == incarnation)
  __stores[key] = { schema=2, groupMeta={
    partial={
      larder={ word='full', count=9, basis='completed-native-source-results' },
      waterStore={ word='full', units=9,
        basis='completed-native-source-results' } },
    scanned={
      larder={ word='fair', count=2, basis='quartermaster-native-scan' },
      waterStore={ word='fair', units=2,
        basis='quartermaster-native-scan' } } },
    groupClaims={} }
  SAO.Standing.larderOf('partial')
  local corrected = __stores[key]
  local correction = corrected.migrations
    and corrected.migrations.c64PartialMaterialCorrection or nil
  check('standing_partial_projection_claims_retired', corrected.schema == 3
    and corrected.groupMeta.partial.larder == nil
    and corrected.groupMeta.partial.waterStore == nil
    and corrected.groupMeta.scanned.larder.word == 'fair'
    and corrected.groupMeta.scanned.waterStore.word == 'fair'
    and correction and correction.retiredPartialLarders == 1
    and correction.retiredPartialWaterStores == 1)
  __stores[key] = migrated
  local eventEvidence = { reservationId='standing-event', sourceId='source-a',
    at=250, order=1, materialProjectionEnabled=true, materialGeneration=1 }
  SAO.Standing.setLarder('old','lean',0,
    'completed-native-source-results',eventEvidence)
  SAO.Standing.setWaterStore('old','dry',0,
    'completed-native-source-results',eventEvidence)
  __historyHours = 500
  SAO.Standing.setLarder('old','lean',0,
    'completed-native-source-results',eventEvidence)
  SAO.Standing.setWaterStore('old','dry',0,
    'completed-native-source-results',eventEvidence)
  local eventTimeStable = migrated.groupMeta.old.larder.atHours == 250
    and migrated.groupMeta.old.waterStore.atHours == 250
  local scanEvidence = { at=500, materialGeneration=1 }
  SAO.Standing.setLarder('old','full',9,
    'quartermaster-native-scan',scanEvidence)
  SAO.Standing.setWaterStore('old','full',9,
    'quartermaster-native-scan',scanEvidence)
  SAO.Standing.setLarder('old','lean',0,
    'completed-native-source-results',eventEvidence)
  SAO.Standing.setWaterStore('old','dry',0,
    'completed-native-source-results',eventEvidence)
  local scanSupersededOldEvent = migrated.groupMeta.old.larder.word == 'full'
    and migrated.groupMeta.old.waterStore.word == 'full'
    and migrated.groupMeta.old.larder.atHours == 500
    and migrated.groupMeta.old.waterStore.atHours == 500
  local aggregateEvidence = { reservationId='standing-event-2',
    sourceId='source-b', at=260, order=2, materialProjectionEnabled=true,
    materialGeneration=2 }
  SAO.Standing.setLarder('old','lean',1,
    'completed-native-source-results',aggregateEvidence)
  SAO.Standing.setWaterStore('old','dry',1,
    'completed-native-source-results',aggregateEvidence)
  local staleNewGenerationRejected =
    migrated.groupMeta.old.larder.word == 'full'
    and migrated.groupMeta.old.waterStore.word == 'full'
    and migrated.groupMeta.old.larder.atHours == 500
    and migrated.groupMeta.old.waterStore.atHours == 500
  local freshAggregate = { reservationId='standing-event-3',
    sourceId='source-b', at=600, order=3, materialProjectionEnabled=true,
    materialGeneration=3 }
  SAO.Standing.setLarder('old','lean',1,
    'completed-native-source-results',freshAggregate)
  SAO.Standing.setWaterStore('old','dry',1,
    'completed-native-source-results',freshAggregate)
  __historyHours = 600
  check('standing_evidence_time_and_cross_producer_order', eventTimeStable
    and scanSupersededOldEvent
    and staleNewGenerationRejected
    and migrated.groupMeta.old.larder.word == 'lean'
    and migrated.groupMeta.old.waterStore.word == 'dry'
    and migrated.groupMeta.old.larder.atHours == 600
    and migrated.groupMeta.old.waterStore.atHours == 600
    and migrated.groupMeta.old.larder.materialGeneration == 3
    and migrated.groupMeta.old.waterStore.materialGeneration == 3
    and migrated.groupMeta.old.larder.reservationId == 'standing-event-3'
    and migrated.groupMeta.old.waterStore.reservationId == 'standing-event-3'
    and migrated.groupMeta.old.larder.basis == 'completed-native-source-results'
    and migrated.groupMeta.old.waterStore.basis == 'completed-native-source-results')
  SAO.Standing.setHearth('old',true)
  local retainedClaim = migrated.groupClaims.old
  local retainedLarder = migrated.groupMeta.old.larder
  local retainedWater = migrated.groupMeta.old.waterStore
  local retainedHearth = migrated.groupMeta.old.hearth
  SandboxVars.SurvivorAwareness.Material = false
  local hiddenLarder = SAO.Standing.larderOf('old')
  local hiddenWater = SAO.Standing.waterStoreOf('old')
  local hiddenHearth = SAO.Standing.hearthOf('old')
  local refusedLarder = SAO.Standing.setLarder(
    'old','lean',0,'quartermaster-native-scan')
  local refusedWater = SAO.Standing.setWaterStore(
    'old','dry',0,'quartermaster-native-scan')
  local refusedHearth = SAO.Standing.setHearth('old',false)
  SandboxVars.SurvivorAwareness.Material = true
  local visibleLarder = SAO.Standing.larderOf('old')
  local visibleWater = SAO.Standing.waterStoreOf('old')
  local visibleHearth = SAO.Standing.hearthOf('old')
  check('material_toggle_hides_standing_without_erasing',
    hiddenLarder == nil and hiddenWater == nil and hiddenHearth == nil
    and refusedLarder == false and refusedWater == false
    and refusedHearth == false
    and migrated.groupClaims.old == retainedClaim
    and migrated.groupMeta.old.larder == retainedLarder
    and migrated.groupMeta.old.waterStore == retainedWater
    and migrated.groupMeta.old.hearth == retainedHearth
    and visibleLarder == retainedLarder and visibleWater == retainedWater
    and visibleHearth == retainedHearth)
  __stores[key] = { schema=4, marker='unchanged', groupMeta={
    future={ larder={ word='full', count=9, atHours=240 } } } }
  local futureLarder = SAO.Standing.larderOf('future')
  local future = __stores[key]
  check('future_standing_schema_refuses_without_mutation',
    futureLarder == nil and future.schema == 4 and future.marker == 'unchanged'
    and future.groupMeta.future.larder.count == 9 and future.migrations == nil)
  return table.concat(checks,'|')
end)()'''


EXPECTED = {
    "legacy_false_outputs_retired_on_upgrade",
    "legacy_provisioning_organizations_retired_or_sanitized",
    "material_dial_skips_all_projections",
    "exact_source_projection", "source_projection_isolated",
    "finite_categories_not_item_double_counted",
    "partial_projection_publishes_no_house_claim",
    "ack_last_records_reason", "provisioning_does_not_found_settlement",
    "material_toggle_hides_house_stock_from_labor",
    "ambient_native_change_refreshes_exact_projection_without_credit",
    "replacement_not_addition",
    "partial_projection_does_not_replace_settlement_storage",
    "settlement_claim_requires_completed_place_result",
    "redelivery_idempotent", "projection_indexes_survive_rebind",
    "partial_projection_skips_aggregate_writer_refusal",
    "ack_refusal_reload_uses_persisted_decision_before_source_conflict",
    "older_applied_retry_cannot_reverse_newer_derivations",
    "acknowledged_crash_window_cleans_durable_transaction",
    "first_spent_source_records_partial_zero_without_house_claim",
    "one_source_has_one_house_owner",
    "older_same_source_result_cannot_reverse_owner",
    "replacement_fingerprint_retires_old_owner",
    "old_receipt_cannot_remove_replacement",
    "personal_use_refreshes_owner_without_house_credit",
    "absent_personal_no_owner_is_terminal_noop",
    "absent_personal_owner_waits",
    "released_claim_downgrades_without_resurrection",
    "same_group_key_new_incarnation_gets_no_old_credit",
    "partial_projection_needs_no_settlement_recognition",
    "partial_projection_does_not_call_recognition",
    "personal_and_house_ownership_remain_distinct",
    "material_toggle_hides_access_view_without_erasing",
    "person_access_views_are_detached",
    "personal_only_view_keeps_owner_and_access",
    "dissolution_retires_all_house_projections",
    "first_ground_absence_records_partial_zero",
    "ambient_source_removal_retires_exact_projection",
    "proved_ground_absence_removes_projection",
    "schema3_results_migrate_unattributed",
    "rotating_cursor_prevents_retry_starvation",
    "unknown_context_never_downgrades_to_personal",
    "current_receipt_requires_exact_source_identity",
    "material_projection_and_owner_index_bounded",
    "future_graph_schema_refuses_without_mutation",
    "future_graph_callers_stop_and_detach_prior_world",
    "standing_legacy_false_claims_retired",
    "standing_migration_is_idempotent",
    "standing_partial_projection_claims_retired",
    "standing_evidence_time_and_cross_producer_order",
    "material_toggle_hides_standing_without_erasing",
    "future_standing_schema_refuses_without_mutation",
}


def runtime_available() -> bool:
    return all((
        (JDK / "javac.exe").is_file(), (JDK / "java.exe").is_file(),
        PZ.is_file(), STDLIB.is_file(), RUNNER.is_file(),
    ))


def run_kahlua() -> tuple[str | None, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300,
    )
    if compiled.returncode:
        return None, compiled.stderr or compiled.stdout
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        probe = work / "probe.lua"
        probe.write_text("__provisioningResult = " + PROBE, encoding="utf-8")
        standing_probe = work / "standing_probe.lua"
        standing_probe.write_text(
            "__standingMigrationResult = " + STANDING_PROBE, encoding="utf-8")
        combine = work / "combine.lua"
        combine.write_text(
            "__provisioningResult = __provisioningResult .. '|' "
            ".. __standingMigrationResult", encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(WORLD), str(MATERIAL), str(SETTLEMENT),
             str(RECOGNITION), str(PROVISIONING), str(GRAPH),
             str(INTEGRATION), str(WORLD_GENESIS), str(LABOR), str(probe),
             str(STANDING),
             str(standing_probe), str(combine),
             "--", "__provisioningResult"],
            cwd=work, capture_output=True, text=True, timeout=300,
        )
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def contract(texts: dict[str, str]) -> bool:
    provisioning = texts["provisioning"]
    reconcile = provisioning.find("SAO.Material.reconcileSource")
    derive = provisioning.find("local function deriveAndAcknowledge")
    derive_end = provisioning.find(
        "local function cleanupAcknowledgedReconciliations", derive)
    acknowledge = provisioning.find("if not acknowledge(receipt", derive)
    finish = provisioning.find(
        "    SAO.Material.finishReconciliation(receipt.reservationId)", derive)
    derive_call = provisioning.find("return deriveAndAcknowledge", reconcile)
    claim_revalidation = provisioning.find("local effectiveContext = context")
    source_absence = provisioning.find('sourceState == "source-absent"')
    return all((
        "if priorSchema > 6 then" in texts["world"],
        'receipt.provisioningContext = "legacy-unattributed"' in texts["world"],
        "sourceFingerprint = reservation.fingerprint" in texts["world"],
        "provisioningContext = reservation.provisioningContext" in texts["world"],
        "reservation.provisioningClaimIncarnation" in texts["world"],
        "materialProjectionEnabled = not options or options.Material ~= false"
        in texts["world"],
        "function WS.resultAcknowledged" in texts["world"],
        "function WS.sourceProjection(id)" in texts["world"],
        "function WS.pendingProjectionChanges(limit)" in texts["world"],
        "function WS.acknowledgeProjectionChange(sourceId, order)"
        in texts["world"],
        "reason = tostring(reason or \"consumed\")" in texts["world"],
        "provisioningContextAt" in texts["source_use"],
        "reservation.provisioningClaimIncarnation =\n"
        "        tonumber(claimIncarnation)" in texts["source_use"],
        'return false, "provisioning-context-unavailable"' in texts["source_use"],
        "local schema = tonumber(value.schema) or 0" in provisioning,
        "receipt.materialProjectionEnabled == false and not inFlight"
        in provisioning,
        'acknowledge(receipt, "material-disabled")' in provisioning,
        "local graphBound, graphWhy = SAO.GraphPersistence.bind()" in provisioning,
        'and "graph-future-schema" or "graph-unavailable"' in provisioning,
        'context == "legacy-unattributed"' in provisioning,
        "if not legacy and (type(receipt.sourceId)" in provisioning,
        'type(receipt.materialProjectionEnabled) ~= "boolean"' in provisioning,
        "tonumber(claim.claimIncarnation) ~= claimIncarnation" in provisioning,
        "SAO.Material.resumeReconciliation(receipt.reservationId)"
        in provisioning,
        "    Provisioning.refreshProjectedSources(limit)\n"
        "    cleanupAcknowledgedReconciliations()\n    local consumed"
        in provisioning,
        "SAO.Material.projectedOwner" in provisioning,
        "SAO.Standing.provisioningClaimOf" in provisioning,
        'effectiveContext = "retired-group"' in provisioning,
        'if accepted ~= true then' in provisioning,
        "store.coverage.complete ~= true" in provisioning,
        "projection.store.coverage.complete == true" in provisioning,
        claim_revalidation >= 0 and source_absence > claim_revalidation,
        'if effectiveContext ~= "retired-group" then' in provisioning,
        "receipt.materialEvidenceAt = tonumber(source and source.observedAt)"
        in provisioning,
        provisioning.count("SAO.Material.markDerivationComplete") >= 3,
        provisioning.count("if not SAO.Material.derivationComplete") >= 2,
        '"completed-native-source-results", evidence' in provisioning,
        reconcile >= 0 and derive_call > reconcile,
        derive >= 0 and derive_end > derive and acknowledge > derive
        and finish > acknowledge and finish < derive_end,
        "Material.sourceOwners = Material.sourceOwners or {}" in texts["material"],
        "transaction.applied == true" in texts["material"],
        "ownerOrder > receiptOrder" in texts["material"],
        "function Material.projectedOwner" in texts["material"],
        "function Material.finishReconciliation" in texts["material"],
        "function Material.resumeReconciliation" in texts["material"],
        "function Material.derivationComplete" in texts["material"],
        "function Material.markDerivationComplete" in texts["material"],
        "function Material.houseProjectionGeneration" in texts["material"],
        "function Material.refreshProjectedSource" in texts["material"],
        'complete = false,\n        basis = "selected-native-sources"'
        in texts["material"],
        "store.projectionGeneration = (tonumber(store.projectionGeneration) or 0) + 1"
        in texts["material"],
        "evidenceAt = tonumber(transaction.evidenceAt)" in texts["material"],
        'source.state == "spent"' in texts["material"],
        "elseif provedEmpty then" in texts["material"],
        "function Material.forgetHouse" in texts["material"],
        "local MAX_NATIVE_SOURCES = 256" in texts["material"],
        'if store.projection == "native-sources" then return false end'
        in texts["material"],
        'if store.projection == "native-sources" then return 0 end'
        in texts["material"],
        "store.material.sourceOwners" in texts["graph"],
        'if priorSchema > GRAPH_SCHEMA then return nil, "future-schema" end'
        in texts["graph"],
        "migrateLegacyFalseOutputs(store, priorSchema)" in texts["graph"],
        "migratePartialMaterialOutputs(store, priorSchema)" in texts["graph"],
        "        detachDurableOwners()\n        return false, why"
        in texts["graph"],
        "retiredProvisioningOrganizations" in texts["graph"],
        "sanitizedElectionOrganizations" in texts["graph"],
        "electionGroundedOrganization(store, organizationId)" in texts["graph"],
        "initialized at C63 upgrade from represented C62 state; no earlier history inferred"
        in texts["graph"],
        "SAO.Material.reconciliations = store.material.reconciliations"
        in texts["graph"],
        "local function copyScalarMap(value)" in texts["material"],
        "items = copyScalarMap(store.items)" in texts["material"],
        "return accessStore(personal, id)" in texts["material"],
        "if options and options.Material == false then return nil end"
        in texts["material"],
        'projection = "person-and-house",\n'
        "                personal = personalView" in texts["material"],
        "function Settlement.clearStorageProjection" in texts["settlement"],
        'evidence.producer ~= "place-development"' in texts["settlement"],
        'evidence.status ~= "completed"' in texts["settlement"],
        "priorGeneration > incomingGeneration" in texts["settlement"],
        "materialGeneration = receipt.materialGeneration" in texts["settlement"],
        "not Settlement.isGrounded(base)" in texts["settlement"],
        "materialStore.coverage.complete ~= true" in texts["settlement"],
        "Settlement.claim(" not in texts["recognition"],
        'return false, "ungrounded-settlement"' in texts["recognition"],
        "SAO.Material.forgetHouse(groupName)" in texts["recognition"],
        "function S.provisioningContextAt" in texts["standing"],
        "function S.provisioningClaimOf" in texts["standing"],
        "if priorSchema > STANDING_SCHEMA then return nil end"
        in texts["standing"],
        "migrateLegacyMaterialClaims(s, priorSchema)" in texts["standing"],
        "migratePartialMaterialClaims(s, priorSchema)" in texts["standing"],
        "claim.claimIncarnation = claimSequence" in texts["standing"],
        "claimIncarnation = claimIncarnation," in texts["standing"],
        "return \"held-group\", tostring(groupName), claim.claimIncarnation"
        in texts["standing"],
        "completed-native-source-results" in provisioning,
        "quartermaster-native-scan" in texts["controller"],
        "SAO.Material.forgetHouse(groupName)" in texts["standing"],
        "SAO.Settlement.clearStorageProjection(groupName)" in texts["standing"],
        "function S.setLarder(groupName, word, count, basis, evidence)"
        in texts["standing"],
        texts["standing"].count(
            "if not materialEnabled() then return nil end") >= 3,
        "evidence = -1\n                    if materialEnabled() then"
        in texts["standing"],
        "if not materialWriteAllowed(evidence) then return false end"
        in texts["standing"],
        "materialEvidenceSuperseded(meta.larder, basis, atHours, resultOrder,"
        in texts["standing"],
        "return priorGeneration > generation" in texts["standing"],
        "local bothProjection = prior.basis == projectionBasis"
        in texts["standing"],
        "and SAO.Material.houseProjectionGeneration" in texts["controller"],
        '"quartermaster-native-scan", qEvidence' in texts["controller"],
        "SAO.Standing.setLarder(g" not in texts["dormant"],
        "SAO.Standing.setWaterStore(g" not in texts["dormant"],
        "SAO.Recognition.onShelved" not in texts["needs"],
        'runSub("provision-results", consumeProvisioningResults)'
        in texts["population"],
        "SAO.Material.storeForPerson(id)" in texts["integration"],
        "local bound = SAO.GraphPersistence.bind()" in texts["integration"],
        "if bound ~= true then" in texts["integration"],
        "SAO.Material.storeForPerson(id)" in texts["labor"],
        "local materialEnabled = not options or options.Material ~= false"
        in texts["labor"],
        "personal = summarizeMaterialStore" in texts["world_genesis"],
        "house = summarizeMaterialStore" in texts["world_genesis"],
        "local bound = SAO.GraphPersistence.bind()" in texts["world_genesis"],
        "if bound ~= true then return false end" in texts["world_genesis"],
        "SAO.Material.storeForPerson" in texts["inspect"],
        "owner = store and store.owner or nil" in texts["inspect"],
        "accessibleBy = store and store.accessibleBy or nil"
        in texts["inspect"],
        '"shared/SAO_WorldSources.lua", "shared/SAO_Provisioning.lua"'
        in texts["county_sweep"],
        "tools/provisioning_result_test.py" in texts["check"],
        "it cannot found one" in texts["sandbox"],
        "Shelving is not connected yet" in texts["sandbox"],
    ))


def static_controls() -> tuple[bool, list[str]]:
    paths = {
        "world": WORLD, "material": MATERIAL, "settlement": SETTLEMENT,
        "recognition": RECOGNITION, "provisioning": PROVISIONING,
        "standing": STANDING, "dormant": DORMANT, "needs": NEEDS,
        "source_use": SOURCE_USE, "population": POPULATION,
        "controller": CONTROLLER, "inspect": INSPECT,
        "integration": INTEGRATION, "labor": LABOR, "graph": GRAPH,
        "world_genesis": WORLD_GENESIS, "county_sweep": COUNTY_SWEEP,
        "check": CHECK,
        "sandbox": SANDBOX,
    }
    baseline = {
        name: path.read_text(encoding="utf-8") for name, path in paths.items()
    }
    if not contract(baseline):
        return False, ["baseline production contract incomplete"]
    controls = [
        ("schema migration removed", "world", "if priorSchema > 6 then",
         "if priorSchema > 4 then"),
        ("ambient source change queue removed", "world",
         "function WS.pendingProjectionChanges(limit)",
         "function WS.noPendingProjectionChanges(limit)"),
        ("ambient source acknowledgement removed", "world",
         "function WS.acknowledgeProjectionChange(sourceId, order)",
         "function WS.noAcknowledgeProjectionChange(sourceId, order)"),
        ("legacy result inferred later membership", "world",
         'receipt.provisioningContext = "legacy-unattributed"',
         'receipt.provisioningContext = "held-group"'),
        ("fingerprint omitted from receipt", "world",
         "sourceFingerprint = reservation.fingerprint", "sourceFingerprint = nil"),
        ("bind context guessed", "source_use", "provisioningContextAt", "groupOf"),
        ("future delivery schema accepted", "provisioning",
         "local schema = tonumber(value.schema) or 0", "local schema = 0"),
        ("captured material decision omitted", "world",
         "materialProjectionEnabled = not options or options.Material ~= false",
         "materialProjectionEnabled = true"),
        ("captured claim incarnation omitted", "world",
         "provisioningClaimIncarnation =\n            reservation.provisioningClaimIncarnation",
         "provisioningClaimIncarnation = nil"),
        ("bound claim incarnation dropped", "source_use",
         "reservation.provisioningClaimIncarnation =\n        tonumber(claimIncarnation)",
         "reservation.provisioningClaimIncarnation = nil"),
        ("material event decision ignored", "provisioning",
         "if receipt.materialProjectionEnabled == false and not inFlight then",
         "if false then"),
        ("material event decision abandons applied transaction", "provisioning",
         "if receipt.materialProjectionEnabled == false and not inFlight then",
         "if receipt.materialProjectionEnabled == false then"),
        ("exact source identity bypassed", "provisioning",
         "if not legacy and (type(receipt.sourceId)",
         "if false and (type(receipt.sourceId)"),
        ("claim incarnation ignored", "provisioning",
         "or tonumber(claim.claimIncarnation) ~= claimIncarnation",
         "or false"),
        ("retired claim still waits for compacted source", "provisioning",
         'if effectiveContext ~= "retired-group" then', "if true then"),
        ("source observation time replaced by result time", "provisioning",
         "receipt.materialEvidenceAt = tonumber(source and source.observedAt)",
         "receipt.materialEvidenceAt = nil -- source time omitted\n    --"),
        ("graph readiness gate removed", "provisioning",
         "local graphBound, graphWhy = SAO.GraphPersistence.bind()",
         "local graphBound, graphWhy = true, nil"),
        ("reconciliation resume removed", "provisioning",
         "SAO.Material.resumeReconciliation(receipt.reservationId)",
         "SAO.Material.noResume(receipt.reservationId)"),
        ("completed derivation phases rerun", "provisioning",
         "if not SAO.Material.derivationComplete",
         "if true or not SAO.Material.derivationComplete"),
        ("derivation evidence omitted from standing", "provisioning",
         '"completed-native-source-results", evidence',
         '"completed-native-source-results"'),
        ("ambient projection refresh removed", "provisioning",
         "    Provisioning.refreshProjectedSources(limit)",
         "    -- ambient refresh removed"),
        ("acknowledged cleanup call removed", "provisioning",
         "    cleanupAcknowledgedReconciliations()\n    local consumed",
         "    -- cleanup removed\n    local consumed"),
        ("transaction cleanup moved before acknowledgement", "provisioning",
         "    SAO.Material.finishReconciliation(receipt.reservationId)\n"
         "    return true, outcome or \"reconciled\"",
         "    return true, outcome or \"reconciled\""),
        ("legacy marker ignored", "provisioning",
         'context == "legacy-unattributed"', "false"),
        ("personal absence forgets owner", "provisioning",
         "SAO.Material.projectedOwner", "SAO.Material.noOwnerCheck"),
        ("released claim resurrects house", "provisioning",
         'effectiveContext = "retired-group"', 'effectiveContext = "held-group"'),
        ("nil recognition accepted", "provisioning",
         'if accepted ~= true then', 'if accepted == false then'),
        ("partial projection writes house claims", "provisioning",
         "store.coverage.complete ~= true", "false"),
        ("partial projection reaches settlement", "provisioning",
         "projection.store.coverage.complete == true", "true"),
        ("retry decision reapplied", "material", "transaction.applied == true",
         "transaction.applied == false"),
        ("first empty result treated as no event", "material",
         "elseif provedEmpty then", "elseif false then"),
        ("older result reverses current owner", "material",
         "ownerOrder > receiptOrder", "ownerOrder < receiptOrder"),
        ("single-owner index removed", "material",
         "Material.sourceOwners = Material.sourceOwners or {}",
         "Material.sourceOwners = {}"),
        ("house projection generation frozen", "material",
         "store.projectionGeneration = (tonumber(store.projectionGeneration) or 0) + 1",
         "store.projectionGeneration = tonumber(store.projectionGeneration) or 0"),
        ("ambient projected source refresh removed", "material",
         "function Material.refreshProjectedSource",
         "function Material.noRefreshProjectedSource"),
        ("partial coverage marked complete", "material",
         'complete = false,\n        basis = "selected-native-sources"',
         'complete = true,\n        basis = "selected-native-sources"'),
        ("durable derivation phase removed", "material",
         "function Material.markDerivationComplete",
         "function Material.dropDerivationComplete"),
        ("material bound removed", "material", "local MAX_NATIVE_SOURCES = 256",
         "local MAX_NATIVE_SOURCES = 999999"),
        ("durable transaction lost", "graph",
         "SAO.Material.reconciliations = store.material.reconciliations",
         "SAO.Material.reconciliations = {}"),
        ("durable owner index lost", "graph", "store.material.sourceOwners",
         "store.material.transientOwners"),
        ("future graph schema accepted", "graph",
         'if priorSchema > GRAPH_SCHEMA then return nil, "future-schema" end',
         "if false then return nil, \"future-schema\" end"),
        ("future graph leaves old world attached", "graph",
         "        detachDurableOwners()\n        return false, why",
         "        return false, why"),
        ("legacy false-output migration removed", "graph",
         "migrateLegacyFalseOutputs(store, priorSchema)",
         "store.schema = priorSchema -- migration removed"),
        ("partial material migration removed", "graph",
         "migratePartialMaterialOutputs(store, priorSchema)",
         "store.schema = priorSchema -- partial migration removed"),
        ("legacy provisioning organization retained", "graph",
         "electionGroundedOrganization(store, organizationId)",
         "true -- preserve every linked organization"),
        ("material access view aliases authority", "material",
         "items = copyScalarMap(store.items)", "items = store.items"),
        ("material toggle exposes person access view", "material",
         "if options and options.Material == false then return nil end",
         "if false then return nil end"),
        ("composite view claims personal ownership", "material",
         'projection = "person-and-house",\n                personal = personalView',
         'projection = "person-and-house",\n                owner = personal.owner,\n'
         '                personal = personalView'),
        ("settlement accepts unperformed ground", "settlement",
         'evidence.status ~= "completed"', 'evidence.status == "impossible"'),
        ("older settlement generation overwrites newer", "settlement",
         "priorGeneration > incomingGeneration",
         "priorGeneration < incomingGeneration"),
        ("settlement accepts partial source projection", "settlement",
         "materialStore.coverage.complete ~= true",
         "false"),
        ("settlement storage survives claim lapse", "settlement",
         "function Settlement.clearStorageProjection",
         "function Settlement.keepStorageProjection"),
        ("dissolution keeps material", "recognition",
         "SAO.Material.forgetHouse(groupName)", "SAO.Material.keepHouse(groupName)"),
        ("standing loses strict context", "standing",
         "function S.provisioningContextAt",
         "function S.guessProvisioningContextAt"),
        ("standing migration removed", "standing",
         "migrateLegacyMaterialClaims(s, priorSchema)",
         "s.schema = priorSchema -- migration removed"),
        ("partial standing claim migration removed", "standing",
         "migratePartialMaterialClaims(s, priorSchema)",
         "s.schema = priorSchema -- partial migration removed"),
        ("future standing schema accepted", "standing",
         "if priorSchema > STANDING_SCHEMA then return nil end",
         "if false then return nil end"),
        ("new claim incarnation omitted", "standing",
         "claimIncarnation = claimIncarnation,",
         "claimIncarnation = nil,"),
        ("context omits claim incarnation", "standing",
         'return "held-group", tostring(groupName), claim.claimIncarnation',
         'return "held-group", tostring(groupName), nil'),
        ("material toggle exposes standing stock", "standing",
         "if not materialEnabled() then return nil end",
         "if false then return nil end"),
        ("material toggle permits standing writes", "standing",
         "if not materialWriteAllowed(evidence) then return false end",
         "if false then return false end"),
        ("older standing generation overwrites newer", "standing",
         "return priorGeneration > generation",
         "return priorGeneration < generation"),
        ("cross-producer freshness ignores observation time", "standing",
         "local bothProjection = prior.basis == projectionBasis",
         "local bothProjection = true or prior.basis == projectionBasis"),
        ("material toggle judges quartermaster stock", "standing",
         "evidence = -1\n                    if materialEnabled() then",
         "evidence = -1\n                    if true then"),
        ("claim change keeps projection", "standing",
         "SAO.Settlement.clearStorageProjection(groupName)",
         "SAO.Settlement.keepStorageProjection(groupName)"),
        ("dormant need dates write stock", "dormant",
         "local function dormantProvision()",
         "local function dormantProvision()\n    SAO.Standing.setLarder(g, 'full')"),
        ("queue acceptance credits shelving", "needs",
         'function N.depositSpareFood(id, body, context)',
         'function N.depositSpareFood(id, body, context)\n'
         '    SAO.Recognition.onShelved(id, nil, "food", 1)'),
        ("population retry removed", "population",
         'runSub("provision-results", consumeProvisioningResults)',
         "-- result consumer removed"),
        ("material toggle leaks stock into labor", "labor",
         "local materialEnabled = not options or options.Material ~= false",
         "local materialEnabled = true"),
        ("quartermaster scan omits material generation", "controller",
         "and SAO.Material.houseProjectionGeneration",
         "and SAO.Material.missingProjectionGeneration"),
        ("integration ignores graph refusal", "integration",
         "if bound ~= true then", "if false then"),
        ("world genesis ignores graph refusal", "world_genesis",
         "if bound ~= true then return false end",
         "if false then return false end"),
        ("world graph collapses ownership", "world_genesis",
         "personal = summarizeMaterialStore", "personal = nil -- collapsed"),
        ("inspect drops personal owner", "inspect",
         "owner = store and store.owner or nil", "owner = nil"),
        ("inspect drops access subject", "inspect",
         "accessibleBy = store and store.accessibleBy or nil",
         "accessibleBy = nil"),
        ("sweep omits consumer", "county_sweep",
         '"shared/SAO_WorldSources.lua", "shared/SAO_Provisioning.lua"',
         '"shared/SAO_WorldSources.lua"'),
        ("settlement tooltip claims provisioning founds bases", "sandbox",
         "it cannot found one", "it founds one"),
        ("material tooltip claims shelving is connected", "sandbox",
         "Shelving is not connected yet", "Shelving is connected"),
    ]
    faults: list[str] = []
    for name, key, old, new in controls:
        mutated = dict(baseline)
        if old not in mutated[key]:
            faults.append(f"control anchor missing: {name}")
            continue
        mutated[key] = mutated[key].replace(old, new)
        if contract(mutated):
            faults.append(f"control survived: {name}")
    return not faults, faults


def main() -> int:
    repository_inputs = [
        WORLD, MATERIAL, SETTLEMENT, RECOGNITION, PROVISIONING, GRAPH,
        WORLD_GENESIS, STANDING, DORMANT, NEEDS, SOURCE_USE, POPULATION,
        CONTROLLER, INSPECT, INTEGRATION, LABOR, COUNTY_SWEEP, CHECK,
        SANDBOX, RUNNER,
        TOOLS / "delivery_knowledge_cases.py",
        TOOLS / "delivery_integration_cases.py",
        TOOLS / "sweep/delivery_knowledge_cases.lua",
        TOOLS / "sweep/delivery_integration_cases.lua",
    ]
    missing = [path for path in repository_inputs if not path.is_file()]
    if missing:
        print("FAULT repository input absent: " + ", ".join(
            str(path.relative_to(ROOT)) for path in missing))
        return 1
    faults: list[str] = []
    static_ok, static_faults = static_controls()
    faults.extend(static_faults)
    print("controls: " + ("all named mutations rejected" if static_ok
                           else "; ".join(static_faults)))
    if not runtime_available():
        if faults:
            for fault in faults:
                print("FAULT", fault)
            return 1
        print("Border 180 SKIPPED: installed Project Zomboid Kahlua/JDK absent")
        return 0

    value, output = run_kahlua()
    if value is None:
        faults.append("Kahlua production probe did not return a value")
        print(output)
    else:
        observed: dict[str, bool] = {}
        for part in value.split("|"):
            name, _, result = part.partition("=")
            observed[name] = result == "true"
        missing = sorted(EXPECTED - observed.keys())
        failed = sorted(name for name in EXPECTED if not observed.get(name))
        if missing:
            faults.append("missing dynamic checks: " + ", ".join(missing))
        if failed:
            faults.append("failed dynamic checks: " + ", ".join(failed))
        print(f"production: {sum(observed.values())}/{len(EXPECTED)} provisioning cases")
    import delivery_knowledge_cases
    import delivery_integration_cases
    if delivery_knowledge_cases.main() != 0:
        faults.append("private delivery knowledge probe failed")
    if delivery_integration_cases.main() != 0:
        faults.append("delivery integration probe failed")
    if faults:
        for fault in faults:
            print("FAULT", fault)
        return 1
    print("Border 180 PASS: exact result consumption is bounded, replay-safe, "
          "single-owner and claim-lifecycle aware")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
