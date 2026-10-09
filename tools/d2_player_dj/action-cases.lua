local total=0
local function check(name,condition)
    if not condition then error("DJ_ACTION:"..name) end
    total=total+1
end

local function refused(name,change,mode,sound)
    __fresh()
    local action=__make(mode,sound)
    change(action)
    check(name.."_refused",action:isValidStart()==false)
    check(name.."_without_effect",action:start()==false and action.saoEnded
        and __xpCount==0 and __moodCount==0 and __volume==0.61
        and __overlayCount==0 and __queueReset==1)
    return action
end

__fresh()
local action=__make()
check("owned_constructor",action.Type=="PlayDJBoothAction"
    and action.saoOwner=="SAO.PlayerDJ" and action.playerIndex==0)
check("source_catalog_over_callback_length",action.sourceLength==215
    and action.length==215*48 and action.sourceSound=="slow1")
check("live_start_admitted",action:isValidStart()==true)
check("native_player_start",action:start()==true and action.saoStarted
    and __volume==0 and LS_DJBooth.isPlaying==true
    and __player:getModData().PlayingInstrument==true
    and __overlayCount==1 and __sounds[1]=="dj_booth_turnon")
check("live_action_stays_valid",action:isValid()==true)
action:update()
check("normal_update_stays_active",action.saoStarted and not action.saoEnded)
action.countstart=99
action:update()
check("selected_source_audio_plays",action.audio=="slow1"
    and __soundPlaying[action.gameSound]==true)
__level=3;action.keyPause=false;__pressed[Keyboard.KEY_UP]=true
action:update()
check("live_mode_change",action.mode=="medium" and LS_DJBooth.speed==2)
__pressed[Keyboard.KEY_UP]=false
action.countstart=99
action:update()
check("new_mode_source_audio_plays",action.audio=="medium1"
    and __soundPlaying[action.gameSound]==true)
action:perform()
check("performed_native_effect_once",action.saoEffectApplied==true
    and __xpCount==1 and __moodCount==1 and __queueComplete==1)
check("performed_cleanup",action.saoEnded and not action.saoStarted
    and LS_DJBooth.isPlaying==false and __player:getModData().PlayingInstrument==false
    and __volume==0.61 and __overlayDestroyed==1)
action:perform()
action:stop()
check("terminal_replay_inert",__xpCount==1 and __moodCount==1
    and __queueComplete==1 and __queueReset==0 and __overlayDestroyed==1)

refused("queue",function()__queueActive=false end)
refused("source_track",function()end,"slow","slow99")
refused("source_changed",function()__tracks[1].length=999 end)
__tracks[1].length=215
refused("player_slot",function()__slotCurrent=false end)
refused("player_dead",function()__playerDead=true end)
refused("not_at_front",function()__playerSquare={} end)
refused("native_left_part",function()__leftPresent=false end)
refused("native_right_part",function()__rightPresent=false end)
refused("native_main",function()__mainPresent=false end)
refused("station_power",function()__nights=3;__power=false end)
refused("player_headphones",function()__headphones=false end)
refused("npc_station_lease",function()__npcLease=true end)
refused("external_dj",function()LS_DJBooth.isPlaying=true end)
refused("external_mic",function()LS_DJBooth.isPlayingMic=true end)
refused("skill_changed",function()end,"fast","fast1")
refused("source_ownership",function()__sourceActive=false end)

__fresh()
action=__make()
check("actual_queue_claim_required",action:isValid()==true)
__queuedAction={}
check("foreign_queue_action_refused",action:isValid()==false)

__fresh()
action=__make()
check("before_start_stop_is_local",action.saoStarted==false)
action:stop()
check("before_start_stop_preserves_shared_state",action.saoEnded
    and LS_DJBooth.isPlaying==false and __volume==0.61
    and __overlayDestroyed==0 and __queueReset==1)

__fresh()
action=__make()
__overlayFailure=true
local startOK,startResult=pcall(function()return action:start()end)
check("source_start_failure_returns",startOK and startResult==false)
check("failed_start_restores",action.saoEnded and action.saoSourceError
    and __volume==0.61 and LS_DJBooth.isPlaying==false
    and __player:getModData().PlayingInstrument==false and __queueReset==1)

__fresh()
action=__make()
check("power_trial_starts",action:start()==true)
__nights=3;__power=false
check("power_outage_is_invalid",action:isValid()==false)
action:update()
check("power_outage_stops_without_credit",action.saoEnded and __xpCount==0
    and __moodCount==0 and __queueReset==1 and __volume==0.61)

__fresh()
action=__make()
check("lease_trial_starts",action:start()==true)
__npcLease=true
action:update()
check("npc_takeover_stops",action.saoEnded and __xpCount==0 and __queueReset==1)

__fresh()
action=__make()
check("disconnection_trial_starts",action:start()==true)
__slotCurrent=false
action:update()
check("stale_character_stops",action.saoEnded and __xpCount==0
    and __player:getModData().PlayingInstrument==false)

__fresh()
action=__make()
check("invalid_completion_trial_starts",action:start()==true)
__headphones=false
action:perform()
check("invalid_completion_no_credit",action.saoCompletionRejected==true
    and __xpCount==0 and __moodCount==0 and __queueComplete==1
    and __volume==0.61)

__fresh()
action=__make()
check("user_volume_trial_starts",action:start()==true)
__volume=0.7
action:stop()
check("user_volume_change_preserved",__volume==0.7 and __queueReset==1)

__fresh()
action=__make()
check("mic_takeover_trial_starts",action:start()==true)
LS_DJBooth.isPlayingMic=true
action:update()
check("mic_takeover_preserves_mic",action.saoEnded
    and LS_DJBooth.isPlayingMic==true and __volume==0
    and __xpCount==0)

print("PASS SAO player DJ action "..total)
