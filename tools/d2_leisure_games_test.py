#!/usr/bin/env python3
"""Installed source game engines and Kahlua serialization; controlled native receivers.

All24 computer cores are compared to original source dynamics and presented
frames. This is not a loaded NPC, native-rendered screen or learned-play proof.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys
sys.dont_write_bytecode=True
import study_test as f
from native_proof_preflight import installed_presence
sys.path.insert(0,str(Path(__file__).parent/'d2_leisure_games'))
import source_profile as p
ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'tools/d2_leisure_games'
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureGames.lua'
ART_FIXTURE=ROOT/'tools/d2_leisure_art/fixture.lua'
RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
CONTROLS=[
    ('forged-source','if same(v,offer)then selected=v;break end','if true then selected=v;break end','forged_source_refused',[]),
    ('ignore-power','or not ComputerModPower.hasComputerPower(obj)','or false ','no_power_refused',[]),
    ('ignore-hardware','or ComputerModComponents.getBootFailure(d)~=nil','or false','broken_hardware_refused',[]),
    ('duplicate-input','if a.inputFrame==a.frameId then return false end','if false then return false end','duplicate_input_refused_asteroids',['asteroids']),
    ('forged-controls','if same(v,offer)then\n            a.keys={};','if true then\n            a.keys={};','forged_controls_refused',[]),
    ('ignore-instance','or SAO.Perception.resolveLeisureObject(a.work.actorId,a.body,a.work.objectKey)~=a.object','or false ','station_replacement_refused',[]),
    ('ignore-generation','and a.body:getModData().SAOExternalToken==w.bodyToken and hours()>=w.admittedAtHours','and hours()>=w.admittedAtHours','foreign_generation_cannot_play',[]),
    ('omit-pong-physics','self.paddle.y = self:clamp(self.paddle.y, 0.035, 1 - self.paddle.height - 0.035)\n    self:gameTick()','self.paddle.y = self:clamp(self.paddle.y, 0.035, 1 - self.paddle.height - 0.035)\n    -- actual source physics omitted','original_mechanics_equivalent_pong',['pong']),
    ('omit-source-presentation','current=a;a.scene:prerender();current=nil','current=a;current=nil','presented_source_frame_asteroids',['asteroids']),
    ('fabricate-win','if a.scene.gameState=="WIN"or a.scene.gameState=="GAMEOVER"then a.terminal=true;self:forceComplete()end','a.scene.gameState="WIN";a.terminal=true;self:forceComplete()','original_mechanics_equivalent_asteroids',['asteroids']),
    ('forget-resume','if resume and resume.sourceId==w.sourceId and resume.revision==w.revision and resume.objectKey==w.objectKey','if false and resume and resume.sourceId==w.sourceId and resume.revision==w.revision and resume.objectKey==w.objectKey','resume_does_not_reroll_pong',['pong']),
    ('future-ping-win','elseif status=="completed"and a.action and a.action.matchData then','elseif a.action and a.action.matchData then','ping_partial_not_future_win',[]),
    ('ignore-arcade-coin','and(c.DebugFreePlay==true or arcadeCount(body,c)>=c.Cost)','and true ','arcade_missing_currency_personal_cabinet',[]),
    ('ignore-arcade-power','and ArcadeSource.power(obj)and','and true and','arcade_no_power_refused',[]),
    ('arcade-invalid-currency','return definition and definition:getFullName()==c.CurrencyFullType and plain(c)or nil','return plain(c)','arcade_invalid_currency_definition',[]),
    ('arcade-type-currency','or itemType~=c.CurrencyFullType then return {}end','then return {}end','arcade_other_type_not_currency',[]),
    ('arcade-context-power','and ArcadeSource.power(obj)then return true end','then return true end','arcade_requirement_power_binding',[]),
    ('arcade-context-machine','if row.activity=="arcade-"..tostring(machine)and ArcadeSource.front','if ArcadeSource.front','arcade_requirement_machine_binding',[]),
    ('arcade-context-revision','if not canonical then return false end','if false then return false end','arcade_requirement_source_revision',[]),
    ('arcade-context-deficit','or arcadeCount(body,c)>=c.Cost then return false end','then return false end','arcade_multi_coin_receipt_candidates',[]),
    ('arcade-receipt-items','materials=arcadeCarried(body,c),','materials={},','arcade_multi_coin_receipt_candidates',[]),
    ('omit-source-payment','c:Remove(coin)','-- source payment omitted','arcade_exact_source_payment_1',[]),
    ('omit-arcade-update-mood','PA_SendMoodDeltaToServer(self, boredomDecrease, unhappinessDecrease, stressDecrease)','-- source incremental mood omitted','arcade_actual_incremental_mood_1',[]),
    ('fabricate-arcade-win','o.didWin = (ZombRand(100) < 60)','o.didWin = not (ZombRand(100) < 60)','arcade_actual_source_rng_1',[]),
    ('publish-partial-arcade-win','if status=="completed"then w.sourceResult={state="source-arcade-session-complete"','if true then w.sourceResult={state="source-arcade-session-complete"','arcade_partial_not_success',[]),
    ('ignore-arcade-native-progress','or self:getJobDelta()<1 then return end','then return end','arcade_native_progress_refuses_success',[]),
    ('ignore-maintained-purpose','if not admission or admission.ownerName~="SAO.LeisureGames"or admission.actorId~=a.work.actorId\n        or admission.sequence~=a.work.sequence or admission.sourceId~=a.work.sourceId or admission.bodyToken~=a.work.bodyToken then return false end','if false then return false end','retired_purpose_cannot_play',[]),
    ('omit-live-computer-mood','ComputerMood.update(a.mood)','-- live computer mood omitted','original_live_mood_equivalent_pong',['pong']),
    ('fabricate-control-label','action = "A",','action = "INVENTED",','source_control_labels_asteroids',['asteroids']),
]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    absent=installed_presence([Path(__file__),Path(p.__file__),OWNER,RUNNER,DIR/'fixture.lua',DIR/'cases.lua',f.GAME/'projectzomboid.jar',p.COMPUTER/'client/ComputerMod_GameInput.lua',p.ARCADE/'client/ProjectArcade_Currency.lua'],f.GAME,f.JDK,'D2 d2_leisure_games_test',installed_roots=(p.COMPUTER,p.LIFESTYLE,p.ARCADE))
    if absent is not None:return absent
    native=[f.GAME/'media/lua/shared/ISBaseObject.lua',f.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    games=p.games();source=[*[row[2]for row in games],p.COMPUTER/'client/ComputerMod_GameInput.lua',p.COMPUTER/'shared/ComputerMod_ComputerTypes.lua',
        p.COMPUTER/'shared/ComputerMod_Components.lua',p.LIFESTYLE/'shared/TimedActions/LSPingPong.lua',p.LIFESTYLE/'shared/MPSocial/social_utils.lua',
        p.LIFESTYLE/'shared/LSUtil.lua',p.LIFESTYLE/'client/ISUI/LSPingPongBall.lua',p.LIFESTYLE/'client/MPSocial/LSPingPongCM.lua',p.COMPUTER/'client/ComputerMod_UI.lua',
        p.COMPUTER/'client/ComputerMod_UI_State.lua',p.COMPUTER/'client/ComputerMod_Power.lua',p.ARCADE/'client/ProjectArcade_Currency.lua',
        p.ARCADE/'client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua',p.ARCADE/'client/ProjectArcade_PAMPlayGameMenu.lua']
    inputs=[Path(__file__),Path(p.__file__),ART_FIXTURE,DIR/'fixture.lua',DIR/'cases.lua',OWNER,RUNNER,*native,*source,f.GAME/'projectzomboid.jar',f.GAME/'stdlib.lua']
    sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    receipt={'schema':'d2-leisure-games/1','status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(path):sha(path)for path in inputs},'runs':[]}
    def seal():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(label,command):
        done=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,timeout=120)
        log=out/(label+'.log');log.write_bytes(done.stdout+done.stderr)
        receipt['runs'].append({'name':label,'exitCode':done.returncode,'logSha256':sha(log)});seal()
        return done.returncode,log.read_text(encoding='utf-8',errors='replace')
    seal()
    try:
        production=OWNER.read_text(encoding='utf-8')
        blocks=[('ComputerMod_GameInput.labels',p.labels()),('ComputerMod_UI_State.mood',p.mood()),('ComputerMod_GameInput.updateGridSelection',p.grid()),('Lifestyle/LSPingPongBall',p.ball()),('Lifestyle/LSPingPong',p.ping()),('Lifestyle/LSMPS.pingRules',p.ping_rules()),('ProjectArcade/currency',p.currency()),('ProjectArcade/play',p.arcade()),*[(str(path.relative_to(p.COMPUTER)),block)for id,cls,path,keys,block in games]]
        for name,body in blocks:assert production.count('-- BEGIN INSTALLED SOURCE '+name+'\n'+body+'-- END INSTALLED SOURCE '+name+'\n')==1,('source-profile-drift',name)
        receipt['sourceProfiles']=len(blocks)
        for path in source:
            group='Computer'if path.is_relative_to(p.COMPUTER)else'Lifestyle'if path.is_relative_to(p.LIFESTYLE)else'Arcade';base=p.COMPUTER if group=='Computer'else p.LIFESTYLE if group=='Lifestyle'else p.ARCADE
            dest=out/'originals'/group/path.relative_to(base);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)
        code,log=run('compile',[f.JDK/'javac.exe','-cp',f.GAME/'projectzomboid.jar','-d',out,RUNNER]);assert code==0,log
        shutil.copyfile(f.GAME/'stdlib.lua',out/'stdlib.lua')
        metadata={id:{'className':cls,'keys':keys}for id,cls,path,keys,block in games}
        def lua(v):
            if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x)for k,x in v.items())+'}'
            if isinstance(v,list):return '{'+','.join(lua(x)for x in v)+'}'
            return json.dumps(v)
        old='\n'.join(path.read_text(encoding='utf-8-sig')for _,_,path,_,_ in games)+'\n'+p.grid()+p.labels()+'\nlocal target={}\n__originalMoodTarget=target\nComputerScreenUI={}\n'+p.mood_original()+'\n__originalMoodUpdate=updateComputerGameMoodFromPlayer\n'+(p.ARCADE/'client/ProjectArcade_Currency.lua').read_text(encoding='utf-8-sig')+'\n'+(p.ARCADE/'client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua').read_text(encoding='utf-8-sig')
        (out/'original-games.lua').write_text(old,encoding='utf-8')
        (out/'metadata.lua').write_text('__definitions='+lua(metadata),encoding='utf-8')
        cases='local ok,err=pcall(function()\n'+(DIR/'cases.lua').read_text()+'\nend)\nif not ok then error(tostring(err).." after "..tostring(__lastPrint))end'
        for label,before,after,marker,selected in [('production',None,None,None,None)]+([]if args.baseline_only else CONTROLS):
            variant=production
            if before:
                assert variant.count(before)==1,(label,variant.count(before));variant=variant.replace(before,after,1)
            owner=out/(label+'.lua');owner.write_text(variant,encoding='utf-8')
            reload=out/(label+'-reload.lua');reload.write_text('__reloadGames=function()\n'+variant+'\nend\n',encoding='utf-8')
            prefix=''if selected is None else '__definitions='+lua({id:metadata[id]for id in selected})+'\n'
            case=out/(label+'-cases.lua');case.write_text(prefix+cases,encoding='utf-8')
            paths=[ART_FIXTURE,*native,DIR/'fixture.lua',p.COMPUTER/'shared/ComputerMod_ComputerTypes.lua',p.COMPUTER/'shared/ComputerMod_Components.lua',p.LIFESTYLE/'shared/LSUtil.lua',out/'original-games.lua',out/'metadata.lua',owner,reload,case]
            code,log=run(label,[f.JDK/'java.exe','-cp',str(out)+os.pathsep+str(f.GAME/'projectzomboid.jar'),'PhysicalMeansLuaProbe',*paths,'--','__result'])
            if marker:assert code!=0 and 'D2_GAMES:'+marker in log,(label,log[-4000:])
            else:
                assert code==0 and 'PASS D2 leisure games 'in log,log[-6000:]
                receipt['checks']=int(re.search(r'PASS D2 leisure games (\d+)',log).group(1))
            print(label+': '+('expected refusal'if marker else'PASS'),flush=True)
        receipt['inputsAfter']={str(path):sha(path)for path in inputs};assert receipt['inputsBefore']==receipt['inputsAfter']
        receipt['status']='PASS';receipt['controls']=0 if args.baseline_only else len(CONTROLS);seal();print('PASS',receipt['checks'],receipt['controls']);return 0
    except Exception as e:
        receipt['failure']=str(e);seal();print('FAIL',e);return 1
if __name__=='__main__':raise SystemExit(main())
