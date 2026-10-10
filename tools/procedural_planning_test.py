#!/usr/bin/env python3
"""Border 211: durable private purposes compile to receipt-bound native work."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
PLANNER = LUA / "shared/SAO_ProceduralPlanning.lua"
D3_CASES = ROOT / "tools/d3_material_planning_cases.lua"
MODELS = LUA / "shared/SAO_CognitiveModels.lua"
COGNITION = LUA / "shared/SAO_Cognition.lua"
COORDINATION = LUA / "shared/SAO_Coordination.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
POPULATION = LUA / "client/SAO_Population.lua"
OBSERVATION = LUA / "client/SAO_Observation.lua"
GESTURE = LUA / "client/SAO_Gesture.lua"
CHECK = ROOT / "tools/check.sh"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
_G.__hours = 100
_G.__records = {
  a={id='a',dead=false,occupation='carpenter',designation='cook'},
  b={id='b',dead=false,occupation='student',designation='scout'},
}
SAO = {
  History={countyHours=function() return __hours end,
    literacyOf=function(id) return id=='b' and 'slow' or 'reads' end},
  Identity={get=function(id) return __records[id] end,
    all=function() return __records end},
  Census={JOB_PERK={cook='Cooking',scout='Lightfooted'},
    bookSkillFor=function(p) return p end,
    skillOf=function(id,perk)
      if id=='a' and perk=='Cooking' then return 4 end
      if id=='a' and perk=='Woodwork' then return 6 end
      if id=='b' and perk=='Lightfooted' then return 2 end
      return 0
    end},
}
Events=setmetatable({}, {__index=function(t,key)
  local slot={Add=function() end,Remove=function() end}; rawset(t,key,slot)
  return slot end})
'''

PROBE = r'''(function()
  local checks={}
  local function check(name,value)
    checks[#checks+1]=name..'='..tostring(value==true)
  end
  local P=SAO.ProceduralPlanning
  P.rememberSpatial('a',{key='home',kind='held-ground',x=5,y=5,
    observedAtHours=0,confidence=1,familiarity=1,routeKnown=true,owned=true})
  P.rememberSpatial('a',{key='alley',kind='cover',x=15,y=10,
    observedAtHours=0,confidence=1,familiarity=0,cover=.8,
    blocksThreatLOS=true,routeKnown=true})
  P.rememberSpatial('b',{key='school',kind='familiar-place',x=30,y=30,
    observedAtHours=90,confidence=1,familiarity=.8,routeKnown=true})
  local ak=P.spatialKnowledge('a',100)
  local bk=P.spatialKnowledge('b',100)
  check('spatial_knowledge_is_person_private',#ak==2 and #bk==1
    and bk[1].key=='school')
  check('familiar_ground_decays_more_slowly',ak[1].confidence>ak[2].confidence)

  local profile=P.techniqueProfile('a')
  check('technique_profile_uses_numeric_game_skills',
    profile.skills.Cooking==4 and profile.skills.Woodwork==6
    and type(profile.skills.Aiming)=='number')

  local views=SAO.Cognition.interpretPlans('a',{
    {id='proven',evidence=1,continuity=1,novelty=0,informationGain=0,blockers=0},
    {id='probe',evidence=.4,continuity=.1,novelty=1,informationGain=1,blockers=0},
  },{domain='learning',pressure=0})
  check('existing_models_independently_disagree_on_shared_candidates',
    views.models[1].selected=='proven' and views.models[2].selected=='probe'
    and views.disagreement==true)

  local study,step=P.planStudy('a','cook',{literacy='reads',readingTime=1,
    fatigue=.5,atHours=100})
  check('study_is_a_maintained_multistep_purpose',study.status=='maintained'
    and step.id=='locate-book' and study.steps[2].effort==1.5
    and study.steps[3].verb=='practice')
  P.noteAdmission('a',study.id,'SAONeeds','queued-1')
  check('queue_admission_does_not_teach_or_advance',study.cursor==1
    and study.steps[1].status=='available')
  local wrong=P.recordResult('a',study.id,{owner='SAONeeds',
    token='reading:progressed',status='completed',atHours=101})
  check('mismatched_result_cannot_advance',wrong==false and study.cursor==1)
  local wrongOwner=P.recordResult('a',study.id,{owner='OtherOwner',
    token='reading:located',status='completed',atHours=101})
  check('wrong_owner_cannot_advance',wrongOwner==false and study.cursor==1)
  local located=P.recordResult('a',study.id,{owner='SAONeeds',
    token='reading:located',status='completed',atHours=101})
  study=P.planStudy('a','cook',{literacy='reads',readingTime=1,
    fatigue=.2,bookOwned=true,atHours=101})
  check('completed_prerequisite_survives_recompilation',located==true
    and study.steps[1].id=='read-session' and study.cursor==1)
  local read=P.recordResult('a',study.id,{owner='SAONeeds',
    token='reading:progressed',status='completed',atHours=102})
  check('exact_read_result_advances_progress',read==true and study.sessions==1
    and study.cursor==2 and P.techniqueProfile('a').practice.Cooking.completed==0
    and P.techniqueProfile('a').practice.Cooking.readingSessions==1)

  local blocked=P.planStudy('b','scout',{literacy='none',atHours=100})
  check('literacy_blocks_reading_without_erasing_purpose',blocked.status=='blocked'
    and blocked.blockers[1]=='cannot-yet-read')

  local fort,fortStep=P.planFortification('a',{insideOwnedGround=true,
    hasKit=true,knownGround=false,atHours=102})
  check('fortification_begins_with_private_ground_inspection',
    fortStep.id=='survey-entrances' and fort.steps[2].status=='blocked')
  P.recordResult('a',fort.id,{owner='SAOBuild',token='ground:surveyed',
    status='completed',atHours=103})
  fort=P.planFortification('a',{insideOwnedGround=true,hasKit=true,
    knownGround=true,entryKey='door:1',atHours=103})
  check('known_owned_entry_opens_native_construction',
    fort.steps[1].id=='board-known-entry' and fort.steps[1].status=='available')

  local leisure,leisureStep=P.planLeisure('a',{activity='play guitar',
    affordance='Base.Guitar',locationKey='porch',atLocation=true,
    owner='SAO.Gesture',spontaneous=true,atHours=103})
  check('leisure_requires_real_affordance_and_place',leisure.status=='maintained'
    and leisureStep.id=='perform-activity' and leisure.locationKey=='porch')
  local before=P.techniqueProfile('a').practice['play guitar']
  P.noteAdmission('a',leisure.id,'SAO.Gesture','gesture-1')
  local still=P.techniqueProfile('a').practice['play guitar']
  P.recordResult('a',leisure.id,{owner='SAO.Gesture',
    token='leisure:performed',status='completed',atHours=104})
  local after=P.techniqueProfile('a').practice['play guitar']
  check('leisure_reward_follows_performed_event',before==nil and still==nil
    and after.completed==1)

  local fallback=P.chooseFallback('a',{position={x=10,y=10,z=0},
    threat={x=5,y=10,z=0,key='zeds'},atHours=10})
  check('withdrawal_prefers_known_cover_and_route',fallback~=nil
    and fallback.key=='alley' and fallback.blocksThreatLOS==true)

  local saved=__records.a.proceduralPlanning
  SAO.ProceduralPlanning=nil
  check('planning_state_is_data_only_and_persistent',saved.schema==1
    and type(saved.purposes)=='table' and type(saved.spatial)=='table')
  return table.concat(checks,',')
end)()'''

EXPECTED = {
    "d3_usable_saw_can_continue_without_repair",
    "d3_condition_pressure_selects_exact_native_maintenance",
    "d3_immediate_security_pressure_can_precede_maintenance",
    "d3_missing_native_repair_eligibility_keeps_usable_craft",
    "d3_unobserved_file_supplies_no_maintenance_means",
    "d3_maintenance_acquires_exact_private_file",
    "d3_acquired_file_retains_original_construction_purpose",
    "d3_repair_wrong_target_admission_refused",
    "d3_repair_wrong_file_admission_refused",
    "d3_repair_generic_completion_refused",
    "d3_repair_admission_retains_exact_work",
    "d3_repair_wrong_target_result_refused",
    "d3_repair_without_native_credit_refused",
    "d3_repair_unheld_target_refused",
    "d3_repair_without_condition_gain_refused",
    "d3_repair_measured_partial_gain_advances_once",
    "d3_repair_continues_same_plank_and_boarding_purpose",
    "spatial_knowledge_is_person_private",
    "familiar_ground_decays_more_slowly",
    "technique_profile_uses_numeric_game_skills",
    "existing_models_independently_disagree_on_shared_candidates",
    "study_is_a_maintained_multistep_purpose",
    "queue_admission_does_not_teach_or_advance",
    "mismatched_result_cannot_advance",
    "wrong_owner_cannot_advance",
    "completed_prerequisite_survives_recompilation",
    "exact_read_result_advances_progress",
    "literacy_blocks_reading_without_erasing_purpose",
    "fortification_begins_with_private_ground_inspection",
    "known_owned_entry_opens_native_construction",
    "leisure_requires_real_affordance_and_place",
    "leisure_reward_follows_performed_event",
    "withdrawal_prefers_known_cover_and_route",
    "planning_state_is_data_only_and_persistent",
    "d3_missing_pane_has_exact_acquisition",
    "d3_unknown_material_source_refused",
    "d3_return_destination_is_plain_exact_and_detached",
    "d3_forged_acquisition_refused",
    "d3_forged_admitted_acquisition_refused",
    "d3_pending_admission_preserves_exact_step",
    "d3_wrong_source_result_refused",
    "d3_wrong_revision_result_refused",
    "d3_wrong_item_type_result_refused",
    "d3_acquisition_preserves_repair_purpose",
    "d3_resource_authority_cannot_complete_repair",
    "d3_native_window_result_after_acquisition",
    "d3_window_duplicate_acknowledges_without_credit",
    "d3_one_nail_cannot_complete_recipe",
    "d3_second_nail_requires_new_exact_acquisition",
    "d3_two_native_nails_open_boarding",
    "d3_forged_board_completion_refused",
    "d3_board_requires_two_consumed_nails",
    "d3_board_wrong_aperture_refused",
    "d3_board_wrong_actor_refused",
    "d3_exact_native_boarding_advances_once",
    "d3_new_aperture_does_not_inherit_completed_board",
    "d3_interruption_keeps_purpose_and_delays_retry",
    "d3_retry_resumes_same_exact_unfinished_step",
    "d3_unavailable_entry_defers_without_losing_purpose",
    "d3_fresh_observation_revises_same_security_purpose",
    "d3_target_refusal_cannot_displace_native_admission",
    "d3_loose_nails_precede_nearer_box",
    "d3_box_without_unpacking_stays_blocked",
    "d3_available_material_work_precedes_blocked_repair",
    "d3_pending_material_admission_precedes_available_work",
    "d3_reload_preserves_pending_admission",
    "d3_reload_consumes_exact_terminal_once",
    "d3_craft_finished_plank_remains_direct_means",
    "d3_craft_acquires_exact_known_log",
    "d3_craft_acquisition_pins_original_purpose",
    "d3_craft_next_acquires_exact_known_saw",
    "d3_craft_exact_inputs_open_native_recipe",
    "d3_craft_unavailable_recipe_remains_blocked",
    "d3_craft_unknown_material_means_remain_blocked",
    "d3_craft_admission_pins_step_without_output_credit",
    "d3_craft_generic_completion_refused",
    "d3_craft_rejects_recipeid",
    "d3_craft_rejects_actorid",
    "d3_craft_rejects_logitemid",
    "d3_craft_rejects_sawitemid",
    "d3_craft_rejects_nativecredit",
    "d3_craft_rejects_outputcount",
    "d3_craft_rejects_nativeattempted",
    "d3_craft_rejects_logconsumed",
    "d3_craft_rejects_sawretained",
    "d3_craft_rejects_held",
    "d3_craft_duplicate_output_identity_refused",
    "d3_craft_wrong_output_type_refused",
    "d3_craft_measured_native_result_advances_once",
    "d3_craft_returns_to_original_boarding_purpose",
    "d3_craft_failure_retains_purpose_and_retry",
    "d3_craft_retry_preserves_exact_means",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(planner_source: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-procedural-planning-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        files = {
            "prelude.lua": PRELUDE,
            "models.lua": MODELS.read_text(encoding="utf-8-sig"),
            "cognition.lua": COGNITION.read_text(encoding="utf-8-sig"),
            "planner.lua": planner_source,
            "d3-cases.lua": D3_CASES.read_text(encoding="utf-8-sig"),
            "d3-probe.lua": "__d3Result=__runD3MaterialPlanningCases()\n__prepareD3MaterialReload()",
            "planner-reload.lua": planner_source,
            "d3-reload.lua": "__d3Result=__d3Result..','..__finishD3MaterialReload()",
            "probe.lua": "__result = " + PROBE + "\n__result=__result..','..__d3Result",
        }
        for name, source in files.items():
            (work / name).write_text(source, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             *(str(work / name) for name in files), "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract() -> tuple[bool, str]:
    sources = {
        "planner": PLANNER.read_text(encoding="utf-8"),
        "models": MODELS.read_text(encoding="utf-8"),
        "cognition": COGNITION.read_text(encoding="utf-8"),
        "coordination": COORDINATION.read_text(encoding="utf-8"),
        "controller": CONTROLLER.read_text(encoding="utf-8"),
        "population": POPULATION.read_text(encoding="utf-8"),
        "observation": OBSERVATION.read_text(encoding="utf-8"),
        "gesture": GESTURE.read_text(encoding="utf-8"),
        "check": CHECK.read_text(encoding="utf-8"),
    }
    required = (
        ("function P.maintain", "planner"),
        ("function P.rememberSpatial", "planner"),
        ("function P.planStudy", "planner"),
        ("function P.planFortification", "planner"),
        ("function P.planLeisure", "planner"),
        ("function P.chooseFallback", "planner"),
        ("function P.recordResult", "planner"),
        ("function M.interpretPlans", "models"),
        ("function C.interpretPlans", "cognition"),
        ("private-spatial-knowledge", "coordination"),
        ("SAO.ProceduralPlanning.planStudy", "controller"),
        ("SAO.ProceduralPlanning.planFortification", "controller"),
        ("native-claim-survey", "population"),
        ('section("planning"', "observation"),
        ("function SAOGestureAction:perform()", "gesture"),
        ('token = "leisure:performed"', "gesture"),
        ("tools/procedural_planning_test.py", "check"),
    )
    missing = [anchor for anchor, key in required if anchor not in sources[key]]
    return not missing, "all joins present" if not missing else repr(missing)


def main() -> int:
    print("=" * 74)
    print("PRIVATE PURPOSES, SPATIAL PLANS AND RECEIPT-BOUND LEARNING")
    print("=" * 74)
    required = [PLANNER, D3_CASES, MODELS, COGNITION, COORDINATION, CONTROLLER,
                POPULATION, OBSERVATION, GESTURE, CHECK, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    if not all(path.is_file() for path in (PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe")):
        print("Border 211 SKIPPED: installed game VM or JDK absent")
        return 0
    static_ok, detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL") + f" ({detail})")
    built, detail = compile_runner()
    if not built:
        print("  FAULT: runner compile failed " + detail[-1000:])
        return 1
    source = PLANNER.read_text(encoding="utf-8-sig")
    value, detail = run_probe(source)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")
    controls_ok = True
    controls = (
        ("receipt ownership", 'step.owner ~= result.owner', 'false', "wrong_owner_cannot_advance"),
        ("receipt token", 'step.token ~= result.token', 'false', "mismatched_result_cannot_advance"),
        ("private spatial store", 'function P.rememberSpatial(id, fact)\n    local s = state(id, true)',
         'function P.rememberSpatial(id, fact)\n    local s = state("a", true)', "spatial_knowledge_is_person_private"),
        ("exact acquisition revision", 'or step.sourceId ~= authoritative.sourceId or step.sourceRevision ~= authoritative.preRevision',
         'or step.sourceId ~= authoritative.sourceId', "d3_wrong_revision_result_refused"),
        ("material acquisition authority", 'or authority ~= RESOURCE_RESULT) then return false end',
         ') then return false end', "d3_forged_admitted_acquisition_refused"),
        ("native nail consumption", 'result.plankConsumed ~= true or result.nailsConsumed ~= 2',
         'result.plankConsumed ~= true', "d3_board_requires_two_consumed_nails"),
        ("construction target revalidation", 'and (purpose.admission or not waiting)',
         'and true', "d3_unavailable_entry_defers_without_losing_purpose"),
        ("usable loose nail source", 'and (category ~= "nails" or source.itemType == "Base.Nails")',
         'and true', "d3_loose_nails_precede_nearer_box"),
        ("construction purpose priority", 'if not selected or rank < priority then selected, priority = purpose, rank end\n'
         '        end\n    end\n    if selected then',
         'if not selected or rank > priority then selected, priority = purpose, rank end\n'
         '        end\n    end\n    if selected then',
         "d3_available_material_work_precedes_blocked_repair"),
        ("native craft authority", 'or step.token == "resource:crafted" and authority ~= CRAFT_RESULT',
         'or false', "d3_craft_generic_completion_refused"),
        ("native repair authority", 'or step.token == "resource:repaired" and authority ~= REPAIR_RESULT',
         'or false', "d3_repair_generic_completion_refused"),
        ("native repair condition gain", 'or after <= before',
         'or false', "d3_repair_without_condition_gain_refused"),
        ("native craft output custody", 'or canonical.sawRetained ~= true or canonical.held ~= true',
         'or canonical.sawRetained ~= true', "d3_craft_rejects_held"),
        ("native craft output identity", 'or item.itemId == "" or outputs[item.itemId]',
         'or item.itemId == ""', "d3_craft_duplicate_output_identity_refused"),
    )
    for name, old, new, expected_failure in controls:
        if old not in source:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutated = source.replace(old, new, 1)
        if mutated == source:
            print(f"  FAULT: {name} mutation did not land")
            controls_ok = False
            continue
        mutant_value, mutant_detail = run_probe(mutated)
        mutant_found = verdicts(mutant_value)
        if set(mutant_found) != EXPECTED or mutant_found.get(expected_failure) != "false":
            print(f"  FAULT: {name} mutation did not fail {expected_failure}")
            print("  " + mutant_detail[-1000:].replace("\n", " "))
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (ownership, token, private store, acquisition revision and authority, native nails, loose sources, target revalidation, purpose priority)")
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + detail[-3000:].replace("\n", " "))
        return 1
    print(f"  verdicts: PASS ({len(EXPECTED)} planning, material, privacy, persistence and receipt cases)")
    print("  211) purposes persist across recomputation; private spatial evidence")
    print("       and independent model tension guide native receipt-bound work")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
