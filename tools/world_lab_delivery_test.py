#!/usr/bin/env python3
"""Border 198/210: saved Lua delivery and exact reviewed-error qualification.
Controlled disk/host fixture. No native launch or game/save mutation.
"""
from __future__ import annotations
import copy
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import types
from types import SimpleNamespace
from unittest.mock import patch

import world_lab as Lab
import world_lab_delivery as D
import world_lab_run as R
import world_lab_session as S

CHECKS = []
CONTROLS = []

def check(value, label):
    if not value: raise AssertionError(label)
    CHECKS.append(label)


def refused(fn, label, contains=None):
    try: fn()
    except (ValueError, OSError, AssertionError) as error:
        if contains and contains not in str(error): raise AssertionError(label + ': wrong refusal ' + str(error))
        CONTROLS.append(label)
    else: raise AssertionError(label + ': invalid candidate accepted')


def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(Lab.canonical(value) if not isinstance(value, bytes) else value)


def junction_checks(root):
    if os.name != 'nt':
        return  # Native junction coverage is provided by the Windows receipt.
    destination,receipt,logs,manifest,errors,update=fixture(root)
    junction=root/'linked-source';target=root/'source'
    before={p:p.read_bytes() for p in target.rglob('*') if p.is_file()}
    env=dict(os.environ,SAO_DELIVERY_JUNCTION_LINK=str(junction),SAO_DELIVERY_JUNCTION_TARGET=str(target))
    result=subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',
        "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path $env:SAO_DELIVERY_JUNCTION_LINK -Target $env:SAO_DELIVERY_JUNCTION_TARGET | Out-Null"],
        env=env,capture_output=True,text=True)
    if result.returncode:
        raise AssertionError('isolated junction creation failed: '+result.stderr)
    try:
        check(junction.is_junction() and not junction.is_symlink() and junction.resolve()==target.resolve(),
              'real Windows junction reproduces nonsymlink reparse ancestor')
        linked=junction/update['files'][0]['path']
        check(linked.is_file(),'junction-backed source is an existing regular target file')
        refused(lambda:D.file_path(linked),'real Windows junction ancestor refused','reparse ancestors')
        changed=copy.deepcopy(update);changed['files'][0]['source']=str(linked)
        put(root/'junction-update.json',changed)
        with patch.object(D,'process_live',return_value=False):
            refused(lambda:D.validate_update(destination,receipt,root/'junction-update.json'),
                    'actual source validation refuses junction-backed source','reparse ancestors')
        prior=Path.cwd()
        try:
            os.chdir(junction)
            check(Path.cwd()==junction,'Windows retains lexical junction cwd for relative-input control')
            refused(lambda:D.file_path(Path(update['files'][0]['path'])),
                    'relative source rejects junction cwd ancestor','reparse ancestors')
        finally:
            os.chdir(prior)
        check(D.file_path(target/update['files'][0]['path'])==(target/update['files'][0]['path']).resolve(),
              'ordinary nonlinked source remains admitted')
    finally:
        # Remove only this verified fixture link. Never recurse through its target.
        assert junction.parent.resolve()==root.resolve() and junction.is_junction()
        assert junction.resolve()==target.resolve()
        junction.rmdir()
    check(not junction.exists() and all(p.read_bytes()==data for p,data in before.items()),
          'junction cleanup removes only fixture link and preserves every target byte')


def fixture(root):
    destination = root / 'run'; attempt = destination / 'attempts/0002'
    cache = destination / 'cache'
    for name in D.FILES:
        put(cache/'mods'/D.MOD/name, ('old '+name).encode())
        put(root/'source'/name, ('new '+name).encode())
    put(cache/'mods'/D.MOD/'42.20/media/java/SAO.jar', b'unchanged-jvm')
    put(cache/'mods/StudyMap/42.20/media/lua/client/ZZStudyLaunch.lua', b'old-bootstrap')
    put(cache/'mods/StudyMap/mod.info', b'study-map')
    put(cache/'mods/default.txt', b'original-mod-order')
    put(cache/'options.ini', b'original-renderer')
    put(destination/'StudyLoadingAgent.jar', b'observer')
    put(cache/'Saves/Sandbox/123/global_mod_data.bin', b'people:sao-1,sao-2;injury:80.37;history:preserved')
    put(cache/'Saves/Sandbox/123/mods.txt', b'original-mod-order')
    manifest = {'fixture': 'package', 'mapName':'StudyMap','definitionSha256':'d'*64}
    mods = {D.MOD: {str(p.relative_to(cache/'mods'/D.MOD)).replace('\\','/'):D.digest(p)
                   for p in (cache/'mods'/D.MOD).rglob('*') if p.is_file()},
            'StudyMap': {'mod.info':D.digest(cache/'mods/StudyMap/mod.info')}}
    observations = {}
    for seq in (84,85):
        p=cache/f'Lua/StudyWorld/123/session/{seq:016d}.json'
        put(p, {'sequence':seq,'hours':12+(seq-84)/4,'save':'123','mods':list(mods)})
        observations[p.relative_to(cache).as_posix()]=D.digest(p)
    logs={'stdout.log':'LOG f:0 startup\nLOG f:8 progressed\n', 'stderr.log':'ERROR: General f:0 known fixture startup\n'+''.join(
        f'ERROR: General      f:{8+i} at CellLoader.DoTileObjectCreation     > CellLoader> missing tile vegetation_groundcover_01_{tile}\n'
        for i,tile in enumerate((18,23,19,22,21)))}
    for name,text in logs.items(): put(attempt/name,text.encode())
    receipt={'schema':'sao-study-run/1','status':'completed','datasetAdmission':'unreviewed','exitCode':0,
       'runtimeErrors':[],'packageSha256':Lab.seal(manifest),'mapName':'StudyMap','mods':mods,
       'loadingAgentSha256':D.digest(destination/'StudyLoadingAgent.jar'),
       'launchSha256':D.digest(cache/'mods/StudyMap/42.20/media/lua/client/ZZStudyLaunch.lua'),
       'mapDependency':None,'nativeImages':{},'host':'observer','observerEvidence':{'state':{'residencyX':1,'residencyY':1,'residencyZ':0}},
       'saveFiles':{p.relative_to(cache).as_posix():D.digest(p) for p in (cache/'Saves').rglob('*') if p.is_file()},
       'observations':observations,'player':{'count':0},'launchNumber':2,'sessionId':'11111111-1111-4111-8111-111111111111',
       'save':'123','pid':99999999,'engineJarSha256':'e'*64,'logs':{n:D.digest(attempt/n) for n in logs},
       'hours':1,'watch':True,'terminal':{'startHours':12.,'endHours':12.3,'nativeSaveReturned':True},
       'inspection':{'fixture':True},'observationFiles':2,'lastSequence':85,'lastHours':12.25,
       'supervision':{'forced':False,'failure':None}}
    put(destination/'run.json',receipt);put(attempt/'report.json',receipt)
    evidence=root/'CellLoader.bytecode.txt'
    put(evidence,b'DoTileObjectCreation hasNoTextures media/ui/missing-tile-debug.png media/ui/missing-tile.png')
    errors={'schema':D.ERROR_SCHEMA,'predecessor':D.binding(receipt,D.digest(destination/'run.json')),
            'engineJarSha256':receipt['engineJarSha256'],'errors':D.error_rows(logs,True),
            'evidence':{'path':str(evidence),'sha256':D.digest(evidence)}}
    put(root/'reviewed-errors.json',errors)
    update={'schema':D.UPDATE_SCHEMA,'predecessor':errors['predecessor'],'modId':D.MOD,'files':[
       {'path':name,'source':str(root/'source'/name),'beforeSha256':mods[D.MOD][name],
        'afterSha256':D.digest(root/'source'/name)} for name in sorted(D.FILES)]}
    put(root/'update.json',update)
    return destination,receipt,logs,manifest,errors,update


