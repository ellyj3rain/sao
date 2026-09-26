#!/usr/bin/env python3
"""Border 200: native sound/sight acquisition and private-belief evidence.

The installed scanner sees actual WorldSound objects, detached native bodies
and loaded native square fixtures. Its exact rows feed production Perception
in the installed Kahlua VM. Source mutations must change named behavioral
verdicts. No game loop, world save or renderer is launched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
GAME = pathlib.Path(os.environ.get(
    "PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
PZ = GAME / "projectzomboid.jar"
ZB = GAME / "ZombieBuddy.jar"
JDK = pathlib.Path(os.environ.get(
    "JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
SCANNER = ROOT / "java/src/com/sao/engine/SAOPerceptionScanner.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
PERCEPTION = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
HASH = PERCEPTION.with_name("SAO_Hash.lua")
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
PROBE = ROOT / "tools/luacheck/SoundEvidenceProbe.java"

NATIVE_EXPECTED = {
    "own_floor_offset_ignored", "other_source_audible", "unattributed_audible",
    "out_of_range_ignored", "silent_nonstress_ignored", "native_stress_sound_retained",
    "mixed_sources_keep_only_audible_others", "own_recent_footprint_ignored_after_move",
    "native_first_visible_body", "continuous_body_keeps_track", "known_empty_tile_is_visible",
    "same_tile_bodies_have_distinct_tracks", "hidden_tile_has_no_positive_or_negative_sight",
    "visibility_gap_starts_new_tracks", "observers_have_private_track_epochs",
    "missing_eye_ends_native_tracking_session", "visible_empty_tile_reported",
    "unknown_floor_not_certified", "unloaded_tile_not_certified", "behind_tile_not_certified",
    "distant_tile_not_certified", "oversize_known_tile_request_is_bounded",
    "occluded_known_tile_not_certified", "twenty_two_native_bodies_stay_distinct",
    "bridge_forwards_known_tiles", "intervening_wall_hides_actual_body",
    "wall_gap_ends_continuous_tracking",
    "bridge_world_reset_ends_tracking_epoch",
}
LUA_EXPECTED = {
    "own_sound_produces_no_belief", "other_sound_is_unknown", "unattributed_sound_is_unknown",
    "sound_cannot_be_shared_as_threat", "observed_zombie_is_actionable",
    "observed_zombie_can_be_told", "mixed_row_order_preserves_observation",
    "legacy_store_migrates_sound", "legacy_bind_migrates_before_query",
    "legacy_bind_cannot_share_sound", "migration_keeps_observed_told_phantom",
    "newer_sound_survives_migration", "migration_is_idempotent",
    "explicit_hallucination_remains_actionable", "sound_expiry_is_bounded",
    "sound_reload_retains_stamp", "prebind_session_sound_migrates",
    "unbound_legacy_cannot_be_told", "unbound_legacy_cannot_be_reported",
    "unbound_legacy_cannot_brief_departure", "valid_evidence_still_briefs_departure",
    "phantom_and_observation_can_be_reported",
    "recognized_cry_keeps_valid_threat_and_clears_sound",
    "briefing_ranks_actual_evidence",
    "moving_visible_body_keeps_one_belief", "same_tile_visible_bodies_stay_distinct",
    "twenty_two_visible_bodies_remain_twenty_two", "visibility_gap_preserves_uncertainty",
    "visible_empty_tile_retires_observed_and_told", "visible_tile_keeps_phantom",
    "unseen_tiles_do_not_clear_memory", "new_floor_does_not_clear_old_floor",
    "unknown_legacy_floor_is_not_inferred", "current_sight_survives_tile_correction",
    "shared_reports_have_no_sender_tracks", "reports_overlap_recipient_sight",
    "return_and_departure_do_not_share_tracks", "restored_track_cannot_overwrite_memory",
    "filtered_sleep_scan_breaks_lua_association", "tracked_threats_expire",
    "known_tile_request_is_bounded_and_floor_bearing",
    "reciprocal_repeated_tell_keeps_one_threat", "ineligible_rows_do_not_shift_tell_ordinals",
    "repeated_return_reports_keep_one_threat", "repeated_briefings_keep_one_threat",
    "large_known_request_keeps_nearest_512_in_order", "known_request_ties_are_lexical",
    "large_reports_keep_every_body_in_order", "reports_order_newest_then_lexical",
}

PRELUDE = r'''
__tick=100
__persisted={}
__rows=''
__starts={}
Events={OnGameStart={Add=function(callback) __starts[#__starts+1]=callback end}}
ModData={getOrCreate=function(key)
    assert(key=='SurvivorAwareness_Beliefs') return __persisted end}
SAO={
    Log={line=function() end},
    History={ticks=function() return __tick end,
        countyHours=function() return __tick/9000 end},
    Conditions={memoryFactor=function() return 1 end},
    Standing={trust=function() return 1 end,sameGroup=function() return true end,
        groupOf=function() return nil end,claimOf=function() return nil end},
    Communication={canConverse=function() return false end},
    Identity={get=function() return nil end,resolveBodyTag=function() return nil end},
    Disposition={},
}
SAOJavaBridge={perceive=function(self,body,known) __known=known return __rows end}
__body={getX=function() return 10.75 end,getY=function() return 20.75 end,
    getZ=function() return 0 end}
'''

CASES = r'''
local P=SAO.Perception
local results={}
local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
local function fresh()
    P.beliefs={} P.beliefVersion=0 __persisted={} __rows='' __tick=100
    SAO.Standing.groupOf=function() return nil end
    SAO.Identity={get=function() return nil end,resolveBodyTag=function() return nil end}
    SAO.Body=nil
end
local function check(name, fn)
    fresh()
    local ok,value=pcall(fn)
    if not ok then print('DETAIL '..name..': '..tostring(value)) end
    results[#results+1]=name..'='..tostring(ok and value==true)
end
local function observe(id,rows,tick)
    __rows=rows __tick=tick or 100
    P.observe(id,__body,__tick,false)
    return P.beliefs[id]
end
local function unknown(b,key)
    local sound=b.sounds and b.sounds[key]
    return sound and sound.source=='heard' and sound.kind=='unknown'
        and sound.at==100 and type(sound.dist)=='number'
end
local function emptyMind(zombies,sounds)
    return {zombies=zombies or {},sounds=sounds,people={},places={},factions={},
        scanCount=0,lastScanAt=0}
end
local function belief(source,x,y,at)
    return {x=x,y=y,dist=3,at=at or 100,source=source}
end
local function legacy()
    return emptyMind({['12,20']=belief('heard',12,20)})
end
check('own_sound_produces_no_belief',function()
    local b=observe('listener',__native.own)
    return count(b.sounds)==0 and count(b.zombies)==0 and count(b.people)==0
end)
check('other_sound_is_unknown',function()
    local b=observe('listener',__native.other)
    return unknown(b,'12,20') and count(b.zombies)==0 and count(b.people)==0
        and P.nearestBelievedZombie('listener',100,10.75,20.75)==nil
        and P.believedThreatCount('listener',100,20,10.75,20.75)==0
end)
check('unattributed_sound_is_unknown',function()
    local b=observe('listener',__native.unattributed)
    return unknown(b,'13,20') and count(b.zombies)==0 and count(b.people)==0
end)
check('sound_cannot_be_shared_as_threat',function()
    observe('listener',__native.other..'|'..__native.unattributed)
    local offered=P.hasAnythingToPass('listener',100)
    local shared=P.tell('listener','recipient',100,true)
    return not offered and shared==0 and count(P.beliefs.recipient.zombies)==0
end)
check('observed_zombie_is_actionable',function()
    local b=observe('listener','Z:14:20:3.3')
    local nearest=P.nearestBelievedZombie('listener',100,10.75,20.75)
    return b.zombies['14,20'].source=='observed' and count(b.sounds)==0
        and nearest and nearest.x==14 and nearest.source=='observed'
        and P.believedThreatCount('listener',100,20,10.75,20.75)==1
end)
check('observed_zombie_can_be_told',function()
    observe('listener','Z:14:20:3.3')
    local offered=P.hasAnythingToPass('listener',100)
    local shared=P.tell('listener','recipient',100,true)
    local told=P.beliefs.recipient.zombies['14,20']
    return offered and shared==1 and told and told.source=='told'
        and told.teller=='listener' and not P.hasAnythingToPass('recipient',100)
        and P.nearestBelievedZombie('recipient',100,10.75,20.75)~=nil
end)
check('mixed_row_order_preserves_observation',function()
    local z='Z:12:20:1.5'
    for index,rows in ipairs({__native.other..'|'..z,z..'|'..__native.other}) do
        local id='listener'..tostring(index)
        local b=observe(id,rows)
        if not b.zombies['12,20'] or b.zombies['12,20'].source~='observed'
            or P.believedThreatCount(id,100,20,10.75,20.75)~=1 then return false end
    end
    return true
end)
check('legacy_store_migrates_sound',function()
    P.beliefs.listener=legacy()
    local b=observe('listener','')
    return unknown(b,'12,20') and count(b.zombies)==0
end)
check('legacy_bind_migrates_before_query',function()
    __persisted.listener=legacy()
    if not P.bindPersistentStore() then return false end
    local b=P.beliefs.listener
    return b==__persisted.listener and unknown(b,'12,20') and count(b.zombies)==0
        and b.scanCount==0 and P.nearestBelievedZombie('listener',100,10.75,20.75)==nil
        and P.believedThreatCount('listener',100,20,10.75,20.75)==0
end)
check('legacy_bind_cannot_share_sound',function()
    __persisted.listener=legacy()
    P.bindPersistentStore()
    local offered=P.hasAnythingToPass('listener',100)
    local shared=P.tell('listener','recipient',100,true)
    return not offered and shared==0 and count(P.beliefs.recipient.zombies)==0
end)
check('migration_keeps_observed_told_phantom',function()
    local observed=belief('observed',14,20)
    local told=belief('told',15,20) told.teller='previous-witness'
    local phantom=belief('heard',16,20) phantom.phantom=true
    __persisted.listener=emptyMind({['12,20']=belief('heard',12,20),
        ['14,20']=observed,['15,20']=told,['16,20']=phantom})
    P.bindPersistentStore()
    local b=P.beliefs.listener
    return count(b.zombies)==3 and b.zombies['14,20']==observed
        and b.zombies['15,20']==told and b.zombies['16,20']==phantom
        and unknown(b,'12,20')
        and P.believedThreatCount('listener',100,20,10.75,20.75)==3
end)
check('newer_sound_survives_migration',function()
    local recent=belief('heard',12,20,99) recent.kind='unknown'
    local b=emptyMind({['12,20']=belief('heard',12,20,80)},{['12,20']=recent})
    __persisted.listener=b
    P.bindPersistentStore()
    return b.sounds['12,20']==recent and recent.at==99 and count(b.zombies)==0
end)
check('migration_is_idempotent',function()
    __persisted.listener=legacy()
    P.bindPersistentStore()
    local b=P.beliefs.listener
    local sound=b.sounds and b.sounds['12,20']
    local version=P.beliefVersion
    P.bindPersistentStore()
    -- The store executes before the acquisition cadence early return.
    b.lastScanAt=100
    observe('listener','')
    return sound~=nil and b.sounds['12,20']==sound and count(b.zombies)==0
        and P.beliefVersion==version and sound.at==100
end)
check('explicit_hallucination_remains_actionable',function()
    local x,y=P.hallucinate('listener',100,10.75,20.75)
    local b=P.beliefs.listener
    b.soundEvidenceVersion=nil
    observe('listener','')
    local phantom=b.zombies[x..','..y]
    return phantom and phantom.phantom==true and phantom.source=='heard'
        and P.nearestBelievedZombie('listener',100,10.75,20.75)~=nil
        and P.believedThreatCount('listener',100,20,10.75,20.75)==1
end)
check('sound_expiry_is_bounded',function()
    local b=observe('listener',__native.other)
    observe('listener','',1300)
    if not b.sounds['12,20'] then return false end
    observe('listener','',1320)
    return count(b.sounds)==0 and count(b.zombies)==0
end)
check('sound_reload_retains_stamp',function()
    local b=observe('listener',__native.other)
    __persisted={listener=b}
    P.beliefs={} __tick=140
    if not P.bindPersistentStore() then return false end
    return P.beliefs.listener==b and unknown(b,'12,20') and b.lastScanAt==100
        and count(b.zombies)==0
end)
check('prebind_session_sound_migrates',function()
    P.beliefs.listener=legacy()
    P.bindPersistentStore()
    local b=P.beliefs.listener
    return unknown(b,'12,20') and count(b.zombies)==0
end)
check('unbound_legacy_cannot_be_told',function()
    P.beliefs.listener=legacy()
    local offered=P.hasAnythingToPass('listener',100)
    local shared=P.tell('listener','recipient',100,true)
    return not offered and shared==0 and count(P.beliefs.recipient.zombies)==0
end)
check('unbound_legacy_cannot_be_reported',function()
    P.beliefs.listener=legacy()
    P.beliefs.recipient=emptyMind()
    local shared=P.reportReturn('listener','recipient',100,12,20)
    return shared==0 and count(P.beliefs.recipient.zombies)==0
end)
local function departure(zombies,otherZombies)
    SAO.Identity={get=function(id) return {id=id} end,
        beliefKey=function(rec) return rec.id end}
    SAO.Body={get=function() return __body end}
    SAO.Standing.groupOf=function() return 'household' end
    P.beliefs.goer=emptyMind()
    P.beliefs.briefer=emptyMind(zombies)
    if otherZombies then P.beliefs.otherBriefer=emptyMind(otherZombies) end
    P.announceDeparture('goer','supply',12,20)
    return P.beliefs.goer
end
check('unbound_legacy_cannot_brief_departure',function()
    local b=departure({['12,20']=belief('heard',12,20)})
    return count(b.zombies)==0
end)
check('valid_evidence_still_briefs_departure',function()
    local phantom=belief('heard',16,20) phantom.phantom=true
    local b=departure({['12,20']=belief('observed',12,20),['16,20']=phantom,
        ['15,20']=belief('told',15,20),['13,20']=belief('heard',13,20)})
    return count(b.zombies)==2 and b.zombies['12,20'].source=='told'
        and b.zombies['16,20'].source=='told' and b.zombies['16,20'].teller=='briefer'
end)
check('briefing_ranks_actual_evidence',function()
    local b=departure({['12,20']=belief('heard',12,20),['13,20']=belief('heard',13,20),
        ['14,20']=belief('heard',14,20)}, {['15,20']=belief('observed',15,20)})
    return count(b.zombies)==1 and b.zombies['15,20']
        and b.zombies['15,20'].teller=='otherBriefer'
end)
check('phantom_and_observation_can_be_reported',function()
    local phantom=belief('heard',16,20) phantom.phantom=true
    P.beliefs.listener=emptyMind({['12,20']=belief('observed',12,20),
        ['16,20']=phantom,['15,20']=belief('told',15,20)})
    P.beliefs.recipient=emptyMind()
    local shared=P.reportReturn('listener','recipient',100,12,20)
    local b=P.beliefs.recipient
    return shared==2 and count(b.zombies)==2 and b.zombies['12,20'].source=='told'
        and b.zombies['16,20'].source=='told' and b.zombies['16,20'].teller=='listener'
end)
check('recognized_cry_keeps_valid_threat_and_clears_sound',function()
    for _,source in ipairs({'observed','told','heard'}) do
        P.beliefs={}
        SAO.Identity={get=function(id) return {id=id} end,
            beliefKey=function(rec) return rec.id end}
        local caller={getX=function() return 12.25 end,getY=function() return 20.25 end}
        SAO.Body={get=function(id) return id=='caller' and caller or __body end}
        SAO.Standing.groupOf=function() return 'household' end
        local b=observe('listener',__native.other)
        local threat=belief(source,12,20)
        if source=='heard' then threat.phantom=true end
        if source=='told' then threat.teller='earlier-witness' end
        b.zombies['12,20']=threat
        local heard=P.cryForHelp('caller',100)
        if #heard~=1 or heard[1]~='listener' or b.zombies['12,20']~=threat
            or b.sounds['12,20']~=nil or b.people.caller.source~='heard'
            or b.people.caller.condition~='bad' then return false end
        observe('listener',__native.other,120)
        if b.sounds['12,20']~=nil or b.zombies['12,20']~=threat then return false end
    end
    return true
end)
local function zrows(rows)
    local out={} for row in string.gmatch(rows,'[^|]+') do
        if string.sub(row,1,2)=='Z:' then out[#out+1]=row end
    end return table.concat(out,'|')
end
local function active(id,tick)
    return P.believedThreatCount(id,tick or 100,20,10.75,20.75)
end
local function noTracks(b)
    for key,zb in pairs(b.zombies) do
        if zb.track or string.find(key,'seen:',1,true) then return false end
    end return true
end
check('moving_visible_body_keeps_one_belief',function()
    local b=observe('listener',zrows(__native.first),100)
    observe('listener',zrows(__native.moved),120)
    local closest=P.nearestBelievedZombie('listener',120,10.75,20.75)
    return count(b.zombies)==1 and active('listener',120)==1 and closest.x==12
end)
check('same_tile_visible_bodies_stay_distinct',function()
    local b=observe('listener',zrows(__native.pair))
    return count(b.zombies)==2 and active('listener')==2
end)
check('twenty_two_visible_bodies_remain_twenty_two',function()
    local b=observe('listener',zrows(__native.crowd))
    return count(b.zombies)==22 and active('listener')==22
end)
check('visibility_gap_preserves_uncertainty',function()
    local b=observe('listener',zrows(__native.first),100)
    observe('listener',__native.hidden,120)
    if count(b.zombies)~=1 then return false end
    observe('listener',zrows(__native.returned),140)
    return count(b.zombies)==3 and active('listener',140)==3
end)
check('visible_empty_tile_retires_observed_and_told',function()
    local b=observe('listener',zrows(__native.returned),100)
    b.zombies.report={x=15,y=20,z=0,dist=4,at=100,source='told',teller='other'}
    observe('listener',__native.empty,120)
    return count(b.zombies)==0 and active('listener',120)==0
end)
check('visible_tile_keeps_phantom',function()
    local b=observe('listener',zrows(__native.returned),100)
    b.zombies.phantom={x=15,y=20,z=0,dist=4,at=100,source='heard',phantom=true}
    observe('listener',__native.empty,120)
    return count(b.zombies)==1 and b.zombies.phantom and active('listener',120)==1
end)
check('unseen_tiles_do_not_clear_memory',function()
    local b=observe('listener',zrows(__native.returned),100)
    for i,label in ipairs({'hidden','unloaded','back','distant','occluded'}) do
        observe('listener',__native[label],100+i*20)
        if count(b.zombies)~=2 then return false end
    end return true
end)
check('new_floor_does_not_clear_old_floor',function()
    local b=observe('listener',zrows(__native.first),100)
    local upstairs={x=11,y=20,z=1,dist=1,at=100,source='told'}
    b.zombies.upstairs=upstairs
    observe('listener','V:11:20:1',120)
    return count(b.zombies)==1 and active('listener',120)==1
        and P.nearestBelievedZombie('listener',120,10.75,20.75).source=='observed'
end)
check('unknown_legacy_floor_is_not_inferred',function()
    local old=belief('observed',11,20)
    P.beliefs.listener=emptyMind({old=old})
    observe('listener','V:11:20:0',120)
    return P.beliefs.listener.zombies.old==old and old.z==nil
end)
check('current_sight_survives_tile_correction',function()
    local b=observe('listener',__native.returned,100)
    observe('listener','',120)
    observe('listener',__native.rebound,140)
    return count(b.zombies)==2 and active('listener',140)==2
end)
check('shared_reports_have_no_sender_tracks',function()
    observe('listener',zrows(__native.pair),100)
    local shared=P.tell('listener','recipient',100,true)
    local b=P.beliefs.recipient
    return shared==2 and count(b.zombies)==2 and active('recipient')==2
        and noTracks(b) and b.zombies['12,20,0'] and b.zombies['12,20,0#2']
        and b.zombies['12,20,0'].z==0
end)
check('reports_overlap_recipient_sight',function()
    observe('listener',zrows(__native.pair),100)
    P.tell('listener','recipient',100,true)
    observe('recipient','Z:12:20:1.5::track:recipient-a:floor:0|Z:12:20:1.5::track:recipient-b:floor:0',120)
    observe('listener',zrows(__native.returned),140)
    return active('recipient',120)==2 and count(P.beliefs.recipient.zombies)==4
        and P.beliefs.recipient.zombies['12,20,0'].x==12
end)
check('return_and_departure_do_not_share_tracks',function()
    local b=observe('listener',zrows(__native.pair),100)
    P.beliefs.recipient=emptyMind()
    local shared=P.reportReturn('listener','recipient',100,12,20)
    if shared~=2 or not noTracks(P.beliefs.recipient) then return false end
    local out=departure(b.zombies)
    return count(out.zombies)==2 and noTracks(out)
end)
check('restored_track_cannot_overwrite_memory',function()
    local b=observe('listener',zrows(__native.first),100)
    P.beliefs={} __persisted={listener=b} __tick=100
    if not P.bindPersistentStore() then return false end
    -- Reuse even the exact old token adversarially. Bind must have revoked it.
    observe('listener',zrows(__native.moved),120)
    return count(b.zombies)==2 and active('listener',120)==2
end)
check('filtered_sleep_scan_breaks_lua_association',function()
    local b=observe('listener',zrows(__native.returned),100)
    __rows=zrows(__native.returned) __tick=120
    P.observe('listener',__body,120,true)
    observe('listener',zrows(__native.returned),140)
    return count(b.zombies)==4
end)
check('tracked_threats_expire',function()
    local b=observe('listener',zrows(__native.pair),100)
    observe('listener','',721)
    if active('listener',721)~=0 or count(b.zombies)~=2 then return false end
    observe('listener','',1301)
    return count(b.zombies)==0
end)
check('known_tile_request_is_bounded_and_floor_bearing',function()
    local b=emptyMind()
    for x=-4,25 do for y=6,35 do
        b.zombies[x..','..y]={x=x,y=y,z=0,at=100,source='observed'}
    end end
    b.zombies.legacy=belief('observed',0,20)
    P.beliefs.listener=b observe('listener','',120)
    local n=0 for item in string.gmatch(__known,'[^;]+') do
        if not string.match(item,'^%-?%d+,%-?%d+,0$') then return false end n=n+1
    end return n==512
end)
check('reciprocal_repeated_tell_keeps_one_threat',function()
    observe('listener',zrows(__native.first),100)
    P.tell('listener','recipient',100,true)
    observe('recipient','Z:11:20:0.8::track:recipient-own:floor:0',120)
    for tick=140,220,20 do
        P.tell('recipient','listener',tick,true)
        P.tell('listener','recipient',tick,true)
        if active('listener',tick)~=1 or active('recipient',tick)~=1 then return false end
    end
    return count(P.beliefs.listener.zombies)==2 and count(P.beliefs.recipient.zombies)==2
end)
check('ineligible_rows_do_not_shift_tell_ordinals',function()
    local b=observe('listener',zrows(__native.first),100)
    P.tell('listener','recipient',100,true)
    for key,source in pairs({a='told',b='heard',c='observed'}) do
        b.zombies[key]={x=11,y=20,z=0,at=source=='observed' and -1000 or 100,
            dist=1,source=source}
    end
    P.tell('listener','recipient',120,true)
    return active('recipient',120)==1 and count(P.beliefs.recipient.zombies)==1
end)
check('repeated_return_reports_keep_one_threat',function()
    local b=observe('listener',zrows(__native.first),100)
    P.beliefs.recipient=emptyMind()
    P.reportReturn('listener','recipient',100,11,20)
    b.zombies['11,20,0']={x=11,y=20,z=0,at=100,dist=1,source='told'}
    b.zombies.legacy={x=11,y=20,z=0,at=100,dist=1,source='heard'}
    for tick=120,200,20 do
        P.reportReturn('listener','recipient',tick,11,20)
        if active('recipient',tick)~=1 or count(P.beliefs.recipient.zombies)~=1 then return false end
    end return true
end)
check('repeated_briefings_keep_one_threat',function()
    local b=observe('listener',zrows(__native.first),100)
    local goer=departure(b.zombies)
    local briefer=P.beliefs.briefer
    briefer.zombies['11,20,0']={x=11,y=20,z=0,at=100,dist=1,source='told'}
    briefer.zombies.legacy={x=11,y=20,z=0,at=100,dist=1,source='heard'}
    for tick=120,200,20 do
        __tick=tick P.announceDeparture('goer','supply',12,20)
        if active('goer',tick)~=1 or count(goer.zombies)~=1 then return false end
    end return true
end)
-- Only the fixture map's iteration order is controlled. The actual producer
-- and installed Kahlua sorter/VM still execute; reverse comparator order is
-- adversarial to the engine's left-pivot recursive quicksort.
local function inOrder(map,order,fn)
    local actualPairs=pairs
    pairs=function(value)
        if value~=map then return actualPairs(value) end
        local i=0
        return function()
            i=i+1 local key=order[i]
            if key then return key,map[key] end
        end
    end
    local ok,result=pcall(fn)
    pairs=actualPairs
    if not ok then error(result) end
    return result
end
check('large_known_request_keeps_nearest_512_in_order',function()
    local b,order=emptyMind(),{}
    -- Fractional remembered positions are an adversarial persisted input,
    -- not a claim that native scanner request parsing admits fractions.
    -- All 4099 locations pass the existing Lua range/floor predicate.
    for i=1,4099 do
        local key='memory-'..i order[#order+1]=key
        b.zombies[key]={x=10+i/65536,y=20,z=0,at=100,source='observed'}
    end
    P.beliefs.listener=b __known=false
    inOrder(b.zombies,order,function() observe('listener','',120) end)
    local expected={}
    for i=4099,4099-511,-1 do expected[#expected+1]=(10+i/65536)..',20,0' end
    return __known==table.concat(expected,';') and count(b.zombies)==4099
end)
check('known_request_ties_are_lexical',function()
    local b,order=emptyMind(),{'east','north','south','west'}
    local points={east={1,0},north={0,1},south={0,-1},west={-1,0}}
    for key,xy in pairs(points) do
        b.zombies[key]={x=xy[1],y=xy[2],z=0,at=100,source='observed'}
    end
    local body={getX=function() return 0 end,getY=function() return 0 end,
        getZ=function() return 0 end}
    P.beliefs.listener=b __known=false
    inOrder(b.zombies,order,function() P.observe('listener',body,120,false) end)
    return __known=='-1,0,0;0,-1,0;0,1,0;1,0,0'
end)
check('large_reports_keep_every_body_in_order',function()
    local b,order=emptyMind(),{}
    for i=4099,1,-1 do
        local key=string.format('stress-%05d',i) order[#order+1]=key
        b.zombies[key]={x=12,y=20,z=0,at=100,dist=1,source='observed',
            formPerformance=i/8192}
    end
    P.beliefs.listener=b
    local shared=inOrder(b.zombies,order,function()
        return P.tell('listener','recipient',100,true)
    end)
    local output=P.beliefs.recipient.zombies
    if shared~=4099 or count(output)~=4099 then return false end
    for i=1,4099 do
        local key='12,20,0'..(i>1 and ('#'..i) or '')
        if not output[key] or output[key].formPerformance~=i/8192 then return false end
    end
    return true
end)
check('reports_order_newest_then_lexical',function()
    local b,order=emptyMind(),{'z','a','b','a-new','c'}
    local times={100,98,100,100,99}
    for i,key in ipairs(order) do
        b.zombies[key]={x=12,y=20,z=0,at=times[i],dist=1,source='observed',
            formPerformance=i/8}
    end
    P.beliefs.listener=b
    local shared=inOrder(b.zombies,order,function()
        return P.tell('listener','recipient',100,true)
    end)
    local output=P.beliefs.recipient.zombies
    local expected={4,3,1,5,2}
    for i,marker in ipairs(expected) do
        local key='12,20,0'..(i>1 and ('#'..i) or '')
        if not output[key] or output[key].formPerformance~=marker/8 then return false end
    end
    return shared==5 and count(output)==5
end)
__soundEvidenceResult=table.concat(results,';')
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, cwd, receipt, label):
    done = subprocess.run(list(map(str, args)), cwd=cwd, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=150)
    receipt["runs"].append({"label": label, "exit": done.returncode,
                            "stdout": done.stdout, "stderr": done.stderr})
    return done


def compile_native(work, receipt):
    classes = work / "classes"
    classes.mkdir()
    version = (ROOT / "VERSION").read_text(encoding="utf-8-sig").strip()
    generated = work / "SAOVersion.java"
    generated.write_text('package com.sao; public final class SAOVersion { '
                         f'public static final String VALUE = "{version}"; }}\n', encoding="utf-8")
    sources = sorted((ROOT / "java/src").rglob("*.java"))
    done = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
                os.pathsep.join(map(str, (PZ, ZB))), "-d", classes,
                *sources, generated, PROBE, RUNNER], work, receipt, "compile-production")
    if done.returncode:
        raise RuntimeError("production native compile failed: " + done.stdout + done.stderr)
    shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
    return classes


def native(work, classes, receipt, label="production", scanner=None):
    leading = []
    if scanner is not None:
        changed = work / label
        changed.mkdir()
        source = changed / "SAOPerceptionScanner.java"
        source.write_text(scanner, encoding="utf-8")
        done = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
                    os.pathsep.join(map(str, (classes, PZ, ZB))), "-d", changed, source],
                   work, receipt, label + "-compile")
        if done.returncode:
            raise RuntimeError("scanner control did not compile: " + done.stdout + done.stderr)
        leading.append(changed)
    done = run([JDK / "java.exe", f"-Duser.home={work / (label + '-home')}",
                "-Djava.awt.headless=true", "-cp",
                os.pathsep.join(map(str, (*leading, classes, PZ, ZB))), "SoundEvidenceProbe"],
               GAME, receipt, label + "-native")
    checks = dict(re.findall(r"^CHECK ([a-z0-9_]+)=(true|false)$", done.stdout, re.M))
    rows = dict(re.findall(r"^ROW ([a-z]+)=(.*)$", done.stdout, re.M))
    return checks, rows, done


def lua(work, classes, rows, receipt, label="production", perception=None):
    prelude = work / "prelude.lua"
    values = ",".join(f"[{json.dumps(key)}]={json.dumps(value)}" for key, value in sorted(rows.items()))
    prelude.write_text(PRELUDE + "\n__native={" + values + "}\n", encoding="utf-8")
    cases = work / "cases.lua"
    cases.write_text(CASES, encoding="utf-8")
    path = PERCEPTION
    if perception is not None:
        path = work / (label + ".lua")
        path.write_text(perception, encoding="utf-8")
    done = run([JDK / "java.exe", "-cp", os.pathsep.join(map(str, (classes, PZ))),
                "LuaRun", prelude, HASH, path, cases, "--", "__soundEvidenceResult"],
               work, receipt, label + "-kahlua")
    checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", done.stdout))
    return checks, done


def require_checks(checks, expected, done, label):
    failures = sorted(name for name, value in checks.items() if value != "true")
    if done.returncode or set(checks) != expected or failures:
        raise RuntimeError(f"{label}: missing={sorted(expected-set(checks))}, "
                           f"extra={sorted(set(checks)-expected)}, failed={failures}\n"
                           + done.stdout + done.stderr)


def execute(receipt):
    with tempfile.TemporaryDirectory(prefix="sao-sound-evidence-") as raw:
        work = pathlib.Path(raw)
        classes = compile_native(work, receipt)
        checks, rows, done = native(work, classes, receipt)
        require_checks(checks, NATIVE_EXPECTED, done, "native sound baseline")
        if set(rows) != {"own", "other", "unattributed", "first", "moved", "pair",
                        "hidden", "returned", "rebound", "empty", "floor", "unloaded",
                        "back", "distant", "occluded", "crowd"}:
            raise RuntimeError("native scanner row inventory differs")
        receipt["native_rows"] = rows
        print(f"PASS {len(checks)} native WorldSound scanner cases", flush=True)
        # A saved token must not acquire authority in a new native process.
        repeat_checks, repeat_rows, repeat_done = native(work, classes, receipt, "new-jvm")
        require_checks(repeat_checks, NATIVE_EXPECTED, repeat_done, "new JVM baseline")
        tokens = lambda value: set(re.findall(r":track:([^:|]+)", value))
        if not tokens(rows["first"]).isdisjoint(tokens(repeat_rows["first"])):
            raise RuntimeError("native sight token reused across JVM sessions")
        print("PASS new JVM has a distinct observation epoch", flush=True)
        scanner = SCANNER.read_text(encoding="utf-8-sig")
        before = "sound.source == shell || "
        if scanner.count(before) != 1:
            raise RuntimeError("scanner own-source mutation seam drifted")
        checks, _, done = native(work, classes, receipt, "self-source-removed",
                                 scanner.replace(before, "", 1))
        if set(checks) != NATIVE_EXPECTED or done.returncode != 1 \
                or checks.get("own_floor_offset_ignored") != "false" \
                or checks.get("own_recent_footprint_ignored_after_move") != "false":
            raise RuntimeError("self-source control did not expose actual own sounds\n"
                               + done.stdout + done.stderr)
        print("PASS self-source control leaks actual own footsteps", flush=True)
        native_controls = [
            ("continuous-track-forgotten", "String prior = previous.get(body);", "String prior = null;",
             "continuous_body_keeps_track"),
            ("hidden-track-retained", "tracks.previous = visible;", "tracks.previous.putAll(visible);",
             "visibility_gap_starts_new_tracks"),
            ("shared-track-epoch", "UUID.randomUUID().toString()", '"shared-epoch"',
             "observers_have_private_track_epochs"),
            ("world-reset-keeps-tracks", "SIGHT_TRACKS.clear();", "// retain old tracks",
             "bridge_world_reset_ends_tracking_epoch"),
            ("coverage-without-sight", "if (wholeTileVisible(shell, square))", "if (square != null)",
             "behind_tile_not_certified"),
            ("intervening-wall-ignored", "\n                && clearPath(eye, zombie.getCurrentSquare(), true)", "",
             "intervening_wall_hides_actual_body"),
        ]
        for label, before, after, verdict in native_controls:
            if scanner.count(before) != 1:
                raise RuntimeError("native source mutation seam drifted: " + label)
            checks, _, done = native(work, classes, receipt, label, scanner.replace(before, after, 1))
            if set(checks) != NATIVE_EXPECTED or done.returncode != 1 or checks.get(verdict) != "false":
                raise RuntimeError(f"{label} did not flip {verdict}\n" + done.stdout + done.stderr)
            print(f"PASS {label} control flips {verdict}", flush=True)
        checks, done = lua(work, classes, rows, receipt)
        require_checks(checks, LUA_EXPECTED, done, "Kahlua sound baseline")
        print(f"PASS {len(checks)} production Kahlua sound-evidence cases", flush=True)
        perception = PERCEPTION.read_text(encoding="utf-8-sig")
        mutations = [
            ("sound-as-zombie", 'b.sounds[key] = { x = x, y = y, dist = d, at = tick,',
             'b.zombies[key] = { x = x, y = y, dist = d, at = tick,', "other_sound_is_unknown"),
            ("migration-disabled", "local function soundEvidence(b)\n",
             "local function soundEvidence(b)\n    b.sounds = b.sounds or {}\n    do return end\n",
             "legacy_bind_migrates_before_query"),
            ("phantom-demoted", 'belief.source == "heard" and belief.phantom ~= true',
             'belief.source == "heard"', "migration_keeps_observed_told_phantom"),
            ("tell-unknown-shared",
             'return tick - belief.at <= tellerHorizon and belief.source ~= "told"\n'
             '            and (belief.source ~= "heard" or belief.phantom == true)',
             'return tick - belief.at <= tellerHorizon and belief.source ~= "told"',
             "unbound_legacy_cannot_be_told"),
            ("report-unknown-shared",
             'return zb.source ~= "told" and (zb.source ~= "heard" or zb.phantom == true)\n'
             '            and dx * dx',
             'return zb.source ~= "told"\n            and dx * dx', "unbound_legacy_cannot_be_reported"),
            ("briefing-unknown-ranked",
             'for _, zb in pairs(b2.zombies or {}) do\n'
             '                            if zb.source ~= "told"\n'
             '                                and (zb.source ~= "heard" or zb.phantom == true) then',
             'for _, zb in pairs(b2.zombies or {}) do\n'
             '                            if zb.source ~= "told" then', "briefing_ranks_actual_evidence"),
            ("briefing-unknown-copied",
             'return zb.source ~= "told" and (zb.source ~= "heard" or zb.phantom == true)\n'
             '                and zdx * zdx',
             'return zb.source ~= "told"\n                and zdx * zdx', "valid_evidence_still_briefs_departure"),
            ("cry-erases-valid-threat", 'if ob.sounds then ob.sounds[tileKey] = nil end',
             'ob.zombies[tileKey] = nil', "recognized_cry_keeps_valid_threat_and_clears_sound"),
            ("moving-trail-restored", "priorTracks[belief.track] = key", "priorTracks[belief.track] = nil",
             "moving_visible_body_keeps_one_belief"),
            ("tile-only-threat-keys", "if belief.track then", "if false then",
             "moving_visible_body_keeps_one_belief"),
            ("absence-treated-as-sight", "covered[zombieTile(belief)]", "true",
             "unseen_tiles_do_not_clear_memory"),
            ("phantom-cleared-by-sight", "and not currentSight[key] and belief.phantom ~= true",
             "and not currentSight[key]", "visible_tile_keeps_phantom"),
            ("current-sighting-cleared", "and not currentSight[key] and belief.phantom ~= true",
             "and belief.phantom ~= true", "current_sight_survives_tile_correction"),
            ("sender-track-key-shared", "pairs(zombieReports(from.zombies, canTellZombie))",
             "pairs(from.zombies)", "shared_reports_have_no_sender_tracks"),
            ("restored-track-trusted", "for _, belief in pairs(b.zombies or {}) do belief.track = nil end",
             "-- restored tracks retained", "restored_track_cannot_overwrite_memory"),
            ("filtered-gap-linked", 'and belief.at == priorScanAt then', 'then',
             "filtered_sleep_scan_breaks_lua_association"),
            ("report-count-added-to-sight", "math.max(tile.observed, tile.told)",
             "(tile.observed + tile.told)", "reports_overlap_recipient_sight"),
            ("floor-identity-dropped", '.. (belief.z ~= nil and ("," .. belief.z) or "")',
             '.. ""', "new_floor_does_not_clear_old_floor"),
            ("ordinal-before-eligibility", "if accept(belief) then", "if true then",
             "reciprocal_repeated_tell_keeps_one_threat"),
            ("unsafe-known-request-sort", "sortSightEvidence(keys, function(a, c)",
             "table.sort(keys, function(a, c)", "large_known_request_keeps_nearest_512_in_order"),
            ("unsafe-zombie-report-sort", "sortSightEvidence(ordered, function(a, b)",
             "table.sort(ordered, function(a, b)", "large_reports_keep_every_body_in_order"),
            ("merge-comparison-reversed", "or not less(values[right], values[left])) then",
             "or less(values[right], values[left])) then", "large_reports_keep_every_body_in_order"),
            ("request-distance-reversed", "return distance[a] < distance[c]",
             "return distance[a] > distance[c]", "large_known_request_keeps_nearest_512_in_order"),
            ("request-tie-reversed", "return a < c", "return a > c", "known_request_ties_are_lexical"),
            ("report-time-reversed", "return a.belief.at > b.belief.at",
             "return a.belief.at < b.belief.at", "reports_order_newest_then_lexical"),
            ("report-key-reversed", "return a.key < b.key", "return a.key > b.key",
             "large_reports_keep_every_body_in_order"),
            ("report-multiplicity-capped", "for _, row in ipairs(ordered) do\n        local tile = zombieTile",
             "while #ordered > 512 do ordered[#ordered] = nil end\n"
             "    for _, row in ipairs(ordered) do\n        local tile = zombieTile",
             "large_reports_keep_every_body_in_order"),
        ]
        for label, before, after, verdict in mutations:
            if perception.count(before) != 1:
                raise RuntimeError("Lua source mutation seam drifted: " + label)
            checks, done = lua(work, classes, rows, receipt, label,
                               perception.replace(before, after, 1))
            if done.returncode or set(checks) != LUA_EXPECTED or checks.get(verdict) != "false":
                raise RuntimeError(f"{label} did not flip {verdict}\n" + done.stdout + done.stderr)
            if label == "tile-only-threat-keys" and checks.get("same_tile_visible_bodies_stay_distinct") != "false":
                raise RuntimeError("old tile-key control did not reproduce same-tile collapse")
            print(f"PASS {label} control flips {verdict}", flush=True)
        receipt["case_counts"] = {"native": len(NATIVE_EXPECTED), "kahlua": len(LUA_EXPECTED),
                                  "source_controls": 1 + len(native_controls) + len(mutations)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=pathlib.Path)
    args = parser.parse_args()
    receipt = {"status": "FAIL", "runs": [], "limits":
        "Actual native WorldSound, IsoZombie, loaded-square LOS and production Kahlua beliefs; detached fixture, no rendered sighting or game loop. Existing query radius is XY-only."}
    try:
        controller = CONTROLLER.read_text(encoding="utf-8-sig")
        if 'heard " .. pname' in controller or "Heard gunfire, attributed" in controller:
            raise RuntimeError("Controller retains unsupported sound-to-shooter attribution")
        receipt["controller_check"] = "source wiring assertion: former arbitrary sound-to-shooter block absent"
        if not all(path.is_file() for path in (PZ, ZB, GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe")):
            receipt["status"] = "SKIPPED"
            print("SKIPPED sound evidence: installed Project Zomboid or JDK absent")
        else:
            receipt["sources"] = {str(path.relative_to(ROOT)).replace("\\", "/"): sha(path)
                                  for path in (SCANNER, BRIDGE, PERCEPTION, HASH, CONTROLLER, PROBE, RUNNER)}
            receipt["engine_sha256"] = sha(PZ)
            execute(receipt)
            receipt["status"] = "PASS"
            print("Border 200 PASS: native sound and sight acquisition, private continuous tracks, "
                  "visible-tile correction, scoped sharing, saved-state migration, iterative sight sorting "
                  f"and {receipt['case_counts']['source_controls']} source controls")
    except Exception as error:
        receipt["error"] = str(error)
        print("FAIL sound evidence: " + str(error))
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt["status"] in ("PASS", "SKIPPED") else 1


if __name__ == "__main__":
    sys.exit(main())
