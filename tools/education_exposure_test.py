"""Authored work/community content through native validation and actual Lua inquiry.

The input registry is reconstructed from held source bytes and explicit authored
events. Native visible cues and movement are controlled; no live acceptance or
retention/mastery/assent is asserted. Prior schooling fixtures remain separate.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import education_background_test as base
from native_proof_preflight import installed_presence

ROOT=base.ROOT
FILES={**{k:v for k,v in base.FILES.items() if k not in ('admissions','admission_cases')},
       'background_cases':ROOT/'tools/education_exposure_cases.lua'}

def sync(value):
    """Reseal custody so negative cases test semantics, not an obsolete transport hash."""
    for row in value['rows']:
        history=row.get('contentExposureHistory')
        if history:
            authored=history['authoredHistory']
            for i,receipt in enumerate(history['receipts']):
                receipt['event']=copy.deepcopy(authored['events'][i])
                receipt['authoredHistorySha256']=hashlib.sha256(base.encoded(authored)).hexdigest()
                history['receipts'][i]=base.seal(receipt)
            history=base.seal(history);row['contentExposureHistory']=history
            for meaning in row['backgroundRelations']:
                if meaning['schema'].endswith('/2'):
                    old=meaning['acquisition']
                    meaning['acquisition']=copy.deepcopy(next(r for r in history['receipts'] if r['unit']['id']==old['unit']['id']))
                    meaning['contentExposureHistorySha256']=history['contentSha256']
                    meaning['projectionSha256']=hashlib.sha256(base.encoded(meaning['projection'])).hexdigest()
        row['backgroundRelations']=[base.seal(m) for m in row['backgroundRelations']]
    value['rows']=[base.seal(r) for r in value['rows']]
    return base.seal(value)

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--registry',type=Path)
    p.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-shared-reasoning/background-exposures/proof')
    p.add_argument('--baseline-only',action='store_true')
    p.add_argument('--controls-only',action='store_true',help='Lua restored-defect controls; reuse the existing native authority proof.')
    p.add_argument('--native-only',action='store_true',help='Native authority checks only; no mutable Lua consumer inputs.')
    p.add_argument('--workbench',action='store_true',help='Additional projection of the same exposed Mechanics unit to a visible workbench.')
    p.add_argument('--control',choices=['workbench_not_consumed','query_selects_native_holder','exact_holder_omitted',
        'generic_inquiry_completion','forged_inspection_receipt','completed_holder_repeated','retained_inquiry_omitted',
        'inspection_completes_goal'],help='One targeted restored-defect control; requires --workbench.')
    args=p.parse_args(argv);out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    if args.control and (not args.workbench or args.baseline_only or args.native_only):p.error('--control requires --workbench without baseline/native-only')
    if args.controls_only and (args.baseline_only or args.native_only or args.control):p.error('--controls-only cannot combine with other selectors')
    registry=(args.registry or ROOT/'tools/education_background/fixtures'/('workbench-registry.json' if args.workbench else 'authored-registry.json')).resolve();data=json.loads(registry.read_text(encoding='utf-8'))
    jar=base.fixture.GAME/'projectzomboid.jar';classes=out/'classes';classes.mkdir(exist_ok=True)
    paths=[*([] if args.native_only else FILES.values()),base.NATIVE,base.PROBE,Path(__file__),Path(base.__file__),
        Path(base.fixture.__file__),Path(base.concepts.__file__),registry,
        ROOT/'java/src/com/sao/engine/SAODurableText.java',jar,base.fixture.GAME/'stdlib.lua']
    paths += [ROOT/'tools/education_background'/n for n in ('compiler.py','source_fixture.py','workshop-tools-v1.json','civic-mutual-assistance-v1.json','workbench-tools-v1.json')]
    if args.workbench:paths.extend([ROOT/'tools/education_workbench_cases.lua',ROOT/'mod/42.20/media/lua/shared/SAO_WorldSources.lua'])
    provenance=registry.with_name('workbench-source-evidence.json' if args.workbench else 'authored-source-evidence.json')
    if provenance.is_file():paths.append(provenance)
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, base.fixture.GAME, base.fixture.JDK, "education exposure")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    receipt={'schema':'sao-authored-exposure-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],'boundary':__doc__}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,cmd,expected=None):
        result=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,text=True,timeout=180)
        log=result.stdout+result.stderr;(out/(name+'.log')).write_text(log,encoding='utf-8')
        receipt['runs'].append({'name':name,'command':list(map(str,cmd)),'cwd':str(out),'exit':result.returncode,
            'expected':expected,'logSha256':hashlib.sha256(log.encode()).hexdigest()});save()
        return result.returncode,log
    def native(path,cp=None):
        return [base.fixture.JDK/'java.exe','-cp',os.pathsep.join(map(str,cp or [jar,classes])),
            'EducationBackgroundProbe','java',path,hashlib.sha256(path.read_bytes()).hexdigest(),
            data['worldDefinitionSha256'],data['sourceBankSha256'],data['sourceArchiveSha256'],108000]
    try:
        code,log=run('compile',[base.fixture.JDK/'javac.exe','-cp',jar,'-d',classes,base.NATIVE,
            ROOT/'java/src/com/sao/engine/SAODurableText.java',base.PROBE]);assert code==0,log
        shutil.copy2(base.fixture.GAME/'stdlib.lua',out/'stdlib.lua')
        (out/'prelude.lua').write_text(base.fixture.PRELUDE+'\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n',encoding='utf-8')
        (out/'capture.lua').write_text('__conceptModules={planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,perception=SAO.Perception}\nSAO.Perception=__ordinaryPerception\n',encoding='utf-8')
        sources={k:path.read_text(encoding='utf-8') for k,path in FILES.items()}
        if args.workbench:
            native_owner=(ROOT/'mod/42.20/media/lua/shared/SAO_WorldSources.lua').read_text(encoding='utf-8')
            sources['worldsources']='local previous=SAO.WorldSources;SAO.WorldSources={}\n'+native_owner.replace(
                'return WS\n','__workbenchWorldSources=WS;SAO.WorldSources=previous\nreturn WS\n')
        code,log=run('native-production',native(registry));assert code==0 and log.startswith('SAO_EDUCATION_REGISTRY_3'),log
        variants=[] if args.native_only else [('production',None,None,None,None)]
        if not args.baseline_only and not args.native_only:
            variants += [
                ('authored_roots_omitted','registry','rows[#rows+1]=edge','if #columns==18 then rows[#rows+1]=edge end','two_authored_sources_distinct'),
                ('authored_conditions_removed','registry','edge.conditions[#edge.conditions+1]=condition','local omitted=condition','civic_exposure_has_no_assent'),
                ('authored_assent_granted','registry','edge.assent="not-established"','edge.assent="accepted"','civic_exposure_has_no_assent'),
                ('authored_source_alias','registry','local result=copy(edge)','local result=edge','query_detached_no_relearning')]
            if args.workbench:
                variants += [('workbench_not_consumed','concepts',
                    'if edge.actorId==id and valid(edge) and (edge.basis=="generated-schooling-exposure" or authored)',
                    'if edge.actorId==id and edge.from~="workbench" and valid(edge) and (edge.basis=="generated-schooling-exposure" or authored)',
                    'WORKBENCH:conditional_bench_content')]
                variants += [
                    ('query_selects_native_holder','planning',
                     'local out={goal=goal,status="unresolved",reason="No current personally observed place is available."}',
                     'local out={goal=goal,status="unresolved",reason="No current personally observed place is available."}\nif SAO.WorldSources then SAO.WorldSources.inspectionCandidate(id,SAO.Body.get(id),"standing",12) end',
                     'WORKBENCH:query_does_not_select_native_holder'),
                    ('exact_holder_omitted','controller','sources.inspectionCandidate(id,body,"standing",12,fresh.sourceId)',
                     'sources.inspectionCandidate(id,body,"standing",12)', 'WORKBENCH:actual_bench_route_dispatched'),
                    ('generic_inquiry_completion','planning','if purpose and purpose.inquiry and purpose.inquiry.mode=="inspect-holder" then return false end',
                     'if false then return false end','WORKBENCH:generic_completion_cannot_finish_inquiry'),
                    ('forged_inspection_receipt','planning','and SAO.WorldSources.inspectionOutcome(id, receipt.id)',
                     'and receipt','WORKBENCH:invented_native_receipt_refused'),
                    ('completed_holder_repeated','planning','local inspected=previous and previous.actorId==id',
                     'local inspected=false and previous and previous.actorId==id','WORKBENCH:same_holder_not_repeated'),
                    ('retained_inquiry_omitted','controller','if not studying and planning.pendingConceptInquiries then',
                     'if false then','WORKBENCH:ordinary_chooser_resumes_genuine_inquiry'),
                    ('inspection_completes_goal','planning','purpose.status,purpose.updatedAt="maintained",canonical.atHours',
                     'purpose.status,purpose.updatedAt=canonical.status=="completed" and "completed" or "maintained",canonical.atHours','WORKBENCH:inspection_does_not_complete_material_goal')]
        if args.control:variants=[v for v in variants if v[0]==args.control]
        if args.controls_only:variants=[v for v in variants if v[0]!='production']
        for name,key,before,after,marker in variants:
            current=dict(sources)
            if key:
                assert current[key].count(before)==1,(name,'anchor');current[key]=current[key].replace(before,after,1)
            current['controller']=current['controller'].replace('return Ctl\n',base.fixture.EXPOSE)
            current['cases']=current.pop('ordinary')+'\n'+current['cases']+'\n'+current.pop('background_cases')
            if args.workbench:
                current['cases']='__workbenchProof=true\n'+current['cases']+'\n'+(ROOT/'tools/education_workbench_cases.lua').read_text(encoding='utf-8')
                current['cases']='local passed,reason=pcall(function()\n'+current['cases']+'\nend) if not passed then error(tostring(__lastWorkbenchCase).."; "..tostring(reason)) end\n'
            for key,text in current.items():(out/(key+'.lua')).write_text(text,encoding='utf-8')
            cmd=[base.fixture.JDK/'java.exe','-cp',os.pathsep.join(map(str,[jar,classes])),'EducationBackgroundProbe','lua-workbench' if args.workbench else 'lua-authored',registry,
                 hashlib.sha256(registry.read_bytes()).hexdigest(),data['worldDefinitionSha256'],data['sourceBankSha256'],data['sourceArchiveSha256'],108000,
                 'prelude.lua','models.lua','cognition.lua','needs.lua','perception.lua','concepts.lua','planning.lua','locomotion.lua',
                 'capture.lua','controller.lua','education.lua','registry.lua',*(['worldsources.lua'] if args.workbench else []),'cases.lua']
            code,log=run(name,cmd,marker)
            verdict=marker if marker and ':' in marker else 'EXPOSURE:'+marker if marker else None
            assert (code!=0 and verdict in log) if marker else code==0 and 'PASS background exposures' in log,(name,log)
            print(name,log.strip().splitlines()[-1],flush=True)
        if not args.baseline_only and not args.control and not args.controls_only:
            mutations={
                'foreign_person':lambda d:d['rows'][0]['backgroundRelations'][2].update(personId='unexposed'),
                'future_admission':lambda d:d['rows'][0]['backgroundRelations'][2].update(admittedAtTick=108001),
                'changed_semantics':lambda d:d['rows'][0]['backgroundRelations'][2]['projection']['relations'][0].update(into='safe-food'),
                'future_event':lambda d:d['rows'][0]['contentExposureHistory']['authoredHistory']['events'][0].update(endYear=1994),
                'foreign_region':lambda d:d['rows'][0]['contentExposureHistory']['authoredHistory']['events'][0].update(regionId='unexposed-region'),
                'unknown_event_unit':lambda d:d['rows'][0]['contentExposureHistory']['authoredHistory']['events'][0].update(unitId='not-the-source'),
                'label_channel':lambda d:d['rows'][0]['contentExposureHistory']['authoredHistory']['events'][0].update(channel='occupation-label'),
                'foreign_world':lambda d:d['rows'][0]['contentExposureHistory']['authoredHistory']['worldOwner'].update(seed='foreign'),
                'foreign_person_history':lambda d:d['rows'][0]['contentExposureHistory']['authoredHistory'].update(personEducationSha256='d'*64),
                'mastery_granted':lambda d:d['rows'][0]['contentExposureHistory']['receipts'][0].update(personalRetentionAuthority=True)}
            for name,mutate in mutations.items():
                changed=copy.deepcopy(data);mutate(changed);changed=sync(changed)
                path=out/(name+'.json');path.write_bytes(base.encoded(changed))
                code,log=run(name,native(path),'native refusal');assert code==2 and log.startswith('SAO_EDUCATION_REFUSED_2'),(name,log)
            text=base.NATIVE.read_text(encoding='utf-8')
            for name,before,after,invalid in [
                ('native_future_guard_removed','require(admitted <= tick, "authored-meaning-future");','require(true, "authored-meaning-future");','future_admission'),
                ('native_projection_guard_removed','EXPOSURE_PROJECTIONS.contains(projectionSha)','true','changed_semantics'),
                ('native_region_guard_removed','require(residence.equals(event.get("regionId")), "exposure-region-binding");','require(true, "exposure-region-binding");','foreign_region')]:
                assert text.count(before)==1,(name,'anchor')
                folder=out/name;folder.mkdir(exist_ok=True);source=folder/base.NATIVE.name;source.write_text(text.replace(before,after,1),encoding='utf-8')
                code,log=run(name+'-compile',[base.fixture.JDK/'javac.exe','-d',folder,source]);assert code==0,log
                code,log=run(name,native(out/(invalid+'.json'),[folder,jar,classes]),'restored defect accepts invalid input')
                assert code==0 and log.startswith('SAO_EDUCATION_REGISTRY_3'),(name,log)
        receipt['inputsAfter']=pins();assert receipt['inputsAfter']==receipt['inputs'],'source input drift'
        receipt.update(status='PASS',exit=0);save()
    except Exception:
        receipt.update(status='FAIL',exit=1);save();raise
    return 0

if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print('FAIL authored exposure: '+str(error),file=sys.stderr);raise SystemExit(1)