def run_checks(root):
    destination, receipt, logs, manifest, errors, update = fixture(root)
    error_path, update_path = root/'reviewed-errors.json',root/'update.json'
    original = (destination/'run.json').read_bytes()
    with patch.object(D,'process_live',return_value=False):
        disposition = D.reviewed_errors(destination,receipt,error_path,logs,[])
        check(disposition['disposition']==D.DISPOSITION and len(disposition['allLogErrors'])==6,
              'qualified result retains complete log errors and says reviewed errors')
        check((destination/'run.json').read_bytes()==original,'error qualification leaves original verdict untouched')
        check(D.validate_update(destination,receipt,update_path)==update,'exact two-file predecessor validates')
        for label,change in (
            ('missing-file',lambda v:v['files'].pop()),
            ('extra-file',lambda v:v['files'].append(dict(v['files'][0]))),
            ('unrelated-file',lambda v:v['files'][0].update(path='42.20/media/lua/client/SAO_Controller.lua')),
            ('path-escape',lambda v:v['files'][0].update(path='../save.bin')),
            ('old-hash',lambda v:v['files'][0].update(beforeSha256='0'*64)),
            ('new-hash',lambda v:v['files'][0].update(afterSha256='0'*64)),
            ('wrong-attempt',lambda v:v['predecessor'].update(attempt=1)),
            ('wrong-save',lambda v:v['predecessor'].update(save='456')),
            ('wrong-receipt',lambda v:v['predecessor'].update(receiptSha256='0'*64))):
            changed=copy.deepcopy(update);change(changed);put(root/'bad-update.json',changed)
            refused(lambda:D.validate_update(destination,receipt,root/'bad-update.json'),label)
        for label,change in (
            ('changed-error',lambda v:v['errors'][0].update(text=v['errors'][0]['text']+' other')),
            ('missing-error',lambda v:v['errors'].pop()),
            ('duplicate-error',lambda v:v['errors'].append(v['errors'][0])),
            ('changed-error-line',lambda v:v['errors'][0].update(line=999)),
            ('wrong-error-predecessor',lambda v:v['predecessor'].update(attempt=3)),
            ('changed-evidence',lambda v:v['evidence'].update(sha256='0'*64))):
            changed=copy.deepcopy(errors);change(changed);put(root/'bad-errors.json',changed)
            refused(lambda:D.reviewed_errors(destination,receipt,root/'bad-errors.json',logs,[]),label)
        extra=dict(logs);extra['stderr.log']+='ERROR: Multiplayer f:34894> StateMachine.stateExecute> Exception thrown\n'
        refused(lambda:D.reviewed_errors(destination,receipt,error_path,extra,[]),'actual lunge exception is not groundcover')
        changed=copy.deepcopy(errors);changed['errors']=D.error_rows(extra,True);put(root/'bad-errors.json',changed)
        refused(lambda:D.reviewed_errors(destination,receipt,root/'bad-errors.json',extra,[]),'cannot bless new exception by listing it')
        refused(lambda:D.reviewed_errors(destination,receipt,error_path,logs,['observer evidence: failed']),
                'unreviewed observer failure')
        for key,value in (('status','running'),('exitCode',1),('terminal',{'nativeSaveReturned':False}),
                          ('supervision',{'forced':True,'failure':None})):
            changed=copy.deepcopy(receipt);changed[key]=value
            refused(lambda:D.saved_boundary(changed),'unsaved boundary '+key)
        with patch.object(D,'process_live',return_value=True):
            refused(lambda:D.validate_update(destination,receipt,update_path),'native still alive')
        # Exercise the actual verifier around real input/save/observation hashes.
        # Native parsing/package construction are existing independently tested seams.
        with patch.object(Lab,'verify_package',return_value=(manifest,{'observation':{'everyHours':.25}})), \
             patch.object(R.ObserverLayout,'from_receipt',return_value=None), \
             patch.object(R,'observer_evidence',return_value=receipt['observerEvidence']), \
             patch.object(R,'saved_state',return_value=receipt['player']), \
             patch.object(R,'terminal',return_value=receipt['terminal']), \
             patch.object(Lab,'inspect_frames',return_value=receipt['inspection']):
            refused(lambda:R.verify_run(destination,root),'default verifier does not report clean success with groundcover')
            check(R.verify_run(destination,root,error_path)==receipt,'qualified verifier preserves original receipt')
            save=destination/'cache/Saves/Sandbox/123/global_mod_data.bin'; prior=save.read_bytes();save.write_bytes(b'healed')
            refused(lambda:R.verify_run(destination,root,error_path),'save mutation still rejected')
            save.write_bytes(prior)
            jar=destination/'cache/mods'/D.MOD/'42.20/media/java/SAO.jar';prior=jar.read_bytes();jar.write_bytes(b'changed')
            refused(lambda:R.verify_run(destination,root,error_path),'unrelated gameplay jar still rejected')
            jar.write_bytes(prior)
        # Actual staged mutation, provenance verification, failed prelaunch rollback.
        before={p:p.read_bytes() for p in (destination/'cache').rglob('*') if p.is_file()}
        next_attempt=destination/'attempts/0003'
        def failed_launch():
            with D.resume_guard(destination, gameplay=True):
                next_attempt.mkdir(); successor=copy.deepcopy(receipt)
                D.retain_review(destination,next_attempt,receipt,successor,error_path,disposition)
                D.apply_update(destination,next_attempt,receipt,successor,update_path)
                D.verify_history(destination,successor)
                check(all(D.digest(destination/'cache/mods'/D.MOD/r['path'])==r['afterSha256'] for r in update['files']),
                      'only staged reviewed Lua bytes activate')
                raise OSError('injected Popen failure')
        refused(failed_launch,'prelaunch failure', 'injected Popen failure')
        check(all(p.read_bytes()==v for p,v in before.items()) and (destination/'run.json').read_bytes()==original,
              'failed prelaunch restores cached sources and original receipt; save untouched')
        check(len(list((destination/'delivery-failures').iterdir()))==1 and not next_attempt.exists(),
              'failed transition evidence retained under distinct directory')
        with D.resume_guard(destination, gameplay=True) as custody:
            refused(lambda:enter_guard(destination),'second resume owner excluded')
            next_attempt.mkdir(); successor=copy.deepcopy(receipt)
            D.apply_update(destination,next_attempt,receipt,successor,update_path)
            D.retain_review(destination,next_attempt,receipt,successor,error_path,disposition)
            custody['nativeStarted']=True
        D.verify_history(destination,successor)
        check(all((destination/'cache'/p).read_bytes()==before[destination/'cache'/p] for p in receipt['saveFiles']),
              'successful source transition preserves every save byte including people injury history')
        check((next_attempt/'gameplay-lua-update/previous-run.json').read_bytes()==original,
              'predecessor receipt retained byte-for-byte')
        changed=copy.deepcopy(successor);changed['mods'][D.MOD]['42.20/media/java/SAO.jar']='0'*64
        refused(lambda:D.verify_history(destination,changed),'provenance cannot cover unrelated JVM pin')
        retained=next_attempt/'gameplay-lua-update/before'/update['files'][0]['path']
        retained.write_bytes(b'changed')
        refused(lambda:D.verify_history(destination,successor),'retained predecessor Lua tamper')
        # Host forwarding and qualification are independent; no automatic allowance.
        args=SimpleNamespace(package=root,out=root,game=root,jdk=root,window='hidden',refresh_observer_adapter=False,
           gameplay_lua_update=update_path,reviewed_errors=error_path,mod=[],profile=None)
        command=S.runner_command(args,True,30)
        check(command[command.index('--gameplay-lua-update')+1]==str(update_path)
              and command[command.index('--reviewed-errors')+1]==str(error_path), 'host forwards distinct explicit manifests')
        command=S.runner_command(args,False,30)
        check('--gameplay-lua-update' not in command and '--reviewed-errors' not in command,
              'new-run command never receives continuation manifests')
        state=S.new_state('Saved fixture',30,False);state.update(status='failed',attempt=2)
        path=root/'study-session.json';S.atomic(path,state)
        S.recover_failed_save(path,state,receipt,qualified=True)
        check(state['status']=='saved' and state['lastStopReason']=='saved-with-reviewed-errors',
              'host exposes qualified saved boundary visibly')
        credited=state['accumulatedWorldHours'];state['status']='failed';state['canContinue']=False
        S.recover_failed_save(path,state,receipt,qualified=True)
        check(state['accumulatedWorldHours']==credited,
              'failed prelaunch requalification never credits same native attempt twice')
        ordinary=S.new_state('Ordinary saved',30,False)
        ordinary.update(status='saved',attempt=2,worldHours=receipt['lastHours'],accumulatedWorldHours=10.3,
                        canContinue=True)
        ordinary.update(status='failed',canContinue=False)
        S.recover_failed_save(path,ordinary,receipt,qualified=True)
        check(ordinary['accumulatedWorldHours']==10.3,
              'normally credited saved predecessor remains once-only after failure')
        stale=S.new_state('Stale host cursor',30,False);stale.update(status='failed',attempt=1)
        S.recover_failed_save(path,stale,receipt,qualified=True)
        credited=stale['accumulatedWorldHours'];stale.update(status='failed',canContinue=False)
        S.recover_failed_save(path,stale,receipt,qualified=True)
        check(stale['attempt']==2 and stale['accumulatedWorldHours']==credited,
              'late-preparation stale host cursor is advanced before any credit retry')
    # A later exception after a real owner is admitted cannot restore active bytes.
    active=root/'active';active.mkdir();dest,rec,*_=fixture(active)
    target=dest/'cache/mods'/D.MOD/next(iter(D.FILES))
    try:
        with D.resume_guard(dest, gameplay=True) as custody:
            target.write_bytes(b'active-source');custody['nativeStarted']=True
            raise RuntimeError('postlaunch owner failure')
    except RuntimeError: pass
    check(target.read_bytes()==b'active-source','postlaunch failure never rolls back an active owner')
    legacy=root/'legacy';legacy.mkdir();dest,rec,*_=fixture(legacy)
    rec['host']='player';put(dest/'run.json',rec)
    for name in D.FILES:(dest/'cache/mods'/D.MOD/name).unlink()
    with D.resume_guard(dest): pass
    check(True,'ordinary player resume guard does not require population delivery files')
    source=Path(S.__file__).read_text(encoding='utf-8')
    before='elapsed = 0 if callback or credited or state["status"] == "saved" else max(0, terminal["endHours"] - terminal["startHours"])'
    after='elapsed = max(0, terminal["endHours"] - terminal["startHours"]) if state["status"] == "failed" else 0'
    check(source.count(before)==1,'credit regression control identifies exact production calculation')
    mutant=types.ModuleType('duplicate_credit_control');mutant.__file__=S.__file__
    exec(compile(source.replace(before,after),'<duplicate-credit-control>','exec'),mutant.__dict__)
    state=mutant.new_state('Credit control',30,False);state.update(status='failed',attempt=2)
    mutant.recover_failed_save(root/'credit-control.json',state,rec,qualified=True)
    expected=state['accumulatedWorldHours'];state.update(status='failed',canContinue=False)
    mutant.recover_failed_save(root/'credit-control.json',state,rec,qualified=True)
    refused(lambda:check(state['accumulatedWorldHours']==expected,'double-credit mutant survived'),
            'old elapsed-credit implementation fails retry assertion','double-credit mutant survived')


