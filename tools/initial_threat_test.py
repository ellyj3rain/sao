"""Authored native threat conditions retain a single source-bound attempt."""
import copy
import os
from pathlib import Path
import subprocess
import tempfile
import world_lab as Lab
from regional_observer_test import GAME, JDK

ROOT = Path(__file__).resolve().parents[1]
CHECKS = r'''
local calls,mode,ready=0,'created',false
local defects={}
local function check(value,reason) if not value then defects[#defects+1]=reason end return value end
local saved={}
local function invoke(receipts)
 local state={situationReceipt={initialThreats=receipts}}
 local Config={definitionSha256=string.rep('a',64),situation={initialThreats={
  {id='pressure',siteId='site',x=120,y=200,z=0,count=3}}}}
 local arrayMeta={studyArray=true}
 getWorld=function() return {getWorld=function() return 'owned-save' end} end
 getGameTime=function() return {getWorldAgeHours=function() return 12 end} end
 local exportOwner={threatReady=function(self,x,y,z) return ready end,seedThreat=function(self,x,y,z,n)
  calls=calls+1
  assert(x==120 and y==200 and z==0 and n==3,'declared threat placement changed')
  assert(receipts.pressure and receipts.pressure.status=='attempted','native attempt lacks durable entry')
  if mode=='exception' then error('native-constructor-failure') end
  return {owner='native-VirtualZombieManager',status=mode,created=mode=='created' and 3 or 0,
   actors=mode=='created' and {{persistentId=42,nativeMember=true,targetAssigned=false}} or {}}
 end}
 __FUNCTION__
 applyInitialThreats()
 return state
end
local completed,fault=pcall(function()
local state=invoke(saved)
assert(calls==0 and saved.pressure==nil,'unloaded placement consumed its attempt')
ready=true;state=invoke(saved)
assert(calls==1 and saved.pressure and saved.pressure.status=='created' and saved.pressure.created==3,
 'native threat receipt changed')
assert(saved.pressure and saved.pressure.definitionSha256==string.rep('a',64) and saved.pressure.save=='owned-save'
 and saved.pressure.siteId=='site' and saved.pressure.actors[1].persistentId==42,
 'threat source and native identity lost')
invoke(saved)
assert(calls==1,'completed threat respawned on resumed state')
for _,field in ipairs({'definitionSha256','save','siteId','requested','x','y','z'}) do
 local value=saved.pressure[field]
 saved.pressure[field]=type(value)=='number' and value+1 or 'foreign'
 local ok=pcall(invoke,saved)
 assert(not ok and calls==1,'foreign threat receipt accepted')
 saved.pressure[field]=value
end
mode='refused';saved={};invoke(saved);invoke(saved)
assert(calls==2 and saved.pressure and saved.pressure.status=='refused' and saved.pressure.created==0,
 'refused native threat was retried or invented')
mode='exception';saved={};local ok=pcall(invoke,saved)
assert(not ok and saved.pressure and saved.pressure.status=='attempted','ambiguous native attempt was erased')
pcall(invoke,saved)
assert(calls==3,'ambiguous native attempt was repeated')
end)
if not completed and #defects==0 then defects[#defects+1]=tostring(fault) end
RESULT=#defects==0 and 'PASS source-bound threat receipts, resume, native refusal and ambiguous constructor controls'
 or 'FAIL '..defects[1]
'''

def run():
    definition = Lab.load(ROOT / "tools/world_lab/definition.example.json")
    origin = definition["origins"][0]
    definition["observation"]["sites"] = [{"id":"site", "label":"Site", **{key:origin[key] for key in ("x","y","z")}}]
    row = {"id":"pressure", "siteId":"site", "x":origin["x"] + 16, "y":origin["y"], "z":origin["z"], "count":3}
    definition["situation"] = {"initialThreats":[row]}
    Lab.validate(definition)
    for change in ({"count":True}, {"count":0}, {"count":33}, {"siteId":"unknown"}, {"x":origin["x"]}, {"z":origin["z"]+1}, {"x":origin["x"]+97}):
        bad = copy.deepcopy(definition); bad["situation"]["initialThreats"][0].update(change)
        try: Lab.validate(bad)
        except ValueError: pass
        else: raise AssertionError("malformed threat accepted: " + repr(change))
    print("PASS threat definition and7 malformed controls")
    if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
        print("SKIPPED threat lifecycle: installed engine or JDK absent")
        return
    source = (ROOT / "tools/world_lab/StudyWorld.lua").read_text(encoding="utf-8")
    begin = source.index("local function applyInitialThreats()")
    function = source[begin:source.index("local function applyInitialNeeds()", begin)]
    variants = [("production", function, None),
        ("repeat", function.replace("local prior = receipts[placement.id]", "local prior = nil"), "completed threat respawned"),
        ("unloaded", function.replace("elseif exportOwner:threatReady(placement.x, placement.y, placement.z) then", "elseif true then"), "unloaded placement consumed its attempt"),
        ("foreign", function.replace("assert(prior.definitionSha256 ==", "assert(true or prior.definitionSha256 =="), "foreign threat receipt accepted"),
        ("late-attempt", function.replace("receipts[placement.id] = receipt", ""), "native attempt lacks durable entry")]
    with tempfile.TemporaryDirectory(prefix="sao-threat-checks-") as temporary:
        work = Path(temporary)
        native = str(GAME / "projectzomboid.jar")
        subprocess.run([str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", native, "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")], check=True, cwd=GAME, timeout=60)
        for name, actual, error in variants:
            if error and actual == function: raise AssertionError("threat mutation did not land: " + name)
            script = work / (name + ".lua"); script.write_text(CHECKS.replace("assert(", "check(").replace("__FUNCTION__", actual), encoding="utf-8")
            result = subprocess.run([str(GAME / "jre64/bin/java.exe"), "-cp", str(work)+os.pathsep+native,
                "LuaRun", str(script), "--", "RESULT"], cwd=GAME, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            if error:
                if result.returncode or "VALUE FAIL " + error not in output: raise AssertionError("threat control survived: " + output)
            elif result.returncode or "PASS source-bound threat" not in output: raise AssertionError(output)
    print("PASS actual Lua threat lifecycle with4 source mutation controls; native spawning requires loaded acceptance")

if __name__ == "__main__":
    raise SystemExit(run())
