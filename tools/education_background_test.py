"""Source-bound schooling expectations reach actual Controller inquiry dispatch.

Installed Java validators and Kahlua serialization run against a registry made
by the actual existing source compiler. Native visibility/movement receivers
are controlled. This proves no live gameplay, retention assessment or skill.
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
import concept_knowledge_test as concepts
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
FILES={**concepts.FILES,
    'education':ROOT/'mod/42.20/media/lua/shared/SAO_Education.lua',
    'registry':ROOT/'mod/42.20/media/lua/shared/SAO_EducationRegistry.lua',
    'admissions':ROOT/'mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua',
    'admission_cases':ROOT/'tools/education_background_admission_cases.lua',
    'background_cases':ROOT/'tools/education_background_cases.lua'}
NATIVE=ROOT/'java/src/com/sao/engine/SAOEducationPrior.java'
PROBE=ROOT/'tools/luacheck/EducationBackgroundProbe.java'

def encoded(value):
    return json.dumps(value,sort_keys=True,separators=(',', ':'),ensure_ascii=False,allow_nan=False).encode()

def seal(value):
    value=copy.deepcopy(value);value.pop('contentSha256',None)
    value['contentSha256']=hashlib.sha256(encoded(value)).hexdigest();return value

def run(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--registry',type=Path,default=ROOT/'tools/education_background/fixtures/registry.json')
    parser.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-shared-reasoning/background-priors/proof')
    parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args(argv);out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    registry=args.registry.resolve();data=json.loads(registry.read_text(encoding='utf-8'))
    jar=fixture.GAME/'projectzomboid.jar'
    paths=[*FILES.values(),NATIVE,PROBE,Path(__file__),Path(fixture.__file__),Path(concepts.__file__),
           ROOT/'java/src/com/sao/engine/SAODurableText.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java',
           ROOT/'mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua',
           ROOT/'tools/education_background/compiler.py',ROOT/'tools/education_background/source_fixture.py',
           ROOT/'tools/education_background/household-stove-cooking-v1.json',registry,
           registry.with_name('source-evidence.json'),jar,fixture.GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "education background")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao-education-background-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],
             'boundary':__doc__}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(name,command,expected=None):
        process=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,timeout=180)
        log=process.stdout+process.stderr;(out/(name+'.log')).write_text(log,encoding='utf-8')
        receipt['runs'].append({'name':name,'command':list(map(str,command)),'cwd':str(out),'exit':process.returncode,
            'expected':expected,'logSha256':hashlib.sha256(log.encode()).hexdigest()});save()
        return process.returncode,log
    try:
        classes=out/'classes';classes.mkdir(exist_ok=True)
        code,log=invoke('compile',[fixture.JDK/'javac.exe','-cp',jar,'-d',classes,NATIVE,
            ROOT/'java/src/com/sao/engine/SAODurableText.java',PROBE])
        assert code==0,log
        shutil.copy2(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
        (out/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n',encoding='utf-8')
        (out/'capture.lua').write_text('__conceptModules={planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,perception=SAO.Perception}\nSAO.Perception=__ordinaryPerception\n',encoding='utf-8')
        sources={key:p.read_text(encoding='utf-8') for key,p in FILES.items()}
        variants=[('production',None,None,None,None)]
        if not args.baseline_only:
            variants += [
                ('background_not_consumed','concepts','type(education.backgroundRelations)=="function"','false','background_composes_expectation'),
                ('unattached_background_accepted','education','if not E.conditioning(id,tick) then return nil end','if false then return nil end','unattached_background_refused'),
                ('dead_person_accepted','education','if not rec or rec.id~=id or rec.dead or not registry','if not rec or rec.id~=id or not registry','dead_person_refused'),
                ('misfiled_identity_accepted','education','or rec.id~=id or rec.dead','or rec.dead','misfiled_identity_refused'),
                ('contrary_background_ignored','concepts','local objection=denied[edge.from.."|"..edge.into]','local objection=nil','local_contradiction_blocks_expected_path'),
                ('background_without_conditions','registry','conditions={"suitable-food","usable-heating-means","permission"}','conditions={}','source_and_acquisition_retained'),
                ('source_background_not_restored','registry','backgroundRelations=roots','backgroundRelations={} ','supported_content_acquired'),
                ('population_attachment_omitted','admissions','        A.attachEducationRecord(rec)\n','        -- education attachment omitted\n','leader-history-then-prior'),
                ('birth_binding_ignored','registry','or nativeBirthYear ~= row.birthYear then','then','actual-native-birth-refused'),
                ('current_birth_binding_ignored','education','if not known or not profile or not finite(birth) or birth~=profile.birthYear then return nil end','if false then return nil end','native-birth-refusal-withholds-meaning'),
                ('world_rebind_keeps_provider','admissions','pcall(SAO.EducationRegistry.clear)','-- source provider retained','world-rebind-clears-source-owner'),
            ]
        for name,key,before,after,marker in variants:
            current=dict(sources)
            if key:
                assert current[key].count(before)==1,(name,'mutation anchor count',current[key].count(before))
                current[key]=current[key].replace(before,after,1)
            current['controller']=current['controller'].replace('return Ctl\n',fixture.EXPOSE)
            current['cases']=current.pop('ordinary')+'\n'+current['cases']+'\n'+current.pop('background_cases')
            for key,value in current.items(): (out/(key+'.lua')).write_text(value,encoding='utf-8')
            command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(classes)]),'EducationBackgroundProbe','lua',registry,
                hashlib.sha256(registry.read_bytes()).hexdigest(),data['worldDefinitionSha256'],data['sourceBankSha256'],data['sourceArchiveSha256'],108000,
                'prelude.lua','models.lua','cognition.lua','needs.lua','perception.lua','concepts.lua','planning.lua','locomotion.lua',
                'capture.lua','controller.lua','education.lua','registry.lua','admissions.lua','cases.lua','admission_cases.lua']
            code,log=invoke(name,command,marker)
            assert (code!=0 and any(prefix+marker in log for prefix in ('BACKGROUND:','CONCEPT:','EDUCATION_ADMISSION:'))) if marker else (code==0 and 'VALUE PASS background' in log),log
            print(name+': '+log.strip().splitlines()[-1],flush=True)
        # Resealed malformed semantics cannot substitute for the fixed source or
        # exact person/date projection even when their transport hash is fresh.
        mutations={
            'content_changed':lambda m:m.update(statementText=m['statementText']+' invented'),
            'meaning_changed':lambda m:m['relations'][0].update(into='food'),
            'foreign_person':lambda m:m.update(personId='unexposed'),
            'future_admission':lambda m:m.update(admittedAtTick=108001),
            'future_schooling':lambda m:m['acquisition'].update(endYear=1994),
            'before_publication':lambda m:m['acquisition'].update(startYear=1917),
            'not_attended':lambda m:m['acquisition'].update(attended=False),
            'source_relabelled':lambda m:m.update(sourceVersion='d'*64),
            'world_relabelled':lambda m:m['bindings'].update(worldSha256='d'*64),
            'conditions_removed':lambda m:m.update(conditions=[]),
        }
        for name,mutate in mutations.items():
            candidate=copy.deepcopy(data);row=candidate['rows'][0];meaning=row['backgroundRelations'][0]
            mutate(meaning);row['backgroundRelations'][0]=seal(meaning);candidate['rows'][0]=seal(row);candidate=seal(candidate)
            path=out/(name+'.json');raw=encoded(candidate);path.write_bytes(raw)
            command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(classes)]),'EducationBackgroundProbe','java',path,
                hashlib.sha256(raw).hexdigest(),data['worldDefinitionSha256'],data['sourceBankSha256'],data['sourceArchiveSha256'],108000]
            code,log=invoke(name,command,'refusal')
            assert code==2 and 'SAO_EDUCATION_REFUSED_2' in log,(name,log)
        if not args.baseline_only:
            native_text=NATIVE.read_text(encoding='utf-8')
            native_controls=[
                ('future_guard_removed','require(admitted <= tick, "background-future");','require(true, "background-future");','future_admission'),
                ('source_text_guard_removed','&& meaning.get("statementSha256").equals(sha256(statement.getBytes(StandardCharsets.UTF_8)))','&& true','content_changed'),
                ('person_guard_removed','personId.equals(meaning.get("personId")) && canonical(bindings).equals(canonical(meaning.get("bindings")))','true','foreign_person')]
            for name,before,after,invalid in native_controls:
                assert native_text.count(before)==1,(name,'mutation anchor')
                mutant=out/name;mutant.mkdir(exist_ok=True);source=mutant/NATIVE.name
                source.write_text(native_text.replace(before,after,1),encoding='utf-8')
                code,log=invoke(name+'-compile',[fixture.JDK/'javac.exe','-d',mutant,source]);assert code==0,log
                path=out/(invalid+'.json');raw=path.read_bytes()
                command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(mutant),str(jar),str(classes)]),'EducationBackgroundProbe','java',path,
                    hashlib.sha256(raw).hexdigest(),data['worldDefinitionSha256'],data['sourceBankSha256'],data['sourceArchiveSha256'],108000]
                code,log=invoke(name,command,'restored defect: invalid input accepted')
                assert code==0 and log.startswith('SAO_EDUCATION_REGISTRY_2'),(name,'control did not reach defective acceptance',log)
        receipt['inputsAfter']=pins();assert receipt['inputsAfter']==receipt['inputs'],'input drift'
        receipt['status']='PASS';save()
    except Exception:
        receipt['status']='FAIL';save();raise
    return 0

if __name__=='__main__':
    try: raise SystemExit(run())
    except Exception as error:
        print('FAIL educational background: '+str(error),file=sys.stderr)
        raise SystemExit(1)