def actual_runner_checks(root, runner=R, profile=None, subset=False):
    destination,receipt,logs,manifest,errors,update=fixture(root)
    if profile is not None:
        for name in D.PROFILES[profile]:
            put(destination/'cache/mods'/D.MOD/name,('old '+name).encode())
            put(root/'source'/name,('new '+name).encode())
            receipt['mods'][D.MOD][name]=D.digest(destination/'cache/mods'/D.MOD/name)
        update['profile']=profile
        update['schema']=D.SOURCE_UPDATE_SCHEMA if profile=='d1-shared-reasoning' else D.UPDATE_SCHEMA
        update['files']=[{'path':name,'source':str(root/'source'/name),
                          'beforeSha256':receipt['mods'][D.MOD][name],
                          'afterSha256':D.digest(root/'source'/name)}
                         for name in sorted(D.PROFILES[profile])]
        if subset:
            update['schema']=D.SOURCE_SUBSET_SCHEMA
            update['files']=[row for row in update['files'] if row['path'].endswith('/SAO_ConceptKnowledge.lua')]
    put(root/'game/projectzomboid.jar',b'fixture-engine')
    receipt['engineJarSha256']=D.digest(root/'game/projectzomboid.jar')
    put(destination/'run.json',receipt);put(destination/'attempts/0002/report.json',receipt)
    for path,value in ((root/'reviewed-errors.json',errors),(root/'update.json',update)):
        value['predecessor']=D.binding(receipt,D.digest(destination/'run.json'))
        if path.name=='reviewed-errors.json':value['engineJarSha256']=receipt['engineJarSha256']
        put(path,value)
    before={p:p.read_bytes() for p in destination.rglob('*') if p.is_file()}
    definition={'observation':{'everyHours':.25,'sites':[]},
                'origins':[{'profession':'unemployed','x':1,'y':1,'z':0}],
                'extent':{'minCellX':0,'minCellY':0,'cellsX':1,'cellsY':1}}
    args=SimpleNamespace(package=root,out=destination,game=root/'game',jdk=root/'jdk',resume=True,
       host='observer',mod=[],profile=None,enable_mod=[],disable_mod=[],replace_dead_player=False,
       refresh_observer_adapter=profile=='d1-shared-reasoning',observer_layout=None,video_encoder=None,
       gameplay_lua_update=root/'update.json',reviewed_errors=root/'reviewed-errors.json',
       hours=1,timeout=30,watch=True,window='hidden',trace_native=False)
    def popen_failure(*unused,**kwargs):
        check(all(D.digest(destination/'cache/mods'/D.MOD/r['path'])==r['afterSha256'] for r in update['files']),
              'actual runner activates exact Lua before native admission')
        current=Lab.load(destination/'run.json')
        check(current['status']=='starting' and current['launchNumber']==3 and current['save']=='123',
              'actual runner retains save and declares successor attempt')
        D.verify_history(destination,current)
        if profile=='d1-shared-reasoning':
            check((destination/'StudyLoadingAgent.jar').read_bytes()==b'controlled-refreshed-observer',
                  'actual source runner composes separate observer refresh before admission')
        raise OSError('injected native Popen refusal')
    def observer_refresh(destination,attempt,game,jdk,previous,current):
        put(destination/'StudyLoadingAgent.jar',b'controlled-refreshed-observer')
        current['loadingAgentSha256']=D.digest(destination/'StudyLoadingAgent.jar')
    with patch.object(D,'process_live',return_value=False), \
         patch.object(Lab,'verify_package',return_value=(manifest,definition)), \
         patch.object(runner.ObserverLayout,'select',return_value=None), \
         patch.object(runner.ObserverLayout,'from_receipt',return_value=None), \
         patch.object(runner,'observer_evidence',return_value=receipt['observerEvidence']), \
         patch.object(runner,'saved_state',return_value=receipt['player']), \
         patch.object(runner,'terminal',return_value=receipt['terminal']), \
         patch.object(Lab,'inspect_frames',return_value=receipt['inspection']), \
         patch.object(runner,'prepare_renderer'), \
         patch.object(runner,'refresh_attempt_adapter',side_effect=observer_refresh), \
         patch.object(runner.Supervision,'owned_child',side_effect=popen_failure):
        try:runner.run(args)
        except OSError as error:check('injected native Popen refusal' in str(error),'actual native launch refusal preserved: '+str(error))
        else:raise AssertionError('fixture launched native unexpectedly')
    check(all(p.read_bytes()==data for p,data in before.items()),
          'actual runner Popen failure restores predecessor cache and original receipt')


def lunge_checks(root):
    destination,receipt,logs,manifest,errors,update=fixture(root)
    evidence_root=root/'lunge';evidence_root.mkdir()
    stack=json.loads((Path(__file__).parent/'world_lab/delivery_lunge_stack.json').read_text(encoding='utf-8'))['text'].encode('utf-8')
    check(hashlib.sha256(stack).hexdigest()==D.LUNGE_STACK_SHA256,'lunge fixture is the retained exact installed stack')
    put(evidence_root/'exception-stack.txt',stack)
    logs['stderr.log']+=stack.decode('utf-8').replace('\r\n','\n')
    put(destination/'attempts/0002/stderr.log',logs['stderr.log'].encode())
    receipt.update(status='incomplete',runtimeErrors=list(D.LUNGE_ERRORS))
    receipt['logs']['stderr.log']=D.digest(destination/'attempts/0002/stderr.log')
    put(destination/'run.json',receipt);put(destination/'attempts/0002/report.json',receipt)
    original=(destination/'run.json').read_bytes()
    # Controlled bytecode-evidence metadata exercises admission and byte pins;
    # the real installed bundle is independently reviewed and checked at --verify.
    classes=[]
    for name in ('zombie.ai.StateMachine','zombie.ai.states.LungeState','zombie.characters.IsoGameCharacter',
                 'zombie.characters.IsoZombie','zombie.iso.IsoMovingObject','zombie.iso.IsoDirections'):
        filename=name.rsplit('.',1)[-1]+'.javap.txt';put(evidence_root/filename,('fixture '+name).encode())
        classes.append({'class':name,'bytecodeFile':filename,'bytecodeSha256':D.digest(evidence_root/filename),'exitCode':0})
    put(evidence_root/'bytecode-inputs.json',{'jarSha256':receipt['engineJarSha256'],'classes':classes})
    diagnosis={'schema':'sao.native-lunge-diagnosis/1','status':'ANALYZED_WITH_QUALIFICATIONS',
       'sessionId':receipt['sessionId'],'attempt':receipt['launchNumber'],'save':receipt['save'],
       'engineJarSha256':receipt['engineJarSha256'],'originalVerdict':'incomplete',
       'incident':{'frame':34894,'episodesInRetainedStderr':1,'runtimeErrorRows':list(D.LUNGE_ERRORS),
          'stackFile':'exception-stack.txt','stackSha256':D.LUNGE_STACK_SHA256,'stderrSha256':receipt['logs']['stderr.log']},
       'bytecodeInputsFile':'bytecode-inputs.json','bytecodeInputsSha256':D.digest(evidence_root/'bytecode-inputs.json'),
       'recommendation':{'limitations':['controlled metadata; actual engine diagnosis is separate evidence']}}
    put(evidence_root/'receipt.json',diagnosis)
    errors.update(predecessor=D.binding(receipt,D.digest(destination/'run.json')),errors=D.error_rows(logs,True),
                  lungeIncident={'path':str(evidence_root/'receipt.json'),'sha256':D.digest(evidence_root/'receipt.json')})
    path=root/'reviewed-errors.json';put(path,errors)
    with patch.object(D,'process_live',return_value=False):
        disposition=D.reviewed_errors(destination,receipt,path,logs,list(D.LUNGE_ERRORS))
        check(disposition['originalStatus']=='incomplete' and disposition['originalRuntimeErrors']==list(D.LUNGE_ERRORS)
              and (destination/'run.json').read_bytes()==original,'lunge qualification preserves incomplete verdict and exact runtime errors')
        for label,change in (
           ('lunge engine mismatch',lambda v:v.update(engineJarSha256='0'*64)),
           ('changed lunge diagnosis pin',lambda v:v['lungeIncident'].update(sha256='0'*64)),
           ('missing lunge diagnosis',lambda v:v.pop('lungeIncident'))):
            changed=copy.deepcopy(errors);change(changed);put(root/'bad-lunge.json',changed)
            refused(lambda:D.reviewed_errors(destination,receipt,root/'bad-lunge.json',logs,list(D.LUNGE_ERRORS)),label)
        for label,text in (
           ('changed lunge frame',logs['stderr.log'].replace('f:34894','f:34895')),
           ('absent exact lunge stack',logs['stderr.log'].replace('LungeState.java:76','LungeState.java:77')),
           ('additional lunge episode',logs['stderr.log']+stack.decode('utf-8').replace('\r\n','\n')),
           ('new observer error',logs['stderr.log']+'ERROR: Observer f:39000> new failure\n')):
            changed=dict(logs);changed['stderr.log']=text
            refused(lambda:D.reviewed_errors(destination,receipt,path,changed,list(D.LUNGE_ERRORS)),label)
        refused(lambda:D.reviewed_errors(destination,receipt,path,logs,[*D.LUNGE_ERRORS,'observer evidence: failed']),
                'lunge cannot absorb producer failure')
        with patch.object(Lab,'verify_package',return_value=(manifest,{'observation':{'everyHours':.25}})), \
             patch.object(R.ObserverLayout,'from_receipt',return_value=None), \
             patch.object(R,'observer_evidence',return_value=receipt['observerEvidence']), \
             patch.object(R,'saved_state',return_value=receipt['player']), \
             patch.object(R,'terminal',return_value=receipt['terminal']), \
             patch.object(Lab,'inspect_frames',return_value=receipt['inspection']):
            refused(lambda:R.verify_run(destination,root),'incomplete lunge remains rejected without explicit disposition')
            check(R.verify_run(destination,root,path)==receipt,'actual verifier admits only explicit qualified incomplete lunge')
        successor=copy.deepcopy(receipt);attempt=destination/'attempts/0003';attempt.mkdir()
        D.retain_review(destination,attempt,receipt,successor,path,disposition)
        D.verify_history(destination,successor)
        check((attempt/'reviewed-errors/previous-run.json').read_bytes()==original,
              'successor retains failed original report and separate lunge evidence')
        retained=attempt/'reviewed-errors/lunge-incident/exception-stack.txt';retained.write_bytes(b'tampered')
        refused(lambda:D.verify_history(destination,successor),'retained lunge evidence tamper')


def enter_guard(destination):
    with D.resume_guard(destination, gameplay=True): pass


