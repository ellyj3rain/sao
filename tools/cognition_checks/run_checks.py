from pathlib import Path
import hashlib,importlib.util,json,os,shutil,subprocess,tempfile

HERE=Path(__file__).resolve().parent
ROOT=Path(os.environ.get("SAO_COGNITION_SOURCE_ROOT",str(HERE.parents[1])))
BASE=Path(os.environ.get("SAO_COGNITION_CANDIDATE_ROOT",str(ROOT)))
OUTPUT=Path(os.environ.get("SAO_COGNITION_OUTPUT",str(ROOT/"_scratch/cognition-checks")))
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
MODEL=Path(os.environ.get('SAO_COGNITION_MODEL',str(BASE/'mod/42.20/media/lua/shared/SAO_CognitiveModels.lua')))
COG=BASE/'mod/42.20/media/lua/shared/SAO_Cognition.lua'

def run():
    output=OUTPUT;output.mkdir(parents=True,exist_ok=True)
    jar=GAME/'projectzomboid.jar'
    if not jar.is_file(): print('SKIPPED installed Kahlua absent');return
    receipt={'schema':'sao-cognition-runtime-checks/1','cases':[],'sources':{}}
    for p in [COG,MODEL,ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua',HERE/'runtime.lua',HERE/'prelude.lua']:
        receipt['sources'][str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='sao-cognition-') as raw:
        work=Path(raw);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua')
        built=subprocess.run([str(JDK/'javac.exe'),'-cp',str(jar),'-d',str(work),str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=60)
        assert built.returncode==0,built.stderr
        source=COG.read_text(encoding='utf-8')
        controls=[
          ('independent-frames','copy(frame))','frame)','both_receive_same_private_frame'),
          ('prior-frame','frame = frame, proposals = proposals','frame = supplied, proposals = proposals','immutable_prior_frame'),
          ('duplicate','if s.seen[x.id] then','if false then','duplicate_no_learning'),
          ('duplicate-conflict','prior.id == x.id and sameData(prior, x)','prior.id == x.id','conflicting_duplicate_rejected'),
          ('late-binding','x.episodeId ~= e.id or ','','late_outcome_cannot_resolve_new_episode'),
          ('no-effect-scored','e.outcome.success, e.outcome.revisions = success, revisions','e.outcome.success, e.outcome.revisions = true, revisions','measured_no_effect'),
          ('settings-paused','data.settings = { enabled = true','if old then return false end\n    data.settings = { enabled = true','paused_configuration'),
          ('evicted-replay','if x.worldHours <= s.retiredThroughHour then','if false then','evicted_replay_refused'),
          ('pending','s.pendingEpisode or (frame.id','false or (frame.id','single_pending'),
          ('allocation','local index = allocation >= 1 and 2 or 1','local index = 1','rival_can_execute'),
          ('frame-scope','for k in pairs(f) do if not FRAME_KEYS[k] then return nil end end','-- hidden input admitted','objective_frame_rejected'),
          ('dead-snapshot','local s = state(id, false, true)\n    local out','local s = state(id)\n    local out','dead_snapshot_retained'),
          ('zero-weight','or allocation == 1','or false','zero_weight_never_selected'),
          ('projection-budget','while jsonBytes(out) > 65536 do','while false do','bounded_projection_reports_omissions'),
        ]
        for label,before,after,marker in [('production',None,None,None)]+controls:
            candidate=source
            if before:
                assert source.count(before)==1,(label,source.count(before));candidate=source.replace(before,after,1)
            p=work/(label+'.lua');p.write_text(candidate,encoding='utf-8')
            result=subprocess.run([str(JDK/'java.exe'),'-cp',str(jar)+os.pathsep+str(work),'LuaRun',str(HERE/'prelude.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua'),str(MODEL),str(p),str(HERE/'runtime.lua'),'--','RESULT'],cwd=work,capture_output=True,text=True,timeout=60)
            text=result.stdout+result.stderr;(output/(label+'.log')).write_text(text,encoding='utf-8')
            if marker: assert result.returncode!=0 and 'COGNITION:'+marker in text,(label,text)
            else: assert result.returncode==0 and 'PASS cognition runtime ' in text,text
            receipt['cases'].append({'name':label,'exit':result.returncode,'expectedFailure':marker,'logSha256':hashlib.sha256(text.encode()).hexdigest()})
            print(label+': '+text.strip().splitlines()[-1],flush=True)
        exported=subprocess.run([str(JDK/'java.exe'),'-cp',str(jar)+os.pathsep+str(work),'LuaRun',str(HERE/'prelude.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua'),str(MODEL),str(COG),str(HERE/'runtime.lua'),str(HERE/'export.lua'),'--','RESULT'],cwd=work,capture_output=True,text=True,timeout=60)
        assert exported.returncode==0,exported.stdout+exported.stderr
        actual=json.loads(next(line[6:] for line in exported.stdout.splitlines() if line.startswith('VALUE ')))
        (output/'snapshot.json').write_text(json.dumps(actual,indent=2)+'\n',encoding='utf-8')
        stress=work/'stress.lua';stress.write_text('MAXIMAL_EXPORT=true',encoding='utf-8')
        exported=subprocess.run([str(JDK/'java.exe'),'-cp',str(jar)+os.pathsep+str(work),'LuaRun',str(HERE/'prelude.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua'),str(MODEL),str(COG),str(HERE/'runtime.lua'),str(stress),str(HERE/'export.lua'),'--','RESULT'],cwd=work,capture_output=True,text=True,timeout=60)
        assert exported.returncode==0,exported.stdout+exported.stderr
        raw=next(line[6:] for line in exported.stdout.splitlines() if line.startswith('VALUE '))
        assert len(raw.encode('utf-8'))<=65536,len(raw.encode('utf-8'))
        receipt['maximalProjectionBytes']=len(raw.encode('utf-8'))
        (output/'maximal-snapshot.json').write_text(raw+'\n',encoding='utf-8')
        unicode_flag=work/'unicode.lua';unicode_flag.write_text('UNICODE_EXPORT=true',encoding='utf-8')
        # Measure the bytes actually emitted by installed Kahlua/Java, not a
        # second Python implementation of the producer's counting algorithm.
        for label,unicode_source in [('production',source),('old-unit-count',source.replace(
                'elseif b < 128 then n = n + 1','elseif b >= 128 then n = n + 1\n            elseif b < 128 then n = n + 1',1))]:
            candidate=work/('unicode-'+label+'.lua');candidate.write_text(unicode_source,encoding='utf-8')
            exported=subprocess.run([str(JDK/'java.exe'),'-Dstdout.encoding=UTF-8','-Dsun.stdout.encoding=UTF-8','-cp',str(jar)+os.pathsep+str(work),'LuaRun',
                str(HERE/'prelude.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua'),
                str(MODEL),str(candidate),str(HERE/'runtime.lua'),str(unicode_flag),str(HERE/'export.lua'),'--','RESULT'],
                cwd=work,capture_output=True,text=True,encoding='utf-8',timeout=60)
            assert exported.returncode==0,exported.stdout+exported.stderr
            raw=next(line[6:]for line in exported.stdout.splitlines()if line.startswith('VALUE '))
            value=json.loads(raw);actual_bytes=len(raw.encode('utf-8'))
            (output/('unicode-'+label+'-raw.json')).write_text(raw+'\n',encoding='utf-8')
            assert len(value['models'])==2 and '\u6797' in raw, (label,actual_bytes,ascii(raw[:300]),
                [len(m['beliefs'])for m in value['models']])
            if label=='production':
                assert actual_bytes<=65536,('unicode-projection-byte-budget',actual_bytes)
                receipt['unicodeProjectionBytes']=actual_bytes
                (output/'unicode-snapshot.json').write_text(raw+'\n',encoding='utf-8')
            else:
                assert unicode_source!=source and actual_bytes>65536,('unicode control survived',actual_bytes)
                receipt['cases'].append({'name':'utf16-unit-count','expectedFailure':'unicode-projection-byte-budget',
                    'actualBytes':actual_bytes,'logSha256':hashlib.sha256(raw.encode()).hexdigest()})
            print('unicode '+label+': '+str(actual_bytes)+' bytes',flush=True)
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':run()
