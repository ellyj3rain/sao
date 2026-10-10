#!/usr/bin/env python3
"""Installed firearm fixing -> exact private planning/acquisition -> native reuse.
Real Java definitions/factories/payment/effects and Kahlua saves; controlled body,
map, dispatch and SourceUse canonical ports. No attached game or shipped JAR edit.
"""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get("PZ_DIR",r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK=Path(os.environ.get("JDK_BIN",r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
LUA=ROOT/"mod/42.20/media/lua"
LEAVES={name:LUA/path for name,path in {
"production.lua":"client/SAO_ResourceProduction.lua","planner.lua":"shared/SAO_ProceduralPlanning.lua",
"cognition.lua":"shared/SAO_Cognition.lua","models.lua":"shared/SAO_CognitiveModels.lua",
"experience.lua":"client/SAO_CapabilityExperience.lua"}.items()}
CONTROLLER=LUA/"client/SAO_Controller.lua"
WORLD=LUA/"shared/SAO_WorldSources.lua"
SOURCEUSE=LUA/"client/SAO_SourceUse.lua"
BASE=ROOT/"tools/luacheck/window_repair_cases.lua"
BOARD=ROOT/"tools/luacheck/d3_native_boarding_cases.lua"
CASES=ROOT/"tools/luacheck/d3_native_item_fixing_cases.lua"
CTL_CASES=ROOT/"tools/luacheck/d3_item_fixing_controller_cases.lua"
SOURCE_CASES=ROOT/"tools/luacheck/d3_item_fixing_source_cases.lua"
PROBE=ROOT/"tools/luacheck/NativeItemFixingProbe.java"
SYNTAX=ROOT/"tools/luacheck/LuaSyntax.java"
NATIVE=[GAME/"media/lua"/p for p in [
"shared/ISBaseObject.lua","shared/TimedActions/ISBaseTimedAction.lua",
"client/TimedActions/ISTimedActionQueue.lua","shared/TimedActions/ISEquipWeaponAction.lua",
"client/TimedActions/ISInventoryTransferAction.lua","shared/TimedActions/ISFixAction.lua","shared/TimedActions/ISTakeWaterAction.lua"]]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd,cwd,log):
    completed=subprocess.run([str(x) for x in cmd],cwd=cwd,capture_output=True,text=True,timeout=120)
    log.write_text(completed.stdout+completed.stderr,encoding="utf-8")
    return completed
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out",type=Path);parser.add_argument("--required",action="store_true")
    parser.add_argument("--controls",choices=["all","none"],default="all")
    parser.add_argument("--case",choices=["equipment-reuse"],help="execute only the bounded native equipment correction cases/control")
    args=parser.parse_args()
    owned=[Path(__file__),*LEAVES.values(),CONTROLLER,WORLD,SOURCEUSE,BASE,BOARD,CASES,CTL_CASES,SOURCE_CASES,PROBE,SYNTAX]
    missing=[str(p) for p in owned if not p.is_file()]
    if missing:print("FAIL missing owned inputs: "+", ".join(missing));return 1
    native=[*NATIVE,GAME/"projectzomboid.jar",GAME/"stdlib.lua",GAME/"media/scripts/generated/fixing.txt",
        *[GAME/"media/scripts/generated/items"/(n+".txt") for n in ["normal","weapon","weaponpart"]],
        *[JDK/n for n in ["java.exe","javac.exe","jar.exe"]]]
    missing=[str(p) for p in native if not p.is_file()]
    if missing:print(("FAIL" if args.required else "UNCHECKED")+" installed item-fixing inputs absent: "+", ".join(missing));return int(args.required)
    temp=tempfile.TemporaryDirectory(prefix="sao-native-item-fixing-") if args.out is None else None
    out=(Path(temp.name)/"proof" if temp else args.out.resolve())
    if out.exists():raise ValueError("refuse replacing retained proof")
    out.mkdir(parents=True)
    inputs=owned+native;before={str(p):sha(p) for p in inputs}
    classes=out/"classes";classes.mkdir()
    compile_result=run([JDK/"javac.exe","-cp",GAME/"projectzomboid.jar","-d",classes,PROBE,SYNTAX],out,out/"compile.log")
    if compile_result.returncode:print(compile_result.stdout+compile_result.stderr);return 1
    test_jar=out/"native-item-fixing-probe.jar"
    jar_result=run([JDK/"jar.exe","--create","--file",test_jar,"-C",classes,"."],out,out/"jar.log")
    cp=str(GAME/"projectzomboid.jar")+os.pathsep+str(test_jar)
    syntax=run([JDK/"java.exe","-cp",cp,"LuaSyntax",*LEAVES.values(),CONTROLLER,WORLD,SOURCEUSE,CASES,CTL_CASES,SOURCE_CASES],out,out/"syntax.log")
    source={name:p.read_text(encoding="utf-8-sig") for name,p in LEAVES.items()}
    source={"base.lua":BASE.read_text(encoding="utf-8-sig").split("function __runWindowCases()",1)[0],
        "boarding-fixture.lua":BOARD.read_text(encoding="utf-8-sig")+"\n__boardingFixture=fixture;__boardingItem=item;__boardingInventory=inventory\n",
        **{f"native-{i}.lua":p.read_text(encoding="utf-8-sig") for i,p in enumerate(NATIVE)},
        "cases.lua":CASES.read_text(encoding="utf-8-sig"),**source,
        "controller-cases.lua":CTL_CASES.read_text(encoding="utf-8-sig"),"source-cases.lua":SOURCE_CASES.read_text(encoding="utf-8-sig")}
    ctl=CONTROLLER.read_text(encoding="utf-8-sig")
    section=ctl.split("function Ctl.toolMaintenanceContext(",1)[1].split("local function rememberConstructionDestination",1)[0]
    source["controller.lua"]="local Ctl=SAO.Controller\nlocal function setState(agent,id,state) agent.state=state;return true end\nfunction Ctl.toolMaintenanceContext("+section
    resource=ctl.split("function Ctl.resourceContext(",1)[1].split("-- This read-only preflight",1)[0]
    source["controller-resource.lua"]="local Ctl=SAO.Controller;local tickCount=100\nfunction Ctl.resourceContext("+resource+"\n__actualFixingResourceContext=Ctl.resourceContext\n"
    world=WORLD.read_text(encoding="utf-8-sig")
    options=world.split("function WS.actionOptions(",1)[1].split("function WS.privatelyKnowsItem",1)[0]
    knows=world.split("function WS.privatelyKnowsItem(",1)[1].split("-- A complete private inspection",1)[0]
    begin=world.split("local function sameActionOption(",1)[1].split("function WS.beginTransfer",1)[0]
    source["world-options.lua"]="""local WS={}
local MAX_ACTION_OPTIONS=16;local SOURCE_CATEGORIES={weapons=true,food=true,water=true}
local function store() return __privateFixingStore end
local function nowHours() return SAO.History.countyHours() end
local function sourceBelongsToPlace(source,place) return source.placeId==tostring(place.id) end
local function pendingFor() return false end
local function beliefHasRevision(belief,id,revision) return belief.revisions[id]==revision end
local function reservationRoom() return true end
local function itemSignature(item) return tostring(item.id)..':'..item.type end
function WS.actionOptions("""+options+"\nfunction WS.privatelyKnowsItem("+knows+"\nlocal function sameActionOption("+begin+"\n__actualFixingWS=WS\n"
    su=SOURCEUSE.read_text(encoding="utf-8-sig")
    begin=su.split("function SU.chooseOption(",1)[1].split("-- The controller calls this when Locomotion",1)[0]
    source["sourceuse.lua"]="""local SU={nativeUseOwners={}}
local function productionActive(id) local rec=SAO.Identity.get(id);return rec and rec.resourceProductionWork~=nil end
local function orderApproach() return true end
local function log() end
function SU.chooseOption("""+begin+"\n__actualFixingSU=SU\n"
    chief=ctl.split("        local maintenanceContext\n",1)[1].split('        elseif chosen and chosen.kind == "acquire" then',1)[0]
    source["ordinary-choice.lua"]="local Ctl=SAO.Controller\nfunction __ordinaryNativeItemFixingChoice(id,agent,body,tick) local idleRec=agent.rec;local planning=SAO.ProceduralPlanning;local candidates,offered={},{};local maintenanceContext\n"+chief+"\nend\nreturn false end\n"
    source["run.lua"]="__runItemFixingEquipmentCorrection()" if args.case else "__runItemFixingCases();__runItemFixingEquipmentCorrection()"
    order=["base.lua","boarding-fixture.lua",*[f"native-{i}.lua" for i in range(len(NATIVE))],
        "cases.lua","models.lua","cognition.lua","planner.lua","production.lua","experience.lua","controller.lua","controller-resource.lua","ordinary-choice.lua","world-options.lua","sourceuse.lua","controller-cases.lua","source-cases.lua","run.lua"]
    def execute(name,sources):
        directory=out/name;directory.mkdir();shutil.copy2(GAME/"stdlib.lua",directory/"stdlib.lua")
        for key,value in sources.items():(directory/key).write_text(value,encoding="utf-8")
        done=run([JDK/"java.exe","--enable-native-access=ALL-UNNAMED",f"-Duser.home={directory}",
            "-cp",cp,"NativeItemFixingProbe",GAME,*[directory/key for key in order]],directory,directory/"output.log")
        text=done.stdout+done.stderr
        checks=dict(re.findall(r"^([a-z0-9_]+)=(true|false)$",text,re.M))
        return {"definitionCount":int(re.search(r"native_registered_definition_count=(\d+)",text).group(1)),"fixerCount":int(re.search(r"native_registered_fixer_count=(\d+)",text).group(1)),"exitCode":done.returncode,"checks":checks,"failed":sorted(k for k,v in checks.items() if v!="true"),"logSha256":sha(directory/"output.log")}
    normal=execute("normal",source)
    controls=[]
    mutations=[
        ("native-end","production.lua","return ok and ended==true","return true","native_early_perform_refuses"),
        ("raw-payment","production.lua","or fixing.rawDonor(rt)~=rt.tool","or false","raw_stale_shadow_complete_refuses"),
        ("native-skill","production.lua","body:getPerkLevel(Perks.FromString(skill:getSkillName()))<skill:getSkillLevel()","false","native_skill_gate_refuses"),
        ("equipment-credit","production.lua","or not row.reequipped","or false","forged_equipment_completion_denied"),
        ("generic-fact","cognition.lua",'or supplied.kind=="tool-repair"','or false',"generic_private_fixing_fact_denied"),
        ("model-damage","models.lua",'or text(e.sourceId,160) and e.sourceId:sub(1,7)=="fixing:"','or false',"native_damage_changes_both_private_predictions"),
        ("controller-dispatch","controller.lua",'and step.productionKind ~= "fix-held-item"','and true',"controller_ordinary_maintenance_dispatches_native_fixing"),
        ("private-donor","planner.lua","source.itemType==option.requiredItemType","true","controller_only_exact_privately_known_donor_acquired"),
        ("source-cap","world-options.lua","expectedItemType==nil or item.type==expectedItemType","true","exact_private_donor_filter_precedes_source_cap"),
        ("reservation-filter","world-options.lua",'operation=="acquire" and selected and selected.parameters','false and selected and selected.parameters',"exact_donor_reservation_reenumeration_keeps_filter"),
        ("sourceuse-filter","sourceuse.lua",'operation=="acquire" and context.itemType or nil','nil',"sourceuse_exact_type_reaches_private_native_admission"),
        ("queue-registry","production.lua","and ISTimedActionQueue.getTimedActionQueue(c.rt.body)==c.rt.queue","and true","whole_replacement_queue_preserves_successor_and_cosmetics"),
        ("target-reuse","production.lua","if rt.nativeCompleted and (rt.target:getCondition()~=rt.afterCondition","if false and (rt.target:getCondition()~=rt.afterCondition","changed_native_target_before_reuse_refuses"),
        ("planner-authority","planner.lua",'step.token == "resource:repaired" and authority ~= REPAIR_RESULT',"false","generic_pending_result_has_no_fixing_completion")]
    correction_mutations=[("already-equipped-native-result","production.lua",
            "(result==true or c.alreadyEquipped and result==false)","result==true",
            "already_held_handgun_native_completion_and_feedback"),
            ("ordinary-donor-selection","production.lua",
                "local donor=items:get(donorIndex)",
                "local nativeRequired=def:getRequiredItems(body,fixer,target);local donor=nativeRequired and nativeRequired:get(0) or target",
                "ordinary_reserved_donor_yields_exact_usable_later_donor")]
    mutations=correction_mutations if args.case else mutations+correction_mutations
    if args.controls=="all":
        for name,file,old,new,target in mutations:
            text=source[file];occurrences=text.count(old)
            if occurrences==0:raise ValueError("missing mutation "+name)
            changed=dict(source);changed[file]=text.replace(old,new)
            changed["run.lua"]="__runItemFixingEquipmentCorrection()" if args.case or name in {m[0] for m in correction_mutations} else "__runItemFixingControl("+json.dumps(name)+")"
            verdict=execute("control-"+name,changed)
            detected=verdict["exitCode"]==0 and verdict["checks"].get(target)=="false"
            controls.append({"name":name,"mutatedOccurrences":occurrences,"target":target,"detected":detected,**verdict})
    after={str(p):sha(p) for p in inputs}
    expected=set(re.findall(r"check\('([a-z0-9_]+)'",source["cases.lua"].split("function __runItemFixingControl",1)[0]+source["controller-cases.lua"]+source["source-cases.lua"]))
    expected.discard("raw_stale_shadow_")
    expected.discard("native_")
    expected|={"native_death_owner_change_refuses","native_body_owner_change_refuses","native_token_owner_change_refuses","native_transfer_owner_change_refuses"}
    expected|={"raw_stale_shadow_perform_refuses","raw_stale_shadow_complete_refuses"}
    correction_expected={"already_held_handgun_native_completion_and_feedback","already_held_two_hand_gun_native_completion_and_feedback",
        "already_held_duplicate_callback_is_inert_pistol","already_held_duplicate_callback_is_inert_shotgun",
        "already_held_lost_hand_uses_native_equipment_effect",
        "ordinary_reserved_donor_yields_exact_usable_later_donor","controller_reserved_first_donor_projects_carried_usable_means",
        "selected_usable_later_donor_prepares_native_raw_payment","native_later_donor_payment_preserves_reserved_item"}
    expected=correction_expected if args.case else expected|correction_expected
    missing=sorted(expected-normal["checks"].keys())
    status="PASS" if not jar_result.returncode and not syntax.returncode and not normal["exitCode"] and not normal["failed"] and not missing and all(x["detected"] for x in controls) and before==after else "FAIL"
    receipt={"schema":"sao-native-item-fixing-v1","status":status,"sourcePreserved":before==after,"inputsBefore":before,"inputsAfter":after,
        "selectedCase":args.case,"normal":normal,"missing":missing,"controls":controls,"syntaxExit":syntax.returncode,"compileExit":compile_result.returncode,"testJarSha256":sha(test_jar),
        "boundary":"Installed definitions/factories/FixingManager and Kahlua save/load; installed Lua action/queue/transfer/equip; actual planning/cognition/controller connectors. Controlled actor/map/dispatch/SourceUse publisher and equipment receivers; no loaded game or shipped JAR edit."}
    (out/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(f"{status} native item fixing {len(normal['checks'])} cases /{len(controls)} controls; receipt={out/'receipt.json'}")
    if status!="PASS":print(json.dumps({"selectedCase":args.case,"normal":normal,"missing":missing,"controlsFailed":[x["name"] for x in controls if not x["detected"]],"syntaxExit":syntax.returncode}))
    return int(status!="PASS")
if __name__=="__main__":raise SystemExit(main())
