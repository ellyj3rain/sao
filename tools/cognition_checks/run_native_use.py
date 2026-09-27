from pathlib import Path
import hashlib,json,os,shutil,subprocess,tempfile
from run_checks import ROOT,BASE,HERE,GAME,JDK,MODEL,COG,OUTPUT

def run():
    out=OUTPUT;out.mkdir(parents=True,exist_ok=True)
    jar=GAME/'projectzomboid.jar';sao=ROOT/'mod/42.20/media/java/SAO.jar'
    needs=BASE/'mod/42.20/media/lua/client/SAO_Needs.lua'
    installed=[GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
        GAME/'media/lua/client/ISUI/ISInventoryPaneContextMenu.lua',
        *[GAME/('media/lua/shared/TimedActions/'+name+'.lua') for name in
          ('ISEatFoodAction','ISTakePillAction','ISDrinkFluidAction','ISTakeWaterAction')]]
    inputs=[ROOT/'tools/world_lab/TransferUiChecks.lua',*installed,HERE/'prelude.lua',
            ROOT/'mod/42.20/media/lua/shared/SAO_Hash.lua',ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua',MODEL,COG]
    receipt={'schema':'sao-cognition-native-use/1','inputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [*inputs,needs,HERE/'native_use.lua',HERE/'CognitionUseProbe.java',jar,sao]},'variants':[]}
    with tempfile.TemporaryDirectory(prefix='sao-cognition-native-') as raw:
        work=Path(raw);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua')
        cp=os.pathsep.join(map(str,[jar,GAME/'ZombieBuddy.jar',sao]))
        compile=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(work),
            str(ROOT/'tools/luacheck/MovementCrossingProbe.java'),str(ROOT/'tools/luacheck/ResourceApproachProbe.java'),
            str(HERE/'CognitionUseProbe.java')],capture_output=True,text=True,timeout=120)
        (out/'native-use-compile.log').write_text(compile.stdout+compile.stderr,encoding='utf-8')
        assert compile.returncode==0,compile.stdout+compile.stderr
        source=needs.read_text(encoding='utf-8')
        controls=[
            ('omit-use-producer','wrapUseEvidence(ISEatFoodAction, "food", false)','-- omitted','native_start_is_attempted'),
            ('reverse-relief','local delta = before.before - measured','local delta = measured - before.before','native_food_delta_published'),
            ('omit-fixture-water','wrapUseEvidence(ISTakeWaterAction, "water", true)','-- omitted','fixture_water_delta_published'),
            ('fill-as-consume','not fixture or action.item == nil','true','bottle_filling_not_consumption'),
            ('error-as-completed','ok and result == true and "completed" or "unavailable"','"completed"','native_callback_error_censored'),
            ('body-binding-omitted','cognitionBodyId(action.character) == before.id','true','replaced_body_binding_censored'),
            ('missing-need-as-zero','if measured == nil then return nil end','if measured == nil then measured = 0 end','absent_baseline_is_not_zero_need'),
        ]
        if os.environ.get('BASELINE_ONLY')=='1':controls=[]
        for label,before,after,marker in [('production',None,None,None)]+controls:
            value=source
            if before:
                assert source.count(before)==1,(label,source.count(before));value=source.replace(before,after,1)
            p=work/(label+'.lua');p.write_text(value,encoding='utf-8')
            result=subprocess.run([str(JDK/'java.exe'),'-Duser.home='+str(work),'-Djava.awt.headless=true',
                '-Dstdout.encoding=UTF-8','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,
                'CognitionUseProbe',str(GAME),*map(str,inputs),str(p),str(HERE/'native_use.lua')],
                cwd=work,capture_output=True,text=True,timeout=120)
            output=result.stdout+result.stderr;(out/('native-use-'+label+'.log')).write_text(output,encoding='utf-8')
            if marker:assert result.returncode!=0 and 'PRODUCER:'+marker in output,(label,output)
            else:assert result.returncode==0 and 'PASS cognition native use ' in output,output
            receipt['variants'].append({'name':label,'exit':result.returncode,'expected':marker,
                'sha256':hashlib.sha256(output.encode()).hexdigest()})
            print(label+': '+next((line for line in output.splitlines() if 'VALUE ' in line or 'PRODUCER:' in line),output[-100:]),flush=True)
    (out/'native-use-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':run()
