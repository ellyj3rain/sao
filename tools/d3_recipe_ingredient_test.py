#!/usr/bin/env python3
"""Native recipe ingredient/workplace observations; explicit controlled loaded scene and demand port."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys

ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
WORLD=ROOT/'java/src/com/sao/engine/SAOWorldSources.java'
BRIDGE=ROOT/'java/src/com/sao/bridge/SAOBridge.java'
PROBE=ROOT/'tools/recipe_ingredient_checks/RecipeIngredientNativeProbe.java'
SUPPORT=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/recipe_policy_checks/RecipePolicyNativeProbe.java']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--control',action='append');parser.add_argument('--lua',type=Path,action='append',default=[]);parser.add_argument('--required',action='store_true');args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    owned=[WORLD,BRIDGE,PROBE,*SUPPORT,Path(__file__),ROOT/'mod/42.20/media/lua/shared/SAO_WorldSources.lua',ROOT/'mod/42.20/media/lua/client/SAO_SourceUse.lua',ROOT/'mod/42.20/media/lua/client/SAO_Needs.lua',*args.lua]
    native=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'java/dist/SAOAgent.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',Path(sys.executable)]
    native+=sorted((GAME/'media/scripts/generated/items').glob('*.txt'))
    native+=[GAME/'media/scripts/generated/recipes'/name for name in ['recipes_fixing.txt','recipes.txt','recipes_carpentry.txt','recipes_metalWelding.txt','recipes_ammunition.txt']]
    # The shipping support JAR belongs to the repository, not optional game input.
    owned.append(ROOT/'java/dist/SAOAgent.jar')
    native.remove(ROOT/'java/dist/SAOAgent.jar')
    missing_owned=[str(p) for p in owned if not p.is_file()]
    missing_native=[str(p) for p in native if not p.is_file()]
    if missing_owned or missing_native:
        status='FAIL' if missing_owned else 'NATIVE_UNAVAILABLE'
        (out/'receipt.json').write_text(json.dumps({'schema':'sao-d3.19-recipe-ingredient-native/1',
            'status':status,'missingOwned':missing_owned,'missingNative':missing_native,
            'required':args.required,'executedChecks':0,'boundary':'Unavailable inputs are not executed native proof.'},indent=2)+'\n',encoding='utf-8')
        print(status+' recipe ingredient inputs absent')
        return 1 if missing_owned or args.required else 0
    before={str(p):digest(p) for p in owned+native}
    cp=os.pathsep.join(str(p) for p in [ROOT/'java/dist/SAOAgent.jar',GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar'])
    expected=set(re.findall(r'check\("([a-z0-9_]+)"',PROBE.read_text()))
    receipt={'schema':'sao-d3.19-recipe-ingredient-native/1','boundary':'Actual native shell/items/inspection/readonly recipe and workplace ports under controlled loaded map, item burn-threshold fixture and retained-demand callback. Optional Lua owns its additional boundary. No rendered/private-consumer completion inferred.','pins':before,'cases':len(expected),'normal':{},'controls':[]}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
    save()
    def execute(name,source):
        target=out/name;target.mkdir();classes=target/'classes';classes.mkdir();candidate=target/WORLD.name;candidate.write_text(source,encoding='utf-8')
        compile_command=[str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),str(candidate),str(BRIDGE),str(PROBE),*map(str,SUPPORT)]
        compiled=subprocess.run(compile_command,text=True,capture_output=True,timeout=90);(target/'compile.log').write_text(compiled.stdout+compiled.stderr)
        if compiled.returncode:return {'compileExit':compiled.returncode,'exitCode':None,'checks':{},'missing':sorted(expected),'failed':['compile']}
        command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(target),'-Djava.awt.headless=true','-Djava.library.path='+str(GAME),'-cp',str(classes)+os.pathsep+cp,'RecipeIngredientNativeProbe',str(GAME),*map(str,args.lua)]
        result=subprocess.run(command,cwd=GAME,text=True,capture_output=True,timeout=90);log=target/'run.log';log.write_text(result.stdout+result.stderr)
        checks=dict(re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',result.stdout))
        return {'compileExit':compiled.returncode,'exitCode':result.returncode,'checks':checks,'missing':sorted(expected-checks.keys()),'failed':sorted(k for k,v in checks.items() if v!='true'),'logSha256':digest(log),'command':command}
    original=WORLD.read_text(encoding='utf-8');receipt['normal']=execute('normal',original);save()
    if receipt['normal']['exitCode']!=0 or receipt['normal']['missing'] or receipt['normal']['failed']:
        print('FAIL normal',receipt['normal']['failed'],receipt['normal']['missing']);return 1
    variants=[
      ('declaration','!java.util.Objects.equals(declaration, input.getOriginalLine())','false','wrong_declaration_refused'),
      ('actual-knowledge','body.isRecipeActuallyKnown(recipe)','body.isRecipeKnown(recipe)','unlearned_native_mean_withheld'),
      ('exact-output','output.getPossibleResultItems()!=null && output.getPossibleResultItems().contains(item)) matches','output.containsItem(item)) matches','unrelated_native_producer_refused'),
      ('reservation','|| !recipeItemUnreserved(item.getID())','|| false','foreign_reservation_not_supply'),
      ('workplace-occupancy','|| object.getUsingPlayer() != null && object.getUsingPlayer() != body) return null;','|| false) return null;','foreign_occupied_workplace_refused'),
    ]
    for name,old,new,detector in variants:
        if args.control and name not in args.control:continue
        if old==new:continue
        assert old in original,name
        result=execute(name,original.replace(old,new));result.update(name=name,detector=detector,detected=result['checks'].get(detector)=='false');receipt['controls'].append(result);save();print(name+': '+str(result['detected']),flush=True)
    receipt['unchanged']=before=={str(p):digest(p) for p in owned+native};receipt['status']='PASS' if receipt['unchanged'] and all(c['detected'] for c in receipt['controls']) else 'FAIL';save()
    print(receipt['status']+' recipe ingredient '+str(receipt['cases'])+' native cases/'+str(len(receipt['controls']))+' detecting controls');return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':sys.exit(main())
