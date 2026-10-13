#!/usr/bin/env python3
"""Original native utility work through current private inquiry/acquisition and separate hydration use."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys
S=Path(__file__).resolve().parent.parent;H=S/"tools/utility_consumer_checks";G=Path(os.environ.get("PZ_DIR",r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"));J=Path(os.environ.get("JDK_BIN",r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(out,r):(out/"receipt.json").write_text(json.dumps(r,indent=2,sort_keys=True)+"\n")
def electrical_run(a):
 """The attained electrical/native consumer recipes in this existing driver."""
 case=a.case or 'normal';control=a.control
 controls={'native-toggle':('accounting','omit-native-toggle'),'native-fuel-revoke':('accounting','restore-fuel-revoke'),'electrical-receiver':('review-corrections','omit-receiver')}
 if control and control not in controls:p.error('managed-electrical control unsupported')
 if control:
  requiredCase,mode=controls[control]
  if a.case and case!=requiredCase:p.error('control requires its exact named electrical case')
  case=requiredCase
 else:mode='changed-source'if case=='source-removed'else'none'
 if case not in ['normal','accounting','review-corrections','source-removed']:p.error('managed-electrical case unsupported')
 if a.source_freeze or a.capture_release or a.reuse_classes or a.diagnostic_scan_stack:p.error('electrical lane uses its exact captured current inputs; release/reuse/diagnostic flags unsupported')
 if a.snapshot_source and(control or a.case or a.preflight):p.error('electrical snapshot-source is data-only, accepts no physical case/control/preflight')
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 supports=[H/n for n in ['ElectricalServiceNativeProbe.java','ElectricalOrdinaryProbe.java','electrical_ports.lua','electrical_cases.lua','electrical_ordinary_ports.lua','electrical_ordinary_cases.lua','electrical_consumer_use.lua']]
 runtime=[S/'mod/42.20/media/lua'/q for q in ['shared/SAO_Ordering.lua','shared/SAO_HouseholdService.lua','shared/SAO_ElectricalService.lua','client/SAO_ElectricalMenu.lua','shared/SAO_WorldSources.lua','shared/SAO_Perception.lua','shared/SAO_SituationAppraisal.lua','shared/SAO_Labor.lua','shared/SAO_CognitiveModels.lua','shared/SAO_Cognition.lua','shared/SAO_ProceduralPlanning.lua','client/SAO_Generator.lua','client/SAO_Cooking.lua','client/SAO_SourceUse.lua','client/SAO_Needs.lua','client/SAO_CapabilityExperience.lua','client/SAO_Controller.lua','client/SAO_ResourceProduction.lua','shared/SAO_Census.lua']]
 helpers=[S/q for q in ['tools/resource_production_checks/GeneratorNativeProbe.java','tools/luacheck/MovementCrossingProbe.java','tools/luacheck/ResourceApproachProbe.java','tools/d2_leisure_materials/metadata.java.inc','tools/utility_consumer_checks/SnapshotDataExport.java','tools/utility_consumer_checks/snapshot_export.py','tools/utility_consumer_checks/archive_projection.py','tools/lua_read.py']]
 owned=[Path(__file__),*supports,*runtime,*helpers,S/'java/dist/SAOAgent.jar',S/'java/src/com/sao/engine/SAOWorldSources.java',S/'java/src/com/sao/bridge/SAOBridge.java']
 if a.snapshot_source:owned.append(a.snapshot_source.resolve())
 native=[G/q for q in ['projectzomboid.jar','ZombieBuddy.jar','stdlib.lua','media/newtiledefinitions.tiles','media/scripts/generated/items/normal.txt','media/scripts/generated/items/food.txt','media/scripts/generated/items/literature.txt','media/scripts/generated/fluids.txt','media/scripts/generated/fluids_Beverages.txt','media/scripts/generated/fluids_Alcoholic.txt']]+[J/'java.exe',J/'javac.exe']
 native += [G/'media/lua'/q for q in ['shared/ISBaseObject.lua','shared/TimedActions/ISBaseTimedAction.lua','client/TimedActions/ISTimedActionQueue.lua','shared/TimedActions/ISActivateGenerator.lua','shared/TimedActions/ISToggleStoveAction.lua','shared/TimedActions/ISToggleLightAction.lua','shared/TimedActions/ISFixGenerator.lua','shared/TimedActions/ISAddFuel.lua','shared/TimedActions/ISPlugGenerator.lua','client/TimedActions/ISGeneratorInfoAction.lua','client/TimedActions/ISInventoryTransferAction.lua','shared/TimedActions/ISEquipWeaponAction.lua','shared/TimedActions/ISEatFoodAction.lua','shared/TimedActions/ISTransferAction.lua','shared/Logs/ISLogSystem.lua']]
 missingOwned=[str(x)for x in owned if not x.is_file()];missingNative=[str(x)for x in native if not x.is_file()]
 base={'schema':'sao-d6-native-managed-electrical/1','scenario':case,'utilityScenario':'managed-electrical','control':control,'required':a.required,'consumerQualified':False,'executedChecks':0,'missingOwned':missingOwned,'missingNative':missingNative,'ownedInputs':[str(x)for x in owned],'nativeInputs':[str(x)for x in native]}
 if missingOwned or missingNative:
  base['status']='FAIL'if missingOwned else'NATIVE_UNAVAILABLE';write(out,base);print(base['status']);return 1 if missingOwned or a.required else 0
 if a.preflight:base['status']='READY';write(out,base);print('READY');return 0
 if a.snapshot_source:return electrical_snapshot(a,out,base)
 package=out/'selected-inputs';package.mkdir();bindings={}
 for src in runtime:
  rel=src.relative_to(S);target=package/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(src.read_bytes());bindings[str(rel)]={'source':str(src),'sha256':sha(target)}
 for src in supports:shutil.copy2(src,package/src.name)
 if case=='review-corrections'and mode!='omit-receiver':
  from lua_read import function_body
  controller=(package/'mod/42.20/media/lua/client/SAO_Controller.lua').read_text()
  framed='local Ctl=SAO.Controller\nlocal setState=function(a,id,state,reason,kind)assert(a==SAO.Controller.agents[id]and a.rec==SAO.Identity.get(id));a.state=state;a.reason=reason;return true end\n'
  for name in ['Ctl.waterGeneratorIntent','Ctl.electricalControlIntent','Ctl.generatorContext','Ctl.advanceGeneratorPurpose']:framed+='function '+name+'('+function_body(controller,name)+'end\n'
  (package/'controller-functions.lua').write_text(framed)

 pins={str(x):sha(x)for x in [*owned,*native]};classes=out/'classes';classes.mkdir();shutil.copy2(G/'stdlib.lua',out/'stdlib.lua')
 metadata=(S/'tools/d2_leisure_materials/metadata.java.inc').read_text();anchor='definition.Load(name,text.substring(match.start(),end));';assert metadata.count(anchor)==1
 metadata=metadata.replace(anchor,'var modField=ScriptManager.class.getDeclaredField("currentLoadFileMod");modField.setAccessible(true);Object oldMod=modField.get(null);modField.set(null,"fixture-installed-source");try{definition.setModID("fixture-installed-source");definition.InitLoadPP(name);'+anchor+'}finally{modField.set(null,oldMod);}')
 generated=(S/'tools/resource_production_checks/GeneratorNativeProbe.java').read_text().replace('    METADATA',metadata,1)
 accounting=case=='accounting'
 if not accounting:generated=generated.replace('"ElectronicsMag4"))','"ElectronicsMag4","MuttonChop"))').replace('String file=name.equals("ElectronicsMag4")?"literature.txt":"normal.txt";','String file=name.equals("MuttonChop")?"food.txt":name.equals("ElectronicsMag4")?"literature.txt":"normal.txt";')
 generatedPath=out/'GeneratorNativeProbe.java';generatedPath.write_text(generated)
 main='ElectricalServiceNativeProbe'if accounting else'ElectricalOrdinaryProbe'
 cp=os.pathsep.join(map(str,[S/'java/dist/SAOAgent.jar',G/'projectzomboid.jar',G/'ZombieBuddy.jar',*sorted((G/'jars').glob('*.jar'))]))
 java=[H/(main+'.java'),generatedPath,S/'tools/luacheck/MovementCrossingProbe.java',S/'tools/luacheck/ResourceApproachProbe.java',S/'java/src/com/sao/engine/SAOWorldSources.java',S/'java/src/com/sao/bridge/SAOBridge.java']
 cc=[str(J/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*map(str,java)];c=subprocess.run(cc,capture_output=True,text=True,timeout=90);(out/'compile.log').write_text(c.stdout+c.stderr)
 base.update(pins=pins,sourceBindings=bindings,selectedPackage=str(package),compileCommand=cc,compileExitCode=c.returncode,generatedBootstrapSHA256=sha(generatedPath))
 if c.returncode:base['status']='FAIL_COMPILE';write(out,base);print(c.stderr);return 1
 cmd=[str(J/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-Duser.home='+str(out),'-Djava.library.path='+str(G),'-Dsao.d6.control='+mode,'-Dsao.electrical.case='+case]
 if case=='normal':cmd.append('-Dsao.d6.consumerScript='+str(package/'electrical_consumer_use.lua'))
 cmd += ['-cp',str(classes)+os.pathsep+cp,main,str(G),str(package),str(out)]
 r=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=120);(out/'native.log').write_text(r.stdout+r.stderr);checks=dict(re.findall(r'^(?:CHECK|CONSUMER_CHECK) ([A-Za-z0-9_-]+)=(true|false)$',r.stdout,re.M));stable=all(sha(Path(k))==v for k,v in pins.items())
 status='PASS'if r.returncode==0 and checks and all(v=='true'for v in checks.values())and stable else'FAIL'
 if control:
  detector={'native-toggle':'omitted_native_toggle_detected','native-fuel-revoke':'restored_fuel_guard_detected','electrical-receiver':'npc_receiver_tamper_refused'}[control];status='DETECTED'if stable and ((checks.get(detector)=='true'and r.returncode==0)if control!='electrical-receiver'else checks.get(detector)=='false'and r.returncode!=0)else'UNDETECTED'
 base.update(status=status,consumerQualified=case=='normal'and status=='PASS',inputStable=stable,checks=checks,executedChecks=len(checks),command=cmd,nativeExitCode=r.returncode,projections={x.name:sha(x)for x in out.glob('*.json')if x.name!='receipt.json'},binaries={x.name:sha(x)for x in out.glob('*.bin')},classPins={str(x.relative_to(classes)):sha(x)for x in classes.rglob('*.class')},boundary='Attained CPU native electrical/source/private P/G/C and original consumer recipes with declared environment/lifetime/Standing/routes/HUD/wait/clock ports. Normal consumer, accounting and bounded correction cases have distinct proof scope; no world/server/GPU/training claim.')
 write(out,base);print(status,len(checks));print((r.stdout+r.stderr)[-4000:]);return 0 if status in ['PASS','DETECTED']else 1

def electrical_snapshot(a,out,base):
 """Original snapshots of the producer native binary, with no physical fixture."""
 producerPath=a.snapshot_source.resolve()
 try:
  producer=json.loads(producerPath.read_text());assert producer['schema']=='sao-d6-native-managed-electrical/1'and producer['scenario']=='normal'and producer['control']is None
  if producer['status']=='NATIVE_UNAVAILABLE':
   assert producer['executedChecks']==0 and not producer['missingOwned']and producer['missingNative'];base.update(status='NATIVE_UNAVAILABLE',reason='original-normal-producer-native-unavailable',missingNative=producer['missingNative']);write(out,base);print(base['status']);return 1 if a.required else 0
  assert producer['status']=='PASS'and producer['inputStable']and producer['consumerQualified']
  sourceDir=Path(producer['selectedPackage']);original=producerPath.parent
  raw=original/'whole-consumer.json';binary=original/'whole-person.bin';assert sha(raw)==producer['projections'][raw.name]and sha(binary)==producer['binaries'][binary.name]
  expectedFull=original/'whole-full.json';expectedBounded=original/'whole-bounded.json';expectedRecord=original/'whole-saved-person.json'
  for x in [expectedFull,expectedBounded,expectedRecord]:assert sha(x)==producer['projections'][x.name]
  whole=json.loads(raw.read_text());settings=whole['full']['settings'];hours=whole['captureHours']
  source=[sourceDir/'mod/42.20/media/lua'/x for x in ['shared/SAO_ElectricalService.lua','shared/SAO_CognitiveModels.lua','shared/SAO_Cognition.lua']]
  for x in source:
   rel=str(x.relative_to(sourceDir));assert x.is_file()and sha(x)==producer['sourceBindings'][rel]['sha256']
 except (OSError,ValueError,KeyError,AssertionError,TypeError):base.update(status='FAIL',reason='invalid-normal-electrical-producer-or-frozen-input');write(out,base);print('FAIL');return 1
 def literal(x):
  if isinstance(x,bool):return'true'if x else'false'
  if isinstance(x,(int,float)):return repr(x)
  if isinstance(x,str):return json.dumps(x,ensure_ascii=False)
  if isinstance(x,dict):return'{'+','.join('['+literal(k)+']='+literal(v)for k,v in x.items())+'}'
  raise ValueError('not plain snapshot settings')
 helper=(H/'SnapshotDataExport.java').read_text();anchor='  env.rawset("__savedNativeRoundTrip",';assert helper.count(anchor)==1
 helper=helper.replace('public final class SnapshotDataExport','public final class ElectricalSavedReadback').replace(anchor,'  var saved=platform.newTable();saved.load(ByteBuffer.wrap(Files.readAllBytes(Path.of(System.getProperty("sao.savedRecord")))),zombie.iso.IsoWorld.WorldVersion);env.rawset("__loadedRecord",saved);\n'+anchor,1)
 java=out/'ElectricalSavedReadback.java';java.write_text(helper);ports=out/'saved-ports.lua';ports.write_text('require=function()end\nlocal saved=__loadedRecord;local data={settings='+literal(settings)+'}\nSAO={Identity={get=function(id)return id==saved.id and saved or nil end},History={countyHours=function()return '+repr(hours)+' end}}\nModData={get=function(k)return k=="SurvivorAwareness_Cognition"and data or nil end}\n')
 query=out/'saved-query.lua';query.write_text('__exportPlain("loaded-person",__loadedRecord)\n__exportPlain("readback-full",assert(SAO.Cognition.snapshot(__loadedRecord.id,true)))\n__exportPlain("readback-bounded",assert(SAO.Cognition.snapshot(__loadedRecord.id,false)))\n')
 inputs=[producerPath,raw,binary,expectedFull,expectedBounded,expectedRecord,*source,H/'SnapshotDataExport.java',G/'projectzomboid.jar',G/'ZombieBuddy.jar',G/'stdlib.lua',java,ports,query];pins={str(x):sha(x)for x in inputs};classes=out/'classes';classes.mkdir();shutil.copy2(G/'stdlib.lua',out/'stdlib.lua');cp=os.pathsep.join(map(str,[G/'projectzomboid.jar',G/'ZombieBuddy.jar']))
 c=subprocess.run([str(J/'javac.exe'),'-cp',cp,'-d',str(classes),str(java)],capture_output=True,text=True,timeout=30);(out/'compile.log').write_text(c.stdout+c.stderr)
 if c.returncode:base.update(status='FAIL_COMPILE',compileExitCode=c.returncode);write(out,base);return 1
 cmd=[str(J/'java.exe'),'-Duser.home='+str(out),'-Dsao.savedRecord='+str(binary),'-cp',str(classes)+os.pathsep+cp,'ElectricalSavedReadback',str(ports),*map(str,source),str(query)];r=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=30);(out/'native-data.log').write_text(r.stdout+r.stderr)
 checks={}
 if r.returncode==0:
  for name,expected in [('loaded-person',expectedRecord),('readback-full',expectedFull),('readback-bounded',expectedBounded)]:checks[name]=json.loads((out/(name+'.json')).read_text())==json.loads(expected.read_text())
 stable=all(sha(Path(k))==v for k,v in pins.items());status='PASS'if r.returncode==0 and len(checks)==3 and all(checks.values())and stable else'FAIL';base.update(status=status,qualificationMode='DATA_ONLY_ORIGINAL_NATIVE_BINARY_LOAD',consumerQualified=False,producer=str(producerPath),captureHours=hours,inputStable=stable,pins=pins,checks=checks,executedChecks=len(checks),physicalRuns=0,nativeExitCode=r.returncode,command=cmd,projections={x.name:sha(x)for x in out.glob('*.json')if x.name!='receipt.json'},boundary='Original native binary load -> exact frozen E/Models/C original snapshot true/false; immutable Identity/lifetime/clock/settings data ports, every-field comparison, no actor/cell/actions/food/service scene or cropping.')
 write(out,base);print(status,checks);return 0 if status=='PASS'else 1

p=argparse.ArgumentParser();p.add_argument("--scenario",choices=["household-restoration","water-network","managed-electrical"],default="household-restoration");p.add_argument("--out",type=Path,required=True);p.add_argument("--reuse-classes",type=Path);p.add_argument("--diagnostic-scan-stack",action="store_true");p.add_argument("--source-freeze",type=Path);p.add_argument("--capture-release",type=Path);p.add_argument("--freeze-sha");p.add_argument("--release-sha");p.add_argument("--case",choices=["normal","parent-revoked","source-removed","cancel","native-swapped","parent-postallocation","installed-offer","review-corrections","recipe-mutation","accounting"]);p.add_argument("--control",choices=["hydration-current","native-instance","obsolete-stop","producer-callback","purification-capacity","network-parent","installed-admission","installed-transfer","review-pump","recipe-observation","recipe-transfer","native-toggle","native-fuel-revoke","electrical-receiver"]);p.add_argument("--required",action="store_true");p.add_argument("--preflight",action="store_true");p.add_argument("--snapshot-source",type=Path);a=p.parse_args();
if a.scenario=="managed-electrical":sys.exit(electrical_run(a))

caseFor={"hydration-current":"parent-revoked","native-instance":"native-swapped","obsolete-stop":"normal","producer-callback":"normal","purification-capacity":"normal","review-pump":"review-corrections","recipe-observation":"review-corrections","recipe-transfer":"recipe-mutation","network-parent":"parent-postallocation","installed-admission":"installed-offer","installed-transfer":"installed-offer"}
if a.control and a.case and a.case!=caseFor[a.control]:p.error("control requires its exact named case")
a.case=a.case or(caseFor[a.control]if a.control else"normal");network=a.scenario=="water-network";sceneFile=H/("network_scene.lua"if network else"scene.lua");caseFile=H/("network_cases.lua"if network else"cases.lua");a.omit_hydration_current=a.control=="hydration-current";a.omit_native_instance=a.control=="native-instance";a.omit_obsolete_stop=a.control=="obsolete-stop"
if network and a.case not in ["normal","parent-revoked","parent-postallocation","installed-offer","review-corrections","recipe-mutation"]:p.error("water-network case unsupported")
if network and a.control not in [None,"network-parent","installed-admission","installed-transfer","review-pump","recipe-observation","recipe-transfer"]:p.error("water-network control unsupported")
if not network and (a.case in ["parent-postallocation","installed-offer","review-corrections","recipe-mutation"]or a.control in ["network-parent","installed-admission","installed-transfer","review-pump","recipe-observation","recipe-transfer"]):p.error("network boundary requires water-network scenario")
if bool(a.source_freeze)!=bool(a.capture_release):p.error("source-freeze and capture-release must be supplied together")
if a.source_freeze and(not a.freeze_sha or not a.release_sha):p.error("source release supplied without exact hashes")
if a.snapshot_source:
 if a.control or a.case!="normal"or a.source_freeze or a.capture_release or a.reuse_classes or a.preflight:p.error("snapshot-source is data-only and accepts no physical control/case/release")
 memberFiles=[Path(__file__),*[H/n for n in ["UtilityConsumerNativeProbe.java","ServiceObserverProbe.java","ports.lua","scene.lua","clock-ports.lua","initialize-person.lua","cases.lua","archive_projection.py","SnapshotDataExport.java","snapshot_export.py","network_scene.lua","network_cases.lua"]]]
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
if network:
 native.insert(1,G/"media/lua/shared/ActionManager.lua");native.insert(2,G/"media/lua/client/TimedActions/ISGrabItemAction.lua")
 owned.insert(3,S/"mod/42.20/media/lua/shared/SAO_Rand.lua");owned.append(S/"mod/42.20/media/lua/client/SAO_NetworkWork.lua")
source=[H/"ports.lua",*native,sceneFile,*owned,H/"clock-ports.lua",H/"initialize-person.lua",caseFile]
inputs=list(dict.fromkeys([Path(__file__),*java,*source,*[G/"media/scripts/generated/items"/n for n in ["normal.txt","weapon.txt","literature.txt"]],*[G/"media/scripts/generated"/n for n in ["fluids.txt","fluids_Beverages.txt","fluids_Alcoholic.txt"]],G/"media/newtiledefinitions.tiles",G/"media/scripts/generated/entities/outdoors/entity_raincollector.txt",G/"projectzomboid.jar",G/"ZombieBuddy.jar",G/"stdlib.lua",S/"java/dist/SAOAgent.jar",J/"java.exe",J/"javac.exe"]))
if network:inputs.extend([*(S/"mod/42.20/media/scripts"/("SAO_WaterNetwork_"+n+".txt")for n in ["Items","Recipes","Models"]),G/"media/scripts/generated/items/drainable.txt",G/"media/scripts/generated/items/clothing.txt"])
ownedInputs=list(dict.fromkeys([Path(__file__),*[H/n for n in ["UtilityConsumerNativeProbe.java","ServiceObserverProbe.java","ports.lua","scene.lua","clock-ports.lua","initialize-person.lua","cases.lua","archive_projection.py","SnapshotDataExport.java","snapshot_export.py","network_scene.lua","network_cases.lua"]],*java,*owned,S/"java/dist/SAOAgent.jar"]))
if network:ownedInputs.extend(S/"mod/42.20/media/scripts"/("SAO_WaterNetwork_"+n+".txt")for n in ["Items","Recipes","Models"])
inputs=list(dict.fromkeys([*inputs,*ownedInputs,Path(sys.executable)]));nativeInputs=[v for v in inputs if v not in ownedInputs]
missingOwned=[str(v)for v in ownedInputs if not v.is_file()];missingNative=[str(v)for v in nativeInputs if not v.is_file()]
if missingOwned or missingNative:
 status="FAIL"if missingOwned else"NATIVE_UNAVAILABLE";write(out,{"schema":"sao-d323-native-utility-consumer/1","status":status,"scenario":a.case,"utilityScenario":a.scenario,"control":a.control,"consumerQualified":False,"required":a.required,"missingOwned":missingOwned,"missingNative":missingNative,"executedChecks":0,"boundary":"Unavailable inputs are not executed native proof."});print(status);sys.exit(1 if missingOwned or a.required else 0)
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
if network and a.case=="parent-postallocation":
 original=S/'java/src/com/sao/engine/SAOWorldSources.java';text=original.read_text();clause='body.getInventory().Remove(item);';begin=text.index('public static synchronized Object placeNetworkPart(');end=text.index('public static synchronized Object networkFluidObservation(',begin);fragment=text[begin:end];assert fragment.count(clause)==1
 hook='var fn=zombie.Lua.LuaManager.env.rawget("__utilityReplaceOriginalRequest");var result=zombie.Lua.LuaManager.thread.pcall(fn,new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(java.util.Arrays.toString(result));'
 target=out/'diagnostic-source/com/sao/engine/SAOWorldSources.java';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text[:begin]+fragment.replace(clause,clause+hook)+text[end:]);javaCompile=[target if x==original else x for x in java];inputs.append(target);pins[str(target)]=sha(target);compilePins[str(target)]=sha(target)
 javaInstrumentation={'productionSHA':sha(original),'copySHA':sha(target),'copyPath':str(target),'onlyChange':'Invoke original P.maintain request replacement after native allocation/removal before topology commit','scope':'Negative definition-replacement endpoint; no physical getter/effect/return override'}
if a.control in ["recipe-observation","recipe-transfer"]or a.case=="recipe-mutation":
 original=S/'java/src/com/sao/engine/SAOWorldSources.java';text=original.read_text();start=text.index('    private static boolean networkStockAvailable(InventoryItem item) {');end=text.index('    private static boolean householdPumpCurrent(',start);before=text[start:end];
 target=out/'diagnostic-source/com/sao/engine/SAOWorldSources.java';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text[:start]+'    private static boolean networkStockAvailable(InventoryItem item) { return true; }\n'+text[end:]);javaCompile=[target if x==original else x for x in java];inputs.append(target);pins[str(target)]=sha(target);compilePins[str(target)]=sha(target);javaInstrumentation={'productionSHA':sha(original),'copySHA':sha(target),'copyPath':str(target),'onlyChange':'Refusal-only networkStockAvailable predicate omission shared observation/resolver/native admission; original identities/revisions/input/visibility unchanged'}
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
 if src==caseFile:text="__utilityCase="+json.dumps(a.case)+";__utilityControl="+json.dumps(a.control)+"\n"+text
 if network and src.name=="SAO_ProceduralPlanning.lua"and a.control=="network-parent":
  clause='or parent.revision~=own.parentRevision or parent.cursor~=own.parentCursor';assert text.count(clause)==1;text=text.replace(clause,'or parent.cursor~=own.parentCursor');omission={'productionSHA':sha(src),'clause':clause,'changedOnly':'Exact current original requesting definition revision guard'}
 if network and src.name=="SAO_Needs.lua"and a.control in ["installed-admission","installed-transfer"]:
  admission='if not okI or worldItem == nil or installedNetworkItem(worldItem)then return false end';assert text.count(admission)==1;text=text.replace(admission,'if not okI or worldItem == nil then return false end')
  omission={'productionSHA':sha(src),'clause':admission,'changedOnly':'Installed original pickup admission omission','scope':'Current native candidate enumeration; transfer guard retained for admission control'}
  if a.control=="installed-transfer":
   transfer='or installedNetworkItem(worldItem)or not self:isValid() then';assert text.count(transfer)==1;text=text.replace(transfer,'or not self:isValid() then');omission['mutationClause']=transfer;omission['changedOnly']='Installed transfer guard omission under identical admission-omitted prerequisite'
 if src.name=="SAO_HouseholdService.lua"and a.control=="review-pump":
  clause='p.row.kind=="pump"and p.powered==true';assert text.count(clause)==1;text=text.replace(clause,'p.row.kind=="pump"');omission={'productionSHA':sha(src),'clause':clause,'changedOnly':'Effective current pump filter omission; actual paid bypass/native off still retained'}
 if src.name=="SAO_SourceUse.lua"and a.case=="recipe-mutation":
  clause='if okWorld and worldItem ~= nil and groundStockAvailable(worldItem)then';assert text.count(clause)==1;text=text.replace(clause,'if okWorld and worldItem ~= nil then');omission={'productionSHA':sha(src),'clause':clause,'changedOnly':'Ground action creation stock admission omission prerequisite; immediate transfer retained'}
  if a.control=="recipe-transfer":
   clause='and self.destContainer==body:getInventory()and groundStockAvailable(worldItem)';assert text.count(clause)==1;text=text.replace(clause,'and self.destContainer==body:getInventory()');omission['mutationClause']=clause;omission['changedOnly']='Immediate exact ground stock predicate omission under same native observation/admission prerequisite'
 if a.control=="recipe-observation":omission={'changedOnly':'Java network stock predicate omission','java':javaInstrumentation}
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
 if src.name=="ports.lua":text="__utilityScenario="+json.dumps(a.scenario)+";__utilityCase="+json.dumps(a.case)+"\n"+text
 if src in native:
  relative=src.relative_to(G).as_posix();dest=packageRoot/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(src.read_bytes());packagePins[relative]=sha(dest);nativeCaptured.append(dest);continue
 if src.name in ["SAO_HouseholdService.lua","SAO_Ordering.lua","SAO_NetworkWork.lua"]:
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
command=[str(J/"java.exe"),"--enable-native-access=ALL-UNNAMED","-Djava.awt.headless=true","-Duser.home="+str(out),"-Djava.library.path="+str(G),"-Dsao.game="+str(G),"-Dsao.ownedPackage="+str(packageRoot),"-Dsao.selectedSource="+str(S),"-Dsao.waterNetwork="+str(network).lower(),"-cp",str(classes)+os.pathsep+cp,"UtilityConsumerNativeProbe",str(G),*map(str,captured)]
r=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=120);(out/"run.log").write_text(r.stdout+r.stderr)
if network:
 checks=dict(re.findall(r"CHECK (ordinary_[a-z0-9_]+)=(true|false)",r.stdout));expected={"ordinary_"+n for n in re.findall(r'check\("([a-z0-9_]+)"',caseFile.read_text())}
 if a.case=="normal":expected={name for name in expected if not name.startswith(("ordinary_guard_","ordinary_review_"))}
 elif a.case in ["review-corrections","recipe-mutation"]:
  expected={name for name in expected if name.startswith("ordinary_review_")}
  if a.case=="recipe-mutation":expected-={"ordinary_review_installed_observation_refused","ordinary_review_installed_admission_refused"}
  else:expected.discard("ordinary_review_installed_mutation_refused")
 if a.case not in ["normal","review-corrections","recipe-mutation"]:
  common={"ordinary_actual_identity","ordinary_actual_default_models","ordinary_initial_missing_network","ordinary_original_water_parent"}
  expected=common|({"ordinary_guard_original_definition_replaced","ordinary_guard_parent_no_unauthorized_topology","ordinary_guard_parent_physical_truth","ordinary_guard_obsolete_callback_preserves_successor"}if a.case!="installed-offer"else{"ordinary_guard_installed_exact_native_candidate","ordinary_guard_installed_admission_refused","ordinary_guard_installed_transfer_refused"})
else:
 checks=dict(re.findall(r"CHECK (utility_[a-z0-9_]+)=(true|false)",r.stdout));expected=set(re.findall(r'check\("([a-z0-9_]+)"',(H/"cases.lua").read_text()));caseText=(H/"cases.lua").read_text()
 if a.case=="normal":expected={name for name in expected if not name.startswith("utility_guard_")}
 else:expected=set(re.findall(r'check\("([a-z0-9_]+)"',caseText[:caseText.index("local sawForage=false")]))|{name for name in expected if name.startswith("utility_guard_")}
 if a.case!="cancel":expected.discard("utility_guard_actual_native_cancel_release")
stable=pins=={str(x):sha(x)for x in inputs};status="PASS"if stable and r.returncode==0 and set(checks)==expected and all(v=="true"for v in checks.values())else"FAIL"
if a.control:
 if network:detector={"review-pump":"ordinary_review_disabled_no_lift","recipe-observation":"ordinary_review_installed_observation_refused","recipe-transfer":"ordinary_review_installed_mutation_refused"}.get(a.control)or ("ordinary_guard_parent_no_unauthorized_topology"if a.control=="network-parent"else"ordinary_guard_installed_admission_refused"if a.control=="installed-admission"else"ordinary_guard_installed_transfer_refused")
 else: detector={"obsolete-stop":"utility_obsolete_callbacks_preserve_successor","producer-callback":"utility_actual_finite_fuel_provider","purification-capacity":"utility_actual_water_conservation"}.get(a.control,"utility_guard_no_native_effect")
 status="DETECTED"if stable and omission and checks.get(detector)=="false"else"UNDETECTED"
write(out,{"schema":"sao-d323-native-utility-consumer/1","status":status,"required":a.required,"control":a.control,"ownedInputs":[str(v)for v in ownedInputs],"nativeInputs":[str(v)for v in nativeInputs],"scenario":a.case,"utilityScenario":a.scenario,"consumerQualified":a.case=="normal"and status=="PASS","detectingOmission":omission,"checks":checks,"expected":sorted(expected),"inputStable":stable,"pins":pins,"compilePins":compilePins,"compileCommand":commandCompile,"compileExit":compileExit,"reusedCompilation":reused,"sourceFreezeSHA":sha(freezePath)if freezePath else None,"sourceReleaseSHA":sha(releasePath)if releasePath else None,"releasedPublicPins":freeze["pins"]if freeze else{str(v.relative_to(S)):sha(v)for v in owned},"instrumentation":instrumentation,"javaDiagnosticInstrumentation":javaInstrumentation,"classPins":{str(x.relative_to(classes)):sha(x)for x in classes.rglob("*.class")},"command":command,"exitCode":r.returncode,"logSha256":sha(out/"run.log"),"ownedPackagePins":packagePins,"loaderBindings":loaderBindings,"selectedHousehold":str(selectedHousehold),"capturedFiles":{x.name:sha(x)for x in captured},"projections":{x.name:sha(x)for x in out.glob("*.json")if x.name!="receipt.json"},"boundary":"Actual isolated ordinary utility consumer/body/native effect with explicit route/clock/animation/network/bootstrap ports. Normal and negative scenarios separate; primitive native/table save only, no fullworld reload/server/training/whole D3 claim."})
print(status,len(checks),"/",len(expected),"exit",r.returncode,"stable",stable);print((r.stdout+r.stderr)[-7000:]);sys.exit(0 if status in("PASS","DETECTED")else 1)