def profile_checks(root):
    destination, receipt, logs, manifest, errors, legacy = fixture(root)
    for name in D.PROFILES['private-threat-contacts']:
        put(destination/'cache/mods'/D.MOD/name, ('old '+name).encode())
        put(root/'source'/name, ('new '+name).encode())
        receipt['mods'][D.MOD][name] = D.digest(destination/'cache/mods'/D.MOD/name)
    put(destination/'run.json', receipt)
    update = {'schema':D.UPDATE_SCHEMA, 'profile':'private-threat-contacts',
              'modId':D.MOD, 'predecessor':D.binding(receipt,D.digest(destination/'run.json')),
              'files':[{'path':name, 'source':str(root/'source'/name),
                        'beforeSha256':receipt['mods'][D.MOD][name],
                        'afterSha256':D.digest(root/'source'/name)}
                       for name in sorted(D.PROFILES['private-threat-contacts'])]}
    path = root/'threat-update.json'; put(path,update)
    with patch.object(D,'process_live',return_value=False):
        check(D.validate_update(destination,receipt,path)==update,
              'private threat profile validates exact two retained predecessor files')
        for label, change in (
            ('threat paths need their named profile',lambda v:v.pop('profile')),
            ('unknown delivery profile',lambda v:v.update(profile='arbitrary-lua')),
            ('nonstring delivery profile',lambda v:v.update(profile=[])),
            ('threat profile refuses population paths',lambda v:v.update(files=copy.deepcopy(legacy['files']))),
            ('mixed profile paths',lambda v:v['files'][0].update(path=sorted(D.FILES)[0])),
            ('duplicate profile file',lambda v:v['files'].__setitem__(1,copy.deepcopy(v['files'][0]))),
            ('third profile file',lambda v:v['files'].append(copy.deepcopy(legacy['files'][0]))),
            ('nonrecord profile row',lambda v:v['files'].__setitem__(0,'not-a-file-record')),
            ('unexpected profile field',lambda v:v.update(allowOtherFiles=True))):
            bad=copy.deepcopy(update);change(bad);put(root/'bad-profile.json',bad)
            refused(lambda:D.validate_update(destination,receipt,root/'bad-profile.json'),label)
        original={p:p.read_bytes() for p in (destination/'cache/mods'/D.MOD).rglob('*') if p.is_file()}
        original_run=(destination/'run.json').read_bytes()
        try:
            with D.resume_guard(destination,gameplay=True):
                attempt=destination/'attempts/0003';attempt.mkdir()
                successor=copy.deepcopy(receipt)
                D.apply_update(destination,attempt,receipt,successor,path)
                check(all(D.digest(destination/'cache/mods'/D.MOD/row['path'])==row['afterSha256']
                          for row in update['files']), 'named threat profile actually stages both new bytes')
                check(all((destination/'cache/mods'/D.MOD/name).read_bytes()==original[destination/'cache/mods'/D.MOD/name]
                          for name in D.FILES), 'threat update preserves both population repair inputs')
                D.verify_history(destination,successor)
                check(len(successor['gameplayLuaUpdates'])==1, 'threat update retains verifiable source manifest and predecessor')
                raise ValueError('controlled prelaunch failure')
        except ValueError as error:
            if str(error)!='controlled prelaunch failure':raise
        else:raise AssertionError('controlled failure did not execute')
        check(all(p.read_bytes()==content for p,content in original.items()),
              'prelaunch rollback restores threat files and preserves all population/JVM bytes')
        check((destination/'run.json').read_bytes()==original_run,
              'named threat transition leaves predecessor verdict unchanged after rollback')
        check(not (destination/'attempts/0003').exists() and any((destination/'delivery-failures').iterdir()),
              'failed threat transition retains provenance outside active next attempt')


def d1_source_checks(root):
    destination,receipt,logs,manifest,errors,update=fixture(root)
    profile='d1-shared-reasoning'
    for name in D.PROFILES[profile]:
        put(destination/'cache/mods'/D.MOD/name,('old '+name).encode())
        put(root/'source'/name,('new '+name).encode())
        receipt['mods'][D.MOD][name]=D.digest(destination/'cache/mods'/D.MOD/name)
    put(destination/'cache/mods/ZombieAwareness/42.20/media/java/ZAO.jar',b'unchanged-zao')
    put(destination/'run.json',receipt)
    update.update(schema=D.SOURCE_UPDATE_SCHEMA,profile=profile,
        predecessor=D.binding(receipt,D.digest(destination/'run.json')),
        files=[{'path':name,'source':str(root/'source'/name),'beforeSha256':receipt['mods'][D.MOD][name],
                'afterSha256':D.digest(root/'source'/name)} for name in sorted(D.PROFILES[profile])])
    path=root/'d1-update.json';put(path,update)
    before={p:p.read_bytes() for p in destination.rglob('*') if p.is_file()}
    with patch.object(D,'process_live',return_value=False):
        check(D.validate_update(destination,receipt,path)==update,'named D1 Lua and native JAR profile validates')
        check(all(p.read_bytes()==v for p,v in before.items()),'source validation does not activate or rewrite any bytes')
        for label,change in (
            ('D1 requires Java-bearing schema',lambda v:v.update(schema=D.UPDATE_SCHEMA)),
            ('D1 cannot omit native JAR',lambda v:v.update(files=[r for r in v['files'] if not r['path'].endswith('.jar')])),
            ('D1 refuses unlisted Java JAR',lambda v:v['files'][0].update(path='42.20/media/java/other.jar')),
            ('D1 refuses added Lua path',lambda v:v['files'].append(dict(v['files'][-1],path='42.20/media/lua/shared/SAO_Unknown.lua'))),
            ('D1 refuses deleted Lua path',lambda v:v['files'].pop()),
            ('D1 refuses duplicate path',lambda v:v['files'].__setitem__(1,dict(v['files'][0]))),
            ('D1 refuses other mod identity',lambda v:v.update(modId='ZombieAwareness')),
            ('D1 refuses changed native source hash',lambda v:v['files'][0].update(afterSha256='0'*64)),
            ('D1 refuses alternate save',lambda v:v['predecessor'].update(save='other')),
            ('D1 refuses path coercion',lambda v:v['files'][0].update(path=['bad'])),
        ):
            bad=copy.deepcopy(update);change(bad);put(root/'bad.json',bad)
            refused(lambda:D.validate_update(destination,receipt,root/'bad.json'),label)
        replace=D.os.replace;calls=[]
        def interrupted(source,target):
            if '.activate-' in str(source):
                calls.append(str(target))
                if len(calls)==2:raise OSError('controlled second source replacement failure')
            return replace(source,target)
        def partial_update():
            with D.resume_guard(destination,gameplay=True):
                attempt=destination/'attempts/0003';attempt.mkdir()
                with patch.object(D.os,'replace',side_effect=interrupted):
                    D.apply_update(destination,attempt,receipt,copy.deepcopy(receipt),path)
        refused(partial_update,'D1 mid-transaction refusal','controlled second source replacement failure')
        check(calls and calls[0].endswith('SAO.jar') and all(p.read_bytes()==v for p,v in before.items()),
              'mid-update rollback restores already replaced SAO JAR and every saved byte')
        with D.resume_guard(destination,gameplay=True) as custody:
            attempt=destination/'attempts/0003';attempt.mkdir();successor=copy.deepcopy(receipt)
            D.apply_update(destination,attempt,receipt,successor,path);D.verify_history(destination,successor)
            custody['nativeStarted']=True
        check(all(D.digest(destination/'cache/mods'/D.MOD/r['path'])==r['afterSha256'] for r in update['files']),
              'D1 exact Lua and JAR transition activates all frozen bytes')
        check(all(p.read_bytes()==v for p,v in before.items() if '/mods/SurvivorAwareness/' not in p.as_posix()),
              'D1 source transition preserves save injuries history ZAO observer and original receipt')
        retained=attempt/'gameplay-source-update'
        check(Lab.load(retained/'manifest.json')==update,'Java-bearing transition has explicit source provenance directory')
        (retained/'after/42.20/media/java/SAO.jar').write_bytes(b'tampered')
        refused(lambda:D.verify_history(destination,successor),'D1 retained native JAR tamper')


def d1_subset_checks(root):
    destination,receipt,logs,manifest,errors,update=fixture(root)
    profile='d1-shared-reasoning';name='42.20/media/lua/shared/SAO_ConceptKnowledge.lua'
    for allowed in D.PROFILES[profile]:
        put(destination/'cache/mods'/D.MOD/allowed,('old '+allowed).encode())
        put(root/'source'/allowed,('new '+allowed).encode())
        receipt['mods'][D.MOD][allowed]=D.digest(destination/'cache/mods'/D.MOD/allowed)
    put(destination/'run.json',receipt)
    update.update(schema=D.SOURCE_SUBSET_SCHEMA,profile=profile,
        predecessor=D.binding(receipt,D.digest(destination/'run.json')),
        files=[{'path':name,'source':str(root/'source'/name),'beforeSha256':receipt['mods'][D.MOD][name],
                'afterSha256':D.digest(root/'source'/name)}])
    path=root/'subset.json';put(path,update)
    before={p:p.read_bytes() for p in destination.rglob('*') if p.is_file()}
    with patch.object(D,'process_live',return_value=False):
        check(D.validate_update(destination,receipt,path)==update,'version3 validates exact one-file D1 subset')
        check(all(p.read_bytes()==v for p,v in before.items()),'subset validation preserves every predecessor byte')
        for label,change in (
            ('subset rejects empty',lambda v:v.update(files=[])),
            ('subset rejects duplicate',lambda v:v['files'].append(dict(v['files'][0]))),
            ('subset rejects outside profile',lambda v:v['files'][0].update(path='42.20/media/lua/shared/SAO_Unknown.lua')),
            ('subset rejects path escape',lambda v:v['files'][0].update(path='../save.bin')),
            ('subset rejects nonrecord',lambda v:v.update(files=['bad'])),
            ('subset rejects path coercion',lambda v:v['files'][0].update(path=[])),
            ('subset rejects unexpected fields',lambda v:v.update(allowAny=True)),
            ('subset requires named D1 profile',lambda v:v.update(profile='private-threat-contacts')),
            ('subset leaves version2 exact',lambda v:v.update(schema=D.SOURCE_UPDATE_SCHEMA)),
            ('subset leaves version1 exact',lambda v:v.update(schema=D.UPDATE_SCHEMA)),
        ):
            bad=copy.deepcopy(update);change(bad)
            refused(lambda:D.update_shape(bad),label)
        for label,change in (
            ('subset checks predecessor',lambda v:v['predecessor'].update(attempt=99)),
            ('subset checks before pin',lambda v:v['files'][0].update(beforeSha256='0'*64)),
            ('subset checks after pin',lambda v:v['files'][0].update(afterSha256='0'*64)),
            ('subset refuses unchanged',lambda v:v['files'][0].update(source=str(destination/'cache/mods'/D.MOD/name),
                afterSha256=receipt['mods'][D.MOD][name])),
        ):
            bad=copy.deepcopy(update);change(bad);put(root/'bad-subset.json',bad)
            refused(lambda:D.validate_update(destination,receipt,root/'bad-subset.json'),label)
        attempt=destination/'attempts/0003'
        def failed_admission():
            with D.resume_guard(destination,gameplay=True):
                attempt.mkdir();successor=copy.deepcopy(receipt)
                D.apply_update(destination,attempt,receipt,successor,path)
                D.verify_history(destination,successor)
                check(D.digest(destination/'cache/mods'/D.MOD/name)==update['files'][0]['afterSha256'],
                      'subset actually activates selected source before failure')
                raise OSError('controlled subset prelaunch refusal')
        refused(failed_admission,'subset prelaunch refusal','controlled subset prelaunch refusal')
        check(all(p.read_bytes()==v for p,v in before.items()),'subset rollback preserves predecessor and every cache save byte')
        check(not attempt.exists() and len(list((destination/'delivery-failures').iterdir()))==1,
              'subset failure evidence retained outside next attempt')
        with D.resume_guard(destination,gameplay=True) as custody:
            attempt.mkdir();successor=copy.deepcopy(receipt)
            D.apply_update(destination,attempt,receipt,successor,path);D.verify_history(destination,successor)
            custody['nativeStarted']=True
        expected=copy.deepcopy(receipt['mods']);expected[D.MOD][name]=update['files'][0]['afterSha256']
        check(successor['mods']==expected,'subset keeps all unrelated source pins')
        check(all(p.read_bytes()==v for p,v in before.items() if p!=destination/'cache/mods'/D.MOD/name),
              'subset changes only selected source and no save or history bytes')
        retained=attempt/'gameplay-source-update'
        check((retained/'manifest.json').is_file() and Lab.load(retained/'manifest.json')==update,
              'subset uses source provenance directory')
        check((retained/'previous-run.json').read_bytes()==before[destination/'run.json'],
              'subset retains exact predecessor receipt')
        bad=copy.deepcopy(successor);bad['mods'][D.MOD]['42.20/media/java/SAO.jar']='0'*64
        refused(lambda:D.verify_history(destination,bad),'subset history rejects unrelated pin change')
        old=(retained/'before'/name);content=old.read_bytes();old.write_bytes(b'tampered')
        refused(lambda:D.verify_history(destination,successor),'subset history checks retained before bytes');old.write_bytes(content)
        (retained/'after'/name).write_bytes(b'tampered')
        refused(lambda:D.verify_history(destination,successor),'subset history checks retained after bytes')


