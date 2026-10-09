"""Stage one exact NewMusic lexical repair; run installed Kahlua with controlled services."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
MOD = ROOT / 'mod/42.20'
GAME = Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')
JDK = Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
REL = 'media/lua/client/runtime/NMClientTrackFinishedDispatch.lua'
OWNER = MOD / REL
VAULT = MOD / 'media/SAOSources/NewMusic' / REL


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def adapt(raw):
    before = b'    if keep then\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n            local source = entry and entry.source or nil\n'
    after = b'    if keep then\n        local source = entry and entry.source or nil\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n'
    if raw.count(before) != 1:
        raise ValueError('NewMusic track-finished source-context anchor changed')
    return raw.replace(before, after, 1)


PRELUDE = r'''
function require(name) end
SAO={SourceIntegration={active=function(id) return id=='NewMusic' end}}
source={context='poisoned-global'}
TOKEN={observedDurationMs=321,expectedPlaybackEpoch=4,expectedTrackIndex=2}
NMPlaybackRuntime={consumeTrackEndedToken=function(uuid) local t=TOKEN;TOKEN=nil;return t end}
NMClientTrackProgressionDispatch={buildTrackFinishedArgs=function(state,mode,duration) return {playbackMode=mode,observedDurationMs=duration,expectedPlaybackEpoch=state.playbackEpoch,expectedTrackIndex=state.trackIndex} end}
NMCore={isMPClientRuntime=function() return MP end}
NMDeviceTransitions={apply=function(profile,state,action,payload) assert(action=='track_finished');TRANSITIONS=TRANSITIONS+1;state.trackIndex=state.trackIndex+1;return CHANGED end}
NMDeviceState={bumpPlaybackEpoch=function(s) s.playbackEpoch=s.playbackEpoch+1 end,bumpRevision=function(s)s.revision=s.revision+1 end,export=function(s)return s end}
NMRegistryPolicy={shouldKeepWorldSourceState=function(s) return KEEP end}
NMClientWorldSourceCache={upsertFromPayload=function(p) CACHE=p end,remove=function(uuid) REMOVED=uuid end}
NMWorldRegistrySnapshot={upsertSP=function(p) SNAPSHOT=p end,removeSP=function(uuid) SNAPSHOT_REMOVED=uuid end}
NMClientDetachedProgressionUiRefresh={invalidateDetachedPortableWindow=function(uuid,itemId,state,context) UI={uuid=uuid,itemId=itemId,state=state,context=context} end,requestRuntimeRefresh=function(uuid,state,reason) REFRESH={uuid=uuid,state=state,reason=reason} end}
NMClientIntentDispatch={performIntent=function(player,item,action,args) INTENT={player=player,item=item,action=action,args=args};return true end,performVehicleIntent=function(player,vehicle,part,action,args) VEHICLE_INTENT={player=player,vehicle=vehicle,part=part,action=action,args=args};return true end}
NMDeviceProfiles={getWorldTrackingFloors=function(profile)return 1 end}
NMInventoryHelpers={findWorldItemByIdNearPlayer=function(player,itemId,range,floors)return WORLD_ITEM end}
PLAYER={};ITEM={};PART={};VEHICLE={getPartById=function(self,id)return PART end}
'''

CASES = r'''
CHECKS=0
local function check(ok,name) assert(ok,'D2_TRACK_CONTEXT:'..name);CHECKS=CHECKS+1 end
local function reset()
 TOKEN={observedDurationMs=321};TRANSITIONS=0;MP=false;KEEP=true;CHANGED=true
 CACHE=nil;SNAPSHOT=nil;UI=nil;REFRESH=nil;REMOVED=nil;SNAPSHOT_REMOVED=nil;INTENT=nil;VEHICLE_INTENT=nil;WORLD_ITEM=ITEM
end
local function state() return {trackIndex=2,playbackEpoch=4,revision=10,sourceGeneration=7,playbackMode='world'} end
for _,context in ipairs({'placed','attached','stowed','world','vehicle'}) do
 reset();local s=state();local entry={itemId='own-item',itemFullType='Base.CDplayer',source={context=context,x=1,y=2,z=0}}
 NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,entry,nil,'detached','uuid-1')
 check(UI and UI.context==context,'exact_current_source_context_'..context)
 check(CACHE.sourceMode==context and SNAPSHOT.sourceMode==context,'cache_and_snapshot_context_'..context)
 check(UI.state==s and SNAPSHOT.state==s and CACHE.state==s,'same_source_state_identity_'..context)
 check(TRANSITIONS==1 and s.trackIndex==3 and s.playbackEpoch==5 and s.revision==11,'one_original_transition_'..context)
 local previous=UI;NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,entry,nil,'detached','uuid-1')
 check(TRANSITIONS==1 and UI==previous,'token_consumed_once_'..context)
end
reset();NMClientWorldSourceCache.upsertFromPayload=nil
NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},state(),{source={mode='attached'}},nil,'detached','uuid-2')
check(UI.context=='attached' and SNAPSHOT.sourceMode=='attached','context_without_cache_provider')
reset();KEEP=false;local s=state()
NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,{source={context='placed'}},nil,'detached','uuid-3')
check(REMOVED=='uuid-3' and SNAPSHOT_REMOVED=='uuid-3' and UI==nil,'retired_source_no_ui_refresh')
reset();CHANGED=false;s=state()
NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,{source={context='attached'}},nil,'detached','uuid-4')
check(UI==nil and s.playbackEpoch==4 and s.revision==10,'unchanged_transition_no_refresh_or_epoch')
for _,kind in ipairs({'inventory','world_item'}) do
 reset();s=state();s.playbackMode=kind=='inventory' and 'inventory' or 'world'
 NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,{},ITEM,kind,'uuid-5')
 check(INTENT and INTENT.item==ITEM and INTENT.player==PLAYER and INTENT.action==(kind=='inventory' and 'track_finished' or 'track_finished_world'),'exact_inventory_route_'..kind)
 check(INTENT.args.observedDurationMs==321 and INTENT.args.expectedPlaybackEpoch==4 and INTENT.args.expectedTrackIndex==2 and TRANSITIONS==0,'inventory_token_args_'..kind)
end
reset();s=state()
NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,{source={vehicle=VEHICLE},partId='Radio'},nil,'vehicle','uuid-6')
check(VEHICLE_INTENT and VEHICLE_INTENT.vehicle==VEHICLE and VEHICLE_INTENT.part==PART and VEHICLE_INTENT.player==PLAYER and TRANSITIONS==0,'exact_vehicle_owner_route')
reset();MP=true;s=state()
NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},s,{itemId='own-item'},nil,'detached','uuid-7')
check(INTENT and INTENT.item==ITEM and INTENT.action=='track_finished' and UI==nil and TRANSITIONS==0,'mp_detached_owner_route')
reset();MP=true;WORLD_ITEM=nil
NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(PLAYER,{},state(),{itemId='missing'},nil,'detached','uuid-8')
check(INTENT==nil and UI==nil and TRANSITIONS==0,'missing_detached_item_refuses')
check(source.context=='poisoned-global','global_source_unchanged')
RESULT='PASS D2 track context '..tostring(CHECKS)
'''

UI_PRELUDE = r'''
function require(name) return {} end
CDPlayerWindow={};NMCDPlayerWindowEnv=setmetatable({CDPlayerWindow=CDPlayerWindow},{__index=_G})
function getNowMs() return 100 end
'''
UI_CASES = r'''
local w=setmetatable({_nmPressedButtonKind='mode'}, {__index=CDPlayerWindow})
assert(NMCDPlayerWindowEnv.SIDE_BUTTON_SCALE_PRESSED==nil,'D2_TRACK_CONTEXT:unexpected_scale_provider')
assert(w:getSideButtonScale('mode')==nil,'D2_TRACK_CONTEXT:dormant_getter_boundary')
local base=w:getSideButtonBgRect('mode');local pressed=w:getSideButtonRect('mode')
local inset=NMCDPlayerWindowEnv.SIDE_BUTTON_PRESSED_INSET_PX
assert(inset==1 and pressed.w==base.w-2 and pressed.h==base.h-2,'D2_TRACK_CONTEXT:actual_source_pressed_layout')
assert(pressed.x==base.x+1 and pressed.y==base.y+1,'D2_TRACK_CONTEXT:actual_source_pressed_offset')
w._nmPressedButtonKind=nil
assert(w:getSideButtonScale('mode')==1 and w:getSideButtonRect('mode').w==base.w,'D2_TRACK_CONTEXT:actual_unpressed_layout')
RESULT='PASS D2 dormant scale/source pressed layout 5'
'''


def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    ui=MOD/'media/SAOSources/NewMusic/media/lua/client/ui/cdplayer'
    ui_files=[ui/('NMCDPlayerWindow'+part+'.lua') for part in ('Constants','Transport','Layout','Render')]
    inputs=[Path(__file__),OWNER,VAULT,*ui_files,ROOT/'tools/luacheck/LuaRun.java',GAME/'projectzomboid.jar',GAME/'stdlib.lua']
    before={str(x):digest(x) for x in inputs}; receipt={'status':'RUNNING','inputsBefore':before,'runs':[],'boundary':'actual installed Kahlua/full original dispatch and UI modules; actor/transition/cache/intent services controlled; no game, audio or native UI claim'}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    save()
    raw=OWNER.read_bytes();fixed=adapt(raw);(out/'NMClientTrackFinishedDispatch.lua').write_bytes(fixed)
    (out/'adaptation.py').write_text("def adapt_newmusic_track_finished_context(raw, selected_path):\n    if selected_path != '"+REL+"': return raw, []\n    before = "+repr(b'    if keep then\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n            local source = entry and entry.source or nil\n')+"\n    after = "+repr(b'    if keep then\n        local source = entry and entry.source or nil\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n')+"\n    if raw.count(before) != 1: raise ValueError('NewMusic track-finished source-context anchor changed')\n    return raw.replace(before,after,1), [{'kind':'lexical-track-finished-source-context','privateOriginalUnchanged':True,'sourceStateAndIntentUnchanged':True}]\n",encoding='utf-8')
    (out/'prelude.lua').write_text(PRELUDE,encoding='utf-8');(out/'cases.lua').write_text(CASES,encoding='utf-8');(out/'original.lua').write_bytes(raw)
    jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))];cp=os.pathsep.join(map(str,jars))
    with tempfile.TemporaryDirectory(prefix='sao-track-context-') as tmp:
        work=Path(tmp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());r=subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True);(out/'compile.log').write_bytes(r.stdout+r.stderr);assert r.returncode==0
        for name,target in [('fixed',out/'NMClientTrackFinishedDispatch.lua'),('restored-defect',out/'original.lua')]:
            r=subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'LuaRun',str(out/'prelude.lua'),str(target),str(out/'cases.lua'),'--','RESULT'],cwd=work,capture_output=True,timeout=40);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);text=log.read_text(errors='replace');receipt['runs'].append({'variant':name,'exit':r.returncode,'logSha256':digest(log)})
            if name=='fixed': assert r.returncode==0 and 'PASS D2 track context' in text,text
            else: assert r.returncode!=0 and 'D2_TRACK_CONTEXT:exact_current_source_context_placed' in text,text
            save()
        (out/'ui-prelude.lua').write_text(UI_PRELUDE,encoding='utf-8');(out/'ui-cases.lua').write_text(UI_CASES,encoding='utf-8')
        r=subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'LuaRun',str(out/'ui-prelude.lua'),*map(str,ui_files[:3]),str(out/'ui-cases.lua'),'--','RESULT'],cwd=work,capture_output=True,timeout=40);(out/'ui.log').write_bytes(r.stdout+r.stderr);assert r.returncode==0 and b'PASS D2 dormant scale' in r.stdout,r.stdout+r.stderr
    all_lua=list((MOD/'media/SAOSources/NewMusic/media/lua').rglob('*.lua'));calls=[str(x.relative_to(MOD)) for x in all_lua if b'getSideButtonScale(' in x.read_bytes()]
    assert calls==[str((ui/'NMCDPlayerWindowTransport.lua').relative_to(MOD))],calls
    assert b'local rect = self:getSideButtonRect(kind)' in ui_files[3].read_bytes()
    assert fixed.replace(b'    if keep then\n        local source = entry and entry.source or nil\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n',b'    if keep then\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n            local source = entry and entry.source or nil\n',1)==raw
    receipt.update(status='PASS_STAGED',checks=36,restoredControls=1,dormantScale={'providerAbsent':True,'onlyDefinitionNoCallers':calls,'actualRendererUsesSourceInset':True,'nativeSourceLayoutChecks':5},stageSha256=digest(out/'NMClientTrackFinishedDispatch.lua'),canonicalUnchanged=True,inputsAfter={str(x):digest(x) for x in inputs})
    assert receipt['inputsAfter']==before;save();print('PASS staged dispatch/source context; original defect detected; native original pressed layout verified; canonical unchanged')


if __name__=='__main__':main()
