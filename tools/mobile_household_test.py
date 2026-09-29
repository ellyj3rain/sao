#!/usr/bin/env python3
"""Border 212: vehicles can remain one moving place across use and reload."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
MOBILE = LUA / "client/SAO_MobileHousehold.lua"
PLANNER = LUA / "shared/SAO_ProceduralPlanning.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
OBSERVATION = LUA / "client/SAO_Observation.lua"
CHECK = ROOT / "tools/check.sh"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
local function list(values)
  return {size=function() return #values end,
    get=function(_,i) return values[i+1] end}
end
_G.__list=list
_G.__hours=100
_G.__hour=23
_G.__now=1000
_G.__recovered=0
_G.__stores={}
_G.__records={
  a={id='a',dead=false}, b={id='b',dead=false}, c={id='c',dead=false}}
ModData={
  getOrCreate=function(key) __stores[key]=__stores[key] or {}; return __stores[key] end,
  get=function(key) return __stores[key] end,
}
Events=setmetatable({}, {__index=function(t,key)
  local slot={Add=function() end,Remove=function() end}; rawset(t,key,slot)
  return slot end})
getTimestampMs=function() return __now end
GameTime={getInstance=function() return {getTimeOfDay=function() return __hour end} end}
local __provider={VehicleTypes={['3x6caravan']={scripts={'Base.RollingRefuge'},
  rooms={{x=22560,y=12300,z=0}},offset={x=2,y=2},roomWidth=3,roomHeight=6}}}
require=function(name) if name=='RVVehicleTypes' then return __provider end
  error('unknown module '..tostring(name)) end
SAO={
  History={countyHours=function() return __hours end},
  Identity={get=function(id) return __records[id] end},
  Standing={insideClaim=function() return true end},
  Log={line=function() end},
  Needs={read=function() return {fatigue=.8} end},
  Body={active={}},
}
local function container(items,capacity)
  return {getItems=function() return list(items) end,
    getCapacity=function() return capacity end}
end
local function item(weight) return {getActualWeight=function() return weight end} end
local function part(id,items)
  local c=items and container(items,30) or nil
  return {getId=function() return id end,getItemContainer=function() return c end}
end
local function script(name) return {getFullName=function() return name end} end
function __vehicle(name,x,y,parts)
  local v={name=name,x=x,y=y,z=0,parts=parts or {},characters={},md={},speed=0}
  function v:getScript() return script(self.name) end
  function v:getModData() return self.md end
  function v:getX() return self.x end; function v:getY() return self.y end
  function v:getZ() return self.z end; function v:getCurrentSpeedKmHour() return self.speed end
  function v:getVehicleTowing() return self.towing end
  function v:getVehicleTowedBy() return self.towedBy end
  function v:getParts() return list(self.parts) end
  function v:getMaxPassengers() return 3 end
  function v:getCharacter(i) return self.characters[i] end
  function v:getSeat(body) return body.vehicle==self and 1 or -1 end
  function v:isSeatInstalled() return true end
  function v:isSeatOccupied(i) return self.characters[i]~=nil end
  function v:enter(i,body) self.characters[i]=body; body.vehicle=self; return true end
  function v:setCharacterPosition() end; function v:playPassengerAnim() end
  function v:exit(body) self.characters[1]=nil; body.vehicle=nil; return true end
  return v
end
_G.__item=item; _G.__part=part
function __body(id,x,y)
  local b={id=id,x=x,y=y,z=0,md={SAOPersonId=id},vehicle=nil}
  function b:getModData() return self.md end
  function b:getVehicle() return self.vehicle end
  function b:getX() return self.x end; function b:getY() return self.y end
  function b:getZ() return self.z end; function b:getCell() return __cell end
  function b:setX(v) self.x=v end; function b:setY(v) self.y=v end
  function b:setZ(v) self.z=v end; function b:setLastX() end
  function b:setLastY() end; function b:setLastZ() end; function b:ensureOnTile() end
  return b
end
_G.__vehicles={}
_G.__cell={getVehicles=function() return list(__vehicles) end}
getCell=function() return __cell end
SAOJavaBridge={
  seatInNearestVehicle=function(_,body,x,y)
    if __seatFails then return -1 end
    local best=nil
    for _,v in ipairs(__vehicles) do if v.x==x and v.y==y then best=v end end
    if not best then return -1 end
    body.vehicle=best; best.characters[1]=body; return 1
  end,
  unseatFromVehicle=function(_,body)
    local v=body.vehicle; if not v then return false end
    v.characters[1]=nil; body.vehicle=nil; return true
  end,
  setShellAsleep=function() end,
  restRecoverTick=function(_,body,delta) __recovered=__recovered+delta end,
}
'''

PROBE = r'''(function()
  local checks={}
  local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
  local M=SAO.MobileHousehold
  check('catalogued_assets_enter_one_ontology',
    M.classifyScript('Base.RollingRefuge')=='motorhome'
    and M.classifyScript('Base.Trailer61Bambi16')=='camper'
    and M.classifyScript('Base.TrailerKI5cargoLarge')=='cargo-trailer'
    and M.classifyScript('Base.TrailerKI5utilitySmall')=='utility-trailer'
    and M.classifyScript('Base.TrailerKI5livestock')=='livestock-trailer')

  local tow=__vehicle('Base.TrailerKI5cargoLarge',11,10,{__part('TrailerTrunk',{__item(2)})})
  local rv=__vehicle('Base.RollingRefuge',10,10,
    {__part('Fridge',{__item(1),__item(3)}),__part('GloveBox',{})})
  rv.md.projectRV_uniqueId='rv-7'; rv.towing=tow; tow.towedBy=rv
  __vehicles={rv,tow}
  local a=__body('a',10,10); a.vehicle=rv; rv.characters[1]=a; SAO.Body.active.a=a
  local first=M.observeVehicle(rv,'observed')
  local revision=first.materialRevision
  M.observeVehicle(rv,'observed')
  check('native_vehicle_identity_and_material_are_durable',first.id=='mobile/1'
    and rv.md.SAOMobileHouseholdId=='mobile/1' and first.material.itemCount==2
    and first.material.weight==4 and first.materialRevision==revision
    and first.materialRevision>0)
  check('towing_is_a_persisted_relation',first.towing=='mobile/2'
    and M.all()['mobile/2'].towedBy=='mobile/1')

  local synced=M.syncPerson('a',a)
  local view=M.snapshot('a')
  local plan=SAO.ProceduralPlanning.snapshot('a')
  check('occupancy_updates_person_private_place_knowledge',synced.id=='mobile/1'
    and __records.a.mobileHouseholdState=='seated'
    and __records.a.proceduralPlanning.spatial['mobile/1'].kind=='mobile-household')
  check('physical_occupancy_drives_continuity_planning',plan.purposes[1].domain=='mobile-household'
    and plan.purposes[1].nextStep=='decide' and view.occupants==1)

  rv.x=41; rv.y=42; rv.speed=12
  M.observeVehicle(rv,'native-motion')
  view=M.snapshot('a')
  check('moving_place_updates_without_changing_identity',view.id=='mobile/1'
    and view.x==41 and view.y==42 and view.motion=='moving')

  a.vehicle=nil; rv.characters[1]=nil
  a.md.projectRV_playerId='pa'
  __stores.modPROJECTRVInterior={Players={pa={VehicleId='rv-7',
    ActualRoom={x=22560,y=12300,z=0},RoomType='3x6caravan'}}}
  M.syncPerson('a',a)
  view=M.snapshot('a')
  check('completed_interior_transition_keeps_external_anchor',view.state=='interior'
    and view.x==41 and view.y==42 and __records.a.mobileHouseholdAnchor.x==41
    and M.all()['mobile/1'].transitions[#M.all()['mobile/1'].transitions].to=='interior')
  __stores.modPROJECTRVInterior.Players.pa=nil; a.md.projectRV_playerId=nil
  M.syncPerson('a',a)
  check('physical_separation_closes_occupancy',__records.a.mobileHouseholdId==nil
    and M.all()['mobile/1'].occupants.a==nil)

  rv.x=5; rv.y=5; rv.speed=0
  local b=__body('b',5,5); SAO.Body.active.b=b
  local entered=M.seekNightShelter('b',b,10)
  check('night_pressure_can_use_native_mobile_shelter',entered==true
    and b.vehicle==nil and __records.b.mobileHouseholdUse.reason=='night-rest'
    and __records.b.mobileHouseholdState=='interior' and b.x==22562 and b.y==12302)
  __hours=101
  local resting=M.tickOccupiedRest('b',b,{})
  check('stationary_mobile_shelter_carries_real_rest',resting==true and __recovered==1)
  __hour=7
  local still=M.tickOccupiedRest('b',b,{})
  check('morning_exit_uses_native_unseat',still==false and b.vehicle==nil
    and __records.b.mobileHouseholdUse==nil and b.x==5 and b.y==5)

  local c=__body('c',5,5); __seatFails=true
  local refused=M.seekNightShelter('c',c,10); __seatFails=false
  check('native_entry_refusal_is_observed_not_overridden',refused==false
    and #M.all()['mobile/1'].failures==1 and c.vehicle==nil)

  local savedId=rv.md.SAOMobileHouseholdId
  SAO.MobileHousehold=nil
  check('save_state_is_plain_data_and_native_id_survives',savedId=='mobile/1'
    and __stores.SurvivorAwareness_MobileHouseholds.vehicles[savedId].script=='Base.RollingRefuge')
  return table.concat(checks,',')
end)()'''

EXPECTED = {
    "catalogued_assets_enter_one_ontology",
    "native_vehicle_identity_and_material_are_durable",
    "towing_is_a_persisted_relation",
    "occupancy_updates_person_private_place_knowledge",
    "physical_occupancy_drives_continuity_planning",
    "moving_place_updates_without_changing_identity",
    "completed_interior_transition_keeps_external_anchor",
    "physical_separation_closes_occupancy",
    "night_pressure_can_use_native_mobile_shelter",
    "stationary_mobile_shelter_carries_real_rest",
    "morning_exit_uses_native_unseat",
    "native_entry_refusal_is_observed_not_overridden",
    "save_state_is_plain_data_and_native_id_survives",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(mobile_source: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-mobile-household-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        files = {
            "prelude.lua": PRELUDE,
            "planner.lua": PLANNER.read_text(encoding="utf-8-sig"),
            "mobile.lua": mobile_source,
            "probe.lua": "__result = " + PROBE,
        }
        for name, source in files.items():
            (work / name).write_text(source, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             *(str(work / name) for name in files), "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract() -> list[str]:
    sources = {
        "mobile": MOBILE.read_text(encoding="utf-8"),
        "planner": PLANNER.read_text(encoding="utf-8"),
        "controller": CONTROLLER.read_text(encoding="utf-8"),
        "observation": OBSERVATION.read_text(encoding="utf-8"),
        "check": CHECK.read_text(encoding="utf-8"),
    }
    required = (
        ("SurvivorAwareness_MobileHouseholds", "mobile"),
        ("function M.observeVehicle", "mobile"),
        ("function M.syncPerson", "mobile"),
        ("function M.seekNightShelter", "mobile"),
        ("function M.tickOccupiedRest", "mobile"),
        ("function P.planMobileHousehold", "planner"),
        ("SAO.MobileHousehold.tickOccupiedRest", "controller"),
        ("SAO.MobileHousehold.seekNightShelter", "controller"),
        ('section("mobile-household"', "observation"),
        ("tools/mobile_household_test.py", "check"),
    )
    return [f"{owner} omits {token}" for token, owner in required
            if token not in sources[owner]]


def main() -> int:
    if not (PZ.is_file() and STDLIB.is_file()):
        print("212) mobile household: SKIPPED - installed game runtime absent")
        return 0
    faults = static_contract()
    ok, detail = compile_runner()
    if not ok:
        faults.append("LuaRun compile failed: " + detail[-1200:])
    source = MOBILE.read_text(encoding="utf-8-sig")
    if ok:
        value, detail = run_probe(source)
        results = verdicts(value)
        missing = sorted(name for name in EXPECTED if results.get(name) != "true")
        if missing:
            faults.append("production mobile continuity failed: " + ", ".join(missing)
                          + "\n" + detail[-1600:])
        controls = (
            (source.replace('["Base.RollingRefuge"] = "motorhome",', "", 1)
                   .replace('lower:find("rollingrefuge", 1, true)',
                            'lower:find("never-rolling-refuge", 1, true)', 1),
             "catalogued_assets_enter_one_ontology"),
            (source.replace("rec.materialRevision = (tonumber(rec.materialRevision) or 0) + 1",
                            "rec.materialRevision = 0", 1),
             "native_vehicle_identity_and_material_are_durable"),
            (source.replace('transition(current, personId, prior, "interior",',
                            'transition(current, personId, prior, "outside",', 1),
             "completed_interior_transition_keeps_external_anchor"),
        )
        for mutated, expected_failure in controls:
            if mutated == source:
                faults.append("control mutation did not apply: " + expected_failure)
                continue
            value, _ = run_probe(mutated)
            if verdicts(value).get(expected_failure) == "true":
                faults.append("control passed after removing " + expected_failure)
    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1
    print("212) mobile household identity, occupants, stores, towing, rest, transitions and observation hold")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
