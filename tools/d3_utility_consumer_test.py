#!/usr/bin/env python3
"""Original native utility work through current private inquiry/acquisition and separate hydration use."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys
S=Path(__file__).resolve().parent.parent;H=S/"tools/utility_consumer_checks";G=Path(os.environ.get("PZ_DIR",r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"));J=Path(os.environ.get("JDK_BIN",r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(out,r):(out/"receipt.json").write_text(json.dumps(r,indent=2,sort_keys=True)+"\n")
p=argparse.ArgumentParser();p.add_argument("--out",type=Path,required=True);p.add_argument("--reuse-classes",type=Path);p.add_argument("--diagnostic-scan-stack",action="store_true");p.add_argument("--source-freeze",type=Path);p.add_argument("--capture-release",type=Path);p.add_argument("--freeze-sha");p.add_argument("--release-sha");p.add_argument("--case",choices=["normal","parent-revoked","source-removed","cancel","native-swapped"]);p.add_argument("--control",choices=["hydration-current","native-instance","obsolete-stop","producer-callback","purification-capacity"]);p.add_argument("--required",action="store_true");p.add_argument("--preflight",action="store_true");p.add_argument("--snapshot-source",type=Path);a=p.parse_args();
caseFor={"hydration-current":"parent-revoked","native-instance":"native-swapped","obsolete-stop":"normal","producer-callback":"normal","purification-capacity":"normal"}
if a.control and a.case and a.case!=caseFor[a.control]:p.error("control requires its exact named case")
a.case=a.case or(caseFor[a.control]if a.control else"normal");a.omit_hydration_current=a.control=="hydration-current";a.omit_native_instance=a.control=="native-instance";a.omit_obsolete_stop=a.control=="obsolete-stop"
if bool(a.source_freeze)!=bool(a.capture_release):p.error("source-freeze and capture-release must be supplied together")
if a.source_freeze and(not a.freeze_sha or not a.release_sha):p.error("source release supplied without exact hashes")
if a.snapshot_source:
 if a.control or a.case!="normal"or a.source_freeze or a.capture_release or a.reuse_classes or a.preflight:p.error("snapshot-source is data-only and accepts no physical control/case/release")
 memberFiles=[Path(__file__),*[H/n for n in ["UtilityConsumerNativeProbe.java","ServiceObserverProbe.java","ports.lua","scene.lua","clock-ports.lua","initialize-person.lua","cases.lua","archive_projection.py","SnapshotDataExport.java","snapshot_export.py"]]]
 missingMembers=[str(v)for v in memberFiles if not v.is_file()]
 if missingMembers:
  target=a.out.resolve();target.mkdir(parents=True,exist_ok=False);write(target,{"schema":"sao-d323-native-snapshot-export/1","status":"FAIL","missingOwned":missingMembers,"executedChecks":0});print("FAIL");sys.exit(1)
 result=subprocess.run([sys.executable,str(H/"snapshot_export.py"),"--producer",str(a.snapshot_source.resolve()),"--out",str(a.out.resolve()),*( ["--required"]if a.required else[])])
 sys.exit(result.returncode)
out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);classes=out/"classes";classes.mkdir()
java=[H/"ServiceObserverProbe.java",H/"UtilityConsumerNativeProbe.java",*[S/x for x in ["tools/luacheck/ResourceApproachProbe.java","tools/luacheck/MovementCrossingProbe.java","java/src/com/sao/engine/SAOWorldSources.java","java/src/com/sao/bridge/SAOBridge.java","java/src/com/sao/engine/SAONativeSnapshot.java"]]]
native=[G/"media/lua"/x for x in ["shared/Logs/ISLogSystem.lua","shared/ISBaseObject.lua","shared/TimedActions/ISBaseTimedAction.lua","client/TimedActions/ISTimedActionQueue.lua","shared/luautils.lua","shared/TimedActions/ISTransferAction.lua","client/TimedActions/ISInventoryTransferAction.lua","shared/TimedActions/ISEquipWeaponAction.lua","shared/TimedActions/ISPlumbItem.lua","shared/TimedActions/ISTakeWaterAction.lua","shared/TimedActions/ISDrinkFromBottle.lua","shared/TimedActions/ISDrinkFluidAction.lua","shared/TimedActions/ISFixGenerator.lua","shared/TimedActions/ISAddFuel.lua","shared/TimedActions/ISPlugGenerator.lua","shared/TimedActions/ISActivateGenerator.lua","client/TimedActions/ISGeneratorInfoAction.lua","shared/TimedActions/ISReadABook.lua","shared/Entity/TimedActions/ISHandcraftAction.lua","shared/TimedActions/ISToggleStoveAction.lua"]]
leaves=[("shared",n)for n in ["Ordering","HouseholdService","Hash","History","Disposition","Identity","Standing","Census","Lessons","BodySnapshot","Places","Perception","Material","RecipePolicy","WorldSources","CognitiveModels","Cognition","Labor","ProceduralPlanning","GraphPersistence","Provisioning","StudySources"]]+[("client",n)for n in ["Body","Needs","SourceUse","ResourceProduction","Generator","Study","Cooking","Controller","CapabilityExperience"]]
owned=[S/"mod/42.20/media/lua"/area/("SAO_"+name+".lua")for area,name in leaves]
source=[H/"ports.lua",*native,H/"scene.lua",*owned,H/"clock-ports.lua",H/"initialize-person.lua",H/"cases.lua"]
inputs=list(dict.fromkeys([Path(__file__),*java,*source,*[G/"media/scripts/generated/items"/n for n in ["normal.txt","weapon.txt","literature.txt"]],*[G/"media/scripts/generated"/n for n in ["fluids.txt","fluids_Beverages.txt","fluids_Alcoholic.txt"]],G/"media/newtiledefinitions.tiles",G/"media/scripts/generated/entities/outdoors/entity_raincollector.txt",G/"projectzomboid.jar",G/"ZombieBuddy.jar",G/"stdlib.lua",S/"java/dist/SAOAgent.jar",J/"java.exe",J/"javac.exe"]))
ownedInputs=list(dict.fromkeys([Path(__file__),*[H/n for n in ["UtilityConsumerNativeProbe.java","ServiceObserverProbe.java","ports.lua","scene.lua","clock-ports.lua","initialize-person.lua","cases.lua","archive_projection.py","SnapshotDataExport.java","snapshot_export.py"]],*java,*owned,S/"java/dist/SAOAgent.jar"]))
inputs=list(dict.fromkeys([*inputs,*ownedInputs,Path(sys.executable)]));nativeInputs=[v for v in inputs if v not in ownedInputs]
missingOwned=[str(v)for v in ownedInputs if not v.is_file()];missingNative=[str(v)for v in nativeInputs if not v.is_file()]
if missingOwned or missingNative:
 status="FAIL"if missingOwned else"NATIVE_UNAVAILABLE";write(out,{"schema":"sao-d323-native-utility-consumer/1","status":status,"scenario":a.case,"control":a.control,"consumerQualified":False,"required":a.required,"missingOwned":missingOwned,"missingNative":missingNative,"executedChecks":0,"boundary":"Unavailable inputs are not executed native proof."});print(status);sys.exit(1 if missingOwned or a.required else 0)
if a.preflight:write(out,{"schema":"sao-d323-native-utility-consumer/1","status":"READY","required":a.required,"ownedInputs":[str(v)for v in ownedInputs],"nativeInputs":[str(v)for v in nativeInputs],"executedChecks":0});print("READY");sys.exit(0)
freezePath=a.source_freeze.resolve()if a.source_freeze else None;releasePath=a.capture_release.resolve()if a.capture_release else None
if bool(freezePath)!=bool(releasePath):p.error("source-freeze and capture-release must be supplied together")
freeze=None
if freezePath:
 if not a.freeze_sha or not a.release_sha:p.error("source release supplied without exact hashes")
 assert sha(freezePath)==a.freeze_sha and sha(releasePath)==a.release_sha
 freeze=json.loads(freezePath.read_text());assert all(sha(S/k)==v for k,v in freeze["pins"].items()),"released source pins drifted";inputs.extend([freezePath,releasePath])
pins={str(x):sha(x)for x in inputs};compilePins={str(x):sha(x)for x in [*java,G/"projectzomboid.jar",G/"ZombieBuddy.jar",S/"java/dist/SAOAgent.jar",J/"javac.exe"]}
cp=os.pathsep.join(map(str,[S/"java/dist/SAOAgent.jar",G/"projectzomboid.jar",G/"ZombieBuddy.jar"]))
javaCompile=java;javaInstrumentation=None
if a.diagnostic_scan_stack:
 original=S/'java/src/com/sao/engine/SAOWorldSources.java';text=original.read_text(encoding='utf-8');marker='SAOAgent.log("world container inspection threw: " + unavailable);';assert text.count(marker)==1
 target=out/'diagnostic-source/com/sao/engine/SAOWorldSources.java';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text.replace(marker,'unavailable.printStackTrace(System.out);'+marker),encoding='utf-8')
 javaCompile=[target if x==original else x for x in java];inputs.append(target);pins[str(target)]=sha(target);compilePins[str(target)]=sha(target)
 javaInstrumentation={'productionSource':str(original),'productionSHA':sha(original),'diagnosticCopy':str(target),'diagnosticSHA':sha(target),'onlyChange':'printStackTrace(System.out) before unchanged existing catch log','boundary':'Error observation only, original methods/guards/effects/result status unchanged'}
commandCompile=[str(J/"javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(classes),*map(str,javaCompile)];reused=None
if a.reuse_classes:
 previous=a.reuse_classes.resolve();old=json.loads((previous/"receipt.json").read_text());assert old["compileExit"]==0
 oldByName={Path(k).name:v for k,v in old["compilePins"].items()};currentByName={Path(k).name:v for k,v in compilePins.items()}
 assert len(oldByName)==len(old["compilePins"])and len(currentByName)==len(compilePins)and oldByName==currentByName,"compiled input source/dependency SHA changed after pathname mapping"
 for name,expected in old["classPins"].items():
  src=previous/"classes"/name;dest=classes/name;assert src.resolve().is_relative_to((previous/"classes").resolve())and dest.resolve().is_relative_to(classes.resolve()),"class path leaves compilation root";assert sha(src)==expected;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
 compileExit=0;reused={"receipt":str(previous/"receipt.json"),"sha256":sha(previous/"receipt.json")}
else:
 r=subprocess.run(commandCompile,capture_output=True,text=True,timeout=90);(out/"compile.log").write_text(r.stdout+r.stderr);compileExit=r.returncode
 if compileExit:write(out,{"status":"FAIL_COMPILE","compileExit":compileExit,"compileCommand":commandCompile,"compilePins":compilePins,"pins":pins});print(r.stderr[-4000:]);sys.exit(1)
captured=[];instrumentation={};omission=None;packageRoot=out/"owned-package";packageRoot.mkdir();packagePins={};loaderBindings={};nativeCaptured=[];selectedHousehold=None
assert not a.omit_hydration_current or a.case=="parent-revoked"
assert not a.omit_native_instance or a.case=="native-swapped"
assert not a.omit_obsolete_stop or a.case=="normal"
for i,src in enumerate(source):
 text=src.read_text(encoding="utf-8-sig");production=text
 if src.name=="cases.lua":text="__utilityCase="+json.dumps(a.case)+";__utilityControl="+json.dumps(a.control)+"\n"+text
 if src.name=="SAO_Needs.lua"and a.omit_hydration_current:
  clause="and planning.hydrationRequestCurrent and planning.hydrationRequestCurrent(id,body,evidence.request)==true";assert text.count(clause)==1
  text=text.replace(clause,"and true -- PRIVATE detecting omission of exact current requesting purpose");omission={"productionSHA":sha(src),"clause":clause,"changedOnly":"Native direct-use requesting-purpose mutation guard"}
 if src.name=="SAO_Needs.lua"and a.omit_native_instance:
  clause="end);return ok and owned==true\n    end\n    local function queueOwned";assert text.count(clause)==1
  text=text.replace(clause,"end);return true -- PRIVATE detecting native instance omission\n    end\n    local function queueOwned");omission={"productionSHA":sha(src),"clause":clause,"changedOnly":"Exact native instance/getTable guard helper"}
 if src.name=="SAO_Needs.lua"and a.omit_obsolete_stop:
  clause="if evidence.outcome or evidence.handedOff or not queueOwned()then return false end";assert text.count(clause)==1
  text=text.replace(clause,"-- PRIVATE detecting omission of obsolete stop guard");omission={"productionSHA":sha(src),"clause":clause,"changedOnly":"Obsolete original-stop/current queue handoff guard"}
 if src.name=="SAO_HouseholdService.lua"and a.control=="producer-callback":
  clause="Events.OnTick.Add(H.onTick)";assert text.count(clause)==1;text=text.replace(clause,"-- PRIVATE detecting selected owned callback omission");omission={"productionSHA":sha(src),"clause":clause,"changedOnly":"Selected owned H native callback registration"}
 if src.name=="SAO_Needs.lua"and a.control=="purification-capacity":
  clause="math.min(remaining,capacity,available)";assert text.count(clause)==1;text=text.replace(clause,"math.min(remaining,available)");omission={"productionSHA":sha(src),"clause":clause,"changedOnly":"Selected original transfer sample-capacity bound"}
 if src.name=='SAO_Controller.lua':
  marker='return Ctl';pos=text.rfind(marker);assert pos>=0
  hook='__utilityUpdateMovement=updateMovement;__utilityUpdateAgent=updateAgent;__utilityDecideNeeds=decideNeedsAndCompanion\n'
  text=text[:pos]+hook+text[pos:];assert text.replace(hook,'',1)==production
  instrumentation={'source':str(src),'productionSHA':sha(src),'hook':hook,'helperBodiesUnchanged':True,'boundary':'Exact original lexical movement/agent/needs handlers exposed only; no function replacement, state/goal/effect/private-fact grant. Declared arrived-route/clock endpoint instrument.'}
 if src in native:
  relative=src.relative_to(G).as_posix();dest=packageRoot/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(src.read_bytes());packagePins[relative]=sha(dest);nativeCaptured.append(dest);continue
 if src.name in ["SAO_HouseholdService.lua","SAO_Ordering.lua"]:
  relative=src.relative_to(S/"mod/42.20").as_posix();dest=packageRoot/relative;dest.parent.mkdir(parents=True,exist_ok=True)
  if text==production:dest.write_bytes(src.read_bytes())
  else:dest.write_text(text,encoding="utf-8")
  packagePins[relative]=sha(dest);loaderBindings[relative]={"source":str(src),"productionSHA":sha(src),"selectedSHA":sha(dest)}
  if src.name=="SAO_HouseholdService.lua":selectedHousehold=dest
  continue
 dest=out/(str(i).zfill(2)+"-"+src.name);dest.write_text('print("UTILITY_LOADING",'+json.dumps(src.name)+')\n'+text,encoding="utf-8");captured.append(dest)
 if src.name=='SAO_Controller.lua':instrumentation['instrumentedCopySHA']=sha(dest)

loader=out/"native-package-loader.lua";loader.write_text("\n".join('require('+json.dumps(p.relative_to(packageRoot/"media/lua").as_posix().split('/',1)[1][:-4])+')'for p in nativeCaptured)+'\nrequire("SAO_Ordering")\nlocal h=require("SAO_HouseholdService");assert(h and h==SAO.HouseholdService and require("SAO_HouseholdService")==h)\n')
captured.insert(1,loader);inputs.extend([loader,*nativeCaptured,*[packageRoot/k for k in loaderBindings]]);pins.update({str(v):sha(v)for v in [loader,*nativeCaptured,*[packageRoot/k for k in loaderBindings]]})
if omission and a.control=="producer-callback":omission["selectedPath"]=str(selectedHousehold);omission["selectedSHA"]=sha(selectedHousehold)
for src in [Path(__file__),*java]:
 if src.parent==H:(out/("captured-"+src.name)).write_bytes(src.read_bytes())
shutil.copy2(G/"stdlib.lua",out/"stdlib.lua")
command=[str(J/"java.exe"),"--enable-native-access=ALL-UNNAMED","-Djava.awt.headless=true","-Duser.home="+str(out),"-Djava.library.path="+str(G),"-Dsao.game="+str(G),"-Dsao.ownedPackage="+str(packageRoot),"-cp",str(classes)+os.pathsep+cp,"UtilityConsumerNativeProbe",str(G),*map(str,captured)]
r=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=120);(out/"run.log").write_text(r.stdout+r.stderr)
checks=dict(re.findall(r"CHECK (utility_[a-z0-9_]+)=(true|false)",r.stdout));expected=set(re.findall(r'check\("([a-z0-9_]+)"',(H/"cases.lua").read_text()));caseText=(H/"cases.lua").read_text()
if a.case=="normal":expected={name for name in expected if not name.startswith("utility_guard_")}
else:expected=set(re.findall(r'check\("([a-z0-9_]+)"',caseText[:caseText.index("local sawForage=false")]))|{name for name in expected if name.startswith("utility_guard_")}
if a.case!="cancel":expected.discard("utility_guard_actual_native_cancel_release")
stable=pins=={str(x):sha(x)for x in inputs};status="PASS"if stable and r.returncode==0 and set(checks)==expected and all(v=="true"for v in checks.values())else"FAIL"
if a.control:
 detector={"obsolete-stop":"utility_obsolete_callbacks_preserve_successor","producer-callback":"utility_actual_finite_fuel_provider","purification-capacity":"utility_actual_water_conservation"}.get(a.control,"utility_guard_no_native_effect")
 status="DETECTED"if stable and omission and checks.get(detector)=="false"else"UNDETECTED"
write(out,{"schema":"sao-d323-native-utility-consumer/1","status":status,"required":a.required,"control":a.control,"ownedInputs":[str(v)for v in ownedInputs],"nativeInputs":[str(v)for v in nativeInputs],"scenario":a.case,"consumerQualified":a.case=="normal"and status=="PASS","detectingOmission":omission,"checks":checks,"expected":sorted(expected),"inputStable":stable,"pins":pins,"compilePins":compilePins,"compileCommand":commandCompile,"compileExit":compileExit,"reusedCompilation":reused,"sourceFreezeSHA":sha(freezePath)if freezePath else None,"sourceReleaseSHA":sha(releasePath)if releasePath else None,"releasedPublicPins":freeze["pins"]if freeze else{str(v.relative_to(S)):sha(v)for v in owned},"instrumentation":instrumentation,"javaDiagnosticInstrumentation":javaInstrumentation,"classPins":{str(x.relative_to(classes)):sha(x)for x in classes.rglob("*.class")},"command":command,"exitCode":r.returncode,"logSha256":sha(out/"run.log"),"ownedPackagePins":packagePins,"loaderBindings":loaderBindings,"selectedHousehold":str(selectedHousehold),"capturedFiles":{x.name:sha(x)for x in captured},"projections":{x.name:sha(x)for x in out.glob("*.json")if x.name!="receipt.json"},"boundary":"Actual isolated ordinary utility consumer/body/native effect with explicit route/clock/animation/network/bootstrap ports. Normal and negative scenarios separate; primitive native/table save only, no fullworld reload/server/training/whole D3 claim."})
print(status,len(checks),"/",len(expected),"exit",r.returncode,"stable",stable);print((r.stdout+r.stderr)[-7000:]);sys.exit(0 if status in("PASS","DETECTED")else 1)
