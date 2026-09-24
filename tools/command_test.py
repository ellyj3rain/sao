#!/usr/bin/env python3
"""Border 111 - commands are acquired, answered, and scope-bound.

This border runs the production Organization and Command modules in Kahlua.
It distinguishes voluntary agreement from authority, holds capability and
current activity inside the recipient's private appraisal, and proves that an
accepted food-delivery commitment cannot authorize an unrelated command.
"""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
COMMAND = LUA / "shared/SAO_Command.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
HARNESS = LUA / "client/SAO_Harness.lua"
CHECK = ROOT / "tools/check.sh"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
_G.__now = 100
_G.__groups, _G.__trust, _G.__hostile = {}, {}, {}
_G.__canConverse = true
_G.__need, _G.__insideClaim = 0, false
SAO = {
  History = { countyHours = function() return __now end },
  Standing = {}, Identity = {}, Body = {}, Controller = { agents = {} },
  Census = { JOB_PERK = {}, skillOf = function() return 0 end },
  Disposition = {
    fear = function() return 0 end,
    fleeDistance = function() return 10 end,
    wouldEngage = function() return true end,
  },
  Perception = {
    believedThreatCount = function() return 1 end,
    believesClaimed = function() return nil end,
    nearestBelievedZombie = function() return nil end,
  },
  Communication = {},
  Needs = { read = function() return { hunger=__need, thirst=0 } end },
}
SAO.Standing.groupOf = function(id) return __groups[tostring(id)] end
SAO.Standing.trust = function(id, other)
  local row = __trust[tostring(id)]
  return row and row[tostring(other)] or 0
end
SAO.Standing.isHostileTo = function(id, other)
  return __hostile[tostring(id) .. '>' .. tostring(other)] == true
end
SAO.Standing.insideClaim = function() return __insideClaim end
SAO.Standing.mayEnter = function() return true end
SAO.Standing.isPlayerKey = function() return false end
SAO.Standing.playerKey = function() return nil end
SAO.Identity.get = function() return nil end
SAO.Body.get = function() return nil end
SAO.Communication.bodyFor = function(id)
  if id == 'recipient' then return {} end
  return nil
