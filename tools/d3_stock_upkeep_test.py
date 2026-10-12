#!/usr/bin/env python3
"""Native registered stock/upkeep effects in the existing SAO craft capsule."""
import argparse,hashlib,json,os,re,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA=ROOT/'mod/42.20/media/lua'
POLICY=LUA/'shared/SAO_RecipePolicy.lua';PRODUCTION=LUA/'client/SAO_ResourceProduction.lua'
CHECKS=ROOT/'tools/stock_upkeep_checks'
BASE=ROOT/'tools/luacheck/window_repair_cases.lua'
PROBES=[ROOT/'tools/recipe_policy_checks/RecipePolicyNativeProbe.java',CHECKS/'StockUpkeepNativeProbe.java']
NATIVE=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
 GAME/'media/lua/client/TimedActions/ISTimedActionQueue.lua',GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
 GAME/'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def execute(out,classes,sources,expected):
 out.mkdir();shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
 for name,source in sources.items():
  p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
 cmd=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED',f'-Duser.home={out}',f'-Dsao.game={GAME}',
      '-cp',f'{GAME/"projectzomboid.jar"};{classes}','StockUpkeepNativeProbe',str(GAME),*paths]
 run=subprocess.run(cmd,cwd=out,text=True,capture_output=True,timeout=90)
 log=out/'output.log';log.write_text(run.stdout+run.stderr,encoding='utf-8')
 checks=dict(re.findall(r'CHECK (\w+)=(true|false)',run.stdout))
 return {'command':cmd,'exitCode':run.returncode,'checks':checks,'missing':sorted(expected-checks.keys()),
         'failed':sorted(k for k,v in checks.items() if v!='true'),'logSha256':digest(log)}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path);p.add_argument('--required',action='store_true');p.add_argument('--control',action='append');p.add_argument('--diagnostic',action='store_true');a=p.parse_args()
 owned=[Path(__file__),POLICY,PRODUCTION,LUA/'shared/SAO_Material.lua',LUA/'shared/SAO_WorldSources.lua',LUA/'client/SAO_SourceUse.lua',BASE,*PROBES,CHECKS/'fixture.lua',CHECKS/'cases.lua']
 native=[*NATIVE,GAME/'projectzomboid.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',Path(sys.executable)]
 native+=list((GAME/'media/scripts/generated/items').rglob('*.txt'))
 native += [GAME/'media/scripts/generated/recipes'/n for n in ['recipes.txt','recipes_fixing.txt','recipes_carpentry.txt','recipes_metalWelding.txt','recipes_ammunition.txt']]
 native += [GAME/'media/scripts/generated'/n for n in ['timedactions.txt','fluids.txt','energies.txt','entities/furniture/entity_carpentry_bed.txt','entities/blacksmith/workstations/entity_grindstone.txt']]
 missing_owned=[str(v) for v in owned if not v.is_file()]
 missing_native=[str(v) for v in native if not v.is_file()]
 if missing_owned or missing_native:
  failed=bool(missing_owned or a.required)
  status='FAIL' if missing_owned else 'NATIVE_UNAVAILABLE'
  print(status+' '+json.dumps({'missingOwned':missing_owned,'missingNative':missing_native,'required':a.required,'executedChecks':0}))
  return 1 if failed else 0
 temp=tempfile.TemporaryDirectory(prefix='sao-stock-') if not a.out else None
 out=Path(temp.name)/'proof' if temp else a.out.resolve()
 if out.exists():raise ValueError('refuse replacing previous proof')
 out.mkdir(parents=True);pins={str(v):digest(v) for v in owned+native};classes=out/'classes';classes.mkdir()
 cmd=[str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar'),'-d',str(classes),*map(str,PROBES)]
 compiled=subprocess.run(cmd,text=True,capture_output=True,timeout=90);(out/'compile.log').write_text(compiled.stdout+compiled.stderr)
 if compiled.returncode:print(compiled.stdout+compiled.stderr);return 1
 sources={'base.lua':BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()',1)[0]}
 sources['fixture.lua']=(CHECKS/'fixture.lua').read_text()
 for n,v in enumerate(NATIVE):sources[f'native-{n}.lua']=v.read_text(encoding='utf-8-sig')
 sources['action-ports.lua']='ISTakeWaterAction=ISBaseTimedAction:derive("ISTakeWaterAction")\n'
 for name,v in [('policy.lua',POLICY),('material.lua',LUA/'shared/SAO_Material.lua'),('sources.lua',LUA/'shared/SAO_WorldSources.lua'),('production.lua',PRODUCTION)]:sources[name]=v.read_text(encoding='utf-8-sig')
 sources['source-use.lua']=(LUA/'client/SAO_SourceUse.lua').read_text(encoding='utf-8-sig')
 sources['cases.lua']=(CHECKS/'cases.lua').read_text()
 if a.diagnostic:
  sources['production.lua']=sources['production.lua'].replace('local ok=pcall(start,self)','local ok,detail=pcall(start,self);print("NATIVE_START_DIAGNOSTIC",ok,detail)',1)
  sources['production.lua']=sources['production.lua'].replace('local ok=pcall(native,action)','local ok,detail=pcall(native,action);print("NATIVE_EFFECT_DIAGNOSTIC",ok,detail)',1)
 expected=set(re.findall(r'check\("(\w+)"',sources['cases.lua']))
 expected.discard('repair_family_')
 expected.update('repair_family_'+n for n in ['adhesive','zipties','glue','woodglue','epoxy_rags','whetstone','file_blade','small_replace','fix'])
 normal=execute(out/'normal',classes,sources,expected)
 controls=[]
 mutations=[('exact-requested-output','if possible and possible:contains(item) then return true end','if true then return true end','unrelated_stock_recipe_refused'),
  ('native-payment','destroyedNative=destroyed:contains(item)','destroyedNative=input:isDestroy()','missing_native_destroy_no_credit'),
  ('successor-retirement','or rt.queue:indexOf(self)~=-1 or rt.queue.current==self then\n            return craftRefuse(rt,"craft-complete-owner-changed")','or rt.queue:indexOf(self)~=-1 or rt.queue.current~=nil then\n            return craftRefuse(rt,"craft-complete-owner-changed")','successor_preserves_completion'),
  ('world-custody','custody=held and "held" or world and "world-unacquired" or "unconfirmed"','custody="held"','world_output_not_stock'),
  ('native-engine-result','return ok and c.enginePerformed==true','return ok','refused_engine_no_completion'),
  ('native-reservations','function WS.recipeInputAvailable(actorId,itemId)','function WS.recipeInputAvailable(actorId,itemId)\n    if true then return true end','current_input_reservation_refuse'),
  ('ingredient-state','return SAO.RecipePolicy and SAO.RecipePolicy.inputEligible(reservation.recipeRequirement,item,body)==true or false','return true','changed_native_ingredient_refuse'),
  ('station-claim','object:setUsingPlayer(rt.body)','return false','native_station_claimed'),
  ('historical-effect','return recipeWork.copy(rt.effectMeasurement) or recipeWork.measure(rt)','local measured=recipeWork.measure(rt); measured.measuredAt=rt.effectMeasurement and rt.effectMeasurement.measuredAt; return measured','consuming_successor_preserves_history'),
  ('requested-quantity','result.afterAvailableAmount>=demand.desiredAmount','result.afterAvailableAmount>=1','partial_stock_keeps_demand')]
 for name,old,new,detector in mutations:
  if a.control and name not in a.control:continue
  filename='sources.lua' if name=='native-reservations' else 'source-use.lua' if name=='ingredient-state' else 'production.lua'
  text=sources[filename];matches=text.count(old)
  if matches!=1:controls.append({'name':name,'detected':False,'matches':matches});continue
  variant=dict(sources);variant[filename]=text.replace(old,new,1);control=execute(out/name,classes,variant,expected)
  control.update(name=name,sourceFile=filename,detector=detector,detected=control['checks'].get(detector)=='false');controls.append(control)
 after={str(v):digest(v) for v in owned+native}
 passed=normal['exitCode']==0 and not normal['failed'] and not normal['missing'] and pins==after and all(c['detected'] for c in controls)
 receipt={'schema':'sao-d3-stock-upkeep-native/1','status':'PASS' if passed else 'FAIL','sourcePins':pins,'sourcePreserved':pins==after,'diagnosticInstrumented':a.diagnostic,
  'normal':normal,'controls':controls,'compile':{'command':cmd,'exitCode':compiled.returncode,'logSha256':digest(out/'compile.log')},
  'executables':{str(v):digest(v) for v in classes.glob('*.class')},
  'boundary':'Actual registered recipe metadata, exact native items/inventory/input allocation, native HandcraftLogic/CraftRecipeData/RecipeCodeOnCreate and installed Lua ISHandcraftAction/queue. Controlled Lua actor/map/action-end/animation/sound and native XP/knowledge/skills ports; body arguments explicitly forward to the native receiver. Private admission/consumer are controlled ports pending owner release. Real native world inventory objects record dropped output; acquisition remains unperformed. No attached game, shipping build, provider or consumer acceptance.'}
 (out/'receipt.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
 print(f'D3 stock/upkeep {receipt["status"]}: {len(normal["checks"])}/{len(expected)} cases; {sum(c["detected"] for c in controls)}/{len(controls)} controls')
 if not passed:print(normal['failed'],normal['missing'],[(c['name'],c['detected']) for c in controls]);print((out/'normal/output.log').read_text()[-5500:])
 print('receipt',out/'receipt.json')
 if temp:temp.cleanup()
 return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
