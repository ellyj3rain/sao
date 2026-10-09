if MODE=='activate' then
 check(nativeEventCount('OnEquipPrimary')==1,'original_equip_callback_registered')
 check(data==nil,'no_borrowed_data')
 NATIVE_VISUAL:setTextureChoice(0)
 local ok,err=pcall(LSInv.OnActivateNeuralHat,BODY,ITEM,3)
 check(ok,'item_local_activation')
 check(NATIVE_VISUAL:getTextureChoice()==3,'native_active_texture')
 check(ITEM.synced==1 and BODY.resets==1,'original_visual_sync_and_model')
 HAT_DATA.movableData.inventionData.fuelUses=0
 LSInv.OnActivateNeuralHat(BODY,ITEM,4)
 check(NATIVE_VISUAL:getTextureChoice()==0,'empty_fuel_off_texture')
 check(ITEM.synced==2 and BODY.resets==2,'empty_original_sync')
 HAT_DATA.movableData.inventionData.fuelUses=8
 BODY.worn=false;LSInv.OnActivateNeuralHat(BODY,ITEM,4)
 check(ITEM.synced==2,'unworn_guard')
 BODY.worn=true;LSInv.OnActivateNeuralHat(FOREIGN,ITEM,4)
 check(ITEM.synced==2,'foreign_wear_guard')
 SERVER=true;LSInv.OnActivateNeuralHat(BODY,ITEM,4)
 check(ITEM.synced==2,'server_only_guard')
 SERVER=false;CLIENT=true;LSInv.OnActivateNeuralHat(BODY,ITEM,1)
 check(NATIVE_VISUAL:getTextureChoice()==1 and ITEM.synced==2,'client_texture_without_local_sync')
 check(#SYNC.commands==1 and SYNC.commands[1][1]==BODY and SYNC.commands[1][4][1]==731 and SYNC.commands[1][4][2]==1,'original_client_texture_command')
 check(data==nil,'no_global_data_created')
elseif MODE=='press' then
 check(character==nil,'no_borrowed_character')
 NATIVE_VISUAL:setTextureChoice(3)
 local root=menu();local parent=menu();local inv=HAT_DATA.movableData.inventionData
 InventionsMenu.NeuralHat(root,parent,BODY,ITEM,HAT_DATA.movableData,'NeuralHat')
 check(#parent.options==2 and #parent.submenus==1,'original_menu_produced_overdrive')
 local off=parent.submenus[1].options[1]
 check(off.name=='ContextMenu_InvNeuralHat_Overdrive_Off' and not off.notAvailable,'original_overdrive_off_option')
 off.callback(off.item,unpack(off.args))
 check(#QUEUE.actions==1,'original_option_enqueued_source_action')
 local action=QUEUE.actions[1]
 check(action.character==BODY and action.item==ITEM and action.invData==inv and action.current==3 and action.target==1,'source_constructor_custody')
 check(action:isValid() and action.maxTime==160,'source_prerequisites_duration')
 local before=#EMITTER.sounds
 local ok,err=pcall(action.perform,action)
 check(ok,'action_owned_character_sound')
 check(#EMITTER.sounds==before+1 and EMITTER.sounds[#EMITTER.sounds][1]=='Gadget_WOOSH','original_utility_dispatched_sound')
 check(math.abs(EMITTER.pitches[#EMITTER.sounds]-0.3)<0.00001,'original_source_pitch')
 check(#FOREIGN_EMITTER.sounds==0,'foreign_emitter_untouched')
 check(inv.recentActive==2 and SYNC.items==1 and SYNC.item==ITEM and SYNC.data==inv,'original_state_and_item_sync')
 check(QUEUE.completed==1 and QUEUE.last==action and BODY.farming==false,'original_base_perform')
 check(NATIVE_VISUAL:getTextureChoice()==1 and ITEM.synced==0 and BODY.resets==1,'original_perform_visual_and_model_before_complete')
 check(action:complete()==true and NATIVE_VISUAL:getTextureChoice()==1 and ITEM.synced==1,'original_complete_native_visual')
 check(character==nil,'no_global_character_created')
 -- The other original power branch remains intact.
 local power=LSInvNeuralHatPress:new(BODY,ITEM,inv,0,1);power:perform()
 check(inv.running==false and EMITTER.sounds[#EMITTER.sounds][1]=='FortuneTeller_PowerDown','power_branch_retained')
 inv.isBroken=true;check(not power:isValid(),'broken_prerequisite_retained');inv.isBroken=false
 BODY.busy=true;local blocked=menu();InventionsMenu.NeuralHat(blocked,blocked,BODY,ITEM,HAT_DATA.movableData,'NeuralHat')
 check(#blocked.options==0,'busy_menu_refusal')
elseif MODE=='melt' then
 OBJECTS[1]=ICE
 check(obj==nil,'no_borrowed_removal_object')
 LSrefreshIO(BODY)
 check(NATIVE_ICE_DATA.movableData.meltStartTime==24000 and #WORLD_EMITTER.sounds==0,'original_initial_melt_time')
 NATIVE_ICE_DATA.movableData.meltStartTime=1;TEMPERATURE=-1;LSrefreshIO(BODY)
 check(NATIVE_ICE_DATA.movableData.meltStartTime==1 and REMOVALS.remove==0,'native_data_freezing_rate')
 TEMPERATURE=20
 local ok,err=pcall(LSrefreshIO,BODY)
 check(ok and REMOVALS.removed==ICE and #OBJECTS==0,'exact_supplied_sculpture_removed')
 check(REMOVALS.transmit==1 and REMOVALS.transmitted==ICE and REMOVALS.remove==1,'original_removal_transmit')
 check(REMOVALS.puddle==1 and REMOVALS.puddleObject==ICE,'original_puddle_effect')
 check(WORLD_EMITTER.sounds[1][1]=='Toilet_Flush_Clogged' and WORLD_EMITTER.sounds[1][2]==ICE,'original_melt_source_sound')
 check(NATIVE_ICE_DATA.movableData.meltStartTime==false and SYNC.objects==2,'source_native_moddata_terminal')
 LSrefreshIO(BODY);check(REMOVALS.remove==1 and REMOVALS.puddle==1,'removed_object_not_redispatched')
 -- Original client path dispatches removal without local square mutation.
 OBJECTS[1]=ICE;CLIENT=true;NATIVE_ICE_DATA.movableData.meltStartTime=1;LSrefreshIO(BODY)
 check(REMOVALS.remove==1 and #SYNC.commands==1 and SYNC.commands[1][2]=='RemoveObject','source_client_removal_command')
 check(SYNC.commands[1][3][1]==10 and SYNC.commands[1][3][4]=='LS_Sculpture_0','source_client_object_identity')
 check(obj==nil,'no_global_object_created')
else error('unknown mode') end
PROVEN=true