def subset_mutation_checks(root):
    source=Path(D.__file__).read_text(encoding='utf-8')
    variants=[
        ('restore-full-profile-only','subset = profile == "d1-shared-reasoning" and value["schema"] == SOURCE_SUBSET_SCHEMA',
         'subset = False','gameplay update profile schema differs'),
        ('allow-duplicate-subset','len(paths) == len(rows) and paths <= PROFILES[profile]',
         'paths <= PROFILES[profile]','subset rejects duplicate: invalid candidate accepted'),
        ('allow-outside-subset','len(paths) == len(rows) and paths <= PROFILES[profile]',
         'len(paths) == len(rows)','subset rejects outside profile: invalid candidate accepted'),
        ('allow-unchanged-subset','digest(after) == row["afterSha256"] != row["beforeSha256"]',
         'digest(after) == row["afterSha256"]','subset refuses unchanged: invalid candidate accepted'),
        ('misclassify-subset-history','value["schema"] in (SOURCE_UPDATE_SCHEMA, SOURCE_SUBSET_SCHEMA)',
         'value["schema"] == SOURCE_UPDATE_SCHEMA','subset uses source provenance directory'),
        ('omit-selected-rollback','if name in previous["mods"][MOD]]',
         'if name in previous["mods"][MOD] and not name.endswith("/SAO_ConceptKnowledge.lua")]',
         'subset rollback preserves predecessor and every cache save byte'),
    ]
    for name,before,after,marker in variants:
        assert source.count(before)==1,(name,'mutation anchor')
        mutant=types.ModuleType(name);mutant.__file__=D.__file__
        exec(compile(source.replace(before,after,1),'<'+name+'>','exec'),mutant.__dict__)
        checks,controls=len(CHECKS),len(CONTROLS)
        try:
            with patch.dict(globals(),D=mutant):d1_subset_checks(root/name)
        except (AssertionError,ValueError,OSError) as error:
            assert marker in str(error),(name,'wrong control verdict',str(error))
        else:raise AssertionError(name+' restored defect survived')
        finally:
            del CHECKS[checks:];del CONTROLS[controls:]
        CONTROLS.append('restored-defect '+name+': '+marker)


def animation_checks(root):
    destination,receipt,logs,manifest,errors,update=fixture(root)
    data=Lab.load(Path(__file__).parent/'world_lab/delivery_animation_stack.json')
    check(hashlib.sha256(data['text'].encode()).hexdigest()==D.ANIMATION_STACK_SHA256
          and Lab.seal(data['boneCounts'])==D.ANIMATION_BONE_COUNTS_SHA256
          and Lab.seal(data['boneFrameCounts'])==D.ANIMATION_BONE_FRAMES_SHA256,
          'animation fixture retains exact installed stack and per-frame bone fingerprints')
    for key,count in data['boneFrameCounts'].items():
        frame,node=key.split(':',1)
        logs['stderr.log']+=(f'ERROR: General      f:{frame} at ImportedSkeleton.collectBoneFrames  > Could not find bone index for node name: "{node}"\n')*count
    logs['stderr.log']+=data['text']
    put(destination/'attempts/0002/stderr.log',logs['stderr.log'].encode())
    receipt.update(status='incomplete',runtimeErrors=list(D.ANIMATION_ERRORS))
    receipt['logs']['stderr.log']=D.digest(destination/'attempts/0002/stderr.log')
    put(destination/'run.json',receipt);put(destination/'attempts/0002/report.json',receipt)
    original=(destination/'run.json').read_bytes();bundle=root/'animation';bundle.mkdir()
    put(bundle/'exception-stack.txt',data['text'].encode())
    classes=[]
    for name in ('zombie.characters.IsoPlayer','zombie.core.skinnedmodel.visual.AnimalVisual',
                 'zombie.core.skinnedmodel.ModelManager','zombie.core.skinnedmodel.advancedanimation.AdvancedAnimator',
                 'zombie.Lua.LuaManager$GlobalObject','zombie.core.skinnedmodel.model.jassimp.ImportedSkeleton'):
        filename=name+'.javap.txt';put(bundle/filename,('controlled metadata '+name).encode())
        classes.append({'class':name,'bytecodeFile':filename,'bytecodeSha256':D.digest(bundle/filename),'exitCode':0})
    put(bundle/'bytecode-inputs.json',{'jarSha256':receipt['engineJarSha256'],'classes':classes})
    put(bundle/'repair-proof.json',{'schema':'sao-native-animation-diagnosis/1','status':'REPAIR_VERIFIED_NATIVE_ACCEPTANCE_OPEN',
        'engine':{'sha256':receipt['engineJarSha256']},'proof':{'wrongBooleanDefectControls':1,'observerLifecycleBaselines':2}})
    diagnosis={'schema':'sao.native-animation-incident/1','status':'ANALYZED_WITH_QUALIFICATIONS',
        'sessionId':receipt['sessionId'],'attempt':receipt['launchNumber'],'save':receipt['save'],
        'engineJarSha256':receipt['engineJarSha256'],'originalVerdict':'incomplete',
        'incident':{'frame':3936,'episodesInRetainedStderr':1,'runtimeErrorRows':list(D.ANIMATION_ERRORS),
            'stackFile':'exception-stack.txt','stackSha256':D.ANIMATION_STACK_SHA256,
            'boneCountsSha256':D.ANIMATION_BONE_COUNTS_SHA256,'boneFramesSha256':D.ANIMATION_BONE_FRAMES_SHA256,
            'stderrSha256':receipt['logs']['stderr.log']},
        'bytecodeInputsFile':'bytecode-inputs.json','bytecodeInputsSha256':D.digest(bundle/'bytecode-inputs.json'),
        'repairProofFile':'repair-proof.json','repairProofSha256':D.digest(bundle/'repair-proof.json'),
        'recommendation':{'limitations':['controlled evidence metadata; native acceptance remains open']}}
    put(bundle/'receipt.json',diagnosis)
    errors.update(predecessor=D.binding(receipt,D.digest(destination/'run.json')),errors=D.error_rows(logs,True),
        animationIncident={'path':str(bundle/'receipt.json'),'sha256':D.digest(bundle/'receipt.json')})
    path=root/'reviewed-animation.json';put(path,errors)
    with patch.object(D,'process_live',return_value=False):
        result=D.reviewed_errors(destination,receipt,path,logs,list(D.ANIMATION_ERRORS))
        check(result['originalStatus']=='incomplete' and result['originalRuntimeErrors']==list(D.ANIMATION_ERRORS)
              and (destination/'run.json').read_bytes()==original,'animation disposition preserves failed report and uncertainty')
        for label,change in (
            ('animation diagnosis engine must match',lambda v:v.update(engineJarSha256='0'*64)),
            ('animation cannot relabel original verdict',lambda v:v.update(originalVerdict='completed')),
            ('animation bytecode inventory is pinned',lambda v:v.update(bytecodeInputsSha256='0'*64)),
            ('animation constructor repair proof is pinned',lambda v:v.update(repairProofSha256='0'*64)),
        ):
            bad=copy.deepcopy(diagnosis);change(bad);put(bundle/'receipt.json',bad)
            refused(lambda:D.animation_bundle({'path':str(bundle/'receipt.json'),
                'sha256':D.digest(bundle/'receipt.json')},receipt),label)
        put(bundle/'receipt.json',diagnosis)
        original_proof=Lab.load(bundle/'repair-proof.json')
        bad_proof=copy.deepcopy(original_proof);bad_proof['proof']['wrongBooleanDefectControls']=0
        put(bundle/'repair-proof.json',bad_proof)
        bad=copy.deepcopy(diagnosis);bad['repairProofSha256']=D.digest(bundle/'repair-proof.json')
        put(bundle/'receipt.json',bad)
        refused(lambda:D.animation_bundle({'path':str(bundle/'receipt.json'),
            'sha256':D.digest(bundle/'receipt.json')},receipt),'animation requires reproduced constructor defect')
        put(bundle/'repair-proof.json',original_proof);put(bundle/'receipt.json',diagnosis)
        for label,change in (
            ('animation evidence required',lambda v:v.pop('animationIncident')),
            ('animation and lunge incidents cannot mix',lambda v:v.update(lungeIncident=v['animationIncident'])),
            ('animation diagnosis pin checked',lambda v:v['animationIncident'].update(sha256='0'*64)),
            ('animation predecessor session checked',lambda v:v['predecessor'].update(sessionId='foreign')),
            ('animation manifest missing error',lambda v:v['errors'].pop()),
            ('animation manifest repeats error',lambda v:v['errors'].append(dict(v['errors'][-1]))),
        ):
            bad=copy.deepcopy(errors);change(bad);put(root/'bad-animation.json',bad)
            refused(lambda:D.reviewed_errors(destination,receipt,root/'bad-animation.json',logs,list(D.ANIMATION_ERRORS)),label)
        for label,text in (
            ('animation exact stack checked',logs['stderr.log'].replace('AnimalVisual.java:83','AnimalVisual.java:84')),
            ('animation cannot absorb another exception',logs['stderr.log']+data['text']),
            ('animation cannot bless new bone node',logs['stderr.log'].replace('"Bip01_Root"','"UnknownNode"',1)),
            ('animation exact bone frame checked',logs['stderr.log'].replace('f:3910 at ImportedSkeleton','f:3911 at ImportedSkeleton',1)),
            ('animation cannot absorb new renderer error',logs['stderr.log']+'ERROR: Render f:3954> new failure\n'),
        ):
            changed=dict(logs);changed['stderr.log']=text;bad=copy.deepcopy(errors);bad['errors']=D.error_rows(changed,True);put(root/'bad-animation.json',bad)
            refused(lambda:D.reviewed_errors(destination,receipt,root/'bad-animation.json',changed,list(D.ANIMATION_ERRORS)),label)
        refused(lambda:D.reviewed_errors(destination,receipt,path,logs,[*D.ANIMATION_ERRORS,'unreviewed runtime failure']),
                'animation cannot absorb producer or runtime failure')
        with patch.object(Lab,'verify_package',return_value=(manifest,{'observation':{'everyHours':.25}})), \
             patch.object(R.ObserverLayout,'from_receipt',return_value=None), \
             patch.object(R,'observer_evidence',return_value=receipt['observerEvidence']), \
             patch.object(R,'saved_state',return_value=receipt['player']), \
             patch.object(R,'terminal',return_value=receipt['terminal']), \
             patch.object(Lab,'inspect_frames',return_value=receipt['inspection']):
            refused(lambda:R.verify_run(destination,root),'incomplete animation remains rejected without explicit disposition')
            check(R.verify_run(destination,root,path)==receipt,
                  'actual verifier admits qualified animation specimen without changing original verdict')
            check((destination/'run.json').read_bytes()==original,
                  'actual qualified animation verification is read-only')
        successor=copy.deepcopy(receipt);attempt=destination/'attempts/0003';attempt.mkdir()
        D.retain_review(destination,attempt,receipt,successor,path,result);D.verify_history(destination,successor)
        check((attempt/'reviewed-errors/previous-run.json').read_bytes()==original,'animation evidence stays separate from original verdict')
        (attempt/'reviewed-errors/animation-incident/exception-stack.txt').write_bytes(b'changed')
        refused(lambda:D.verify_history(destination,successor),'retained animation evidence tamper')