end
SAO.Communication.canConverse = function() return __canConverse end
getSpecificPlayer = function() return nil end
Perks = {}
'''

PROBE = r'''(function()
  local checks = {}
  local function check(name, value)
    checks[#checks + 1] = name .. '=' .. tostring(value == true)
  end
  local function latest(origin, kind)
    for index = #SAO.Organization.processOrder, 1, -1 do
      local p = SAO.Organization.processes[SAO.Organization.processOrder[index]]
      if p and p.originatorId == origin and p.kind == 'command:' .. kind then
        return p
      end
    end
    return nil
  end
  local function accept(origin, actor, matter, proposal)
    local p = SAO.Organization.raiseMatter(origin, matter, 'g', proposal,
      { actor }, { source='border111' })
    SAO.Organization.recordReception(p.id, actor, p.revision, 'spoken', origin, {})
    SAO.Organization.appraiseMatter(p.id, actor, {
      owner='border111', executor='border111', currentActivity='idle',
      canAcquire=true, canCarry=true, canDeliver=true, canExecute=true,
      relationship=1, destinationKnown=true, choice='accept',
    })
    SAO.Organization.deliverResponse(p.id, actor, origin, 'spoken', {})
    return p, SAO.Organization.activeCommitment(actor, matter)
  end

  local Org, Cmd = SAO.Organization, SAO.Command
  Org.createOrganization('g', {}, 'communal')
  for _, id in ipairs({ 'recipient', 'giver', 'office-giver', 'requester' }) do
    Org.join('g', id)
  end
  __groups.recipient = 'g'
  SAO.Controller.agents.recipient = { state='IDLE', armed=false }

  __canConverse = false
  local verdict, reason = Cmd.order('unheard', 'recipient', 'walk', nil)
  local unheard = latest('unheard', 'walk')
  local unheardRow = unheard.participants.recipient
  check('unheard_request_stays_unanswered', verdict == 'refuses'
    and reason == 'did not receive the request'
    and unheardRow.responses['1'] == nil)

  __canConverse = true
  verdict, reason = Cmd.order('neutral', 'recipient', 'walk', nil)
  local neutral = latest('neutral', 'walk')
  local neutralView = Org.viewFor('recipient', neutral.id, false)
  check('neutral_recipient_qualifies_instead_of_inferred_assent',
    verdict == 'refuses' and neutralView.response.response == 'qualify'
    and neutralView.privateInputs.choice == 'qualify'
    and neutralView.privateInputs.executor == 'SAO.Command')

  __trust.recipient = { liked=0.4 }
  verdict = Cmd.order('liked', 'recipient', 'walk', nil)
  check('relationship_can_support_voluntary_acceptance', verdict == 'complies'
    and Org.activeCommitment('recipient', 'command:walk') ~= nil)

  SAO.Controller.agents.recipient.state = 'WORK'
  verdict = Cmd.order('busy', 'recipient', 'hold', nil)
  local busy = latest('busy', 'hold')
  check('current_activity_can_defer', verdict == 'refuses'
    and Org.viewFor('recipient', busy.id, false).response.response == 'defer')

  SAO.Controller.agents.recipient.state = 'IDLE'
  __hostile['recipient>hostile'] = true
  verdict = Cmd.order('hostile', 'recipient', 'hold', nil)
  local contested = latest('hostile', 'hold')
  check('hostility_can_contest', verdict == 'refuses' and contested.contested == true
    and Org.viewFor('recipient', contested.id, false).response.response == 'contest')

  verdict, reason = Cmd.order('liked', 'recipient', 'engage', nil)
  local incapable = latest('liked', 'engage')
  check('capability_can_decline', verdict == 'refuses'
    and reason == 'has nothing to fight with'
    and Org.viewFor('recipient', incapable.id, false).response.response == 'decline')

  __insideClaim, __need = true, 0.9
  SAO.Controller.agents.recipient.state = 'FORAGE'
  verdict = Cmd.order('owner', 'recipient', 'leave', { x=2, y=3 })
  local desperate = latest('owner', 'leave')
  local desperateView = Org.viewFor('recipient', desperate.id, false)
  check('urgent_need_is_a_recorded_decline', verdict == 'refuses'
    and desperateView.response.response == 'decline'
    and desperateView.privateInputs.ownNeed == 0.9)
  __need = 0.1
  verdict = Cmd.order('owner2', 'recipient', 'leave', { x=2, y=3 })
  check('interruptible_leave_can_be_accepted', verdict == 'complies')
  __insideClaim, __need = false, 0
  SAO.Controller.agents.recipient.state = 'IDLE'

  __trust.recipient.giver = 0
  local food, foodCommitment = accept('requester', 'giver', 'food-delivery', {
    officeId='chair', holderId='giver',
    scope={ quantity=1, category='food' },
  })
  check('delivery_commitment_is_not_command_authority', foodCommitment ~= nil
    and Cmd.officeOf('giver', 'recipient', 'walk') == 'none')
  verdict = Cmd.order('giver', 'recipient', 'walk', nil)
  check('unrelated_commitment_does_not_change_conduct', verdict == 'refuses'
    and Org.viewFor('recipient', latest('giver', 'walk').id, false)
      .response.response == 'qualify')

  local mandate, mandateCommitment = accept('procedure', 'giver',
    'command:walk', { scope={ action='walk', recipientId='recipient' } })
  check('exact_command_mandate_is_scoped', mandateCommitment ~= nil
    and Cmd.officeOf('giver', 'recipient', 'walk') == 'mandate'
    and Cmd.officeOf('giver', 'recipient', 'hold') == 'none')
  verdict = Cmd.order('giver', 'recipient', 'walk', nil)
  local holdVerdict = Cmd.order('giver', 'recipient', 'hold', nil)
  check('scoped_mandate_affects_only_its_matter', verdict == 'complies'
    and holdVerdict == 'refuses')

  Org.createOffice('g', 'chair', { ['command:travel']=true },
    'consent', 'consent')
  local appointment, appointmentCommitment = accept('procedure',
    'office-giver', 'office:chair', {
      officeId='chair', holderId='office-giver',
      scope={ officeId='chair', holderId='office-giver' },
    })
  check('office_requires_matching_appointment_process',
    Org.appoint('g', 'chair', 'giver', foodCommitment.id) == false
    and Org.appoint('g', 'chair', 'office-giver',
      appointmentCommitment.id) == true)
  check('office_jurisdiction_is_command_specific',
    Cmd.officeOf('office-giver', 'recipient', 'travel') == 'leader'
    and Cmd.officeOf('office-giver', 'recipient', 'hold') == 'none')
  verdict = Cmd.order('office-giver', 'recipient', 'travel', { x=2, y=3 })
  holdVerdict = Cmd.order('office-giver', 'recipient', 'hold', nil)
  check('jurisdiction_changes_only_covered_request', verdict == 'complies'
    and holdVerdict == 'refuses')

  local words = Cmd.describe('recipient', 'giver')
  check('panel_reports_enacted_history',
    string.find(words, 'accepted the last request', 1, true) ~= nil)
  return table.concat(checks, ',')
end)()'''

EXPECTED = {
    "unheard_request_stays_unanswered",
    "neutral_recipient_qualifies_instead_of_inferred_assent",
    "relationship_can_support_voluntary_acceptance",
    "current_activity_can_defer", "hostility_can_contest",
    "capability_can_decline", "urgent_need_is_a_recorded_decline",
    "interruptible_leave_can_be_accepted",
    "delivery_commitment_is_not_command_authority",
    "unrelated_commitment_does_not_change_conduct",
    "exact_command_mandate_is_scoped",
    "scoped_mandate_affects_only_its_matter",
    "office_requires_matching_appointment_process",
    "office_jurisdiction_is_command_specific",
    "jurisdiction_changes_only_covered_request",
    "panel_reports_enacted_history",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(command_source: str, organization_source: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-command-") as temporary:
        work = pathlib.Path(temporary)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for compiled in OUT.glob("LuaRun*.class"):
            shutil.copy2(compiled, work / compiled.name)
        files = {
            "prelude.lua": PRELUDE,
            "organization.lua": organization_source,
            "command.lua": command_source,
            "probe.lua": "__result = " + PROBE,
        }
        for name, source in files.items():
            (work / name).write_text(source, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(work / "prelude.lua"), str(work / "organization.lua"),
             str(work / "command.lua"), str(work / "probe.lua"),
             "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, (done.stdout or "") + (done.stderr or "")


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract(command_source: str) -> tuple[bool, list[str]]:
    controller = CONTROLLER.read_text(encoding="utf-8")
    harness = HARNESS.read_text(encoding="utf-8")
    checks = {
        "command records actual reception and a private appraisal": all(
            anchor in command_source for anchor in (
                "SAO.Communication.canConverse", "recordReception(process.id",
                "appraiseMatter(process.id", "deliverResponse(process.id",
                'executor = "SAO.Command"')),
        "authority is matter-scoped":
            'Org.authorityFor(giverKey, group, "command:" .. kind)' in command_source
            and "jurisdictionCovers(office, kind)" in command_source,
        "aggregate obedience scoring is retired": all(
            anchor not in command_source for anchor in (
                "Cmd.WEIGHT", "Cmd.COMPLIES_AT", "Cmd.standingOf",
                "Cmd.leansAway")),
        "survivor orders use the same response owner":
            "SAO.Command.order(giverId, id, kind, arg)" in controller
            and controller.count("onTheirWord(") >= 4
            and "local heeds = not desperate" not in controller,
        "player asks use the same response owner":
            "SAO.Command.order(key, id, kind, arg)" in harness,
        "the gate runs this border": "tools/command_test.py" in
            CHECK.read_text(encoding="utf-8"),
    }
    return all(checks.values()), [name for name, ok in checks.items() if not ok]


def main() -> int:
    print("=" * 74)
    print("COMMANDS ARE ACQUIRED, ANSWERED, AND SCOPE-BOUND")
    print("=" * 74)
    missing = [path for path in (ORGANIZATION, COMMAND, CONTROLLER, HARNESS,
                                 RUNNER) if not path.is_file()]
    if missing:
        print("  FAULT: missing inputs: " + ", ".join(map(str, missing)))
        return 1
    command_source = COMMAND.read_text(encoding="utf-8-sig")
    organization_source = ORGANIZATION.read_text(encoding="utf-8-sig")
    static_ok, static_faults = static_contract(command_source)
    print("  static contract: " + ("PASS" if static_ok else "FAIL"))
    for fault in static_faults:
        print("  FAULT: " + fault)
    installed = (PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe")
    if not all(path.is_file() for path in installed):
        print("  SKIPPED Kahlua VM: installed game/JDK absent")
        return 0 if static_ok else 1
    built, detail = compile_runner()
    if not built:
        print("  FAULT: LuaRun compile failed: " + detail[-1000:])
        return 1
    value, detail = run_probe(command_source, organization_source)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")
    controls = [
        ("actual reception",
         "SAO.Communication.canConverse(tostring(giverKey), tostring(id)) ~= true",
         "false"),
        ("matter-scoped mandate",
         '#Org.authorityFor(giverKey, group, "command:" .. kind) > 0',
         "#Org.authorityFor(giverKey, group) > 0"),
        ("voluntary relationship",
         "or trust >= 0.30) and \"accept\"",
         "or true) and \"accept\""),
        ("current activity",
         'or (activity ~= "idle" and kind ~= "rouse" and kind ~= "leave")',
         'or (false and kind ~= "rouse" and kind ~= "leave")'),
        ("recipient need",
         'or (kind == "leave" and ownNeed >= 0.75) and "decline"',
         'or (kind == "leave" and false) and "decline"'),
        ("office jurisdiction", "and jurisdictionCovers(office, kind)",
         "and true"),
    ]
    controls_ok = True
    for name, old, new in controls:
        if command_source.count(old) != 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutant = command_source.replace(old, new, 1)
        mutant_value, _ = run_probe(mutant, organization_source)
        if not any(result == "false" for result in verdicts(mutant_value).values()):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (six production controls)")
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + detail[-1800:].replace("\n", " "))
        return 1
    print("  111) actual recipient responses, exact authority scope, private "
          "activity/capability and voluntary agreement execute in Kahlua")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
