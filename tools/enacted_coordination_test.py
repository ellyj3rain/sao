#!/usr/bin/env python3
"""Border 190: acquired proposals become revisable, receipt-backed work."""
from __future__ import annotations

import json
import pathlib
import re
import shutil
import subprocess
import tempfile

import county_dump as Dump


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
COMMUNICATION = LUA / "shared/SAO_Communication.lua"
GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
SOURCE_USE = LUA / "client/SAO_SourceUse.lua"
HANDOVER = LUA / "shared/SAO_Handover.lua"
PROVISIONING = LUA / "shared/SAO_Provisioning.lua"
EXCHANGE = LUA / "client/SAO_Exchange.lua"
DORMANT = LUA / "client/SAO_DormantPopulation.lua"
HARNESS = LUA / "client/SAO_Harness.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
STANDING = LUA / "shared/SAO_Standing.lua"
RECOGNITION = LUA / "shared/SAO_Recognition.lua"
CAPTURE = ROOT / "tools/sweep/decision_capture.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
_G.__now = 100
plainNameOf = function(first, last) return first .. " " .. last end
_G.__people = {}
local function person(id)
  __people[id] = __people[id] or { id=id, forename=id, surname="Witness",
    occupation="survivor", profile={ frozen="decision" } }
  return __people[id]
