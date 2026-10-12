#!/usr/bin/env python3
"""Native demand, private source acquisition and retained requesting work."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys

ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA=ROOT/'mod/42.20/media/lua'
CHECKS=ROOT/'tools/recipe_consumer_checks'
JAVA=[ROOT/'java/src/com/sao/engine/SAOWorldSources.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java',
 ROOT/'tools/recipe_ingredient_checks/RecipeIngredientNativeProbe.java',ROOT/'tools/luacheck/MovementCrossingProbe.java',
 ROOT/'tools/recipe_policy_checks/RecipePolicyNativeProbe.java',CHECKS/'BenchConsumerNativeSetup.java']
NATIVE=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
 GAME/'media/lua/client/TimedActions/ISTimedActionQueue.lua',GAME/'media/lua/shared/TimedActions/ISTransferAction.lua',
 GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
 GAME/'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua',
 GAME/'media/lua/shared/TimedActions/ISTakeWaterAction.lua',GAME/'media/lua/client/TimedActions/ISGrabItemAction.lua']
OWNED=[LUA/'shared/SAO_Ordering.lua',LUA/'shared/SAO_Identity.lua',LUA/'client/SAO_Body.lua',LUA/'shared/SAO_Places.lua',LUA/'shared/SAO_Perception.lua',LUA/'shared/SAO_Material.lua',
 LUA/'shared/SAO_RecipePolicy.lua',LUA/'shared/SAO_WorldSources.lua',LUA/'shared/SAO_CognitiveModels.lua',LUA/'shared/SAO_Cognition.lua',
 LUA/'shared/SAO_ProceduralPlanning.lua',LUA/'shared/SAO_GraphPersistence.lua',LUA/'shared/SAO_Provisioning.lua',
 LUA/'client/SAO_Needs.lua',LUA/'client/SAO_SourceUse.lua',
 LUA/'client/SAO_ResourceProduction.lua',LUA/'client/SAO_Controller.lua',LUA/'client/SAO_CapabilityExperience.lua']
CONTROLS={
 'dead-demand':('SAO_ProceduralPlanning.lua','return rec~=nil and not rec.dead and p~=nil','return rec~=nil and p~=nil','consumer_dead_private_demand_refused'),
 'definition-demand':('SAO_ProceduralPlanning.lua',' and req.sourceRevision==demand.sourceRevision','','consumer_foreign_definition_demand_refused'),
 'current-stock':('SAO_ProceduralPlanning.lua','current.requestedStockAvailable==true','true','consumer_historical_stock_not_current'),
 'original-request':('SAO_ProceduralPlanning.lua','tostring(p.recipeSupply.productionAttempt or 1)','tostring(rec.resourceProductionSequence or 0)','consumer_original_request_identity_retained'),
 'ingredient-feedback':('SAO_Perception.lua','and receipt.category ~= "water" and not ingredient)','and receipt.category ~= "water")','consumer_actual_transfer_and_private_result'),
 'canonical-feedback':('SAO_Cognition.lua','if not canonical or not sameData(canonical,receipt) then return false,"recipe-owner-unavailable" end','if not canonical then return false,"recipe-owner-unavailable" end','consumer_forged_native_feedback_refused'),
 'remembered-source':('SAO_ProceduralPlanning.lua','if possible and (fact.kind=="container" or fact.kind=="ground")','if false and (fact.kind=="container" or fact.kind=="ground")','consumer_private_remembered_source_approach'),
 'request-retirement':('SAO_ProceduralPlanning.lua','elseif p.admission==nil then\n       p.status="abandoned";p.resolvedAt=c.atHours;own.retiredByWorkId=c.id','elseif false then\n       p.status="abandoned";p.resolvedAt=c.atHours;own.retiredByWorkId=c.id','consumer_other_stock_retires_supplier_without_use_credit'),
 'refill-deficit':('SAO_Controller.lua','metric=="uses" and row.currentUses or metric and row[metric]','metric and row[metric]','consumer_measured_private_refill_deficit'),
 'prospective-bench':('SAO_ResourceProduction.lua','prospectiveWorkstation=true','prospectiveWorkstation=false','consumer_free_native_bench_private_ready'),
 'feasibility-scoring':('SAO_ProceduralPlanning.lua','novelty=0,informationGain=.2,blockers=option.ready and 0 or 1,','novelty=0,informationGain=.2,blockers=option.ready and 0 or 1,\n     utility=(deficit or .5)+(tonumber(context.pressure) or 0)*.25,','consumer_free_native_bench_private_ready'),
 'unavailable-platform':('SAOWorldSources.java','public static synchronized Object recipeUpkeepDemands(SAOIsoPlayerShell body) {\n        try {\n            var out = recipeTable();','public static synchronized Object recipeUpkeepDemands(SAOIsoPlayerShell body) {\n        var out = recipeTable();\n        try {','unavailable_platform_upkeep_refused'),
}
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True)
 p.add_argument('--required',action='store_true',help='Fail when installed native inputs are unavailable.')
 p.add_argument('--reuse-classes',type=Path,help='Reuse retained compiled classes after exact source/dependency/executable verification.')
 p.add_argument('--control',choices=CONTROLS,help='Private single omission; its named behavioral detector must fail.')
 a=p.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);classes=out/'classes';classes.mkdir()
 inputs=[Path(__file__),CHECKS/'prelude.lua',CHECKS/'cases.lua',*JAVA,*NATIVE,*OWNED,GAME/'projectzomboid.jar',
  GAME/'ZombieBuddy.jar',ROOT/'java/dist/SAOAgent.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',Path(sys.executable)]
 owned=[Path(__file__),CHECKS/'prelude.lua',CHECKS/'cases.lua',*JAVA,*OWNED,ROOT/'java/dist/SAOAgent.jar']
 native=[*NATIVE,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',Path(sys.executable)]
 missing_owned=[str(v) for v in owned if not v.is_file()]
 missing_native=[str(v) for v in native if not v.is_file()]
 if missing_owned or missing_native:
  status='FAIL' if missing_owned else 'NATIVE_UNAVAILABLE'
  (out/'receipt.json').write_text(json.dumps({'schema':'sao-d3.19-native-private-consumer/1',
   'status':status,'missingOwned':missing_owned,'missingNative':missing_native,
   'required':a.required,'executedChecks':0,'boundary':'Unavailable inputs are not executed native proof.'},indent=2)+'\n',encoding='utf-8')
  print(status+' private native consumer inputs absent')
  return 1 if missing_owned or a.required else 0
 pins={str(v):digest(v) for v in inputs}
 cp=os.pathsep.join(map(str,[ROOT/'java/dist/SAOAgent.jar',GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']))
 compilation_sources=list(JAVA);java_control=None
 if a.control and CONTROLS[a.control][0].endswith('.java'):
  if a.reuse_classes:raise ValueError('a changed Java control requires its own compilation')
  filename,before,after,_=CONTROLS[a.control];source=next(v for v in JAVA if v.name==filename)
  content=source.read_text(encoding='utf-8-sig')
  if content.count(before)!=1:raise ValueError('Java control must replace exactly one source clause')
  java_control=out/filename;java_control.write_text(content.replace(before,after),encoding='utf-8')
  compilation_sources[compilation_sources.index(source)]=java_control
 command=[str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*map(str,compilation_sources)]
 compile_inputs=JAVA+[ROOT/'java/dist/SAOAgent.jar',GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',JDK/'javac.exe']
 reused=None
 if a.reuse_classes:
  previous=a.reuse_classes.resolve();old=json.loads((previous/'receipt.json').read_text())
  if old.get('compileExit')!=0 or not old.get('executables'):raise ValueError('retained compilation/executable provenance missing')
  if any(old['pins'].get(str(v))!=pins[str(v)] for v in compile_inputs):raise ValueError('compiled source/dependency changed')
  for name,sha in old['executables'].items():
   source=previous/'classes'/name
   target=classes/name
   if not source.resolve().is_relative_to((previous/'classes').resolve()) or not target.resolve().is_relative_to(classes.resolve()):
    raise ValueError('retained executable path leaves its compilation root')
   if digest(source)!=sha:raise ValueError('retained executable changed: '+name)
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
  compile_exit=0;reused={'receipt':str(previous/'receipt.json'),'sha256':digest(previous/'receipt.json')}
 else:
  compiled=subprocess.run(command,text=True,capture_output=True,timeout=90);(out/'compile.log').write_text(compiled.stdout+compiled.stderr)
  compile_exit=compiled.returncode
  if compile_exit:print(compiled.stdout+compiled.stderr);return 1
 selected=[CHECKS/'prelude.lua',*NATIVE,*OWNED,CHECKS/'cases.lua'];paths=[]
 for index,source in enumerate(selected):
  target=out/f'{index:02d}-{source.name}'
  content=source.read_text(encoding='utf-8-sig')
  if a.control and source.name==CONTROLS[a.control][0]:
   _,before,after,_=CONTROLS[a.control]
   if content.count(before)!=1:raise ValueError('control must replace exactly one source clause: '+a.control)
   content=content.replace(before,after)
  target.write_text('print("CONSUMER_LOADING",'+json.dumps(source.name)+')\n'+content,encoding='utf-8')
  paths.append(str(target))
 cmd=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-Djava.awt.headless=true',
  '-Djava.library.path='+str(GAME),'-Dsao.game='+str(GAME),'-cp',str(classes)+os.pathsep+cp,'RecipeIngredientNativeProbe',str(GAME),*paths]
 run=subprocess.run(cmd,cwd=GAME,text=True,capture_output=True,timeout=90);(out/'run.log').write_text(run.stdout+run.stderr)
 checks=dict(re.findall(r'CHECK (consumer_[a-z0-9_]+)=(true|false)',run.stdout));expected=set(re.findall(r'(?<![A-Za-z0-9_])check\("([a-z0-9_]+)"', (CHECKS/'cases.lua').read_text()))
 native_checks={k:v for k,v in re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',run.stdout) if not k.startswith('consumer_')}
 expected={'consumer_'+name for name in expected}
 receipt={'schema':'sao-d3.19-native-private-consumer/1','status':'PASS' if run.returncode==0 and set(checks)==expected and all(v=='true' for v in checks.values()) else 'FAIL',
  'pins':pins,'inputStable':pins=={str(v):digest(v) for v in inputs},'compileExit':compile_exit,'compileCommand':command,
  'reusedCompilation':reused,'executables':{str(v.relative_to(classes)):digest(v) for v in classes.rglob('*.class')},'exitCode':run.returncode,
  'checks':checks,'nativeObservationChecks':native_checks,'missing':sorted(expected-set(checks)),'command':cmd,'logSha256':digest(out/'run.log'),
  'capturedFiles':{str(v.relative_to(out)):digest(v) for v in out.glob('*.lua')},
  'projections':{str(v.relative_to(out)):digest(v) for v in out.glob('*.json') if v.name!='receipt.json'},
  'boundary':'Actual native shell/cell/record/items, signed native source inspection, native recipe/workplace ports and changed personal owners. Clock/Standing/unchanged locomotion and cadence endpoints, nonrendering texture metadata and native animation end are controlled isolated ports; no game/UI/deploy or learned-model claim.'}
 if not receipt['inputStable']:receipt['status']='FAIL'
 if a.control:
  detector=CONTROLS[a.control][3]
  receipt['control']={'name':a.control,'detector':detector,'mutation':CONTROLS[a.control][:3],
   'capturedSource':str(java_control if java_control else out/f'{selected.index(next(v for v in selected if v.name==CONTROLS[a.control][0])):02d}-{CONTROLS[a.control][0]}')}
  receipt['status']='DETECTED' if receipt['inputStable'] and (checks.get(detector)=='false' or native_checks.get(detector)=='false') else 'UNDETECTED'
 (out/'receipt.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
 print(receipt['status'],str(len(checks))+'/'+str(len(expected)), 'exit',run.returncode, 'receipt',out/'receipt.json')
 if receipt['status'] not in ('PASS','DETECTED'):print((run.stdout+run.stderr)[-6000:])
 return 0 if receipt['status'] in ('PASS','DETECTED') else 1
if __name__=='__main__':sys.exit(main())
