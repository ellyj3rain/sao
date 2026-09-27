#!/usr/bin/env python3
"""Border 171: actual owned health clocks in the installed Kahlua VM.

This clock fixture drives Habits, Pharmacology and Drugs together. Its body
receiver is controlled; native item/effect receivers are covered separately by
pharmacology_test. Assertions concern durable owner state, not callback counts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))

HOST = r'''
function require() end
local records = {
    p1 = { id="p1", habitsGained={opioids=true,drinker=true},
        lastUseHours={opioids=0}, drugDay=0, drinksToday=8 },
    legacy = { id="legacy", drinksToday=4 },
}
local nowHours, minuteStamp, refreshes = 23.99, 100, 0
local bodyData = {SAOPersonId="p1",NnCMethadoneEffect=145}
local values={}
local stats={get=function(self,name)return values[name] or 0 end,
    set=function(self,name,value)values[name]=value end,
    add=function(self,name,value)values[name]=(values[name] or 0)+value end,
    remove=function(self,name,value)values[name]=(values[name] or 0)-value end}
local body={getModData=function()return bodyData end,getStats=function()return stats end,
    isDead=function()return false end,isAsleep=function()return false end}
CharacterStat=setmetatable({},{__index=function(self,name)return name end})
SAO={Hash={of=function()return 9999 end},
    History={countyHours=function()return nowHours end,ageOf=function()return 34 end},
    Identity={get=function(id)return records[tostring(id)] end},
    Body={active={p1=body},foreign={},isTransitioning=function()return false end},
    Controller={tick=function()return 1 end},
    Population={refreshBodyFacts=function(rec,seen,at)
        assert(rec==records.p1 and seen==body and at==nowHours)
        refreshes=refreshes+1
    end},Neuro={advance=function()end},Rand={int=function()return 0 end},
    Log={line=function()end}}
Events={OnTick={Add=function(fn)SAO.__eventTick=fn end},OnLoad={Add=function()end}}
function getGameTime()return {getMinutesStamp=function()return minuteStamp end}end
function __clock(stamp)minuteStamp=stamp;nowHours=23.99+(stamp-100)/60 end
function __hours()return nowHours end
function __record(id)return records[id] end
function __body()return body end
function __refreshes()return refreshes end
'''

PROBE = r'''(function()
    local failures={}
    local function assert(value,reason)
        if not value then failures[#failures+1]=reason or "unexpected owner state" end
    end
    local tick,rec=SAO.__eventTick,__record("p1")
    local H,P,D=SAO.Habits,SAO.Pharmacology,SAO.Drugs
    assert(BenzoEffect==nil and NnCReg==nil,"foreign runtime entered fixture")
    assert(P.advance(rec,__body(),__hours()))
    assert(rec.pharmacology.maintenance==145,"legacy saved maintenance was discarded")
    H.freezeUse("p1","opioids",__hours())
    local frozenAt=rec.useFrozen.opioids
    local cleanAtFreeze=H.cleanDays("p1","opioids",frozenAt)
    tick()
    assert(rec.drinksToday==8 and rec.drinkTolerance==nil)
    __clock(101);tick()
    assert(rec.drinksToday==8 and rec.drinkTolerance==nil,
        "one-minute callback consumed ten-minute daily work")
    __clock(110);tick()
    assert(rec.drinksToday==0 and rec.drinkTolerance==0.01 and rec.drugDay==1,
        "ten-minute boundary did not close the drinking day")
    assert(math.abs(rec.drinkSickness-.001)<.0000001 and __refreshes()==1,
        "offset alcohol withdrawal cadence changed")
    assert(rec.pharmacology.minute==math.floor(__hours()*60+.0000001)
        and rec.pharmacology.maintenance==144,"owned minute clock skipped initial interval")
    __clock(140);tick()
    assert(math.abs(rec.drinkSickness-.004)<.0000001 and __refreshes()==2,
        "skipped callback intervals were sampled only once")
    assert(rec.pharmacology.minute==math.floor(__hours()*60+.0000001)
        and rec.pharmacology.maintenance==141,"owned clock skipped elapsed dependency passes")
    assert(rec.drinkTolerance==.01,"durable daily marker repeated tolerance work")
    assert(math.abs(H.cleanDays("p1","opioids",72)-cleanAtFreeze)<.0000001,
        "active maintenance treatment advanced abstinence")
    -- The saved owner cursor, not an external callback, ends maintenance.
    rec.pharmacology.maintenance=1
    __clock(150);tick()
    local expiry=math.floor(__hours()*6)/6
    assert(rec.useFrozen.opioids==nil and rec.pharmacology.maintenance==0,
        "expired treatment stayed frozen")
    assert(math.abs(H.cleanDays("p1","opioids",expiry)-cleanAtFreeze)<.0000001,
        "resume did not preserve the frozen interval")
    assert(math.abs(H.cleanDays("p1","opioids",__hours())-cleanAtFreeze
        -(__hours()-expiry)/24)<.0000001,"post-expiry clean time did not resume")
    -- Runtime reset must retain the durable day and use origins.
    local sickness,clean=rec.drinkSickness,H.cleanDays("p1","opioids",__hours())
    D.resetRuntimeForWorld();tick();tick()
    assert(rec.drinkTolerance==.01 and rec.drinkSickness==sickness
        and H.cleanDays("p1","opioids",__hours())==clean,
        "runtime reload repeated durable work")
    local legacy=__record("legacy")
    assert(D.completeThrough(legacy,5)==0 and legacy.drinksToday==4)
    legacy.drinksToday=8
    assert(D.completeThrough(legacy,8)==3 and legacy.drinkTolerance==.01
        and legacy.drinksToday==0 and legacy.drugDay==8,
        "multi-day daily closure changed")
    assert(D.completeThrough(legacy,8)==0 and legacy.drinkTolerance==.01,
        "reload-equivalent repeat duplicated completed daily work")
    return #failures==0 and "health clocks hold" or "REFUSED: "..table.concat(failures,"; ")
end)()'''


def main(argv=None) -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--candidate',type=Path)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args(argv)
    root=args.root.resolve(); base=(args.candidate or root).resolve()
    lua=base/'mod/42.20/media/lua'
    files=[lua/'shared/SAO_Habits.lua',lua/'shared/SAO_PharmacologyProfiles.lua',
        lua/'shared/SAO_Pharmacology.lua',lua/'client/SAO_Drugs.lua']
    jar=GAME/'projectzomboid.jar';stdlib=GAME/'stdlib.lua';runner=root/'tools/luacheck/LuaRun.java'
    if not all(path.is_file() for path in [jar,stdlib,JDK/'java.exe',JDK/'javac.exe',runner]):
        print('Border 171 SKIPPED: installed game VM or JDK absent');return 0
    if not all(path.is_file() for path in files):
        print('Border 171 REFUSED: owned production input missing');return 1
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    receipt={'schema':'sao-health-clock-check/2','inputs':{str(p):sha(p) for p in [*files,runner,jar,Path(__file__)]},'variants':[]}
    variants=[('production',None,None,None,None),
        ('daily-before-ten-minute',files[3],'if tenPasses > 0 then\n                local rec = nil',
            'if onePasses > 0 then\n                local rec = nil','one-minute callback consumed ten-minute daily work'),
        ('sample-skipped-intervals',files[3],'for _ = 1, tenPasses do Dg.ladder(rec, body, tick) end',
            'for _ = 1, 1 do Dg.ladder(rec, body, tick) end','skipped callback intervals were sampled only once'),
        ('unfrozen-abstinence',files[0],'if type(frozen) == "number" and frozen < now then now = frozen end',
            '-- old frozen origin ignored','active maintenance treatment advanced abstinence'),
        ('saved-maintenance-discarded',files[2],'s.maintenance=clamp(md.NnCMethadoneEffect,0,145)',
            's.maintenance=0','legacy saved maintenance was discarded')]
    out=args.output.resolve() if args.output else None
    if out:out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='sao-health-clock-') as tmp:
        work=Path(tmp);shutil.copyfile(stdlib,work/'stdlib.lua')
        (work/'host.lua').write_text(HOST,encoding='utf-8')
        compiled=subprocess.run([str(JDK/'javac.exe'),'-cp',str(jar),'-d',str(work),str(runner)],
            capture_output=True,text=True,encoding='utf-8',timeout=60)
        if compiled.returncode:print(compiled.stdout+compiled.stderr);return 1
        for name,target,before,after,failure in variants:
            chosen=list(files)
            if target:
                source=target.read_text(encoding='utf-8-sig')
                assert source.count(before)==1,(name,'changed mutation seam')
                changed=work/(name+'.lua');changed.write_text(source.replace(before,after),encoding='utf-8')
                chosen=[changed if p==target else p for p in chosen]
            result=subprocess.run([str(JDK/'java.exe'),'-cp',str(jar)+os.pathsep+str(work),
                'LuaRun',str(work/'host.lua'),*map(str,chosen),'--',PROBE],cwd=work,
                capture_output=True,text=True,encoding='utf-8',timeout=60)
            log=result.stdout+result.stderr
            if out:(out/(name+'.log')).write_text(log,encoding='utf-8')
            passed=result.returncode==0 and 'VALUE REFUSED:' in log and failure in log if failure else result.returncode==0 and 'VALUE health clocks hold' in log
            if not passed:print('Border 171 REFUSED '+name+'\n'+log);return 1
            receipt['variants'].append({'name':name,'exit':result.returncode,'expected':failure,
                'logSha256':hashlib.sha256(log.encode()).hexdigest()})
    if out:(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print('Border 171 PASS: owned minute/dependency cadence, durable alcohol day, offset/skipped intervals, frozen abstinence, expiry and reload; four controls rejected')
    return 0

if __name__=='__main__':raise SystemExit(main())
