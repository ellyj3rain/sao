#!/usr/bin/env python3
"""Company admission and departure in the shipped Kahlua modules.

People weigh their own contact, appetite, needs and relationships. Group size
and unseen property do not impose a capacity. Fixtures hold personal inputs;
Standing, Population and Isolation execute their actual rules. Mutations restore a cap,
silence each pressure source, or introduce unseen supplies and must fail.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

import company_pull_test as vm

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
STANDING = "shared/SAO_Standing.lua"
ISOLATION = "shared/SAO_Isolation.lua"

PROBE = r"""(function()
    local S, Pop = SAO.Standing, SAO.Population
    local actualIsolation = SAO.Isolation
    local out, readings, bodies, needs = {}, {}, {}, {}
    local function check(name, result)
        out[#out + 1] = name .. "=" .. (result and "1" or "0")
    end
    local function near(a, b) return math.abs(a - b) < 0.000001 end
    _G.__hours = 240
    SAO.History.countyHours = function() return _G.__hours end
    SAO.History.clockMonths = function() return 6 end
    SAO.Isolation = { of = function(id) return readings[id] end }
    SAO.Body = { get = function(id) return bodies[id] end }
    SAO.Needs = { read = function(body) return needs[body.id] end }
    -- Hold unrelated creed politics still while the real election runs.
    S.creedOf = function() return nil end
    S.formOf = function() return "commune" end
    local function make()
        local r = SAO.Identity.create(nil, nil, 10500, 9000, 0)
        r.lastWaterDay, r.lastFoodDay = 10, 10
        readings[r.id] = { appetite = 1, experiencedContact = 1, isolation = 0 }
        return r
    end
    local function trust(a, b, value)
        S.adjustTrust(a, b, value - S.trust(a, b))
    end
    local function reading(r, appetite, contact)
        readings[r.id] = { appetite = appetite, experiencedContact = contact,
            isolation = 1 - contact }
        _G.__hours = _G.__hours + 0.001
    end
    local host, mate = make(), make()
    trust(host.id, mate.id, 0.9); trust(mate.id, host.id, 0.9)
    S.formCompany({ host.id, mate.id }, "large")
    local noRefusals = true
    for n = 3, 12 do
        local joiner = make()
        for _, id in ipairs(S.membersOf("large")) do
            trust(joiner.id, id, 0.9); trust(id, joiner.id, 0.9)
        end
        if S.circleRefuses(host.id, "large", joiner.id)
            or S.circleRefuses(joiner.id, "large", host.id) then
            noRefusals = false
        else
            S.joinGroup(joiner.id, "large")
        end
        if n == 4 then check("past_three", S.groupSize("large") == 4) end
        if n == 9 then check("past_eight", S.groupSize("large") == 9) end
    end
    check("twelve_members", noRefusals and S.groupSize("large") == 12)

    local guest = make()
    trust(host.id, guest.id, 0.6); trust(guest.id, host.id, 0.6)
    check("well_host_accepts", not S.circleRefuses(host.id, "large", guest.id))
    -- Day 10, last drink day 7: three days without water against the same
    -- two-day patience the dormant errand reads gives one half of pressure.
    host.lastWaterDay = 7
    check("own_water_pressure", near(Pop.companyNeedPressure(host.id), 0.5))
    host.lastWaterDay = 6
    check("short_host_refuses", S.circleRefuses(host.id, "large", guest.id))
    check("fed_guest_unaffected", not S.circleRefuses(guest.id, "large", host.id))
    host.lastWaterDay = 10
    check("water_restores_answer", not S.circleRefuses(host.id, "large", guest.id))
    host.lastFoodDay = -4
    check("own_food_pressure", near(Pop.companyNeedPressure(host.id), 1))
    check("hungry_host_refuses", S.circleRefuses(host.id, "large", guest.id))
    host.lastFoodDay = 10
    guest.lastWaterDay = 6
    check("hungry_outsider_can_seek", not S.circleRefuses(guest.id, "large", host.id))
    guest.lastWaterDay, guest.lastFoodDay = nil, nil
    check("unknown_need_is_not_hunger", near(Pop.companyNeedPressure(guest.id), 0))

    -- The live path reads only this person's present body, never old dormant
    -- stamps or another member's body.
    bodies[host.id] = { id = host.id }
    needs[host.id] = { thirst = SAO.Disposition.drinkAt(host.id) * 2,
        hunger = 0 }
    check("live_water_pressure", near(Pop.companyNeedPressure(host.id), 1))
    check("live_shortage_refuses", S.circleRefuses(host.id, "large", guest.id))
    needs[host.id] = { thirst = 0, hunger = 0 }
    host.lastWaterDay = 0
    check("live_ignores_dormant_stamp", near(Pop.companyNeedPressure(host.id), 0))
    needs[host.id] = nil
    check("unread_live_need_unknown", near(Pop.companyNeedPressure(host.id), 0))
    bodies[host.id] = nil; host.lastWaterDay = 10

    reading(host, 0.1, 1)
    check("solitude_preference_refuses", S.circleRefuses(host.id, "large", guest.id))
    reading(host, 0.9, 1)
    check("social_preference_accepts", not S.circleRefuses(host.id, "large", guest.id))
    reading(host, 0.1, 0.1)
    check("low_contact_relieves_strain", not S.circleRefuses(host.id, "large", guest.id))
    reading(host, 1, 0)
    trust(host.id, guest.id, 0)
    check("isolation_can_carry_company", S.companyStanding(host.id, guest.id) > 0.5
        and not S.circleRefuses(host.id, "large", guest.id))
    trust(host.id, guest.id, -0.2)
    check("distrust_not_erased_by_need", S.circleRefuses(host.id, "large", guest.id))
    trust(host.id, guest.id, 0.6); reading(host, 1, 1)
    S.setHostile(host.id, guest.id, true)
    check("declared_hostility_refuses", S.circleRefuses(host.id, "large", guest.id))
    S.setHostile(host.id, guest.id, false)

    local store = ModData.getOrCreate("SurvivorAwareness_Standing")
    store.groupClaims = store.groupClaims or {}
    local before = S.circleRefuses(guest.id, "large", host.id)
    store.groupClaims.large = { minX = 0, minY = 0, maxX = 1, maxY = 1 }
    store.groupMeta.large.larder = { word = "lean", atHours = _G.__hours }
    check("unseen_ground_no_verdict", before == S.circleRefuses(guest.id, "large", host.id))
    store.groupClaims.large = { minX = 0, minY = 0, maxX = 10000, maxY = 10000 }
    store.groupMeta.large.larder = { word = "full", atHours = _G.__hours }
    check("unseen_abundance_no_verdict", before == S.circleRefuses(guest.id, "large", host.id))
    -- A forbidden read throws: swallowing it would still be distinguishable
    -- from the direct decision returning without asking it.
    local oldSize, oldLarder, oldClaim = S.groupSize, S.larderOf, S.groupClaimOf
    local function forbidden() error("unseen house truth was consulted") end
    S.groupSize, S.larderOf, S.groupClaimOf = forbidden, forbidden, forbidden
    local ok = pcall(function() S.circleRefuses(guest.id, "large", host.id) end)
    check("admission_no_hidden_reads", ok)
    S.groupSize, S.larderOf, S.groupClaimOf = oldSize, oldLarder, oldClaim
    check("missing_counterpart_safe", pcall(function()
        S.circleRefuses(guest.id, "unknown")
        S.circleRefuses(mate.id, "large")
    end))
    readings[guest.id] = nil
    check("unread_contact_invents_no_strain", near(S.companyPressure(guest.id, "large"), 0))

    -- The same relations and three people no longer feed an automatic
    -- election or score-triggered schism. Private pressure may motivate a
    -- later proposal; it cannot move the roster by itself.
    local leader, ally, dissenter = make(), make(), make()
    for _, r in ipairs({leader, ally, dissenter}) do store.groups[r.id] = "departure" end
    trust(ally.id, leader.id, 1); trust(dissenter.id, leader.id, -0.1)
    trust(leader.id, ally.id, 0.3); trust(dissenter.id, ally.id, 0.2)
    trust(leader.id, dissenter.id, 0.2); trust(ally.id, dissenter.id, 0.2)
    local elected = S.electLeader("departure")
    check("no_automatic_leader", elected == nil
        and S.leaderOf("departure") == nil)
    dissenter.lastWaterDay = 6
    local split = S.checkSchism("departure")
    check("automatic_schism_cannot_eject", split == nil
        and S.groupSize("departure") == 3
        and S.groupOf(dissenter.id) == "departure")
    S.leaveGroup(dissenter.id)
    check("explicit_departure_clears_work", S.groupOf(dissenter.id) == nil)
    check("departure_clears_work", dissenter.designation == nil and dissenter.designatedBy == nil)
    check("remaining_pair_stays", S.groupSize("departure") == 2)
    S.leaveGroup(ally.id)
    check("widow_released", S.groupOf(leader.id) == nil)

    -- Composition check: the real Isolation module measures encounter memory
    -- separately from roster affiliation. A distant ledger fact must not be
    -- converted into firsthand company strain by Standing.
    SAO.Isolation = actualIsolation
    local quiet, familiar, distant, visitor = make(), make(), make(), make()
    SAO.History.contactFactor = function() return 0.1 end
    for _, r in ipairs({quiet, familiar, distant}) do store.groups[r.id] = "remote" end
    trust(quiet.id, familiar.id, 0.9); trust(quiet.id, distant.id, 0.9)
    trust(quiet.id, visitor.id, 0.6)
    local P = SAO.Perception
    P.beliefs[quiet.id] = { people = {} }
    local people = P.beliefs[quiet.id].people
    check("roster_and_old_trust_are_not_contact",
        actualIsolation.of(quiet.id).contact == 1
        and near(S.companyPressure(quiet.id, "remote"), 0)
        and not S.circleRefuses(quiet.id, "remote", visitor.id))
    people.old = { id = familiar.id, source = "observed", atHours = _G.__hours - 25 }
    check("stale_observation_is_not_contact", near(S.companyPressure(quiet.id, "remote"), 0))
    people.report = { id = distant.id, source = "told", atHours = _G.__hours }
    people.unknown = { id = visitor.id, source = "unknown", atHours = _G.__hours }
    people.future = { id = visitor.id, source = "observed", atHours = _G.__hours + 1 }
    people.unstamped = { id = visitor.id, source = "heard" }
    people.self = { id = quiet.id, source = "observed", atHours = _G.__hours }
    check("reports_are_not_experienced_contact", near(S.companyPressure(quiet.id, "remote"), 0))
    P.sawPerson(quiet.id, "familiar", 10500, 9000, _G.__hours * 9000, familiar.id, 1)
    check("observed_contact_reaches_pressure", near(S.companyPressure(quiet.id, "remote"), 0.3))
    -- Heard encounter memory uses the same timestamp form as the cry-for-help
    -- producer; it need not have an atHours stamp or a registry identity.
    people.voice = { source = "heard", at = _G.__hours * 9000 }
    check("heard_unknown_person_reaches_pressure", near(S.companyPressure(quiet.id, "remote"), 0.6))
    P.sawPerson(quiet.id, "distant", 10500, 9000, _G.__hours * 9000, distant.id, 1)
    local experienced = S.companyPressure(quiet.id, "remote")
    check("experienced_company_can_refuse", near(experienced, 0.9)
        and S.circleRefuses(quiet.id, "remote", visitor.id))
    distant.dead = true
    check("unseen_death_does_not_change_pressure",
        near(S.companyPressure(quiet.id, "remote"), experienced)
        and S.circleRefuses(quiet.id, "remote", visitor.id))
    people.distant.dead = true
    check("known_death_changes_contact", near(S.companyPressure(quiet.id, "remote"), 0.6))
    people.familiar.dead, people.voice.dead = true, true
    check("known_absence_relieves_strain", near(S.companyPressure(quiet.id, "remote"), 0)
        and not S.circleRefuses(quiet.id, "remote", visitor.id))
    return table.concat(out, " ")
end)()"""


def run(source, isolation_source=None):
    with tempfile.TemporaryDirectory(prefix="sao-company-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(vm.STDLIB, work / "stdlib.lua")
        for compiled in vm.OUT.glob("*.class"):
            shutil.copy2(compiled, work / compiled.name)
        standing = work / "standing.lua"
        standing.write_text(source, encoding="utf-8")
        paths = [str(standing if module == STANDING else LUA / module) for module in vm.MODULES]
        isolation = work / "isolation.lua"
        isolation.write_text(isolation_source if isolation_source is not None
                             else (LUA / ISOLATION).read_text(encoding="utf-8"), encoding="utf-8")
        paths.append(str(isolation))
        result = subprocess.run(
            [str(vm.JDK / "java.exe"), "-cp", f"{vm.PZ};.", "LuaRun",
             str(ROOT / "tools/sweep/prelude.lua"), *paths, "--", PROBE],
            cwd=work, capture_output=True, text=True, timeout=120)
        lines = [line[6:] for line in result.stdout.splitlines() if line.startswith("VALUE ")]
        if not lines:
            return {}, (result.stdout + result.stderr)[-1800:]
        values = dict(piece.split("=", 1) for piece in lines[-1].split())
        return values, ""


def main():
    if not (vm.JDK.exists() and vm.PZ.exists() and vm.STDLIB.exists()):
        print("SKIPPED company admission: installed engine/JDK absent")
        return 0
    if not vm.build():
        print("FAIL company admission: VM runner failed to compile")
        return 1
    source = (LUA / STANDING).read_text(encoding="utf-8")
    got, error = run(source)
    if error or not got or any(value != "1" for value in got.values()):
        print("FAIL company admission:", error or {key: val for key, val in got.items() if val != "1"})
        return 1
    print(f"  161) PASS company admission: {len(got)} behavioral checks in the engine VM")
    mutations = {
        "eight-person cap": (
            "function S.circleRefuses(id, groupName, otherKey)",
            "function S.circleRefuses(id, groupName, otherKey)\n    if S.groupSize(groupName) >= 8 then return true end", "past_eight"),
        "shortage disconnected": (
            "pressure = pressure + math.max(0, math.min(1, need))", "pressure = pressure + 0", "short_host_refuses"),
        "personal preference disconnected": (
            "pressure = (1 - math.max(0, math.min(1, reading.appetite)))", "pressure = 0", "solitude_preference_refuses"),
        "unseen ground decides": (
            "function S.circleRefuses(id, groupName, otherKey)",
            "function S.circleRefuses(id, groupName, otherKey)\n    if S.groupClaimOf(groupName) then return true end", "unseen_ground_no_verdict"),
        "automatic election restored": (
            "return nil, S.leaderOf(groupName), \"explicit-process-required\"",
            "local members = S.membersOf(groupName); return members[1], S.leaderOf(groupName), \"automatic\"",
            "no_automatic_leader"),
        "automatic schism restored": (
            "return nil, nil, 0, \"explicit-process-required\"",
            "local members = S.membersOf(_groupName); if members[1] then S.leaveGroup(members[1]) end; return \"automatic\", members[1], 1",
            "automatic_schism_cannot_eject"),
        "declared hostility ignored": (
            "if otherKey and S.isHostileTo(id, otherKey) then return true end", "-- ignored hostile state", "declared_hostility_refuses"),
        "affiliation treated as experience": (
            "* math.max(0, math.min(1, reading.experiencedContact))",
            "* math.max(0, math.min(1, reading.contact or reading.experiencedContact))",
            "roster_and_old_trust_are_not_contact"),
    }
    for name, (old, new, expected_failure) in mutations.items():
        if source.count(old) != 1:
            print(f"FAIL control {name}: mutation anchor count {source.count(old)}")
            return 1
        changed = source.replace(old, new, 1)
        assert changed != source
        measured, error = run(changed)
        if error or measured.get(expected_failure) != "0":
            print(f"FAIL control {name}: expected behavioral failure {expected_failure}; {error or measured}")
            return 1
        print(f"PASS control {name}: {expected_failure} changed")
    isolation = (LUA / ISOLATION).read_text(encoding="utf-8")
    for name, old, new, expected_failure in [
        ("unseen death changes experience", "if otherId ~= id and not pb.dead",
         "if otherId ~= id and not pb.dead and not (otherId and SAO.Identity.get(otherId) and SAO.Identity.get(otherId).dead)",
         "unseen_death_does_not_change_pressure"),
        ("reports count as encounter", '(pb.source == "observed" or pb.source == "heard")',
         '(pb.source == "observed" or pb.source == "heard" or pb.source == "told")',
         "reports_are_not_experienced_contact"),
    ]:
        if isolation.count(old) != 1:
            print(f"FAIL control {name}: mutation anchor count {isolation.count(old)}")
            return 1
        measured, error = run(source, isolation.replace(old, new, 1))
        if error or measured.get(expected_failure) != "0":
            print(f"FAIL control {name}: expected behavioral failure {expected_failure}; {error or measured}")
            return 1
        print(f"PASS control {name}: {expected_failure} changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
