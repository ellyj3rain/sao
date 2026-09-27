from pathlib import Path
import hashlib, json, os, shutil, subprocess, tempfile
import re
HERE=Path(__file__).resolve().parent
from config import ROOT, OUT, GAME, JDK, COOKING_JAVA
CONTROLS = [
    ('stale-current-square-approach', 'IsoGridSquare target = SAOWorldSources.interactionSquare(body, square);', 'IsoGridSquare target = body.getCurrentSquare();', 'fresh_approach_center_is_standable_and_within_strict_reach'),
    ('unbounded-reapproach', 'if (distance(body, square) > APPROACH_RANGE * APPROACH_RANGE) return null;', '', 'reapproach_is_locally_bounded'),
    ('detached-appliance-reapproach', 'public static KahluaTable approach(IsoPlayer body, IsoObject object, ItemContainer container) {\n        int index = attachedContainerIndex(body, object, container);', 'public static KahluaTable approach(IsoPlayer body, IsoObject object, ItemContainer container) {\n        int index = 0;', 'removed_appliance_cannot_supply_reapproach'),
    ('loosen-native-inspection-reach', 'if (index < 0 || !SAONeeds.containerAccessibleNow(body, container)) return null;', 'if (index < 0) return null;', 'small_displacement_requires_physical_return'),
    ('iterator-backed-object-copy',
     'var objects = square.getObjects();\n                for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {\n                    IsoObject object = objects.get(objectIndex);',
     'for (IsoObject object : new ArrayList<>(square.getObjects())) {',
     'native_object_collection_offers_appliance'),
    ('setter-is-thermal-proof', '\n                || food.getCookingTime() <= food.getMinutesToCook()', '', 'fake_cooked_write_rejected'),
    ('repeated-completion-xp', 'if (credit == null) {', 'if (true) {', 'completion_xp_once'),
    ('ignore-body-owner-token', '|| !java.util.Objects.equals(value.ownerToken(), body.getModData().rawget("SAOExternalToken"))', '', 'changed_owner_token_refused'),
    ('ignore-actor-identity', '|| !value.actor().equals(String.valueOf(body.getModData().rawget("SAOPersonId")))', '', 'changed_actor_identity_refused'),
    ('ignore-intervening-chef', '|| food.getModData().rawget(CREDIT) == null && food.getChef() != null', '', 'intervening_chef_change_refused'),
    ('ignore-body-attachment', ' && body.isExistInTheWorld()', '', 'detached_body_refused'),
    ('disable-replacement-foods', 'return item instanceof Food food && food.isCookable()', 'return item instanceof Food food && food.isCookable() && food.getReplaceOnCooked() == null', 'ordinary_replacement_food_may_be_prepared'),
    ('consume-result-from-removed-appliance', '|| inspect(body, value.appliance().get(), container) == null', '', 'small_displacement_requires_physical_return'),
]
def main():
    sources=[COOKING_JAVA,ROOT/'tools/luacheck/MovementCrossingProbe.java',
        ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java',HERE/'CookingProbe.java']
    jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    receipt={'boundary':'Installed native bodies, Food.update, stove, physical native containers, XP and item save/load; controlled cell fixture, no game/render loop.',
        'inputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources+jars},'runs':[],'controls':[]}
    with tempfile.TemporaryDirectory(prefix='native-') as directory:
        work=Path(directory);shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
        cp=os.pathsep.join(map(str,jars))
        def run(label, command):
            done=subprocess.run(list(map(str,command)),cwd=work,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
            receipt['runs'].append({'name':label,'exit':done.returncode,'stdout':done.stdout,'stderr':done.stderr})
            (OUT/'native-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
            print(label,done.returncode,done.stdout[-1500:] if done.returncode or label=='native' else '',done.stderr[-1500:],flush=True)
            return done
        done=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*sources])
        if done.returncode:return 1
        done=run('native',[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
            '-cp',str(work)+os.pathsep+cp,'CookingProbe',GAME])
        if done.returncode or 'COOKING_NATIVE_OK' not in done.stdout: return 1
        receipt['cases']=len(re.findall(r'^CHECK [a-z0-9_]+=true$',done.stdout,re.M))
        baseline=(COOKING_JAVA).read_text(encoding='utf-8')
        for label,before,after,target in CONTROLS:
            if baseline.count(before)!=1: raise RuntimeError(label+': mutation anchor must match exactly once')
            changed=baseline.replace(before,after,1)
            folder=work/label;folder.mkdir();path=folder/'SAOCooking.java';path.write_text(changed,encoding='utf-8')
            done=run(label+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',folder,path])
            if done.returncode: return 1
            done=run(label,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                '-cp',str(folder)+os.pathsep+str(work)+os.pathsep+cp,'CookingProbe',GAME])
            if done.returncode==0 or 'CHECK '+target+'=false' not in done.stdout:
                raise RuntimeError(label+': named target did not fail: '+target)
            receipt['controls'].append({'name':label,'target':target,'source_sha256':hashlib.sha256(changed.encode()).hexdigest(),'verdict':'false'})
        receipt['status']='passed'
        (OUT/'native-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        print('PASSED',receipt['cases'],'native checks;',len(receipt['controls']),'defect controls')
        return 0
if __name__=='__main__':raise SystemExit(main())
