#!/usr/bin/env python3
"""Actual ordinary worn-garment upkeep, signed material acquisition and retained native protection use."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys
S=Path(__file__).resolve().parent.parent;H=S/"tools/garment_consumer_checks"
G=Path(os.environ.get("PZ_DIR",r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"));J=Path(os.environ.get("JDK_BIN",r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def receipt(out,r):(out/"receipt.json").write_text(json.dumps(r,indent=2,sort_keys=True)+"\n",encoding="utf-8")
CASES={"normal":"cases.lua","cancel":"cancel-cases.lua","upgrade":"cases.lua","layers":"cases.lua","stale-use":"cases.lua","final-contracts":"cases.lua"}
CONTROLS={
 "sourceclass":("SAO_CognitiveModels.lua",'not text(o.nativeClass,160)or o.nativeClass~=w.beforeObservation.nativeClass','not text(o.nativeClass,160)or o.nativeClass~="zombie.inventory.types.Clothing"or o.nativeClass~=w.beforeObservation.nativeClass',"garment_contract_sourceclass_full_feedback"),
 "current-token":("SAO_ProceduralPlanning.lua",'or measured.currentBodyToken~=currentBodyToken or type(measured.currentObservation)~="table"','or type(measured.currentObservation)~="table"',"garment_contract_current_token_refused"),
 "unconfirmed-link":("SAO_ProceduralPlanning.lua",'if row.serviceRelationStatus~="confirmed"or type(row.serviceRelation)~="table"then','if false then',"garment_contract_unconfirmed_not_linked"),
 "restore-benefit":("SAO_ResourceProduction.lua",'benefit=scratch+bite','benefit=math.max(1,scratch+bite)',"garment_contract_zero_actual_native_forecast"),
 "retry-authority":("SAO_ProceduralPlanning.lua",'  local prior=type(previous)=="string"and SAO.ResourceProduction.outcome(id,previous)\n  local consumed=false\n  for _,receipt in ipairs(p.resultReceipts or{})do\n   if receipt=="SAO.ResourceProduction:"..tostring(previous)then consumed=true;break end\n  end\n  if not consumed or type(prior)~="table"or prior.id~=previous or prior.actorId~=id\n   or prior.purposeId~=p.id or prior.kind~="maintain-garment"or prior.status~="completed"\n   or prior.nativeCredit~=prior.id or prior.itemId~=known.itemId or prior.part~=known.part\n   or not finite(prior.sequence)or prior.sequence<1 or prior.sequence%1~=0 then return nil end\n  frame=frame..":after:"..tostring(prior.sequence)','  local prefix="resource-production/"..id.."/";local consumed=false\n  for _,receipt in ipairs(p.resultReceipts or{})do\n   if receipt=="SAO.ResourceProduction:"..previous then consumed=true;break end\n  end\n  local sequence=previous:sub(1,#prefix)==prefix and previous:sub(#prefix+1)\n  if consumed and sequence and sequence:match("^%d+$")and finite(tonumber(sequence))\n   and tonumber(sequence)>0 then frame=frame..":after:"..sequence end',"garment_stale_corrupt_history_refused"),
 "stale-link":("SAO_ProceduralPlanning.lua",'g.physicalResultId=nil;g.wornUseReceipt=nil;g.wornBenefitMeasured=nil\n p.status="maintained";p.awaitingReassessment=true;p.blockers={"garment-native-use-binding-changed"}', 'g.physicalResultId=g.physicalResultId;g.wornUseReceipt=nil;g.wornBenefitMeasured=nil\n p.status="maintained";p.awaitingReassessment=true;p.blockers={"garment-native-use-binding-changed"}',"garment_stale_same_original_replan"),
 "utility-domain":("SAO_ProceduralPlanning.lua","utility=clamp(option.benefit,0,16)","utility=option.benefit","garment_highskill_default_choice_valid"),
 "removal-replan":("SAO_ProceduralPlanning.lua",'if row.operation=="remove-patch"then','if false then',"garment_upgrade_preparatory_no_use_credit"),
 "aggregate-benefit":("SAO_ResourceProduction.lua",'current.targetScratchDefense>before.targetScratchDefense or current.targetBiteDefense>before.targetBiteDefense','current.wornScratchDefense>before.wornScratchDefense or current.wornBiteDefense>before.wornBiteDefense',"garment_layer_target_survives_lower_aggregate"),
 "inspection-phase":("SAO_Controller.lua","retained and not retained.awaitingReassessment and step and","retained and step and","garment_actual_three_role_acquisitions"),
 "use-phase":("SAO_ProceduralPlanning.lua",'and matches then use.status="available"end','and matches then -- omitted exact original USE promotion\n end',"garment_normal_original_worn_use_closure"),
 "garment-transfer":("SAO_Perception.lua",'local garment=receipt.category=="garment-input"','local garment=false',"garment_actual_three_role_acquisitions")}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("--required",action="store_true",help="Fail when installed native inputs are unavailable.");p.add_argument("--out",type=Path,required=True);p.add_argument("--reuse-classes",type=Path);p.add_argument("--case",choices=sorted(CASES),default="normal");p.add_argument("--control",choices=sorted(CONTROLS));a=p.parse_args();
 if a.control and a.case!=({"removal-replan":"upgrade","aggregate-benefit":"layers","utility-domain":"layers","stale-link":"stale-use","retry-authority":"stale-use","sourceclass":"final-contracts","current-token":"final-contracts","unconfirmed-link":"final-contracts","restore-benefit":"final-contracts"}.get(a.control,"normal")):p.error("--control is not valid for selected --case")
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);classes=out/"classes";classes.mkdir()
 java=[H/n for n in ["NormalGarmentConsumerProbe.java","GarmentOwnerNativeProbe.java","GarmentConsumerNativeProbe.java"]]+[S/n for n in ["tools/luacheck/ResourceApproachProbe.java","tools/luacheck/MovementCrossingProbe.java","java/src/com/sao/engine/SAOWorldSources.java","java/src/com/sao/bridge/SAOBridge.java","java/src/com/sao/engine/SAONativeSnapshot.java"]]
 baseDriver=S/"tools/d3_recipe_consumer_test.py"
 if not baseDriver.is_file():
  receipt(out,{"status":"FAIL","missingOwned":[str(baseDriver)],"executedChecks":0});print("FAIL missing owned source-input declaration");return 1
 scope={"__file__":str(baseDriver),"__name__":"source_inputs"};exec(compile(baseDriver.read_text(encoding="utf-8-sig"),str(baseDriver),"exec"),scope)
 owned=scope["OWNED"]
 native=scope["NATIVE"]+[G/"media/lua/shared/Definitions/ClothingRecipesDefinitions.lua",G/"media/lua/shared/TimedActions/ISRepairClothing.lua",G/"media/lua/shared/TimedActions/ISRemovePatch.lua"]
 source=[H/"prelude.lua",*native,*owned,H/"initialize-person.lua",H/CASES[a.case]]
 inputs=[Path(__file__),baseDriver,*[H/v for v in CASES.values()],*java,*source,*[G/"media/scripts/generated/items"/n for n in ["clothing.txt","normal.txt","drainable.txt"]],G/"media/scripts/generated/fluids.txt",G/"media/clothing/clothingItems/Shirt_FormalWhite.xml",G/"media/clothing/clothingItems/Jacket_Leather.xml",G/"projectzomboid.jar",G/"ZombieBuddy.jar",G/"stdlib.lua",S/"java/dist/SAOAgent.jar",J/"java.exe",J/"javac.exe"]
 inputs=list(dict.fromkeys([*inputs,Path(sys.executable),H/"prelude.lua",H/"initialize-person.lua"]))
 ownedInputs=list(dict.fromkeys([Path(__file__),baseDriver,*[H/v for v in CASES.values()],H/"prelude.lua",H/"initialize-person.lua",*java,*owned,S/"java/dist/SAOAgent.jar"]))
 nativeInputs=[v for v in inputs if v not in ownedInputs]
 missingOwned=[str(v) for v in ownedInputs if not v.is_file()];missingNative=[str(v) for v in nativeInputs if not v.is_file()]
 if missingOwned or missingNative:
  status="FAIL" if missingOwned else "NATIVE_UNAVAILABLE"
  receipt(out,{"schema":"sao-d322-normal-native-garment-consumer/1","case":a.case,"control":a.control,"status":status,"missingOwned":missingOwned,"missingNative":missingNative,"required":a.required,"executedChecks":0})
  print(status,"native garment inputs absent");return 1 if missingOwned or a.required else 0
 pins={str(x):sha(x)for x in inputs};compilePins={str(x):sha(x)for x in [*java,G/"projectzomboid.jar",G/"ZombieBuddy.jar",S/"java/dist/SAOAgent.jar",J/"javac.exe"]}
 cp=os.pathsep.join(map(str,[S/"java/dist/SAOAgent.jar",G/"projectzomboid.jar",G/"ZombieBuddy.jar"]))
 compileCommand=[str(J/"javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(classes),*map(str,java)];reused=None
 for src in [Path(__file__),*java]:
  if src==Path(__file__) or src.parent==H:(out/("captured-"+src.name)).write_bytes(src.read_bytes())
 if a.reuse_classes:
  previous=a.reuse_classes.resolve();old=json.loads((previous/"receipt.json").read_text());assert old["compilePins"]==compilePins and old["compileExit"]==0
  for name,expected in old["classPins"].items():
   src=previous/"classes"/name;dest=classes/name
   if not src.resolve().is_relative_to((previous/"classes").resolve()) or not dest.resolve().is_relative_to(classes.resolve()):raise ValueError("retained class path leaves compilation root")
   assert sha(src)==expected;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
  reused={"receipt":str(previous/"receipt.json"),"sha256":sha(previous/"receipt.json")};compileExit=0
 else:
  r=subprocess.run(compileCommand,capture_output=True,text=True,timeout=90);(out/"compile.log").write_text(r.stdout+r.stderr,encoding="utf-8");compileExit=r.returncode
  if compileExit:receipt(out,{"status":"FAIL_COMPILE","compileExit":compileExit,"compileCommand":compileCommand,"compilePins":compilePins,"pins":pins});print(r.stderr[-4000:]);return 1
 captured=[]
 for i,src in enumerate(source):
  dest=out/(str(i).zfill(2)+"-"+src.name);content=src.read_text(encoding="utf-8-sig")
  if a.control and src.name==CONTROLS[a.control][0]:
   _,before,after,_=CONTROLS[a.control];assert content.count(before)==1;content=content.replace(before,after)
  dest.write_text('print("GARMENT_LOADING",'+json.dumps(src.name)+')\n'+content,encoding="utf-8");captured.append(dest)
 shutil.copy2(G/"stdlib.lua",out/"stdlib.lua")
 command=[str(J/"java.exe"),"--enable-native-access=ALL-UNNAMED","-Djava.awt.headless=true","-Duser.home="+str(out),"-Djava.library.path="+str(G),"-Dsao.game="+str(G),"-Dsao.garment.case="+a.case,"-Dsao.garment.layer="+("damage"if a.case=="stale-use"else"subclass"if a.case=="final-contracts"else"positive"),"-cp",str(classes)+os.pathsep+cp,"NormalGarmentConsumerProbe",str(G),*map(str,captured)]
 r=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=120);runs=[{"scene":"positive"if a.case=="layers"else"damage"if a.case=="stale-use"else"subclass"if a.case=="final-contracts"else a.case,"command":command,"exitCode":r.returncode}]
 if a.case in("layers","stale-use","final-contracts"):
  for scene in (("highskill","zero")if a.case=="layers"else("replacement","missing","missing-history","foreign-history")if a.case=="stale-use"else("current-token","wrong-token","unconfirmed","zero-benefit")):
   child=out/scene;child.mkdir();shutil.copy2(G/"stdlib.lua",child/"stdlib.lua")
   childCommand=[v if not v.startswith("-Duser.home=")else "-Duser.home="+str(child) for v in command];childCommand=[v if not v.startswith("-Dsao.garment.layer=")else "-Dsao.garment.layer="+scene for v in childCommand]
   cr=subprocess.run(childCommand,cwd=child,capture_output=True,text=True,timeout=120);(child/"run.log").write_text(cr.stdout+cr.stderr,encoding="utf-8")
   runs.append({"scene":scene,"command":childCommand,"exitCode":cr.returncode,"logSha256":sha(child/"run.log")});r.stdout+="\n"+cr.stdout;r.stderr+="\n"+cr.stderr;r.returncode=r.returncode or cr.returncode
 (out/"run.log").write_text(r.stdout+r.stderr,encoding="utf-8")
 checks=dict(re.findall(r"CHECK (garment_[a-z0-9_]+)=(true|false)",r.stdout));expected=set(re.findall(r'check\("([a-z0-9_]+)"',(H/CASES[a.case]).read_text()))
 if a.case!="upgrade":expected={v for v in expected if not v.startswith("garment_upgrade_")}
 if a.case!="layers":expected={v for v in expected if not v.startswith(("garment_layer","garment_highskill"))}
 if a.case!="stale-use":expected={v for v in expected if not v.startswith("garment_stale_")}
 if a.case not in("final-contracts","layers"):expected={v for v in expected if not v.startswith("garment_contract_")}
 if a.case=="layers":expected={v for v in expected if not v.startswith("garment_contract_")or v.startswith("garment_contract_zero_")}
 stable=pins=={str(x):sha(x)for x in inputs};status="PASS"if stable and r.returncode==0 and set(checks)==expected and all(x=="true"for x in checks.values())else"FAIL"
 if a.control:status="DETECTED"if stable and checks.get(CONTROLS[a.control][3])=="false"else"UNDETECTED"
 receipt(out,{"case":a.case,"control":a.control,"required":a.required,"ownedInputs":[str(x)for x in ownedInputs],"nativeInputs":[str(x)for x in nativeInputs],"schema":"sao-d322-normal-native-garment-consumer/1","status":status,"inputStable":stable,"pins":pins,"compileExit":compileExit,"compileCommand":compileCommand,"compilePins":compilePins,"reusedCompilation":reused,"classPins":{str(x.relative_to(classes)):sha(x)for x in classes.rglob("*.class")},"command":command,"runs":runs,"exitCode":r.returncode,"checks":checks,"missing":sorted(expected-set(checks)),"logSha256":sha(out/"run.log"),"capturedFiles":{x.name:sha(x)for x in captured},"projections":{str(x.relative_to(out)):sha(x)for x in out.rglob("*")if x.is_file() and (x.suffix==".json" or x.name=="native-body-snapshot.txt") and x.name!="receipt.json"},"controlledZeroScope":"Layers zero actor inspects one exact current Cotton metadata offer with zero protection benefit and no admission/payment; historical restoration proof is retained separately.","proofScope":"Normal30, queued cancellation15, affected native upgrade and independent layer scenes, case-bound named source omissions. Death/body-transfer/request-revocation retained only at controlled R owner44/use20 scope.","boundary":"Real native person/current Identity/Body/Perception/defaultModels/P/Ctl/SU/Needs/R/feedback; isolated clock/Standing/scene/route/assetready/animation/network endpoints. No source/purpose/selected-option/material/payment/effect/canonical/use/feedback fixture graduation, server/UI/peer/fullD3 completion."})
 print(status,len(checks),"/",len(expected),"exit",r.returncode,"stable",stable);print((r.stdout+r.stderr)[-5500:]if status!="PASS"else"")
 return 0 if status in("PASS","DETECTED")else 1

if __name__=="__main__":sys.exit(main())
