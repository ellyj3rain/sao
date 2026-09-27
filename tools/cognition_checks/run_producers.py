import sys
sys.dont_write_bytecode=True
from pathlib import Path
import hashlib,json,os,shutil,subprocess,tempfile
from run_checks import ROOT,BASE,HERE,GAME,JDK,MODEL,COG,OUTPUT
sys.path.insert(0,str(ROOT/'tools'))
import private_inventory_test as inventory
import provisioning_transfer_cases as transfer
import source_use_test as source

def run():
    output=OUTPUT;output.mkdir(parents=True,exist_ok=True)
    W=BASE/'mod/42.20/media/lua/shared/SAO_WorldSources.lua'
    P=BASE/'mod/42.20/media/lua/shared/SAO_Perception.lua'
    SU=BASE/'mod/42.20/media/lua/client/SAO_SourceUse.lua'
    fp='a'*64
    empty={'id':'C:test:0','fp':fp,'rev':'empty-1','kind':'container','x':11,'y':11,'building':-1,
           'state':'spent','quantities':{},'items':[]}
    candidate=f'H|protocol=SAOWI1\nC|id=C:test:0|fp={fp}|sx=11|sy=11|sz=0|x=10|y=11|z=0|reachable=1\nE\n'
    snapshot='I|source=C:test:0\n'+source.snapshot(1,1,'chunk-empty',[empty])
    inspection_prelude=inventory.INSPECTION_PRELUDE+ '\nSAO.Identity.all=function()return records end\n'+ '\ncandidateText='+json.dumps(candidate)+'\nsnapshotText='+json.dumps(snapshot)+'\n'
    transfer_prelude=transfer.prelude()+r'''
ModData.get=function(key)return __stores[key]end
SAO.Identity.all=function()return __records end
SAO.History.ticks=function()return 48*9000 end
SAO.History.ticksFromHours=function(h)return h*9000 end
__witnessSkilled=true
SAO.Census={skillOf=function(id,perk)
    if id=='a' and perk=='Cooking' then return 3 end
    if id=='b' and perk=='Foraging' and __witnessSkilled then return 2 end
    return 0
end}
SAO.Conditions={memoryFactor=function()return 1 end}
SAO.Standing.provisioningContextAt=function()return 'personal' end
bodyD={};__item={};__container={}
for _,body in ipairs({bodyA,bodyB,bodyC,bodyD}) do
    function body:getX()return 8 end;function body:getY()return 8 end;function body:getZ()return 0 end
end
SAO.Body.active=__bodies;SAO.Body.foreign={}
SAO.Needs={busy=function()return __busy end,
    queueVerified=function(a)if __rejectQueue then return false end;__busy=true;return true end,
    worldSourceTransferAction=function()return {}end}
SAOJavaBridge.bindWorldSourceAction=function()return 'BOUND:8:8:0'end
SAOJavaBridge.worldSourceActionItem=function()return __item end
SAOJavaBridge.worldSourceActionContainer=function()return __container end
SAOJavaBridge.worldSourceActionPermissionContainer=function()return __container end
SAOJavaBridge.observeWorldChunk=function()return __observeText end
SAOJavaBridge.clearWorldSourceAction=function()end
SAOJavaBridge.carriedWorldSourceItem=function()return __carried end
SAOJavaBridge.canWitnessWorldTransfer=function(self,candidate)return candidate==bodyB end
'''
    checks=[('inspection',inspection_prelude,[W,P],HERE/'inspection.lua'),
            ('transfer',transfer_prelude,[W,P,SU],HERE/'transfer.lua')]
    controls=[
        ('inspection-missing',W,'if SAO.Cognition and context.cognitionToken then','if false then','inspection','exact_empty_inspection'),
        ('inspection-empty-true',W,'foodPresent = (tonumber(source.quantities.food) or 0) > 0','foodPresent = true','inspection','empty_is_known_not_failure'),
        ('actor-missing',W,'if SAO.Cognition and reservation.cognitionToken then','if false then','transfer','completed_transfer_one_actor_event'),
        ('admission-binding-missing',SU,'reservation.cognitionToken = SAO.Cognition.capture(tostring(id), "source")','-- token missing','transfer','source_admission_token'),
        ('witness-missing',P,'if source == "observed" and SAO.Cognition then','if false then','transfer','captured_witness_only'),
        ('actor-double-count',P,'if source == "observed" and SAO.Cognition then','if SAO.Cognition then','transfer','captured_witness_only'),
        ('witness-capabilities-now',P,'capabilities = cognitionCapabilities and cognitionCapabilities[id]','capabilities = SAO.Cognition.capabilities(id)','transfer','witness_own_frozen_capability'),
        ('witness-proof-omitted',P,'or observation.nativeTransferProven ~= true','or false','transfer','unproved_witness_refused'),
    ]
    if os.environ.get('BASELINE_ONLY')=='1':controls=[]
    receipt={'schema':'sao-cognition-producer-checks/1','variants':[],
             'sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [COG,MODEL,W,P,SU,HERE/'inspection.lua',HERE/'transfer.lua']}}
    with tempfile.TemporaryDirectory(prefix='sao-cognition-producers-') as raw:
        work=Path(raw);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua')
        jar=GAME/'projectzomboid.jar'
        result=subprocess.run([str(JDK/'javac.exe'),'-cp',str(jar),'-d',str(work),str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=60)
        assert result.returncode==0,result.stderr
        for label,path,before,after,kind,marker in [(kind,None,None,None,kind,None) for kind,*_ in checks]+controls:
            _,prelude,modules,cases=next(x for x in checks if x[0]==kind)
            pre=work/(label+'-pre.lua');pre.write_text(prelude,encoding='utf-8')
            selected=[]
            for p in modules:
                if p==path:
                    original=p.read_text(encoding='utf-8');assert before in original,label
                    value=original.replace(before,after,1)
                    if label=='actor-double-count':
                        value=value.replace('perspective = "observed", status = "completed"','perspective = source, status = "completed"',1)
                    mutant=work/(label+'-mutant.lua');mutant.write_text(value,encoding='utf-8');selected.append(mutant)
                else:selected.append(p)
            result=subprocess.run([str(JDK/'java.exe'),'-cp',str(jar)+os.pathsep+str(work),'LuaRun',str(pre),
                str(ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua'),str(ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua'),str(MODEL),str(COG),*map(str,selected),str(cases),'--','RESULT'],
                cwd=work,capture_output=True,text=True,timeout=60)
            text=result.stdout+result.stderr;(output/(label+'-producer.log')).write_text(text,encoding='utf-8')
            if marker:assert result.returncode!=0 and 'PRODUCER:'+marker in text,(label,text)
            else:assert result.returncode==0 and 'PASS cognition '+kind in text,(label,text)
            receipt['variants'].append({'name':label,'exit':result.returncode,'expected':marker,'sha256':hashlib.sha256(text.encode()).hexdigest()})
            print(label+': '+text.strip().splitlines()[-1],flush=True)
    (output/'producer-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':run()
