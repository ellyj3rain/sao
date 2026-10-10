#!/usr/bin/env python3
"""D3.6 installed timed machinery/reading, actual generator/fluid/power effects and owned custody.

Native objects, items, fluid amounts, activation power propagation and literature
learning are installed Java. Lua body/map/queue dispatch and sounds/network are
controlled receivers; separate native source proof qualifies bridge geometry.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'tools/native_proof_preflight.py'
if not HELPER.is_file():
    print('FAILED D3.6 native machinery: owned proof inputs absent: '+str(HELPER));raise SystemExit(1)
from native_proof_preflight import presence, causal_controls, installed_path
GAME=installed_path(os.environ.get('PZ_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=installed_path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
LUA=ROOT/'mod/42.20/media/lua'
PROBE=ROOT/'tools/resource_production_checks/GeneratorNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/generator_cases.lua'
BASE=ROOT/'tools/luacheck/window_repair_cases.lua'
BOARD=ROOT/'tools/luacheck/d3_native_boarding_cases.lua'
PLUMB=ROOT/'tools/resource_production_checks/plumbing_cases.lua'
METADATA=ROOT/'tools/d2_leisure_materials/metadata.java.inc'
CONTROLLER=LUA/'client/SAO_Controller.lua'
LEAVES={name:LUA/f'{area}/SAO_{leaf}.lua' for name,area,leaf in [
    ('sources','shared','WorldSources'),('perception','shared','Perception'),('models','shared','CognitiveModels'),
    ('cognition','shared','Cognition'),('labor','shared','Labor'),('planner','shared','ProceduralPlanning'),('production','client','ResourceProduction'),
    ('generator','client','Generator'),('study','client','Study'),('experience','client','CapabilityExperience')]}
NATIVE=[GAME/p for p in [
    'media/lua/shared/ISBaseObject.lua','media/lua/shared/TimedActions/ISBaseTimedAction.lua',
    'media/lua/client/TimedActions/ISTimedActionQueue.lua','media/lua/shared/TimedActions/ISEquipWeaponAction.lua',
    'media/lua/client/TimedActions/ISInventoryTransferAction.lua','media/lua/shared/TimedActions/ISPlumbItem.lua',
    'media/lua/shared/TimedActions/ISTakeWaterAction.lua','media/lua/shared/TimedActions/ISFixGenerator.lua',
    'media/lua/shared/TimedActions/ISAddFuel.lua','media/lua/shared/TimedActions/ISPlugGenerator.lua',
    'media/lua/shared/TimedActions/ISActivateGenerator.lua','media/lua/client/TimedActions/ISGeneratorInfoAction.lua',
    'media/lua/shared/TimedActions/ISReadABook.lua']]
SCRIPTS=[GAME/'media/scripts/generated/items'/p for p in ['normal.txt','literature.txt']]

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def controller_reading_join(source):
    begin='function Ctl.generatorContext'
    end='-- Retained private prerequisites'
    assert source.count(begin)==1 and source.count(end)==1
    functions=begin+source.split(begin,1)[1].split(end,1)[0]
    begin='    if Ctl.preemptStudyForCoordination(id, agent, body) then return end'
    end='    if decideCompany(id, agent, body, tick) then return end'
    assert source.count(begin)==1 and source.count(end)==1
    idle=begin+source.split(begin,1)[1].split(end,1)[0]
    return ('local Ctl=SAO.Controller\nlocal tickCount=0\n'
        'local setState=function(agent,id,state,reason) agent.state=state;agent.reason=reason;return true end\n'
        'local advanceCoordination=function() return false end\n'
        'Ctl.preemptStudyForCoordination=function() return false end\n'
        'Ctl.resourceContext=function() return {sources={}} end\n'
        'Ctl.advanceResourcePurpose=function() return false end\nCtl.advanceResidencePurpose=function() return false end\n'
        +functions+'\nfunction __generatorOrdinaryTick(id,agent,body,tick,needs)\ntickCount=tick\n'+idle+'\nend\n')
def sources(reading_controller=False):
    chunks={'base.lua':BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()',1)[0],
        'boarding-fixture.lua':BOARD.read_text(encoding='utf-8-sig')+'\n__boardingFixture=fixture;__boardingItem=item;__boardingInventory=inventory\n'}
    chunks.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(NATIVE)})
    chunks['plumbing-fixture.lua']=PLUMB.read_text(encoding='utf-8-sig').split('function __runPlumbingControl',1)[0]+'\n__plumbingFixture=fixture\n'
    chunks['generator-fixture.lua']=CASES.read_text(encoding='utf-8-sig')
    chunks.update({name+'.lua':p.read_text(encoding='utf-8-sig') for name,p in LEAVES.items()})
    if reading_controller:chunks['controller-join.lua']=controller_reading_join(CONTROLLER.read_text(encoding='utf-8-sig'))
    return chunks
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--required',action='store_true');ap.add_argument('--baseline-only',action='store_true')
    ap.add_argument('--reading-controller-only',action='store_true')
    ap.add_argument('--review-corrections-only',action='store_true')
    ap.add_argument('--selection-only',action='store_true')
    args=ap.parse_args()
    helpers=[ROOT/'tools/luacheck'/p for p in ['MovementCrossingProbe.java','ResourceApproachProbe.java','LuaSyntax.java']]
    jar=ROOT/'mod/42.20/media/java/SAO.jar'
    owned=[Path(__file__),HELPER,PROBE,CASES,BASE,BOARD,PLUMB,METADATA,jar,*helpers,*LEAVES.values()]
    if args.reading_controller_only:owned.append(CONTROLLER)
    installed=[*NATIVE,*SCRIPTS,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',
        *[GAME/'media/scripts/generated'/p for p in ['fluids.txt','fluids_Beverages.txt','fluids_Alcoholic.txt']]]
    absent=presence(owned,installed,args.required,'D3.6 native machinery')
    if absent is not None:return absent
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    jars=[jar,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',*sorted((GAME/'jars').glob('*.jar'))]
    inputs=list(dict.fromkeys(owned+installed+jars))
    receipt={'schema':'sao-d36-native-machinery/1','status':'INCOMPLETE','boundary':__doc__,
        'inputsBefore':{str(p):sha(p) for p in inputs},'runs':[],'controls':[]}
    if args.reading_controller_only:
        receipt['scope']='Actual extracted Controller generator dispatch + ordinary Study/IDLE gates; actual native reading -> same utility next stage. State setter and unrelated context/coordination/resource ports are controlled. Original native60/5 evidence reused for unchanged producers.'
    if args.review_corrections_only:
        receipt['scope']='PR147 Study queue admission/loss/ACK, retained native generator selection before cap, persisted identity routing and reached native-state reassessment. Original native60/5 and reading3/1 producer evidence reused; installed effects are unchanged.'
    if args.selection_only:
        receipt['scope']='Inspected indoor utility exclusion, optional repair with executable required fuel/connect/activate alternatives, and exact rejected generator fingerprints filtered before cap. Actual private native facts/Planner/installed stages; unchanged native guard evidence reused.'
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def run(name,command,work):
        done=subprocess.run(list(map(str,command)),cwd=work,capture_output=True,timeout=90)
        log=out/(name+'.log');log.write_bytes(done.stdout+done.stderr)
        receipt['runs'].append({'name':name,'exitCode':done.returncode,'logSha256':sha(log)});save()
        return done.returncode,log.read_text(encoding='utf-8',errors='replace')
    save()
    try:
        metadata=METADATA.read_text();anchor='definition.Load(name,text.substring(match.start(),end));';assert metadata.count(anchor)==1
        metadata=metadata.replace(anchor,'var modField=ScriptManager.class.getDeclaredField("currentLoadFileMod");modField.setAccessible(true);Object oldMod=modField.get(null);modField.set(null,"fixture-installed-source");try{definition.setModID("fixture-installed-source");definition.InitLoadPP(name);'+anchor+'}finally{modField.set(null,oldMod);}',1)
        generated=out/PROBE.name;generated.write_text(PROBE.read_text().replace('    METADATA',metadata,1))
        with tempfile.TemporaryDirectory(prefix='sao-generator-native-') as temporary:
            work=Path(temporary);shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
            code,log=run('syntax',[JDK/'java.exe','-cp',str(work)+os.pathsep+cp,'LuaSyntax',CASES,*LEAVES.values()],work);assert code==0,log
            chunks=sources(args.reading_controller_only)
            def execute(name,variant,entry):
                directory=out/name;directory.mkdir();paths=[]
                for filename,source in variant.items():
                    p=directory/filename;p.write_text(source,encoding='utf-8');paths.append(p)
                p=directory/'run.lua';p.write_text(entry);paths.append(p)
                return run(name,[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Duser.home='+str(work),'-Djava.awt.headless=true',
                    '-cp',str(work)+os.pathsep+cp,'GeneratorNativeProbe',GAME,*paths],work)
            entry='__runGeneratorSelectionCases()' if args.selection_only else '__runGeneratorReviewCases()' if args.review_corrections_only else '__runGeneratorReadingControllerCases()' if args.reading_controller_only else '__runGeneratorCases()'
            code,log=execute('baseline',chunks,entry)
            checks=dict(re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M));receipt['checks']=checks;save()
            count=7 if args.selection_only else 9 if args.review_corrections_only else 3 if args.reading_controller_only else 60
            marker='PASS generator selection 7' if args.selection_only else 'PASS generator review 9' if args.review_corrections_only else 'PASS generator reading Controller 3' if args.reading_controller_only else 'PASS generator native 60'
            assert code==0 and len(checks)==count and all(v=='true' for v in checks.values()) and marker in log,log
            if not args.baseline_only:
                mutations=[
                    ('native-payment','generator.lua','rt.inventory:getFirstTypeRecurse("ElectronicsScrap")~=rt.input','false','changed_native_payment_refused'),
                    ('pending-ack','generator.lua','if not retired(rt) or r~=rt.record','if false or r~=rt.record','pending_native_ack_retained'),
                    ('consumer-return','generator.lua','verification and SAO.WorldSources.generatorConsumerTarget(body,step.consumer)',
                        'false and SAO.WorldSources.generatorConsumerTarget(body,step.consumer)','return_to_reached_consumer'),
                    ('native-reading','study.lua','local result=ISReadABook.complete(self)','local result=true','native_manual_learns_generator'),
                    ('captured-runtime-retirement','generator.lua','if child.action.action then pcall(function() child.action:forceStop() end)',
                        'if false then pcall(function() child.action:forceStop() end)','saved_generator_interrupt_no_replay'),
                ]
                if args.reading_controller_only:
                    mutations=[('restore-unhandled-study-state','controller-join.lua',
                        'setState(agent,id,"IDLE","reads an exact generator manual',
                        'setState(agent,id,"STUDY","reads an exact generator manual','controller_native_reading_resumes_same_utility')]
                if args.review_corrections_only:
                    mutations=[
                        ('omit-refused-reading-retirement','study.lua','generatorReading.interrupt(id,body,"native-reading-queue-refused")',
                            'generatorReading.finish(id,"interrupted","native-reading-queue-refused")','unqueued_reading_refusal_retires'),
                        ('omit-lost-reading-queue-check','study.lua','or not generatorReading.ownsQueue(active)','or false','disappeared_reading_waits_native_ack'),
                        ('omit-retained-generator-prefilter','generator.lua','source:sub(1,2)=="J:" and retained',
                            'source:sub(1,2)=="J:"','retained_native_generator_survives_cap_and_save_order'),
                        ('omit-reached-reinspection','generator.lua','verification and "verify-power" or "inspect")',
                            'verification and "verify-power" or rt.operation)','saved_fuel_drift_reobserves_and_replans'),
                    ]
                if args.selection_only:
                    mutations=[
                        ('omit-indoor-purpose-filter','generator.lua','and (row.inspected~=true or row.outside==true)',
                            'and true','inspected_indoor_generator_excluded'),
                        ('omit-required-stage-alternative','generator.lua',
                            'if known.inspected and not known.active and known.condition>0 and known.condition<=50 and #out<8 then',
                            'if false then','optional_repair_does_not_block_fuel'),
                        ('omit-rejected-fingerprint-filter','generator.lua','and rejected[source]~=row.fingerprint',
                            'and true','rejected_generators_filtered_before_cap'),
                    ]
                for name,file,old,new,marker in mutations:
                    variant=dict(chunks);assert variant[file].count(old)==1,(name,variant[file].count(old));variant[file]=variant[file].replace(old,new,1)
                    function='__runGeneratorSelectionControl' if args.selection_only else '__runGeneratorReviewControl' if args.review_corrections_only else '__runGeneratorReadingControllerControl' if args.reading_controller_only else '__runGeneratorControl'
                    code,log=execute(name,variant,function+"('"+marker+"')")
                    detected=code==0 and 'CHECK '+marker+'=false' in log
                    receipt['controls'].append({'name':name,'detector':marker,'detected':detected});save();assert detected,(name,log)
                if not args.reading_controller_only and not args.review_corrections_only and not args.selection_only:
                    receipt['preflightControls']=causal_controls(ROOT,Path(__file__),owned,child_args=['--out','proof'],missing_owned=PROBE)
            receipt['inputsAfter']={str(p):sha(p)for p in inputs};receipt['sourcePreserved']=receipt['inputsBefore']==receipt['inputsAfter']
            assert receipt['sourcePreserved'],'input pin changed during proof'
            receipt['status']='PASS';save();print('PASS D3.6 native machinery: '+str(len(checks))+' cases; '+str(len(receipt['controls']))+' controls');print(out/'receipt.json');return 0
    except Exception as error:
        receipt['status']='FAIL';receipt['error']=str(error);save();print('FAIL D3.6 native machinery: '+str(error)[-4000:]);return 1
if __name__=='__main__':raise SystemExit(main())
