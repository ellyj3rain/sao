check(arg==nil and stopLoopedSounds==nil and playNextSound==nil and GetText==nil,'no_borrowed_globals')
if MODE=='capacity' then
    check(nativeCreationCount()==0,'native_receiver_empty')
    local ok,result=pcall(LSUtil.getOrCreateFluidContainer,NATIVE_ENTITY,{false,12.5})
    check(ok,'supplied_capacity_original_branch')
    check(nativeCreationCount()==1 and nativeFluidCapacity()==12.5,'native_capacity_applied')
    check(result==LSUtil.getFluidContainer(NATIVE_ENTITY),'actual_native_fluid_identity')
    local same=LSUtil.getOrCreateFluidContainer(NATIVE_ENTITY,{false,99})
    check(same==result and nativeFluidCapacity()==12.5 and nativeCreationCount()==1,'existing_fluid_unchanged')
    check(LSUtil.getOrCreateFluidContainer(nil,{false,2})==false,'nil_entity_refused')
    nativeRemoveFluid()
    local fresh=LSUtil.getOrCreateFluidContainer(NATIVE_ENTITY,{false,3})
    check(fresh~=nil and nativeFluidCapacity()==3 and nativeCreationCount()==2,'fresh_native_recreation')
elseif MODE=='loop' then
    for cycle=1,2 do
        local stopped=EMITTER.stops
        LSUtil.playSoundCharacter(SOUND_BODY,'controlled-sound',false,3,true,false,false,false)
        check(eventCount('EveryOneMinute')==2,'loop_registered')
        emit('EveryOneMinute');emit('EveryOneMinute')
        check(eventCount('EveryOneMinute')==2 and EMITTER.stops==stopped,'loop_actual_intermediate')
        emit('EveryOneMinute')
        check(eventCount('EveryOneMinute')==1,'loop_retired')
        check(EMITTER.stops==stopped+1,'loop_original_cleanup')
        emit('EveryOneMinute')
        check(EMITTER.stops==stopped+1,'loop_duplicate_no_effect')
    end
    check(FOLLOWER_HITS==8,'loop_follower_preserved')
elseif MODE=='delay' then
    for cycle=1,2 do
        local starts=EMITTER.starts
        local id=LSUtil.playSoundCharacter(SOUND_BODY,'controlled-sound',false,false,true,false,{false,false,'next-sound'},false)
        EMITTER.playing[id]=false
        check(eventCount('OnTick')==2,'delay_registered')
        for i=1,29 do emit('OnTick') end
        check(eventCount('OnTick')==2 and EMITTER.starts==starts+1,'delay_actual_intermediate')
        emit('OnTick')
        check(eventCount('OnTick')==1,'delay_retired')
        check(EMITTER.starts==starts+2,'delay_original_sound_dispatch')
        emit('OnTick')
        check(EMITTER.starts==starts+2,'delay_duplicate_no_effect')
    end
    check(FOLLOWER_HITS==62,'delay_follower_preserved')
elseif MODE=='text' then
    check(nativeCurrencyCount('Base.SilverCoin')==0,'actual_native_insufficient_currency')
    local action=ProjectArcade_PunchingTimedAction:new(TEXT_BODY,OBJECT,1,'Base.SilverCoin',false)
    local ok=pcall(function() action:start() end)
    check(ok,'native_refusal_text_branch')
    local expected=getText('ContextMenu_ProjectArcade_NotEnoughCoins')
    check(expected~='ContextMenu_ProjectArcade_NotEnoughCoins' and TEXT_BODY.words[1]==expected,'actual_native_translated_refusal')
    check(action.paid==false and action.maxTime==0 and action.useProgressBar==false,'refusal_no_paid_success')
    check(QUEUE.completed==1 and QUEUE.last==action,'original_base_perform_called')
    check(nativeCurrencyCount('Base.SilverCoin')==0,'refusal_no_currency_effect')
end
PROVEN=true