def callback_checks(root, session=True, preparation=False, rebind=False, budgets=False):
    """Generated incident fixture; no installed engine, private archive or native save required.

    Fixture hashes replace the incident's declared pins only inside this test.
    Production qualification, source guards and retained-history code run intact.
    These bytes supply contract coverage, never native incident authorization.
    """
    destination,receipt,_,_,_,_=fixture(root)
    cache=destination/'cache';attempt=destination/'attempts/0001'
    before=cache/'mods'/D.MOD/D.CALLBACK_POSE;after=root/'source'/D.CALLBACK_POSE
    put(before,b'controlled old recovery callback');put(after,b'controlled owned complete callback')
    receipt['mods'][D.MOD][D.CALLBACK_POSE]=D.digest(before)
    assert not (rebind or budgets) or preparation
    assert not (rebind and budgets)
    profile = D.CALLBACK_BUDGETS_PROFILE if budgets else D.CALLBACK_REBIND_PROFILE if rebind else D.CALLBACK_PREPARATION_PROFILE if preparation else D.CALLBACK_PROFILE
    extra_pins = {}
    if preparation:
        # fixture() starts with an unrelated launch2 folder; this generated callback
        # predecessor is launch1, so its unused synthetic next-attempt stub is absent.
        shutil.rmtree(destination/'attempts/0002')
        for name, prefix in ((D.CALLBACK_NEEDS,'CALLBACK_NEEDS'), (D.CALLBACK_CONTROLLER,'CALLBACK_CONTROLLER')):
            old = cache/'mods'/D.MOD/name; new = root/'source'/name
            put(old, ('controlled before '+name).encode()); put(new, (('controlled budgets after ' if budgets else 'controlled rebind after ' if rebind else 'controlled after ')+name).encode())
            receipt['mods'][D.MOD][name] = D.digest(old)
            extra_pins[prefix+'_BEFORE'] = D.digest(old)
            if rebind or budgets:
                historical=root/'historical-source'/name;put(historical,('controlled after '+name).encode())
                extra_pins[prefix+'_AFTER'] = D.digest(historical)
                axis='NEEDS' if name==D.CALLBACK_NEEDS else 'CONTROLLER'
                if budgets:
                    prior_rebind=root/'historical-rebind-source'/name;put(prior_rebind,('controlled rebind after '+name).encode())
                    extra_pins['CALLBACK_REBIND_'+axis+'_AFTER'] = D.digest(prior_rebind)
                    extra_pins['CALLBACK_BUDGETS_'+axis+'_AFTER'] = D.digest(new)
                else:extra_pins['CALLBACK_REBIND_'+axis+'_AFTER'] = D.digest(new)
            else: extra_pins[prefix+'_AFTER'] = D.digest(new)
    for index in range(437):
        put(cache/f'Saves/Sandbox/123/controlled-{index:03d}.bin',f'controlled-save-{index}'.encode())
    receipt.update(status='incomplete',launchNumber=1,runtimeErrors=list(D.CALLBACK_ERRORS),
        terminal={'endHours':2.248784065246582,'nativeSaveReturned':True,
                  'receiptFormat':'supervisor-stop/2','startHours':2.0,'stopReason':'producer-failure'},
        supervision={'forced':False,'failure':'[StudyObserver] FAILED'},lastHours=2.248784065246582)
    receipt['saveFiles']={p.relative_to(cache).as_posix():D.digest(p) for p in (cache/'Saves').rglob('*') if p.is_file()}
    logs={'stdout.log':'sao-2 recovery admission accepted: sleep at bed:3424.0:10901.0:0.0:2:6e7239a1\n',
          'stderr.log':'\n'.join(D.CALLBACK_ERRORS[:4])+'\n'}
    for name,text in logs.items():put(attempt/name,text.encode())
    receipt['logs']={n:D.digest(attempt/n) for n in logs}
    state={'status':'failed','worldAdvanced':True,'hours':receipt['terminal']['endHours'],
           'failure':'controlled SAO_RecoveryPose.lua:245','detached':True,'objects':0,'squareMemberships':0}
    put(attempt/'observer-state.json',state)
    image=attempt/'native-view/controlled.png';put(image,b'controlled-image-byte-custody')
    view={'image':{'file':image.name,'sha256':D.digest(image)},'views':[]}
    put(attempt/'native-view/native.json',view)
    frame=cache/'Lua/StudyWorld/123/session/0000000000000001.json'
    put(frame,{'sequence':1,'countyHours':2,'people':[],'population':{'total':0,'captured':0},
               'save':receipt['save'],'definitionSha256':receipt.get('definitionSha256','d'*64)})
    receipt['definitionSha256']='d'*64
    receipt['observations']={frame.relative_to(cache).as_posix():D.digest(frame)}
    put(destination/'run.json',receipt)
    diagnosis=root/'controlled-diagnosis.json';put(diagnosis,{'fixture':'not native diagnosis'})
    save_evidence=root/'controlled-save-evidence.json';put(save_evidence,{'fixture':'not native save proof'})
    proof_path=root/'controlled-proof/receipt.json';variants=[]
    source=root/'controlled-proof/driver.py';put(source,b'# controlled source fixture\n')
    for index,name in enumerate(('production','nil-call','foreign-custody','callback-replacement')):
        log=proof_path.parent/(name+'.log');put(log,('controlled '+name).encode())
        variants.append({'name':name,'exit':0 if index==0 else 1,'logSha256':D.digest(log)})
    inputs={str(source):D.digest(source)}
    put(proof_path,{'status':'PASS','variants':variants,'inputs':inputs,'inputsAfter':inputs})
    pins={'CALLBACK_BEFORE':D.digest(before),'CALLBACK_AFTER':D.digest(after),
          'CALLBACK_RECEIPT':D.digest(destination/'run.json'),'CALLBACK_ENGINE':receipt['engineJarSha256'],
          'CALLBACK_STATE':D.digest(attempt/'observer-state.json'),'CALLBACK_VIEW':D.digest(attempt/'native-view/native.json'),
          'CALLBACK_FRAME':D.digest(frame),'CALLBACK_DIAGNOSIS':D.digest(diagnosis),
          'CALLBACK_PROOF':D.digest(proof_path),'CALLBACK_SAVE_EVIDENCE':D.digest(save_evidence)}
    pins.update(extra_pins)
    pins['CALLBACK_PREDECESSOR']=D.binding(receipt,pins['CALLBACK_RECEIPT'])
    pin=lambda p:{'path':str(p),'sha256':D.digest(p)}
    with patch.multiple(D,**pins),patch.object(D,'process_live',return_value=False):
        update={'schema':D.UPDATE_SCHEMA,'profile':profile,'modId':D.MOD,
                'predecessor':pins['CALLBACK_PREDECESSOR'],'files':[{'path':name,
                    'source':str(root/'source'/name),'beforeSha256':old,'afterSha256':new}
                    for name,(old,new) in sorted(D.callback_source_pins(profile).items())]}
        update_path=root/'controlled-update.json';put(update_path,update)
        approval_path=root/'controlled-approval.json';put(approval_path,D._callback_approval(D.digest(update_path)))
        manifest={'schema':D.CALLBACK_ERROR_SCHEMA,'predecessor':pins['CALLBACK_PREDECESSOR'],
            'engineJarSha256':pins['CALLBACK_ENGINE'],'runtimeErrors':list(D.CALLBACK_ERRORS),
            'detectedRuntimeErrors':list(D.CALLBACK_ERRORS[:4]),'approval':pin(approval_path),
            'diagnosis':pin(diagnosis),'factoryProof':pin(proof_path),'saveEvidence':pin(save_evidence),'update':pin(update_path)}
        review_path=root/'controlled-review.json'
        def review(value=manifest,rec=receipt,detected=None):
            put(review_path,value)
            return D.reviewed_errors(destination,rec,review_path,logs,
                                    list(D.CALLBACK_ERRORS[:4]) if detected is None else detected)
        disposition=review()
        check(disposition['originalStatus']=='incomplete' and disposition['originalRuntimeErrors']==list(D.CALLBACK_ERRORS),
              'callback preserves original incomplete verdict and all six faults')
        check(D.verify_callback_observer(destination,receipt,disposition)['state']['status']=='failed',
              'callback retains failed observer without healthy certification')
        check(D.validate_update(destination,receipt,update_path,disposition)==update,
              'budgets accepts only qualified exact three-file update' if budgets else 'rebind accepts only qualified exact three-file update' if rebind else 'preparation accepts only qualified exact three-file update' if preparation else 'callback accepts only qualified exact Pose update')
        refused(lambda:D.saved_boundary(receipt),'callback requires explicit review','failed native owner')
        refused(lambda:D.validate_update(destination,receipt,update_path),'callback update requires disposition','explicit callback disposition')
        for label,edit in (
            ('foreign UUID',lambda r:r.update(sessionId='foreign')),
            ('foreign save',lambda r:r.update(save='foreign')),
            ('foreign dependency',lambda r:r['mods'].update(Foreign={'mod.info':'0'*64})),
            ('foreign JAR',lambda r:r['mods'][D.MOD].update({'42.20/media/java/SAO.jar':'0'*64})),
            ('completed history',lambda r:r.update(status='completed')),
            ('forced save',lambda r:r['supervision'].update(forced=True))):
            bad=copy.deepcopy(receipt);edit(bad)
            refused(lambda:review(rec=bad),'callback refuses '+label,'predecessor')
            refused(lambda:D.saved_boundary(bad,disposition),'callback direct qualification refuses '+label)
        refused(lambda:review(detected=list(D.CALLBACK_ERRORS[:4])+['extra']),'callback refuses extra fault','fingerprints')
        bad=copy.deepcopy(manifest);bad['runtimeErrors']=bad['runtimeErrors'][:-1]
        refused(lambda:review(value=bad),'callback requires all six faults','fingerprints')
        bad=copy.deepcopy(manifest);bad.pop('approval')
        refused(lambda:review(value=bad),'callback refuses missing review','fields')
        wrong=root/'controlled-wrong-approval.json';put(wrong,{'status':'APPROVED'})
        bad=copy.deepcopy(manifest);bad['approval']=pin(wrong)
        refused(lambda:review(value=bad),'callback refuses schema-less approval','approved review')
        bad=copy.deepcopy(disposition);bad['callbackIncident'].update(approval=pin(wrong),approvedReview={'status':'APPROVED'})
        refused(lambda:D.saved_boundary(receipt,bad),'callback refuses direct fabricated approval','approval')
        for label,path in [('saved byte',cache/next(iter(receipt['saveFiles']))),('log',attempt/'stderr.log'),
                           ('observer',attempt/'observer-state.json'),('viewport',attempt/'native-view/native.json'),
                           ('frame',frame),('image',image),('factory source',source)]:
            content=path.read_bytes();put(path,content+b'changed')
            refused(lambda:review(),'callback refuses changed '+label);put(path,content)
        # Duplicate count/foreign path checks must survive distinct restored-defect controls.
        for label,edit in [('extra Pose',lambda u:u['files'].append(copy.deepcopy(u['files'][0]))),
                           ('extra JAR',lambda u:u['files'].append(dict(u['files'][0],path='42.20/media/java/SAO.jar'))),
                           ('before pin',lambda u:u['files'][0].update(beforeSha256='0'*64)),
                           ('after pin',lambda u:u['files'][0].update(afterSha256='0'*64))]:
            bad=copy.deepcopy(update);edit(bad)
            refused(lambda:D.update_shape(bad),'callback refuses '+label)
        if preparation:
            for label, edit in (
                ('missing file', lambda u:u['files'].pop()),
                ('extra file', lambda u:u['files'].append(copy.deepcopy(u['files'][0]))),
                ('profile mixing', lambda u:u.update(profile=D.CALLBACK_PROFILE)),
                ('subset schema', lambda u:u.update(schema=D.SOURCE_SUBSET_SCHEMA))):
                bad=copy.deepcopy(update);edit(bad)
                refused(lambda:D.update_shape(bad),'preparation refuses '+label)
            for index,row in enumerate(update['files']):
                for field in ('beforeSha256','afterSha256'):
                    bad=copy.deepcopy(update);bad['files'][index][field]='0'*64
                    refused(lambda:D.update_shape(bad),'preparation refuses '+Path(row['path']).stem+' '+field)
                source_path=Path(row['source']);content=source_path.read_bytes();put(source_path,content+b'changed')
                refused(lambda:D.validate_update(destination,receipt,update_path,disposition),
                        'preparation refuses changed '+Path(row['path']).stem+' source')
                put(source_path,content)
            bad=copy.deepcopy(update);bad['profile']=D.CALLBACK_PROFILE;bad['files']=[r for r in bad['files'] if r['path']==D.CALLBACK_POSE]
            old_path=root/'old-Pose-only-update.json';put(old_path,bad)
            refused(lambda:D.validate_update(destination,receipt,old_path,disposition),
                    'preparation refuses old Pose-only approved-update substitution','approved update changed')
            if rebind or budgets:
                historical=copy.deepcopy(update);historical['profile']=D.CALLBACK_PREPARATION_PROFILE
                refused(lambda:D.update_shape(historical),'rebind refuses new pins under historical preparation profile','exact reviewed per-file source pins')
                for row in historical['files']:
                    row['afterSha256']=D.callback_source_pins(D.CALLBACK_PREPARATION_PROFILE)[row['path']][1]
                check(D.update_shape(historical)==D.CALLBACK_PREPARATION_PROFILE,'rebind validator preserves historical preparation source table')
                old_path=root/'historical-preparation-update.json';put(old_path,historical)
                refused(lambda:D.validate_update(destination,receipt,old_path,disposition),
                        'rebind refuses historical preparation approval substitution','approved update changed')
                bad=copy.deepcopy(update)
                for row in bad['files']:
                    row['afterSha256']=D.callback_source_pins(D.CALLBACK_PREPARATION_PROFILE)[row['path']][1]
                refused(lambda:D.update_shape(bad),'rebind refuses historical pins under new profile','exact reviewed per-file source pins')
            if budgets:
                prior=copy.deepcopy(update);prior['profile']=D.CALLBACK_REBIND_PROFILE
                refused(lambda:D.update_shape(prior),'budgets refuses new pins under historical rebind profile','exact reviewed per-file source pins')
                for row in prior['files']:
                    row['afterSha256']=D.callback_source_pins(D.CALLBACK_REBIND_PROFILE)[row['path']][1]
                check(D.update_shape(prior)==D.CALLBACK_REBIND_PROFILE,'budgets validator preserves historical rebind source table')
                old_path=root/'historical-rebind-update.json';put(old_path,prior)
                refused(lambda:D.validate_update(destination,receipt,old_path,disposition),
                        'budgets refuses historical rebind approval substitution','approved update changed')
                bad=copy.deepcopy(prior);bad['profile']=D.CALLBACK_BUDGETS_PROFILE
                refused(lambda:D.update_shape(bad),'budgets refuses historical rebind pins under new profile','exact reviewed per-file source pins')
            # Exercise all-row rollback after exact validation/application, without a native launch.
            guarded={p:p.read_bytes() for p in cache.rglob('*') if p.is_file()}
            original_run=(destination/'run.json').read_bytes()
            try:
                with D.resume_guard(destination,gameplay=True):
                    rollback_attempt=destination/'attempts/0002';rollback_attempt.mkdir()
                    candidate=copy.deepcopy(receipt)
                    D.apply_update(destination,rollback_attempt,receipt,candidate,update_path,disposition)
                    check(all(D.digest(cache/'mods'/D.MOD/r['path'])==r['afterSha256'] for r in update['files']),
                          'preparation three-file update applied before injected prelaunch refusal')
                    raise RuntimeError('controlled preparation prelaunch refusal')
            except RuntimeError as error:
                check(str(error)=='controlled preparation prelaunch refusal','preparation preserves actual prelaunch failure')
            check(all(p.read_bytes()==v for p,v in guarded.items()) and (destination/'run.json').read_bytes()==original_run,
                  'preparation rollback restores all three sources and every save byte')
            check(not rollback_attempt.exists() and len(list((destination/'delivery-failures').iterdir()))==1,
                  'preparation archives failed attempt without reserving next cursor')
        if session:
            cursor=S.new_state('Controlled callback' ,30,False);cursor.update(status='failed',attempt=1)
            state_path=root/'controlled-session.json'
            S.recover_failed_save(state_path,cursor,receipt,qualified=True,disposition=disposition)
            check(cursor['status']=='saved' and cursor['accumulatedWorldHours']==0
                  and cursor['lastStopReason']=='saved-with-reviewed-callback-failure',
                  'callback Session supplies saved control with zero outcome credit')
            cursor.update(status='failed',canContinue=False)
            S.recover_failed_save(state_path,cursor,receipt,qualified=True,disposition=disposition)
            check(cursor['accumulatedWorldHours']==0,'callback repeated Session qualification keeps zero credit')
            loaded=Lab.load(state_path);loaded.update(status='failed',canContinue=False)
            S.recover_failed_save(state_path,loaded,receipt,qualified=True,disposition=disposition)
            check(loaded['accumulatedWorldHours']==0,'callback Session reload retains zero credit')
            stale=S.new_state('Stale controlled callback',30,False)
            stale.update(status='failed',attempt=0,accumulatedWorldHours=7.5)
            S.recover_failed_save(state_path,stale,receipt,qualified=True,disposition=disposition)
            check(stale['attempt']==1 and stale['accumulatedWorldHours']==7.5,
                  'callback stale cursor advances without adding historical time')
            for label,edit in [('foreign save',lambda r:r.update(save='foreign')),
                               ('forced save',lambda r:r['supervision'].update(forced=True))]:
                bad=copy.deepcopy(receipt);edit(bad)
                cursor=S.new_state('Rejected callback',30,False);cursor.update(status='failed',attempt=1)
                refused(lambda:S.recover_failed_save(state_path,cursor,bad,qualified=True,disposition=disposition),
                        'callback Session refuses '+label)
                check(cursor['status']=='failed' and cursor['accumulatedWorldHours']==0,
                      'callback rejected '+label+' leaves Session unchanged')
        successor=copy.deepcopy(receipt);next_attempt=destination/'attempts/0003';next_attempt.mkdir()
        # The case-review file from the last rejected call is not retained as authorization.
        put(review_path,manifest)
        D.apply_update(destination,next_attempt,receipt,successor,update_path,disposition)
        D.retain_review(destination,next_attempt,receipt,successor,review_path,disposition)
        relocated=root/'relocated';shutil.copytree(destination,relocated)
        approval_path.unlink();update_path.unlink();source.unlink()
        D.verify_history(relocated,successor)
        check(True,'callback retained history works without original approval update or proof source')
        if preparation:
            check(successor['mods'][D.MOD]==dict(receipt['mods'][D.MOD], **{r['path']:r['afterSha256'] for r in update['files']}),
                  'preparation successor changes exactly its three source pins')
            for row in update['files']:
                for group,field in (('before','beforeSha256'),('after','afterSha256')):
                    path=relocated/'attempts/0003/gameplay-lua-update'/group/row['path']
                    check(D.digest(path)==row[field], 'preparation relocated '+group+' '+Path(row['path']).stem+' retained')
                    content=path.read_bytes();put(path,content+b'tamper')
                    refused(lambda:D.verify_history(relocated,successor),'preparation relocated '+group+' '+Path(row['path']).stem+' tamper')
                    put(path,content)
        for name in ('approval.json','factory-proof.json','save-evidence.json','observer-state.json','original-world-frame.json','stdout.log'):
            path=relocated/'attempts/0003/reviewed-errors/callback-incident'/name;content=path.read_bytes()
            put(path,content+b'changed')
            refused(lambda:D.verify_history(relocated,successor),'callback retained '+name+' tamper');put(path,content)
        check(Lab.load(destination/'run.json')['status']=='incomplete',
              'callback never rewrites failed predecessor receipt')


