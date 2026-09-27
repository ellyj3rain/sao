"""Owned pharmacology against installed native items/bodies and Lua actions."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tempfile


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--candidate',type=Path)
    parser.add_argument('--integration',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args()
    root=args.root.resolve();base=(args.candidate or root).resolve()
    out=(args.output or base/'_scratch/pharmacology').resolve();out.mkdir(parents=True,exist_ok=True)
    game=Path(os.environ.get('PZ_GAME','C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
    jdk=Path(os.environ.get('JAVA_HOME','C:/Users/jleyv/Peanut Butter/JetBrains/Java'))/'bin'
    jar=game/'projectzomboid.jar'
    if not jar.is_file() or not (jdk/'javac.exe').is_file() or not (jdk/'java.exe').is_file():
        print('  203) SKIPPED pharmacology: installed engine and JDK required');return 0
    here=base/'tools/pharmacology_checks';lua=base/'mod/42.20/media/lua'
    production=lua/'shared/SAO_Pharmacology.lua'
    sources=[root/'tools/world_lab/TransferUiChecks.lua',
        game/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
        game/'media/lua/client/ISUI/ISInventoryPaneContextMenu.lua',
        *[game/('media/lua/shared/TimedActions/'+n+'.lua') for n in
          ('ISEatFoodAction','ISTakePillAction','ISDrinkFluidAction','ISTakeWaterAction')],
        here/'prelude.lua',root/'mod/42.20/media/lua/shared/SAO_Hash.lua',
        lua/'shared/SAO_Habits.lua',lua/'shared/SAO_PharmacologyProfiles.lua']
    needs=(args.integration/'SAO_Needs.lua' if args.integration else root/'mod/42.20/media/lua/client/SAO_Needs.lua').resolve()
    neuro=(args.integration/'SAO_Neuro.lua' if args.integration else root/'mod/42.20/media/lua/shared/SAO_Neuro.lua').resolve()
    metabolism=(args.integration/'SAOHibernation.java' if args.integration else root/'java/src/com/sao/engine/SAOHibernation.java').resolve()
    needs_java=(args.integration/'SAONeeds.java' if args.integration else root/'java/src/com/sao/engine/SAONeeds.java').resolve()
    dormant=(args.integration/'SAO_DormantPopulation.lua' if args.integration else root/'mod/42.20/media/lua/client/SAO_DormantPopulation.lua').resolve()
    tail=[needs,neuro,dormant,lua/'client/SAO_Drugs.lua',
        *sorted((game/'media/lua/server/Items').glob('Distribution_*.lua')),
        game/'media/lua/server/Items/ProceduralDistributions.lua',
        lua/'server/Items/SAO_PharmacologyLoot.lua',here/'native.lua']
    definitions=base/'mod/42.20/media/scripts/items_SAO_pharmacology.txt'
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    receipt={'schema':'sao-owned-pharmacology-check/1','inputs':{str(p):sha(p) for p in
        [*sources,*tail,production,definitions,metabolism,needs_java,here/'PharmacologyProbe.java',jar]},'variants':[]}
    controls=[]
    def control(name,before,after,marker,target=production,count=1):
        controls.append((name,target,before,after,marker,count))
    control('external-runtime-required','if not r or not r.awake then return end',
        'if not BenzoEffect or not r or not r.awake then return end','sedative_native_effect')
    control('dose-check-removed','if not ok or not finite(after) or after<0 or after>=token.beforeUses\n        or token.beforeUses-after~=1 then',
        'if not ok or not finite(after) then','unconsumed_native_action_refused')
    control('completion-refusal-ignored','if completed~=true or token.body~=body',
        'if token.body~=body','native_failure_censored')
    control('sleep-ignored','if not r or not r.awake then return end','if not r then return end','sleep_suppresses_active_packets')
    control('maintenance-clock-ignored','if not frozen then f.counter=math.min(2880,f.counter+1) end',
        'f.counter=math.min(2880,f.counter+1)','maintenance_pauses_dependency')
    control('overload-ignored','return threshold and s.families[key].amount>threshold or false','return false','overload_native_effect')
    control('duplicate-cursor-reset','local finish=math.min(target,s.minute+MAX_MINUTES)\n    local r=receiver',
        's.minute=math.max(0,s.minute-1)\n    local finish=math.min(target,s.minute+MAX_MINUTES)\n    local r=receiver','same_minute_no_replay')
    control('pain-effect-omitted','        r.painOff()','        -- omitted','pain_suppression_native_receiver')
    control('history-unbounded','if #s.events>HISTORY_LIMIT then','if false then','history_bounded_with_loss_count')
    control('id-only-owner','owner.active[rec.id]==body','owner.active[rec.id]~=nil','stale_shell_capture_refused')
    control('foreign-token-ignored','and md.SAOExternalToken==rec.bodyOwnerToken','and true','foreign_token_refused')
    control('captured-token-ignored','or token.ownerToken~=(rec.bodyOwnerToken or false)',
        'or false','changed_token_completion_refused',count=2)
    control('foreign-driver-omitted','for id,body in pairs(SAO.Body.foreign) do visit(id,body) end',
        '-- omitted','foreign_loaded_driver',lua/'client/SAO_Drugs.lua')
    control('world-reset-omitted','lastTenMinutes=nil;lastOneMinute=nil','-- omitted',
        'world_reset_no_old_interval',lua/'client/SAO_Drugs.lua')
    control('sensitivity-ignored','local paranoid=s.paranoid==true','local paranoid=false','owned_sensitivity_native_effect')
    control('native-loot-omitted','if not present then','if false then','native_loot_registration',lua/'server/Items/SAO_PharmacologyLoot.lua')
    control('native-loot-duplicated','if not present then','if true then','loot_reload_no_weight_duplication',lua/'server/Items/SAO_PharmacologyLoot.lua')
    control('start-refusal-ignored','if not self.saoPharmacologyToken then','if false then',
        'unready_start_refuses_native_use',needs)
    control('pre-completion-clock-ignored','if not ok or ready ~= true then','if false then',
        'unready_completion_refuses_native_use',needs)
    control('current-item-owner-ignored','and token.item:getOutermostContainer()==body:getInventory()',
        'and true','moved_dose_refuses_native_completion')
    control('replay-uses-mutated-origin','original.stats=copy(d.origin.stats)','original.stats=copy(d.stats)',
        'restored_native_effect')
    control('dependency-history-repeated','dependency(historyRec,work,key,minute,r,minute<=s.minute)',
        'dependency(historyRec,work,key,minute,r,false)','replay_dependency_history_exact_once')
    control('settled-dormancy-minute-loop','if not hasInfluence(s) then','if false then',
        'settled_dormancy_fast_forwards')
    control('first-checkpoint-migration-lost','if first then','if false then','first_checkpoint_retains_legacy_state')
    control('native-fault-ignored','if s.fault then return false,"effect-reconciliation-required" end',
        '-- fault ignored','native_fault_does_not_replay',count=2)
    control('drink-without-consumption','or not (before.amount > after and after >= 0) then return end',
        'or false then return end','callback_without_fluid_loss_not_counted',needs)
    control('drink-repeated-history','self.saoDrinkObserved = true','self.saoDrinkObserved = false',
        'partial_then_complete_not_recounted',needs)
    control('water-counted-as-alcohol','and SAOJavaBridge:isAlcoholicDrink(item)','and true',
        'native_water_not_alcohol',needs)
    control('last-fluid-classified-too-late','local after = before.fluid:getAmount()',
        'local after = before.fluid:getAmount()\n            if not SAOJavaBridge:isAlcoholicDrink(before.item) then return end',
        'last_alcohol_fluid_counted',needs)
    control('changed-drink-owner-ignored','or not SAO.Pharmacology.ownsBody(before.rec, before.body) then return end',
        'or false then return end','changed_owner_drink_not_attributed',needs)
    if args.baseline_only:controls=[]
    with tempfile.TemporaryDirectory(prefix='sao-owned-pharma-') as raw:
        work=Path(raw);shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua')
        cp=os.pathsep.join(map(str,[jar,game/'ZombieBuddy.jar',root/'mod/42.20/media/java/SAO.jar']))
        result=subprocess.run([str(jdk/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(work),
            str(root/'tools/luacheck/MovementCrossingProbe.java'),str(root/'tools/luacheck/ResourceApproachProbe.java'),
            str(metabolism),str(needs_java),str(here/'PharmacologyProbe.java')],capture_output=True,text=True,encoding='utf-8',timeout=120)
        (out/'compile.log').write_text(result.stdout+result.stderr,encoding='utf-8')
        assert result.returncode==0,result.stdout+result.stderr
        for label,target,before,after,marker,expected_count in [('production',production,None,None,None,0),*controls]:
            value=target.read_text(encoding='utf-8')
            if before:
                assert value.count(before)==expected_count,(label,value.count(before));value=value.replace(before,after)
            source=work/(label+'.lua');source.write_text(value,encoding='utf-8')
            chosen=[source if p==target else p for p in [*sources,production,*tail]]
            result=subprocess.run([str(jdk/'java.exe'),'-Duser.home='+str(work),'-Djava.awt.headless=true',
                '-Dstdout.encoding=UTF-8','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,
                'PharmacologyProbe',str(game),str(definitions),*map(str,chosen)],
                cwd=work,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
            text=result.stdout+result.stderr;(out/(label+'.log')).write_text(text,encoding='utf-8')
            if marker:assert result.returncode!=0 and 'PHARMA:'+marker in text,(label,text[-7000:])
            else:assert result.returncode==0 and 'PASS owned pharmacology ' in text,text[-12000:]
            receipt['variants'].append({'name':label,'exit':result.returncode,'expected':marker,'target':str(target),
                'variantSha256':sha(source),
                'cases':sum(line.startswith('CASE ') and line.endswith('=true') for line in text.splitlines()),
                'logSha256':hashlib.sha256(text.encode()).hexdigest()})
            print(label+': '+next((line for line in reversed(text.splitlines()) if 'VALUE ' in line or 'PHARMA:' in line),text[-200:]),flush=True)
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print('  203) PASS -- owned pharmacology; native cases and defect controls above')
    return 0

if __name__=='__main__':raise SystemExit(main())
