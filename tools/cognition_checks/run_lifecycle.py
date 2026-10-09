import hashlib,json,os,shutil,subprocess,tempfile
from pathlib import Path
from run_checks import ROOT,BASE,HERE,GAME,JDK,MODEL,COG,OUTPUT

def run():
    controller=ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua'
    identity=ROOT/'mod/42.20/media/lua/shared/SAO_Identity.lua'
    inputs=[COG,MODEL,controller,identity,HERE/'lifecycle.lua',HERE/'lifecycle_prelude.lua']
    receipt={'schema':'sao-cognition-lifecycle/1','sources':{str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in inputs},'variants':[]}
    control=[
        ('missing-drop',controller,'SAO.Cognition.interrupt(id, "controller-drop")','-- omitted','successful_drop_censors'),
        ('premature-drop',controller,'function Ctl.drop(id)\n    id = tostring(id)','function Ctl.drop(id)\n    id = tostring(id)\n    SAO.Cognition.interrupt(id,"bad-early-drop")','refused_drop_retains_episode'),
        ('missing-adoption',controller,'if not Ctl.agents[rec.id] then\n        closeUnownedCognitionOnAdoption(rec.id)','if not Ctl.agents[rec.id] then\n        -- omitted cognition adoption','fresh_adoption_closes_orphan'),
        ('ignore-source-owner',controller,'if not ok or sourceOwner then return end','if not ok then return end','adoption_retains_source_owner'),
        ('missing-death',identity,'SAO.Cognition.interrupt(rec.id, "death")','-- omitted','canonical_death_censors_after_dead'),
        ('premature-death',identity,'if rec.returnTransition then return false end','SAO.Cognition.interrupt(rec.id,"death")\n    if rec.returnTransition then return false end','refused_death_retains_episode'),
    ]
    with tempfile.TemporaryDirectory(prefix='sao-cognition-lifecycle-')as raw:
        work=Path(raw);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');jar=GAME/'projectzomboid.jar'
        result=subprocess.run([str(JDK/'javac.exe'),'-cp',str(jar),'-d',str(work),str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=60)
        assert result.returncode==0,result.stderr
        for label,target,before,after,marker in [('production',None,None,None,None)]+control:
            c=controller.read_text(encoding='utf-8-sig');i=identity.read_text(encoding='utf-8-sig')
            if target:
                source=c if target==controller else i;assert source.count(before)==1,label
                if target==controller:c=source.replace(before,after,1)
                else:i=source.replace(before,after,1)
            assert c.count('\nreturn Ctl')==1
            c=c.replace('\nreturn Ctl','\nCtl.__cognitionLifecycleUpdate=updateAgent\nreturn Ctl')
            cp=work/(label+'-controller.lua');cp.write_text(c,encoding='utf-8')
            ip=work/(label+'-identity.lua');ip.write_text(i,encoding='utf-8')
            result=subprocess.run([str(JDK/'java.exe'),'-cp',str(jar)+os.pathsep+str(work),'LuaRun',
                str(HERE/'prelude.lua'),str(HERE/'lifecycle_prelude.lua'),str(ip),
                str(ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua'),
                str(MODEL),str(COG),str(cp),str(HERE/'lifecycle.lua'),'--','RESULT'],cwd=work,capture_output=True,text=True,timeout=60)
            text=result.stdout+result.stderr;(OUTPUT/('lifecycle-'+label+'.log')).write_text(text,encoding='utf-8')
            if marker:assert result.returncode!=0 and 'LIFECYCLE:'+marker in text,(label,text)
            else:assert result.returncode==0 and 'PASS cognition lifecycle' in text,text
            receipt['variants'].append({'name':label,'exit':result.returncode,'expected':marker,'sha256':hashlib.sha256(text.encode()).hexdigest()})
            print(label+': '+text.strip().splitlines()[-1],flush=True)
    (OUTPUT/'lifecycle-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':
    OUTPUT.mkdir(parents=True,exist_ok=True)
    run()