def callback_mutation_checks(root):
    source=Path(D.__file__).read_text(encoding='utf-8')
    variants=[
        ('callback-extra-update','Lab.require(isinstance(rows, list) and len(rows) == len(PROFILES[profile])',
         'Lab.require(profile == CALLBACK_PROFILE or isinstance(rows, list) and len(rows) == len(PROFILES[profile])',
         'callback refuses extra Pose: invalid candidate accepted'),
        ('callback-status-only-approval','and approval == _callback_approval(update_pin["sha256"]),',
         'and approval.get("status") == "APPROVED",','callback refuses direct fabricated approval: invalid candidate accepted'),
        ('callback-unchecked-history','Lab.require(Path(name).name == name and digest(file_path(root / "callback-incident" / name)) == source["sha256"],',
         'Lab.require(Path(name).name == name,','callback retained approval.json tamper: invalid candidate accepted'),
    ]
    for name,before,after,marker in variants:
        assert source.count(before)==1,(name,'mutation anchor')
        mutant=types.ModuleType(name);mutant.__file__=D.__file__
        exec(compile(source.replace(before,after,1),'<'+name+'>','exec'),mutant.__dict__)
        checks,controls=len(CHECKS),len(CONTROLS)
        try:
            with patch.dict(globals(),D=mutant):callback_checks(root/name,session=False)
        except (AssertionError,ValueError,OSError) as error:
            assert marker in str(error),(name,'wrong control verdict',str(error))
        else:raise AssertionError(name+' restored defect survived')
        finally:
            del CHECKS[checks:];del CONTROLS[controls:]
        CONTROLS.append('restored-defect '+name+': '+marker)