end
SAO = {
  History = { countyHours = function() return __now end,
    ageOf = function() return 30 end },
  Branching = {}, Settlement = {}, Material = {}, PlayerInteraction = {},
  Identity = { get = person },
  Body = { active = {}, hasRepresentation = function() return false end },
  Disposition = { circle=function() return "near" end,
    traits=function() return {patience=0.5} end },
  Conditions = { of=function() return {} end },
  Habits = { of=function() return {} end },
  Lessons = { renderClaims=function() return {} end },
  Census = { JOB_PERK={}, classOf=function() return "survivor" end,
    skillOf=function() return 0 end },
  Perception = { beliefs={} },
  Rand = { state=function() return "border190", 0 end },
}
getSpecificPlayer = function() return nil end
_G.__stores = {
  SurvivorAwareness_Graph = {
    schema = 3,
    branching = { patterns = {}, offices = {} },
    organization = { organizations = {}, offices = {}, claims = {},
      decisions = {} },
    settlement = { bases = {} },
    material = { stores = {}, reconciliations = {}, sourceOwners = {} },
    communication = { messages = {} }, player = { claims = {} },
    migrations = {},
  },
}
ModData = { getOrCreate = function(key)
  __stores[key] = __stores[key] or {}
  return __stores[key]
end }
Events = setmetatable({}, { __index = function(t, key)
  local slot = { Add = function() end, Remove = function() end }
  rawset(t, key, slot)
  return slot
end })
'''

PROBE = r'''(function()
  local checks = {}
  local function check(name, value)
    checks[#checks + 1] = name .. '=' .. tostring(value == true)
  end
  local function count(value)
    local n = 0
    for _ in pairs(value or {}) do n = n + 1 end
    return n
  end
  local coordinationCapture = SAODecisionCapture.beginCoordination({
    runId="run-border190", county="CountyBorder" })
  local function receive(process, person)
    local message = SAO.Communication.send(process.originatorId, person,
      'process-proposal', { processId = process.id,
        revision = process.revision })
    message.transportAdmitted = true
    message.channel = 'spoken'
    message.transportEvidence = { distance = 2 }
    return SAO.Communication.deliver(message)
  end
  local function appraise(process, person, choice)
    return SAO.Organization.appraiseMatter(process.id, person, {
      choice = choice, owner = 'border190.private', executor = 'border190',
      bodyOwner = 'SAO', currentActivity = 'idle', relationship = 0.6,
      ownNeed = choice == 'qualify' and 0.9 or 0.1,
      destinationKnown = choice ~= 'counter-propose',
      canAcquire = true, canCarry = true, canDeliver = true,
      interests = { own = person }, constraints = { current = 'idle' },
      inputOwners = { currentActivity='border190.activity',
        capabilities='border190.capability', ownNeed='border190.need',
        relationship='border190.relationship', interests='border190.interest',
        constraints='border190.constraint' },
    })
  end
  local function acceptMatter(origin, actor, suffix)
    local p = SAO.Organization.raiseMatter(origin, 'food-delivery', 'g', {
      purpose = suffix, destination = { minX=1, minY=1, maxX=2, maxY=2 },
      scope = { quantity = 1, category = 'food' },
    }, { actor }, { privateNeed = suffix })
    receive(p, actor)
    appraise(p, actor, 'accept')
    SAO.Organization.deliverResponse(p.id, actor, origin, 'spoken',
      { distance = 2 })
    return p, SAO.Organization.activeCommitment(actor, 'food-delivery')
  end

  check('schema4_migrated', SAO.GraphPersistence.bind() == true
    and __stores.SurvivorAwareness_Graph.schema == 4
    and __stores.SurvivorAwareness_Graph.migrations.c79EnactedProcesses ~= nil)

  local Org = SAO.Organization
  Org.createOrganization('g', { minX=0, minY=0, maxX=10, maxY=10 },
    'communal')
  for _, id in ipairs({ 'origin', 'acceptor', 'acceptor2', 'qualifier',
      'counter', 'decliner', 'deferer', 'contester', 'withdrawer', 'silent' }) do
    Org.join('g', id)
  end
  Org.createOffice('g', 'chair', { ['resource allocation'] = true },
    'consent', 'consent')
  local people = { 'acceptor', 'acceptor2', 'qualifier', 'counter',
    'decliner', 'deferer', 'contester', 'withdrawer', 'silent' }
  local process = Org.raiseMatter('origin', 'food-delivery', 'g', {
    destination = { minX=4, minY=4, maxX=6, maxY=6 },
    scope = { quantity = 2, category = 'food' },
    -- Adversarial payload: field names alone cannot turn delivery assent into
    -- an office appointment; the process matter must also match.
    officeId = 'chair', holderId = 'acceptor',
  }, people, { hiddenLarder = 0, source = 'private-observation' })

  local generic = SAO.Communication.send('origin', 'acceptor',
    'process-proposal', { processId=process.id, revision=1 })
  SAO.Communication.deliver(generic)
  check('generic_delivery_is_not_acquisition',
    #Org.responseOptions(process.id, 'acceptor', {}) == 0)
  check('unheard_proposal_is_private',
    Org.viewFor('silent', process.id, false).proposal == nil)

  for _, person in ipairs(people) do
    if person ~= 'silent' then receive(process, person) end
  end
  local choices = {
    acceptor='accept', acceptor2='accept', qualifier='qualify',
    counter='counter-propose', decliner='decline', deferer='defer',
    contester='contest', withdrawer='accept',
  }
  for person, choice in pairs(choices) do appraise(process, person, choice) end
  check('formed_acceptance_is_not_commitment',
    Org.activeCommitment('acceptor', 'food-delivery') == nil)
  check('misdelivered_response_has_no_effect',
    Org.deliverResponse(process.id, 'acceptor', 'someone-else', 'spoken', {})
      == false and Org.activeCommitment('acceptor', 'food-delivery') == nil)
  for person in pairs(choices) do
    Org.deliverResponse(process.id, person, 'origin', 'spoken', { distance=2 })
  end
  appraise(process, 'withdrawer', 'withdraw')
  Org.deliverResponse(process.id, 'withdrawer', 'origin', 'spoken', {})

  local originView = Org.viewFor('origin', process.id, false)
  local qualifierView = Org.viewFor('qualifier', process.id, false)
  check('all_response_kinds_and_unanswered',
    originView.responses.acceptor.response == 'accept'
    and originView.responses.qualifier.response == 'qualify'
    and originView.responses.counter.response == 'counter-propose'
    and originView.responses.decliner.response == 'decline'
    and originView.responses.deferer.response == 'defer'
    and originView.responses.contester.response == 'contest'
    and originView.responses.withdrawer.response == 'withdraw'
    and originView.responses.silent.response == 'unanswered')
  check('private_appraisal_is_actor_owned',
    qualifierView.privateInputs.choice == 'qualify'
    and qualifierView.privateInputs.executor == 'border190'
    and qualifierView.privateInputs.hiddenLarder == nil)
  check('withdrawal_is_revisable_not_erasure',
    Org.activeCommitment('withdrawer', 'food-delivery') == nil
    and #qualifierView.responseHistory == 0
    and #Org.viewFor('withdrawer', process.id, false).responseHistory == 1)
  check('contest_is_shared_without_forced_result', process.contested == true
    and Org.activeCommitment('contester', 'food-delivery') == nil)
  check('concurrent_scoped_commitments',
    Org.activeCommitment('acceptor', 'food-delivery') ~= nil
    and Org.activeCommitment('acceptor2', 'food-delivery') ~= nil
    and #Org.authorityFor('acceptor', 'g', 'food-delivery') == 1)
  check('delivery_scope_not_command',
    #Org.authorityFor('acceptor', 'g', 'command:walk') == 0)

  local commitment = Org.activeCommitment('acceptor', 'food-delivery')
  check('unrelated_commitment_cannot_appoint',
    Org.appoint('g', 'chair', 'acceptor', commitment.id) == false)
  local officeProcess = Org.raiseMatter('origin', 'office:chair', 'g', {
    officeId='chair', holderId='acceptor',
    scope={ officeId='chair', holderId='acceptor' },
  }, { 'acceptor' }, { source='explicit-office-proposal' })
  receive(officeProcess, 'acceptor')
  appraise(officeProcess, 'acceptor', 'accept')
  Org.deliverResponse(officeProcess.id, 'acceptor', 'origin', 'spoken', {})
  local officeCommitment = Org.activeCommitment('acceptor', 'office:chair')
  check('accepted_office_projection',
    officeCommitment ~= nil
    and Org.appoint('g', 'chair', 'acceptor', officeCommitment.id) == true)
  local d1 = Org.recordDecision('g', 'chair', 'acceptor',
    'resource allocation', { quantity=1 }, { observed='shortage' },
    officeProcess.id)
  local d2 = Org.recordDecision('g', 'chair', 'acceptor',
    'resource allocation', { quantity=2 }, { observed='change' },
    officeProcess.id)
  local decisionKey = 'g:chair:resource allocation'
  check('revision_safe_decision_history', d1 and d2 and d1.id ~= d2.id
    and #Org.decisionHistory[decisionKey] == 2)
  local c1 = Org.recordClaim('origin', 'need', 'food', 'g', { amount=1 })
  local c2 = Org.recordClaim('origin', 'need', 'food', 'g', { amount=2 })
  check('revision_safe_claim_history', c1.id ~= c2.id
    and #Org.claimHistory['origin:need:food'] == 2)

  Org.startWork(commitment.id, 'SAO', 'acquiring')
  Org.noteWorkAdmission(commitment.id, 'SourceUse', 'source-1',
    { phase='queued' })
  local sourceReceipt = { reservationId='source-1', processId=process.id,
    processRevision=1, commitmentId=commitment.id, operation='acquire',
    actorId='acceptor', status='completed', at=110,
    transferObservation={ item='food' } }
  local foreignOk, foreignWhy = Org.consumeSourceResult({
    reservationId='source-1', processId=process.id, processRevision=1,
    commitmentId=commitment.id, actorId='someone-else', operation='acquire',
    status='completed', at=109 })
  check('native_receipt_is_actor_revision_and_admission_bound',
    foreignOk == false and foreignWhy == 'receipt-not-admitted'
    and commitment.work.pendingReceiptId == 'source-1')
  Org.consumeSourceResult(sourceReceipt)
  local outcomesBefore = #commitment.work.outcomes
  local replayOk, replayWhy = Org.consumeSourceResult(sourceReceipt)
  check('acquisition_becomes_carrying_once', commitment.work.phase == 'carrying'
    and replayOk and replayWhy == 'duplicate'
    and #commitment.work.outcomes == outcomesBefore)
  Org.noteWorkAdmission(commitment.id, 'Handover', 'handover-1', {})
  Org.consumeHandoverResult({ id='handover-1', processId=process.id,
    processRevision=1, commitmentId=commitment.id, actorId='acceptor',
    recipientId='origin', status='completed', completedAt=112 })
  check('native_handover_completes_commitment', commitment.status == 'completed'
    and commitment.work.phase == 'completed'
    and commitment.work.owner == 'SAO'
    and commitment.work.nativeOwner == 'Handover'
    and commitment.work.sourceReceipts['source-1'].owner == 'SourceUse'
    and commitment.work.handoverReceipts['handover-1'].owner == 'Handover')

  local evidence = Org.decisionEvidence(process.id, 'acceptor')
  check('decision_and_outcome_horizons_are_separate',
    evidence.decisionTime.privateInputs.choice == 'accept'
    and evidence.decisionTime.privateInputs.inputOwners.currentActivity
      == 'border190.activity'
    and evidence.decisionTime.response.delivered == false
    and evidence.decisionTime.response.deliveredAt == nil
    and evidence.decisionTime.asOfHour
      == evidence.decisionTime.response.formedAt
    and count(evidence.decisionTime.commitments) == 0
    and evidence.laterOutcome.privateInputs == nil
    and evidence.laterOutcome.responseHistory == nil
    and evidence.laterOutcome.asOfHour >= evidence.decisionTime.asOfHour
    and evidence.laterOutcome.commitments[commitment.id].status == 'completed')

  local _, partial = acceptMatter('origin', 'partial-worker', 'partial')
  Org.startWork(partial.id, 'SAO', 'acquiring')
  Org.noteWorkAdmission(partial.id, 'SourceUse', 'source-partial', {})
  Org.consumeSourceResult({ reservationId='source-partial',
    processId=partial.processId, processRevision=partial.revision,
    commitmentId=partial.id, actorId='partial-worker',
    operation='acquire', status='completed', at=120 })
  Org.noteWorkAdmission(partial.id, 'Handover', 'handover-partial', {})
  Org.consumeHandoverResult({ id='handover-partial',
    processId=partial.processId, processRevision=partial.revision,
    commitmentId=partial.id, actorId='partial-worker', recipientId='origin',
    status='interrupted', reason='threat' })
  local _, failed = acceptMatter('origin', 'failed-worker', 'failed')
  Org.startWork(failed.id, 'SAO', 'acquiring')
  Org.noteWorkAdmission(failed.id, 'SourceUse', 'source-failed', {})
  Org.consumeSourceResult({ reservationId='source-failed',
    processId=failed.processId, processRevision=failed.revision,
    commitmentId=failed.id, actorId='failed-worker',
    operation='acquire', status='failed', detail='source changed' })
  check('partial_and_failure_remain_distinct',
    partial.status == 'interrupted' and partial.work.phase == 'partial'
    and failed.status == 'failed' and failed.work.phase == 'failed')

  local pauseProcess, paused = acceptMatter('origin', 'paused-worker', 'pause')
  Org.startWork(paused.id, 'SAO', 'acquiring')
  Org.noteRoute(paused.id, 'Locomotion', 4, 5, 0, 'acquiring')
  Org.pauseWork(paused.id, 'observed-danger', { threat='near' })
  local pausedRoute = paused.work.routeAttempts[#paused.work.routeAttempts]
  check('danger_pauses_without_completion', paused.status == 'paused'
    and paused.work.phase == 'paused' and pausedRoute.status == 'paused'
    and Org.activeCommitment('paused-worker', 'food-delivery') ~= nil)
  Org.resumeWork(paused.id, 'SAO', 'acquiring', { threat='clear' })
  check('paused_work_resumes_same_commitment', paused.status == 'in-progress'
    and paused.work.phase == 'resumed'
    and Org.activeCommitment('paused-worker', 'food-delivery').id == paused.id)
  Org.releaseActor('paused-worker', 'actor-dead')
  check('actor_lifecycle_ends_work_without_erasure',
    paused.status == 'withdrawn'
    and Org.activeCommitment('paused-worker', 'food-delivery') == nil
    and Org.viewFor('paused-worker', pauseProcess.id, true).response ~= nil)

  local activeBeforeRevision = Org.activeCommitment('acceptor2', 'food-delivery')
  Org.reviseMatter(process.id, 'origin', {
    destination={ minX=7,minY=7,maxX=8,maxY=8 },
    scope={ quantity=1, category='food' },
  }, { changedNeed=1 })
  check('revision_supersedes_unfinished_responsibility',
    activeBeforeRevision.status == 'superseded'
    and Org.activeCommitment('acceptor2', 'food-delivery') == nil
    and Org.viewFor('acceptor2', process.id, false).proposal == nil)
  local priorEvidence = Org.decisionEvidence(process.id, 'acceptor', 1)
  check('prior_revision_evidence_remains_addressable', priorEvidence ~= nil
    and priorEvidence.processRevision == 1
    and priorEvidence.decisionTime.revision == 1
    and priorEvidence.decisionTime.currentRevision == 1
    and priorEvidence.decisionTime.privateInputs.choice == 'accept'
    and priorEvidence.laterOutcome.currentRevision == 2
    and priorEvidence.laterOutcome.commitments[commitment.id].status
      == 'completed')
  receive(process, 'acceptor2')
  appraise(process, 'acceptor2', 'accept')
  Org.deliverResponse(process.id, 'acceptor2', 'origin', 'spoken', {})
  check('revised_proposal_requires_fresh_acquisition',
    Org.activeCommitment('acceptor2', 'food-delivery').revision == 2)

  local savedProcessId = process.id
  local savedReceiptCount = count(Org.workReceipts)
  Org.processes, Org.processOrder, Org.processMeta, Org.workReceipts = {}, {}, {}, {}
  check('reload_rebinds_processes_and_receipts',
    SAO.GraphPersistence.bind() == true
    and Org.processes[savedProcessId] ~= nil
    and count(Org.workReceipts) == savedReceiptCount)

  Org.createOffice('g', 'deputy', { membership=true }, 'consent', 'consent')
  Org.retireOrganization('g', 'house-dissolved')
  check('organization_retirement_preserves_evidence',
    Org.organizations.g == nil and Org.offices['g:chair'] == nil
    and Org.offices['g:deputy'] == nil
    and Org.processes[savedProcessId] ~= nil
    and count(Org.workReceipts) == savedReceiptCount)

  __now = 130
  local captured = coordinationCapture.finish()
  return '{"checks":' .. SAODecisionCapture.encode(table.concat(checks, ','))
    .. ',"capture":' .. captured .. '}'
end)()'''

EXPECTED = {
    'schema4_migrated', 'generic_delivery_is_not_acquisition',
    'unheard_proposal_is_private', 'formed_acceptance_is_not_commitment',
    'misdelivered_response_has_no_effect', 'all_response_kinds_and_unanswered',
    'private_appraisal_is_actor_owned', 'withdrawal_is_revisable_not_erasure',
    'contest_is_shared_without_forced_result', 'concurrent_scoped_commitments',
    'delivery_scope_not_command', 'unrelated_commitment_cannot_appoint',
    'accepted_office_projection', 'revision_safe_decision_history',
    'revision_safe_claim_history',
    'native_receipt_is_actor_revision_and_admission_bound',
    'acquisition_becomes_carrying_once',
    'native_handover_completes_commitment',
    'decision_and_outcome_horizons_are_separate',
    'partial_and_failure_remain_distinct',
    'danger_pauses_without_completion', 'paused_work_resumes_same_commitment',
    'actor_lifecycle_ends_work_without_erasure',
    'revision_supersedes_unfinished_responsibility',
    'prior_revision_evidence_remains_addressable',
    'revised_proposal_requires_fresh_acquisition',
    'reload_rebinds_processes_and_receipts',
    'organization_retirement_preserves_evidence',
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / 'javac.exe'), '-cp', str(PZ), '-d', str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(org_source: str, communication_source: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix='sao-enacted-coordination-') as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / 'stdlib.lua')
        for cls in OUT.glob('LuaRun*.class'):
            shutil.copy2(cls, work / cls.name)
        files = {
            'prelude.lua': PRELUDE,
            'organization.lua': org_source,
            'communication.lua': communication_source,
            'probe.lua': '__result = ' + PROBE,
        }
        for name, source in files.items():
            (work / name).write_text(source, encoding='utf-8')
        done = subprocess.run(
            [str(JDK / 'java.exe'), '-cp', f'{PZ};.', 'LuaRun',
             str(work / 'prelude.lua'), str(work / 'organization.lua'),
             str(work / 'communication.lua'), str(GRAPH),
             str(CAPTURE),
             str(work / 'probe.lua'), '--', '__result'],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or '') + (done.stderr or '')
    lines = (done.stdout or '').strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith('VALUE ') else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r'([a-z0-9_]+)=(true|false)', value or ''))


def static_contract() -> tuple[bool, str]:
    source_use = SOURCE_USE.read_text(encoding='utf-8')
    handover = HANDOVER.read_text(encoding='utf-8')
    provisioning = PROVISIONING.read_text(encoding='utf-8')
    standing = STANDING.read_text(encoding='utf-8')
    recognition = RECOGNITION.read_text(encoding='utf-8')
    controller = CONTROLLER.read_text(encoding='utf-8')
    exchange = EXCHANGE.read_text(encoding='utf-8')
    dormant = DORMANT.read_text(encoding='utf-8')
    production = '\n'.join(path.read_text(encoding='utf-8')
                           for path in (EXCHANGE, DORMANT, HARNESS,
                                        CONTROLLER))
    required = [
        'SAO.Organization.noteWorkAdmission',
        'reservation.processId = context.processId',
    ]
    if any(anchor not in source_use for anchor in required):
        return False, 'SourceUse does not retain coordinated admission'
    if ('SAO.Organization.noteWorkAdmission' not in handover
            or 'SAO.Organization.consumeHandoverResult' not in handover):
        return False, 'Handover does not admit and consume coordinated work'
    if 'SAO.Organization.consumeSourceResult' not in provisioning:
        return False, 'Provisioning does not consume native source results'
    if ('function S.maybeCallForBread' not in standing
            or 'SAO.Standing.maybeCallForBread(id)' not in controller
            or 'SAO.Standing.maybeCallForBread(id)' not in dormant):
        return False, 'private material pressure has no loaded/dormant producer'
    if ('SAO.Standing.proposeCompany(' not in exchange
            or 'SAO.Standing.proposeCompany(' not in dormant
            or any(call in exchange + dormant for call in (
                'SAO.Standing.electLeader(', 'SAO.Standing.checkSchism('))):
        return False, 'encounter membership bypasses explicit participants'
    if ('SAO.Organization.pauseWork' not in controller
            or 'SAO.Organization.resumeWork' not in controller):
        return False, 'competing pressure cannot pause and resume native work'
    if ('function R.onElection' not in recognition
            or 'return false, "explicit-process-required"' not in recognition):
        return False, 'legacy recognition shortcut is not explicitly retired'
    if any(call in production for call in (
            'Standing.electLeader(', 'Recognition.onElection(',
            'Standing.checkSchism(')):
        return False, 'production caller retains automatic authority shortcut'
    return True, 'native owners and production shortcut removals are wired'


def main() -> int:
    print('=' * 74)
    print('ENACTED SOCIAL COORDINATION AND RECEIPT-BACKED WORK')
    print('=' * 74)
    required = [ORGANIZATION, COMMUNICATION, GRAPH, CAPTURE, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print('  FAULT: repository input absent: ' + ', '.join(map(str, missing)))
        return 1
    installed = [PZ, STDLIB, JDK / 'java.exe', JDK / 'javac.exe']
    if not all(path.is_file() for path in installed):
        print('Border 190 SKIPPED: installed game VM or JDK absent')
        return 0
    static_ok, static_detail = static_contract()
    print('  static contract: ' + ('PASS' if static_ok else 'FAIL')
          + ' (' + static_detail + ')')
    built, detail = compile_runner()
    if not built:
        print('  FAULT: runner compile failed ' + detail[-1000:])
        return 1
    org_source = ORGANIZATION.read_text(encoding='utf-8-sig')
    communication_source = COMMUNICATION.read_text(encoding='utf-8-sig')
    value, detail = run_probe(org_source, communication_source)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != 'true')
    capture_ok = True
    try:
        capture = json.loads(value or "{}")["capture"]
        Dump.validate_coordination_capture(
            capture, "CountyBorder", "run-border190")
        withdrawer = [row for row in capture["events"]
                      if row["namespace"]["personId"] == "withdrawer"]
        acceptor = [row for row in capture["events"]
                    if row["namespace"]["personId"] == "acceptor"
                    and row["situation"]["kind"] == "food-delivery"]
        if (len(withdrawer) != 1
                or withdrawer[0]["choice"]["optionId"]
                != "coordination:withdraw"
                or withdrawer[0]["enactedProcess"]["decisionTime"]
                ["response"]["delivered"] is not False
                or withdrawer[0]["enactedProcess"]["laterOutcome"]
                ["response"]["delivered"] is not True
                or len(acceptor) != 1
                or not any(commitment.get("status") == "completed"
                           for commitment in acceptor[0]["enactedProcess"]
                           ["laterOutcome"]["commitments"].values())):
            capture_ok = False
    except (KeyError, TypeError, ValueError, Dump.Sweep.EvidenceError) as error:
        capture_ok = False
        print("  FAULT: production coordination capture: " + str(error))
    controls = [
        ('transport acquisition guard', 'message.transportAdmitted == true',
         'true'),
        ('private acquisition view',
         'proposal = acquired and dataCopy(selectedProposal) or nil',
         'proposal = dataCopy(selectedProposal)'),
        ('exact-once source receipt',
         'local receiptKey = receiptId and "source:" .. receiptId or nil\n'
         '    local prior = receiptKey and Org.workReceipts[receiptKey] or nil',
         'local receiptKey = receiptId and "source:" .. receiptId or nil\n'
         '    local prior = nil'),
        ('receipt actor binding',
         'and receipt.actorId == commitment.actorId',
         'and true'),
        ('decision-time horizon', 'decision.commitments = {}',
         'decision.commitments = outcome and dataCopy(outcome.commitments) or {}'),
        ('revision supersession',
         'endCommitment(process, commitment, "superseded",',
         'endCommitment(process, commitment, commitment.status,'),
        ('office matter scope',
         'or process.kind ~= "office:" .. tostring(officeId)',
         'or false'),
        ('pause remains resumable', 'commitment.status = "paused"',
         'commitment.status = "interrupted"'),
    ]
    controls_ok = True
    for name, old, new in controls:
        target = communication_source if name == 'transport acquisition guard' else org_source
        if target.count(old) != 1:
            print(f'  FAULT: {name} mutation seam changed')
            controls_ok = False
            continue
        mutated = target.replace(old, new, 1)
        if name == 'transport acquisition guard':
            mutant_value, _ = run_probe(org_source, mutated)
        else:
            mutant_value, _ = run_probe(mutated, communication_source)
        if not any(result == 'false' for result in verdicts(mutant_value).values()):
            print(f'  FAULT: {name} mutation survived')
            controls_ok = False
    print('  mutation controls: ' + ('PASS' if controls_ok else 'FAIL')
          + ' (eight production controls)')
    print('  v3 production capture: ' + ('PASS' if capture_ok else 'FAIL'))
    if (not static_ok or not controls_ok or not capture_ok
            or set(found) != EXPECTED or failed):
        print('  FAULT: missing=' + repr(sorted(EXPECTED - set(found)))
              + ' failed=' + repr(failed) + ' value=' + repr(value))
        print('  ' + detail[-2500:].replace('\n', ' '))
        return 1
    print('  190) proposals, responses, revisions, scoped authority, native work, '
          'exact-once receipts, private horizons and reload execute in Kahlua')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
