#!/usr/bin/env python3
"""Execute the actual SAO/ZAO return transaction with explicit engine doubles."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import person_handoff_test as vm

ROOT = vm.ROOT
SISTER = ROOT.parent / "zombie-awareness"
BASE_FILES = list(vm.FILES)
SISTER_FILES = ["ZAO_StateStore.lua", "ZAO_Forms.lua", "ZAO_Pathogen.lua", "ZAO_State.lua", "ZAO_Controller.lua"]
vm.FILES += SISTER_FILES
BASE_PRELUDE = vm.PRELUDE
HOST = r'''
__stores={}
ModData={getOrCreate=function(k) __stores[k]=__stores[k] or {} return __stores[k] end}
getCell=function() return {getObjectListForLua=function() return {
 size=function() return __source and 1 or 0 end,
 get=function() return __source end} end} end
instanceof=function(o,t) return o==__source and t=='IsoZombie' end
ZAO={Sandbox={policy=function() return {enabled=true,controller=true,mind=true} end}}
ZAOJavaBridge={
 supportsReturnBody=function() return __sourceSupported~=false end,
 isDormantReturnSource=function() return __sourceDormant==true end,
 findReturnBody=function(self,id) return __source end,
 holdReturnBody=function(self,b,id,token)
  assert(__records[id].returnTransition.token==token,'hold without durable phase')
  b.md.ZAOReturnToken=token __held=true
  return __fault~='hold'
 end,
 resumeReturnBody=function(self,b,id,token)
  if b.removing then return false end b.md.ZAOReturnToken=nil __held=false return true
 end,
 removeReturnBody=function(self,b,id,token)
  assert(__held,'source removed before hold')
  assert(__records[id].returnTransition.packed=='SNAP:'..b.payload,'stale material removed')
  __removeAttempts=__removeAttempts+1
  if __fault=='remove' then return false end
  b.removed=true __source=nil return true
 end,
 restoreReturnHealth=function(self,b)
  __healthCalls=__healthCalls+1
  if __fault=='health' then return false end
  b.healthRestored=true return true
 end,
}
SAOJavaBridge.createReturnBody=function(self,first,last,x,y,z)
 __creates=__creates+1
 if __fault=='create' then return nil end
 local b=__body() b.x,b.y,b.z=x,y,z b.payload='defaults' b.visual='bodyvisual' table.insert(__native,b) return b
end
SAOJavaBridge.findReturnDestination=function(self,id,token)
 for _,b in ipairs(__native) do
  if not b.discarded and b.md.SAOPersonId==id and b.md.SAOReturnToken==token then return b end
 end
end
SAOJavaBridge.returnBodyNeedsCleanup=function(self,b) return b.discarding==true end
SAOJavaBridge.discardReturnBody=function(self,b)
 b.discarding=true
 if __deferEachDiscard and not b.discardAttempted then b.discardAttempted=true return false end
 if __fault=='discard' or __discardFail then return false end
 b.discarded=true return true
end
SAOJavaBridge.restoreReturnLiving=function(self,b,p)
 if __fault=='restore' then return false end
 assert(type(p)=='string' and p:sub(1,5)=='SNAP:','invalid living restore')
 assert(not b.discarding,'discarding shell restored')
 if b.published then error('published shell restored twice') end
 b.payload=p:sub(6) return true
end
SAOJavaBridge.captureReturn=function(self,s,b)
 assert(__held,'capture before hold')
 if __fault=='capture' then return '' end
 return 'SNAP:'..s.payload
end
SAOJavaBridge.captureReturnVisual=function(self,b) return 'VIS:'..(b.visual or 'sourcevisual') end
SAOJavaBridge.restoreReturnVisual=function(self,b,p)
 if __fault=='visual' then return false end
 b.visual=p:sub(5) return true
end
SAOJavaBridge.returnMaterialsMatch=function(self,s,p,v)
 return p=='SNAP:'..s.payload and v=='VIS:'..(s.visual or 'sourcevisual')
end
SAOJavaBridge.publishReturnBody=function(self,b)
 assert(__source==nil,'published before source removal')
 assert(SAO.Body.get('p1')==nil,'pending destination available')
 if __fault=='publish' or b.discarding then return false end
 if not b.published then __publishes=__publishes+1 b.published=true end
 return true
end
SAOJavaBridge.activateReturnBody=function(self,b)
 assert(SAO.Controller.agents.p1,'activation without controller')
 if __fault=='activate' then return false end
 if not b.activated then __activations=__activations+1 b.activated=true end
 return true
end
function __returnSetup(dormant)
 local r,b=__setup()
 __realReturnHealth=__realReturnHealth or ZAO.Controller.restoreReturnHealth
 ZAO.Controller.restoreReturnHealth=__realReturnHealth
 SAO.Body.returning={} SAO.Body.active={} SAO.Controller.agents={} SAO.Controller.pendingCorpses={}
 r.dead=true r.diedAtHours=24 r.returnLiving='SNAP:living'
 r.returnLivingDeath=0
 r.turnedDormant=dormant==true r.hibernation='SNAP:dormant'
 __native={} __discardFail=false __deferEachDiscard=false __sourceSupported=true __sourceDormant=false
 __now=48 __fault='' __held=false __removeAttempts=0 __creates=0 __publishes=0 __activations=0 __healthCalls=0
 __source=dormant and nil or b
 if dormant then __source=nil end
 b.payload='current' b.visual='sourcevisual' b.md.SAOPersonId='p1'
 b.isDead=function() return false end
 __stores={}
 ZAO.StateStore.store().people.p1={terminalState='afflicted',currentForm='Husk',
  returnEvent={token='reversion:1',day=2}}
 ZAO.Controller.controlled={} ZAO.Controller.nextScanAt=0
 SAO.Rand.unit=function() return 0.9 end
 __realAdopt=__realAdopt or SAO.Controller.adopt
 SAO.Controller.adopt=function(rec)
  if __fault=='adopt' then return false end
  return __realAdopt(rec)
 end
 return r,b
end
function __complete(r)
 __fault=''
 SAO.AfflictedReturn.resumePending()
 assert(not r.dead and not r.returnTransition,'retry did not complete')
 assert(r.returnEvent=='reversion:1','event consumption missing')
end
'''
CASES = r'''
do
 local r,b=__returnSetup(false)
 assert(SAO.Body.materialize(r)==nil,'ordinary dead-record safeguard bypassed')
 assert(SAO.AfflictedReturn.adopt(2),'loaded return failed')
 assert(r.returnSaveTouched==true,'return did not enter cross-file generation journal')
 assert(b.removed and not r.dead and SAO.Controller.agents.p1,'return missing controller or source removal')
 assert(SAO.Body.get('p1').payload=='current','historical possessions restored')
 assert(r.bodyVisual=='VIS:sourcevisual','completed return lost durable appearance')
 assert(SAO.Body.get('p1').healthRestored and SAO.Body.get('p1').md.ZAODormantKnox==true,
  'return did not preserve systemic-dormant afflicted state')
 assert(r.diedAtHours==24 and r.hibernation=='SNAP:current','death history or current pack lost')
 SAO.AfflictedReturn.adopt(2) SAO.AfflictedReturn.resumePending()
 assert(__creates==1 and __publishes==1 and __activations==1,'repeat return duplicated destination')
 assert(__healthCalls==1,'completed phase repeated recovery physiology')
end
for _,fault in ipairs({'hold','create','health','capture','restore','visual','remove','publish','adopt','activate'}) do
 local r,b=__returnSetup(false) __fault=fault
 SAO.AfflictedReturn.adopt(2)
 assert(r.returnTransition,'failure relinquished durable return: '..fault)
 assert(SAO.Body.pendingTransitionCount()==1,'pending return absent from ownership census')
 assert(SAO.Body.get('p1')==nil and SAO.Body.hasRepresentation('p1'),'pending ownership leaked: '..fault)
 if fault~='publish' and fault~='adopt' and fault~='activate' then
  assert(not b.removed,'source lost on pre-removal failure: '..fault)
 end
 __complete(r)
 assert(SAO.Controller.agents.p1 and __publishes==1 and __activations==1,'retry controller/publication duplication: '..fault)
 assert(SAO.Body.returning.p1==nil,'completed return leaked staged ownership')
end
do
 local r,b=__returnSetup(false) __fault='remove'
 SAO.AfflictedReturn.adopt(2)
 assert(r.returnTransition.packed=='SNAP:current','capture not durable')
 b.payload='after-loot' __radio=false __fault=''
 SAO.AfflictedReturn.resumePending()
 assert(not b.removed and r.returnTransition.recapture==true,'changed source consumed stale capture')
 __complete(r)
 assert(SAO.Body.get('p1').payload=='after-loot','looted item reappeared')
 assert(not r.hasRadio,'return retained stale inventory facts')
end
for _,fault in ipairs({'remove','publish','adopt','activate'}) do
 local r,b=__returnSetup(false) __fault=fault
 SAO.AfflictedReturn.adopt(2)
 -- Lua-only reload retains native staged/published objects.
 SAO.Body.returning={} SAO.Body.active={} SAO.Controller.agents={} ZAO.Controller.controlled={}
 __complete(r)
 assert(SAO.Body.get('p1').payload=='current' and SAO.Controller.agents.p1,'reload lost restored person: '..fault)
end
for _,fault in ipairs({'publish','adopt','activate'}) do
 local r,b=__returnSetup(false) __fault=fault
 SAO.AfflictedReturn.adopt(2)
 assert(r.returnTransition.sourceRemoved and b.removed,'world reload fixture lacks acknowledged source removal')
 -- A full world reload retains the durable phase and loses transient shells.
 -- Actual engine save/load coverage lives in the native probes.
 __native={} SAO.Body.returning={} SAO.Body.active={} SAO.Controller.agents={}
 __complete(r)
 assert(__creates==2 and SAO.Body.get('p1').payload=='current','durable return did not rebuild destination')
end
do
 local r=__returnSetup(true)
 r.bodyVisual='VIS:dormantvisual'
 assert(SAO.AfflictedReturn.adopt(2),'bodyless historical return failed')
 assert(not r.dead and not r.turnedDormant and not SAO.Body.get('p1'),'dormant return minted a loaded body')
 assert(not SAO.Controller.agents.p1 and __publishes==0 and r.hibernation=='SNAP:dormant','dormant return lost state')
 assert(r.bodyVisual=='VIS:dormantvisual','dormant return replaced known appearance')
end
do
 local r=__returnSetup(false) __source=nil
 assert(not SAO.AfflictedReturn.adopt(2) and r.dead and not r.returnTransition,'missing loaded body treated as dormant')
end
do
 local r=__returnSetup(false) r.returnLiving=nil r.hibernation=nil
 assert(not SAO.AfflictedReturn.adopt(2) and r.dead and __creates==0,'unknown living state replaced by defaults')
end
do
 local r,b=__returnSetup(false) ZAO.Controller.restoreReturnHealth=nil
 SAO.AfflictedReturn.adopt(2)
 assert(r.dead and not b.removed and not r.returnTransition and not __held,'missing health policy held source')
end
do
 local r,b=__returnSetup(false) __sourceDormant=true
 assert(SAO.AfflictedReturn.adopt(2),'checkpoint-backed source did not return offscreen')
 assert(b.removed and not r.dead and not SAO.Body.get('p1') and not SAO.Controller.agents.p1
  and r.hibernation=='SNAP:current' and __publishes==0,'offscreen return duplicated or lost source state')
end
do
 local r,b=__returnSetup(false) __sourceDormant=true __fault='discard'
 SAO.AfflictedReturn.adopt(2)
 assert(b.removed and r.returnTransition and r.returnTransition.sourceRemoved,
  'offscreen cleanup failure lost durable transfer')
 __fault=''
 SAO.AfflictedReturn.resumePending() SAO.AfflictedReturn.resumePending()
 assert(not r.dead and not r.returnTransition and not SAO.Body.get('p1') and __publishes==0,
  'offscreen cleanup retry changed representation')
end
do
 local r,b=__returnSetup(false) __sourceDormant=true __deferEachDiscard=true
 SAO.AfflictedReturn.adopt(2)
 assert(b.removed and r.returnTransition and r.returnTransition.sourceRemoved,
  'deferred dormant cleanup fixture missing')
 SAO.AfflictedReturn.resumePending() SAO.AfflictedReturn.resumePending()
 assert(not r.dead and not r.returnTransition and __creates==1 and __publishes==0,
  'dormant cleanup recreated its temporary shell')
end
do
 local r,b=__returnSetup(false) __sourceSupported=false
 SAO.AfflictedReturn.adopt(2)
 assert(r.dead and not r.returnTransition and not __held,'unsupported source entered return')
end
do
 local r=__returnSetup(false)
 ZAO.StateStore.store().people.p1.returnEvent=nil
 assert(not SAO.AfflictedReturn.adopt(2) and not r.returnTransition,'afflicted state without event licensed resurrection')
end
for _,order in ipairs({'sao-first','zao-first'}) do
 local r=__returnSetup(false) __fault='remove'
 SAO.AfflictedReturn.adopt(2) __fault=''
 if order=='zao-first' then ZAO.Controller.tick(100) SAO.AfflictedReturn.resumePending()
 else SAO.AfflictedReturn.resumePending() ZAO.Controller.tick(100) end
 assert(not r.dead and __publishes==1 and __activations==1,'callback order changed ownership')
end
do
 local r=__returnSetup(false) local sister=ZAO ZAO=nil
 assert(not SAO.AfflictedReturn.adopt(2) and r.dead and __creates==0,'optional absence changed lifecycle')
 ZAO=sister
end

do
 local r,b=__returnSetup(false) __fault='capture' __discardFail=true
 SAO.AfflictedReturn.adopt(2) __fault=''
 SAO.AfflictedReturn.resumePending()
 assert(not b.removed and r.returnTransition.cleanup,'failed cleanup lost ownership')
 __discardFail=false __complete(r)
 assert(__creates==2 and __publishes==1,'cleanup retry reused terminal stage')
end
do
 local r,b=__returnSetup(false) __mode='busy'
 SAO.AfflictedReturn.adopt(2)
 assert(r.returnTransition and not __held,'busy source was held')
 ZAO.StateStore.store().people.p1.terminalState='crossed'
 SAO.AfflictedReturn.resumePending()
 assert(not r.returnTransition and not b.removed,'unheld revoked source could not cancel')
end
do
 local r,b=__returnSetup(false) __mode='busy'
 SAO.AfflictedReturn.adopt(2)
 b.x,b.y=345,678 __mode='ok'
 __complete(r)
 assert(SAO.Body.get('p1'):getX()==345 and SAO.Body.get('p1'):getY()==678
  and r.x==345 and r.y==678,'return published at pre-hold coordinates')
end
do
 local r,b=__returnSetup(false) r.dead=false r.deathSequence=1 r.returnLivingDeath=1
 SAO.Body.active.p1=b __mode='throw'
 assert(SAO.Identity.markDead(r,3,'test'),'second death failed')
 assert(not r.returnLiving and not r.returnLivingDeath,'failed second capture retained old living state')
 SAO.Body.active={} __mode='ok'
 ZAO.StateStore.store().people.p1.returnEvent={token='reversion:2',day=2,deathSequence=2}
 assert(not SAO.AfflictedReturn.adopt(2) and r.dead and not __held,'prior death supplied new living state')
end
do
 local r,b=__returnSetup(false) __fault='remove'
 SAO.AfflictedReturn.adopt(2)
 local count=#__logs
 local ok,completed,pending=SAO.AfflictedReturn.resumePending()
 assert(not ok and completed==0 and pending==1,'pending return reported clean completion')
 assert(r.returnTransition.lastReason=='source-removal-pending' and #__logs==count,'pending reason absent or repeated noisily')
 assert(__logs[count]:find('p1') and __logs[count]:find('captured'),'diagnostic lost person or phase')
end
do
 local r,b=__returnSetup(false)
 local capture=SAOJavaBridge.captureReturn
 SAOJavaBridge.captureReturn=function() error('injected capture exception') end
 SAO.AfflictedReturn.adopt(2)
 assert(r.returnTransition and r.returnTransition.lastReason:find('injected capture exception')
  and not b.removed,'bridge exception lost owned phase or diagnosis')
 SAOJavaBridge.captureReturn=capture
 __complete(r)
end
do
 local r,b=__returnSetup(false)
 __stores={} r.deathSequence=1 r.returnLivingDeath=1
 ZAO.Pathogen.begin('p1','dead',2,'death',r)
 ZAO.Controller.tick(100)
 local state=ZAO.StateStore.read('p1')
 assert(state.terminalState=='turned' and state.deathSequence==1,'observed reanimation did not produce current turned state')
 assert(not r.turnedDormant,'loaded turn marked dormant')
 __now=72 SAO.Rand.unit=function() return 0 end
 ZAO.Controller.tick(140)
 state=ZAO.StateStore.read('p1')
 assert(state.terminalState=='afflicted' and state.returnEvent
  and state.returnEvent.deathSequence==1,'loaded pathogen did not produce return event')
 assert(SAO.AfflictedReturn.adopt(3) and not r.dead and b.removed,'produced return event did not transfer person')
end
do
 local r,b=__returnSetup(false) __fault='remove'
 SAO.AfflictedReturn.adopt(2)
 local phase=r.returnTransition
 SAO.Identity.markDead(r,3,'test')
 assert(r.returnTransition==phase and not b.removed,'repeat death destroyed return ownership')
 __fault=''
 assert(SAO.Body.recover(r),'body recovery did not resume return')
 assert(not r.returnTransition and not r.dead,'body recovery left return pending')
end
for _,verdict in ipairs({'DIE_PENDING','DIE_FAILED','throw'}) do
 local r,b=__returnSetup(false)
 SAO.Controller.pendingCorpses.p1={at=0,body=b}
 SAOJavaBridge.ensureCorpse=function()
  if verdict=='throw' then error('corpse failure fixture') end
  return verdict
 end
 SAO.Controller.settleCorpses(1000000)
 assert(SAO.Controller.pendingCorpses.p1,'unacknowledged corpse lost pending ownership')
 assert(not SAO.AfflictedReturn.adopt(2) and not r.returnTransition,'return overtook unfinished corpse creation')
 SAOJavaBridge.ensureCorpse=function() return 'ALREADY_CORPSE' end
 SAO.Controller.settleCorpses(1000001)
 assert(not SAO.Controller.pendingCorpses.p1,'acknowledged corpse retained pending ownership')
 assert(SAO.AfflictedReturn.adopt(2),'return failed after corpse acknowledgment')
end
do
 local r,b=__returnSetup(false) __fault='remove'
 SAO.AfflictedReturn.adopt(2)
 ZAO.StateStore.store().people.p1.terminalState='crossed'
 SAO.AfflictedReturn.resumePending()
 assert(r.dead and not r.returnTransition and not b.removed and not __held,'revoked recovery did not resume source')
end
do
 local r=__returnSetup(false) r.afflictedReturn=true r.returnedAtHours=48
 local state=ZAO.StateStore.store().people.p1
 state.returnEvent=nil state.history={{type='reversion',day=2}} state.startedDay=1
 assert(not SAO.AfflictedReturn.adopt(2) and r.dead and not r.returnTransition,'legacy reversion reused for another death')
end
do
 local r=__returnSetup(false) r.deathSequence=2
 ZAO.StateStore.store().people.p1.returnEvent.deathSequence=1
 assert(not SAO.AfflictedReturn.adopt(2) and r.dead,'prior death reversion reused')
end
return 'PASS'
'''


def main():
    sources = {}
    for name in BASE_FILES:
        path = ROOT/'mod/42.20/media/lua'/('shared' if name=='SAO_Identity.lua' else 'client')/name
        if not path.is_file():
            print('FAULT missing production module '+name); return 1
        sources[name]=path.read_text(encoding='utf-8')
    for name in SISTER_FILES:
        folder='client' if name=='ZAO_Controller.lua' else 'shared'
        path=SISTER/'mod/42.20/media/lua'/folder/name
        if not path.is_file():
            print('SKIPPED afflicted return joint VM: sibling checkout unavailable'); return 0
        sources[name]=path.read_text(encoding='utf-8')
    if not (vm.GAME/'projectzomboid.jar').is_file() or not (vm.JDK/'javac.exe').is_file():
        print('SKIPPED afflicted return joint VM: installed engine/JDK absent'); return 0
    vm.PRELUDE=BASE_PRELUDE+HOST
    vm.CASES=CASES
    faults=[]
    with tempfile.TemporaryDirectory(prefix='sao-afflicted-return-') as tmp:
        work=Path(tmp); shutil.copy2(vm.GAME/'stdlib.lua',work/'stdlib.lua')
        built=subprocess.run([str(vm.JDK/'javac.exe'),'-cp',str(vm.GAME/'projectzomboid.jar'),'-d',str(work),
          str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=120)
        if built.returncode:
            print('FAULT runner compilation '+built.stderr); return 1
        result=vm.run(work,sources); print('production: '+result)
        if result!='VALUE PASS': faults.append('production')
        controls=[
          ('SAO_AfflictedReturn.lua','if SAO.Controller.adopt(rec) ~= true then return false, "adoption-pending" end',
           'if false then return false, "adoption-pending" end','loaded return failed'),
          ('ZAO_Controller.lua','if ZAOJavaBridge:removeReturnBody(body, personId, token) ~= true then return false end',
           'ZAOJavaBridge:removeReturnBody(body, personId, token)','retry did not complete'),
          ('SAO_AfflictedReturn.lua','if not SAOJavaBridge:returnMaterialsMatch(source, p.packed, p.visual) then',
           'if false then','changed source consumed stale capture'),
          ('SAO_AfflictedReturn.lua','if not source and rec.turnedDormant ~= true then return false, "source-unavailable" end',
           '', 'missing loaded body treated as dormant'),
          ('SAO_AfflictedReturn.lua','if body:getModData().SAOReturnReady ~= p.token then',
           'if true then','retry did not complete'),
          ('SAO_AfflictedReturn.lua','SAO.Body.returning[rec.id] = nil',
           '', 'completed return leaked staged ownership'),
          ('SAO_Controller.lua','if okE and (verdict == "DIED" or verdict == "ALREADY_CORPSE") then',
           'if true then','unacknowledged corpse lost pending ownership'),
          ('SAO_Body.lua','if SAO.AfflictedReturn then return SAO.AfflictedReturn.resume(rec) end',
           'if false then return SAO.AfflictedReturn.resume(rec) end','body recovery did not resume return'),
          ('ZAO_Controller.lua','if rec.dead and observedTurned then recordTerminal = "turned" end',
           '', 'observed reanimation did not produce current turned state'),
          ('ZAO_State.lua','if record.dead and savedTerminal == "turned"',
           'if false and record.dead and savedTerminal == "turned"','observed reanimation did not produce current turned state'),
          ('SAO_Identity.lua','rec.returnLiving, rec.returnLivingDeath = nil, nil',
           '', 'failed second capture retained old living state'),
          ('SAO_AfflictedReturn.lua','p.x, p.y, p.z = x, y, z',
           '', 'return published at pre-hold coordinates'),
          ('SAO_AfflictedReturn.lua','p.lastReason = reason',
           '', 'pending reason absent or repeated noisily'),
          ('ZAO_Controller.lua','return ZAOJavaBridge:isDormantReturnSource(body) == true',
           'return false', 'offscreen return duplicated or lost source state'),
          ('SAO_AfflictedReturn.lua','if p.sourceRemoved and (p.destination or p.source) == "dormant" then',
           'if false then', 'dormant cleanup recreated its temporary shell'),
          ('SAO_AfflictedReturn.lua','rec.returnSaveTouched = true',
           '', 'return did not enter cross-file generation journal'),
        ]
        for name,old,new,reason in controls:
            if sources[name].count(old)!=1: faults.append('control seam '+reason); continue
            changed=dict(sources); changed[name]=changed[name].replace(old,new,1)
            result=vm.run(work,changed)
            rejected=result.startswith('ERROR ') and reason in result
            print('CONTROL '+reason+': '+('REJECTED ' if rejected else 'SURVIVED ')+result)
            if not rejected: faults.append(reason)
    print(('FAULT '+', '.join(faults)) if faults else "  164) PASS -- afflicted return ownership")
    return bool(faults)

if __name__=='__main__':
    sys.exit(main())
