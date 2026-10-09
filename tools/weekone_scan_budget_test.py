#!/usr/bin/env python3
"""Bounded Week One cache and person-row scans on installed Kahlua."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

CASES = r'''
local W=SAO.WeekOneContinuity
local s=ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
local rows={}
for i=1,1000 do rows[string.format('r%04d',i)]={personId='absent:'..i} end
s.byBrain=rows
local watchedRows=rows
local watchedCache=BanditZombie.CacheLightB
local originalPairs=pairs
local originalSort=table.sort
local rowSeen,cacheSeen={},{}
local rowNext,cacheNext,rowPairs,cachePairs,sortCalls=0,0,0,0,0
local rowLast,cacheLast
__pollVisitHook=function(source,stream,key)
 if source==watchedRows then
  rowNext=rowNext+1 rowSeen[key]=true rowLast=key
 elseif source==watchedCache then
  cacheNext=cacheNext+1 cacheSeen[key]=true cacheLast=key
 end
end
pairs=function(source)
 local iterator,state,initial=originalPairs(source)
 if source~=watchedRows and source~=watchedCache then
  return iterator,state,initial end
 if source==watchedRows then rowPairs=rowPairs+1
 else cachePairs=cachePairs+1 end
 return iterator,state,initial
end
table.sort=function(...)
 sortCalls=sortCalls+1 return originalSort(...) end
local function measuredPoll()
 rowNext,cacheNext,rowPairs,cachePairs,sortCalls=0,0,0,0,0
 local before=W.costMetrics().scans
 __tick=__tick+21 __clock=__clock+0.01
 W.onBudgetTick()
 W.poll()
 assert(rowNext<=128 and cacheNext<=12
  and rowPairs==0 and cachePairs==0 and sortCalls==0,
  'minute poll traversed or sorted beyond fixed raw-entry budgets')
 assert(W.costMetrics().scans-before<=4,
  'minute poll exceeded the existing four-private-scan budget')
end
__step='1000-row-sweep'
for minute=1,8 do measuredPoll() end
local seenCount=0
for i=1,1000 do
 if rowSeen[string.format('r%04d',i)] then seenCount=seenCount+1 end
end
assert(seenCount==1000 and s.nextScan==nil
 and s.cachePollCursor==nil and s.personPollCursor==nil,
 '128-row minute cursor did not cover 1000 rows in eight visits or leaked to save')

__step='exact-stale-row'
local stale={id='stale-person',weekOne={source='BanditsWeekOne',
 brainId=9999,born=12.5,status='external',lastSeenHours=160,
 bodyMode='native'}}
local unavailable={id='lookup-error',weekOne={source='BanditsWeekOne',
 brainId=9998,born=12.5,status='external',lastSeenHours=160,
 bodyMode='native'}}
__records[stale.id]=stale __records[unavailable.id]=unavailable
rows.r1000={personId=stale.id,brainId=9999,born='12.5',status='external'}
rows.r0999={personId=unavailable.id,brainId=9998,born='12.5',status='external'}
BanditZombie.GetInstanceById=function(id)
 if id==9998 then error('source body lookup unavailable') end
 return nil end
for minute=1,8 do measuredPoll() end
assert(rows.r1000==nil and __records[stale.id]==stale
 and s.inactiveBySource['r1000@12.5'].personId==stale.id
 and rows.r0999 and __records[unavailable.id]==unavailable,
 'stale exact body was not eventually archived or failed lookup lost its person')

__step='deleted-person-cursor'
local deletedRow=rowLast
for minute=1,8 do
 if deletedRow and rows[deletedRow] then break end
 measuredPoll() deletedRow=rowLast
end
assert(deletedRow and rows[deletedRow],
 'person cursor had no live row for deletion control')
rows[deletedRow]=nil
rows.r1001={personId='absent:new'}
rowSeen.r1001=nil
for minute=1,16 do measuredPoll() end
assert(rowSeen.r1001,
 'deleted person cursor key prevented eventual new-row visit')

__step='1200-mixed-cache'
local cache,bodies,stamped={}, {}, {}
for id=1,1200 do cache[id]={id=id} end
local ordinal=0
for id,light in originalPairs(cache) do
 ordinal=ordinal+1
 if ordinal<=12 or ordinal%100==0 then
  light.brain=__brain(id,'BanditsWeekOne')
  bodies[id]=__body(id)
  stamped[#stamped+1]=id
 elseif ordinal%2==0 then light.brain=__brain(id,'Bandits2') end
end
assert(#stamped==24,'mixed source setup did not create 24 exact stamped bodies')
BanditZombie.CacheLightB=cache watchedCache=cache
BanditZombie.GetInstanceById=function(id)
 if id==9998 then error('source body lookup unavailable') end
 return bodies[id] end
cacheSeen={}
__target='none' __threat=0
local beforeScans=W.costMetrics().scans
measuredPoll()
assert(W.costMetrics().scans-beforeScans==4
 and W.costMetrics().scanQueuePeak>=8,
 'first twelve stamped bodies bypassed four-scan queue')
for minute=2,100 do measuredPoll() end
local cacheCount=0
for id=1,1200 do if cacheSeen[id] then cacheCount=cacheCount+1 end end
assert(cacheCount==1200,
 '12-entry cache cursor starved a raw entry in 100 minutes')
for _,id in ipairs(stamped) do
 local person=bodies[id].md.SAOWeekOnePersonId
 assert(person and __records[person]
  and __records[person].heldBy=='BanditsWeekOne'
  and __ageAdmissions[person]==tostring(id)..'@12.5',
  'mixed cache lost exact body, claim or chronology admission')
end

__step='deleted-cache-cursor'
local small={}
for id=1,30 do small[id]={brain=__brain(id,'Bandits2')} end
BanditZombie.CacheLightB=small watchedCache=small cacheSeen={}
measuredPoll()
local deletedCache=cacheLast
assert(deletedCache and small[deletedCache],
 'cache cursor had no live key for deletion control')
small[deletedCache]=nil
small[31]={brain=__brain(31,'Bandits2')}
for minute=1,8 do measuredPoll() end
assert(cacheSeen[31],
 'deleted cache cursor key prevented eventual new-entry visit')

__step='replacement-tables'
local replacementBody=__body(2001)
bodies[2001]=replacementBody
local replacement={[2001]={brain=__brain(2001,'BanditsWeekOne')}}
BanditZombie.CacheLightB=replacement watchedCache=replacement cacheSeen={}
for minute=1,101 do
 measuredPoll()
 if cacheSeen[2001] then break end
end
assert(cacheSeen[2001] and replacementBody.md.SAOWeekOnePersonId,
 'replacement cache retained the old iterator or skipped its stamped body')
BanditZombie.CacheLightB={}
watchedCache=BanditZombie.CacheLightB
local replacementRows={fresh={personId='absent:fresh'}}
s.byBrain=replacementRows watchedRows=replacementRows rowSeen={}
for minute=1,9 do
 measuredPoll()
 if rowSeen.fresh then break end
end
assert(rowSeen.fresh and s.nextScan==nil
 and s.cachePollCursor==nil and s.personPollCursor==nil,
 'replacement row table retained the old iterator or saved its cursor')
return 'PASS'
'''

CONTROLS = [
    ("cache-raw-budget", "local POLL_CACHE_VISITS = 12",
     "local POLL_CACHE_VISITS = 1200",
     "first twelve stamped bodies bypassed four-scan queue"),
    ("person-raw-budget", "local POLL_PERSON_VISITS = 128",
     "local POLL_PERSON_VISITS = 1000",
     "128-row minute cursor did not cover 1000 rows"),
    ("stale-lookup-error", "if ok and not body then",
     "if not ok or not body then",
     "stale exact body was not eventually archived or failed lookup lost its person"),
    ("bridge-closed", "local cacheKeys = pollKeys(cache, \"ClientCache\", POLL_CACHE_VISITS)",
     "local cacheKeys = nil", "first twelve stamped bodies bypassed four-scan queue"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path,
        default=ROOT / "_scratch/d2-leisure-01/weekone-poll-budget01/receipt.json")
    out = parser.parse_args().out.resolve()
    required = [SOURCE, GAME / "projectzomboid.jar", GAME / "stdlib.lua",
        JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in required):
        raise SystemExit("missing installed Kahlua or Week One source")
    source = SOURCE.read_text(encoding="utf-8")
    receipt = {"saoSourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "testSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-poll-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (work / "cases.lua").write_text("function __cases()\n" + CASES +
            "\nend\nfunction __safe() local ok,value=pcall(__cases)" +
            " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")

        def run(name, current):
            (work / "sao.lua").write_text(current, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "sao.lua"),
                str(work / "cases.lua"), "--", "__safe()"], cwd=work,
                capture_output=True, text=True, timeout=90)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                "output": output[-1500:]})
            return done.returncode, output

        code, output = run("bounded-poll", source)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("production poll failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in source:
                raise RuntimeError("missing inverse target " + name)
            code, output = run(name, source.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " did not trip its contract: " + output)
        receipt["status"] = "PASS"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS 1000 person rows, 1200 mixed cache entries and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