def preparation_mutation_checks(root):
    source=Path(D.__file__).read_text(encoding='utf-8')
    before='        if profile in CALLBACK_PROFILES:'
    after='        if profile == CALLBACK_PROFILE:'
    assert source.count(before)==1,'preparation source-pin mutant anchor'
    mutant=types.ModuleType('preparation-unchecked-pins');mutant.__file__=D.__file__
    exec(compile(source.replace(before,after,1),'<preparation-unchecked-pins>','exec'),mutant.__dict__)
    checks,controls=len(CHECKS),len(CONTROLS)
    try:
        with patch.dict(globals(),D=mutant):callback_checks(root/'unchecked-pins',session=False,preparation=True)
    except (AssertionError,ValueError,OSError) as error:
        assert 'invalid candidate accepted' in str(error),('preparation mutant wrong verdict',str(error))
    else:raise AssertionError('preparation unchecked source-pin defect survived')
    finally:
        del CHECKS[checks:];del CONTROLS[controls:]
    CONTROLS.append('restored-defect preparation-unchecked-pins')



def rebind_mutation_checks(root):
    source=Path(D.__file__).read_text(encoding='utf-8')
    before='        if profile in CALLBACK_PROFILES:'
    after='        if profile in (CALLBACK_PROFILE, CALLBACK_PREPARATION_PROFILE):'
    assert source.count(before)==1,'rebind source-pin mutant anchor'
    mutant=types.ModuleType('rebind-unchecked-pins');mutant.__file__=D.__file__
    exec(compile(source.replace(before,after,1),'<rebind-unchecked-pins>','exec'),mutant.__dict__)
    checks,controls=len(CHECKS),len(CONTROLS)
    try:
        with patch.dict(globals(),D=mutant):callback_checks(root/'unchecked-pins',session=False,preparation=True,rebind=True)
    except (AssertionError,ValueError,OSError) as error:
        assert 'invalid candidate accepted' in str(error),('rebind mutant wrong verdict',str(error))
    else:raise AssertionError('rebind unchecked source-pin defect survived')
    finally:
        del CHECKS[checks:];del CONTROLS[controls:]
    CONTROLS.append('restored-defect rebind-unchecked-pins')



def budgets_mutation_checks(root):
    source=Path(D.__file__).read_text(encoding='utf-8')
    before='        if profile in CALLBACK_PROFILES:'
    after='        if profile in (CALLBACK_PROFILE, CALLBACK_PREPARATION_PROFILE, CALLBACK_REBIND_PROFILE):'
    assert source.count(before)==1,'budgets source-pin mutant anchor'
    mutant=types.ModuleType('budgets-unchecked-pins');mutant.__file__=D.__file__
    exec(compile(source.replace(before,after,1),'<budgets-unchecked-pins>','exec'),mutant.__dict__)
    checks,controls=len(CHECKS),len(CONTROLS)
    try:
        with patch.dict(globals(),D=mutant):callback_checks(root/'unchecked-pins',session=False,preparation=True,budgets=True)
    except (AssertionError,ValueError,OSError) as error:
        assert 'invalid candidate accepted' in str(error),('budgets mutant wrong verdict',str(error))
    else:raise AssertionError('budgets unchecked source-pin defect survived')
    finally:
        del CHECKS[checks:];del CONTROLS[controls:]
    CONTROLS.append('restored-defect budgets-unchecked-pins')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--d1-subset-only',action='store_true')
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sao-delivery-proof-') as temporary:
        if args.d1_subset_only:
            profile_checks(Path(temporary)/'legacy-v1')
            d1_source_checks(Path(temporary)/'legacy-v2')
            d1_subset_checks(Path(temporary)/'subset-v3')
            actual_runner_checks(Path(temporary)/'subset-runner',profile='d1-shared-reasoning',subset=True)
            subset_mutation_checks(Path(temporary)/'mutants')
            print(json.dumps({'status':'PASS','scope':'D1 subset and version1/version2 compatibility',
                'checks':len(CHECKS),'rejectionControls':len(CONTROLS),'checkNames':CHECKS,'controlNames':CONTROLS},indent=2))
            return 0
        junction_checks(Path(temporary)/'junction')
        run_checks(Path(temporary)/'units')
        actual_runner_checks(Path(temporary)/'runner')
        lunge_checks(Path(temporary)/'lunge')
        profile_checks(Path(temporary)/'profiles')
        actual_runner_checks(Path(temporary)/'threat-runner',profile='private-threat-contacts')
        d1_source_checks(Path(temporary)/'d1-source')
        actual_runner_checks(Path(temporary)/'d1-runner',profile='d1-shared-reasoning')
        d1_subset_checks(Path(temporary)/'d1-subset')
        actual_runner_checks(Path(temporary)/'d1-subset-runner',profile='d1-shared-reasoning',subset=True)
        subset_mutation_checks(Path(temporary)/'d1-subset-mutants')
        animation_checks(Path(temporary)/'animation')
        callback_checks(Path(temporary)/'callback')
        callback_mutation_checks(Path(temporary)/'callback-mutants')
        callback_checks(Path(temporary)/'callback-preparation', preparation=True)
        preparation_mutation_checks(Path(temporary)/'preparation-mutants')
        callback_checks(Path(temporary)/'callback-rebind',preparation=True,rebind=True)
        rebind_mutation_checks(Path(temporary)/'rebind-mutants')
        callback_checks(Path(temporary)/'callback-budgets',preparation=True,budgets=True)
        budgets_mutation_checks(Path(temporary)/'budgets-mutants')
    print(json.dumps({'status':'PASS','checks':len(CHECKS),'rejectionControls':len(CONTROLS),
                      'checkNames':CHECKS,'controlNames':CONTROLS},indent=2))
    return 0

if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print('world_lab_delivery_test FAILED: '+str(error),file=sys.stderr)
        raise SystemExit(1)
