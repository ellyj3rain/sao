#!/usr/bin/env python3
"""Installed Lifestyle cores in installed Kahlua; controlled body/object/native action receivers.

Pins complete originals and selection libraries. Profile equality and differential
original/core effects establish source equivalence, not loaded NPC gameplay.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys
sys.dont_write_bytecode=True
import study_test as f
from native_proof_preflight import installed_presence
sys.path.insert(0,str(Path(__file__).parent/'d2_leisure_art'))
import source_profile as profile
ROOT=Path(__file__).resolve().parents[1]
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureArt.lua'
DIR=ROOT/'tools/d2_leisure_art'
RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
CONTROLS=[
    ('bare-global-sound-interval','\n\t\tself.soundTimeInterval = self.soundTime+self.doAnim\n',
     '\n\t\tsoundTimeInterval = self.soundTime+self.doAnim\n','action_owned_interval_advances'),
    ('private-issued-request','local request=active.skillRequests and active.skillRequests[sequence]',
     'local request=record(id).artSkillRequests[#record(id).artSkillRequests]','saved_request_cannot_replace_live_issuance'),
    ('foreign-interrupt','if active and active.body~=body then return false end','if false then return false end','foreign_interrupt_cannot_retire_art'),
    ('forged-offer','if same(candidate,offer) then selected=candidate break end','if true then selected=candidate break end','forged_source_refused'),
    ('forget-progress','or not self.action or self:getJobDelta()<1 or self.owner.work.nativeProgress.sourceUpdates<1','or not self.action','premature_terminal_refused'),
    ('ignore-custody','if not held(active.body,item) then','if false then','lost_material_interrupts_without_progress'),
    ('ignore-instance','or SAO.Perception.resolveLeisureObject(active.work.actorId,active.body,active.work.objectKey)~=active.object','or false','station_instance_changed_refused'),
    ('ignore-generation',['and active.body:getModData().SAOExternalToken==w.bodyToken and hours()>=w.admittedAtHours','and active.body:getModData().SAOExternalToken==active.work.bodyToken and active or nil'],['and hours()>=w.admittedAtHours','and active or nil'],'body_generation_changed_refused'),
    ('ignore-art-mutation','or not same(active.artifact,artifact(active.object,active.kind))','or false','foreign_art_metadata_refused'),
    ('retain-retired-skill','if not active or not activeFor(active.body) or active.work.sequence~=workSequence then return nil end','if not active or not activeFor(active.body) or active.work.sequence~=workSequence then return plain(record(id).artSkillRequests and record(id).artSkillRequests[sequence]) end','old_terminal_request_refused_canvas'),
    ('omit-source-final-sprite','updateCanvasSprite(self.easel, self.painting["stage4"], 4)','updateCanvasSprite(self.easel, self.painting["stage3"], 4)','physical_completion_canvas'),
    ('omit-source-mood','_G.LSUtil.changeCharacterMood(character,...)','-- source mood omitted','original_mood_equivalence_canvas'),
    ('omit-source-use','_G.LSUtil.useItem(item,character,...)','-- source material use omitted','original_material_equivalence_canvas'),
]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    absent=installed_presence([Path(__file__),Path(profile.__file__),OWNER,RUNNER,DIR/'fixture.lua',DIR/'cases.lua',f.GAME/'projectzomboid.jar',profile.SOURCE/'shared/LSUtil.lua'],f.GAME,f.JDK,'D2 d2_leisure_art_test',installed_roots=(profile.SOURCE,))
    if absent is not None:return absent
    native=[f.GAME/'media/lua/shared/ISBaseObject.lua',f.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    libraries=[*sorted((profile.SOURCE/'client/Painting/lib').glob('*.lua')),*sorted((profile.SOURCE/'client/Painting/Sculpting/lib').glob('*.lua')),profile.SOURCE/'client/Painting/Quality.lua']
    sources=[profile.SOURCE/p for p in [*profile.ACTION_FILES.values(),*profile.MENU_FILES.values(),*profile.EXTRA]]
    inputs=[Path(__file__),Path(profile.__file__),DIR/'fixture.lua',DIR/'cases.lua',OWNER,RUNNER,*native,*sources,*libraries,f.GAME/'projectzomboid.jar',f.GAME/'stdlib.lua']
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    receipt={'schema':'d2-leisure-art/1','status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[]}
    def seal():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,command):
        p=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,timeout=90)
        log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
        receipt['runs'].append({'name':name,'exitCode':p.returncode,'logSha256':sha(log)});seal()
        return p.returncode,log.read_text(encoding='utf-8',errors='replace')
    seal()
    try:
        production=OWNER.read_text(encoding='utf-8')
        for name,block in profile.blocks():
            exact='-- BEGIN INSTALLED SOURCE '+name+'\n'+block+'-- END INSTALLED SOURCE '+name+'\n'
            assert production.count(exact)==1,('source profile drift',name)
        receipt['sourceProfiles']=5
        for p in sources+libraries:
            dest=out/'originals'/p.relative_to(profile.SOURCE);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
        code,log=run('compile',[f.JDK/'javac.exe','-cp',f.GAME/'projectzomboid.jar','-d',out,RUNNER]);assert code==0,log
        shutil.copyfile(f.GAME/'stdlib.lua',out/'stdlib.lua')
        libcode='__libraries={}\n'+''.join('__libraries['+json.dumps(str(p.relative_to(profile.SOURCE/'client')).replace('\\','/')[:-4])+']=(function()\n'+p.read_text(encoding='utf-8-sig')+'\nend)()\n'for p in libraries)
        (out/'libraries.lua').write_text(libcode,encoding='utf-8')
        # Full original source classes remain separate and receive controlled player UI.
        old='\n'.join((profile.SOURCE/p).read_text(encoding='utf-8-sig')for p in profile.ACTION_FILES.values())
        (out/'original-actions.lua').write_text(old,encoding='utf-8')
        (out/'cases.lua').write_text('local ok,result=pcall(function()\n'+(DIR/'cases.lua').read_text()+'\nend)\nif not ok then error(tostring(result).." after "..tostring(__lastPrint))end\n',encoding='utf-8')
        for name,before,after,marker in [('production',None,None,None)]+([]if args.baseline_only else CONTROLS):
            variant=production
            if before:
                for old,new in zip(before if isinstance(before,list)else[before],after if isinstance(after,list)else[after]):
                    assert variant.count(old)==1,(name,variant.count(old));variant=variant.replace(old,new,1)
            owner=out/(name+'.lua');owner.write_text(variant,encoding='utf-8')
            reload=out/(name+'-reload.lua');reload.write_text('__reloadArt=function()\n'+variant+'\nend\n',encoding='utf-8')
            paths=[DIR/'fixture.lua',*native,out/'libraries.lua',profile.SOURCE/'shared/LSUtil.lua',profile.SOURCE/'shared/LSSync.lua',profile.SOURCE/'shared/Art/ArtFunctions.lua',profile.SOURCE/'shared/Art/PaintingMarkings.lua',out/'original-actions.lua',owner,reload,out/'cases.lua']
            code,log=run(name,[f.JDK/'java.exe','-cp',str(out)+os.pathsep+str(f.GAME/'projectzomboid.jar'),'PhysicalMeansLuaProbe',*paths,'--','__result'])
            if marker:assert code!=0 and 'D2_ART:'+marker in log,(name,log[-4000:])
            else:
                assert code==0 and 'PASS D2 leisure art 'in log,log[-6000:]
                receipt['checks']=int(re.search(r'PASS D2 leisure art (\d+)',log).group(1))
            print(name+': '+('expected refusal'if marker else 'PASS'),flush=True)
        receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter']
        receipt['status']='PASS';receipt['controls']=0 if args.baseline_only else len(CONTROLS);seal();print('PASS',receipt['checks'],receipt['controls']);return 0
    except Exception as e:
        receipt['failure']=str(e);seal();print('FAIL',e);return 1
if __name__=='__main__':raise SystemExit(main())
