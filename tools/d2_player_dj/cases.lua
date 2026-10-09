local total=0
local function check(name,condition)
    if not condition then error("DJ_PLAYER:"..name) end
    total=total+1
end

__fresh()
local initial=__menu()
check("housemix_conditional",__option(__option(initial,"ContextMenu_Play_DJBooth").submenu,
    "ContextMenu_Play_DJBooth_HouseMix")==nil)
__tracks[#__tracks+1]={mode="housemix",sound="house1",length=200}
local menu=__menu()
local parent=__option(menu,"ContextMenu_Play_DJBooth")
check("menu_no_save_mutation",__player:getModData().WantsToDance==nil)
check("parent_look",parent and parent.iconTexture=="media/ui/djbooth_icon.png")
check("slow_visible",__option(parent.submenu,"ContextMenu_Play_DJBooth_Slow")~=nil)
check("medium_visible",__option(parent.submenu,"ContextMenu_Play_DJBooth_Medium")~=nil)
check("fast_visible",__option(parent.submenu,"ContextMenu_Play_DJBooth_Fast")~=nil)
check("housemix_visible",__option(parent.submenu,"ContextMenu_Play_DJBooth_HouseMix")~=nil)
check("skill_tooltip",__option(parent.submenu,"ContextMenu_Play_DJBooth_Medium").notAvailable
    and __option(parent.submenu,"ContextMenu_Play_DJBooth_Fast").notAvailable)
check("no_dance_toggle_without_saved_choice",#__menu().options==1)
local slow=__option(parent.submenu,"ContextMenu_Play_DJBooth_Slow")
check("source_track_starts",__play(slow)==true and #__queued==2)
local dj=__queued[2]
check("native_action_parameters",dj.kind=="dj" and dj.args[1]==__player and dj.args[2]==__booth
    and dj.args[3]=="slow1" and dj.args[4]=="slow" and dj.args[5]==215*48
    and dj.args[6]==0.01 and dj.args[7]==0.12 and dj.args[8]==0.001
    and dj.args[9]=="Bob_PlayDJDefault" and dj.args[10]==false)
check("explicit_action_initializes_preference",__player:getModData().WantsToDance==true)
check("exact_pending_player_action",DJBoothMenu.playerQueueOwner(__booth)==true
    and DJBoothMenu.playerQueueOwner(__booth,dj)==true
    and DJBoothMenu.playerQueueOwner(__booth,{})==false
    and DJBoothMenu.playerQueueOwner(__left)==false)
check("player_queue_claim_prevents_duplicate",__play(slow)==false and #__queued==2)
__queued={}
check("cancelled_queue_releases_claim",DJBoothMenu.playerQueueOwner(__booth)==false)
menu=__menu()
local disable=__option(menu,"ContextMenu_DancingPartner_Disable_Option")
check("dance_toggle_look",disable and disable.iconTexture=="media/ui/okayNo_icon.png")
disable.args[2](disable.args[1],disable.args[3])
check("dance_toggle_persists",__player:getModData().WantsToDance==false)
local enable=__option(__menu(),"ContextMenu_DancingPartner_Enable_Option")
enable.args[2](enable.args[1],enable.args[3])
check("dance_toggle_can_restore",__player:getModData().WantsToDance==true)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__ownedObject=__booth
check("npc_exact_station_lease",__play(slow)==false and #__queued==0
    and __player:getModData().WantsToDance==nil)
__ownedObject=__left
check("other_station_not_blocked",__play(slow)==true and #__queued==2)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
LS_DJBooth.isPlaying=true
check("existing_physical_player_busy",__play(slow)==false and #__queued==0)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__nights=3;__power=false
check("power_requeried_at_click",__play(slow)==false and #__queued==0)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__headphones=false
check("equipment_requeried_at_click",__play(slow)==false and #__queued==0)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__slotCurrent=false
check("saved_character_binding_requeried",__play(slow)==false and #__queued==0
    and __player:getModData().WantsToDance==nil)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__leftPresent=false
check("booth_assembly_requeried_at_click",__play(slow)==false and #__queued==0)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__mainPresent=false
check("same_native_station_requeried",__play(slow)==false and #__queued==0)

__fresh()
__level=3
local medium=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Medium")
__level=0
check("skill_requeried_at_click",__play(medium)==false and #__queued==0)

__fresh()
check("forged_track_refused",DJBoothMenu.onPlay({},__player,__booth,"slow99","slow")==false
    and #__queued==0)
check("forged_mode_refused",DJBoothMenu.onPlay({},__player,__booth,"slow1","unknown")==false
    and #__queued==0)
check("source_catalog_over_stale_callback_arguments",
    DJBoothMenu.onPlay({},__player,__booth,"slow1","slow",1,999,999,999)==true
    and __queued[2].args[5]==215*48 and __queued[2].args[6]==0.01)

__fresh()
slow=__option(__option(__menu(),"ContextMenu_Play_DJBooth").submenu,"ContextMenu_Play_DJBooth_Slow")
__queueRefusal=true
check("queue_refusal_has_no_choice_or_claim",__play(slow)==false
    and #__queued==1 and __player:getModData().WantsToDance==nil
    and DJBoothMenu.playerQueueOwner(__booth)==false)

__fresh()
__headphones=false
parent=__option(__menu(),"ContextMenu_Play_DJBooth")
check("headphone_denial_look",parent and parent.notAvailable
    and parent.iconTexture=="media/ui/djboothNo_icon.png"
    and parent.toolTip.description==" <RED>ContextMenu_Play_DJBooth_NoHeadPhone")

__fresh()
__player:getModData().LSMoodles.Embarrassed.Value=0.2
parent=__option(__menu(),"ContextMenu_Play_DJBooth")
check("embarrassment_denial_look",parent and parent.notAvailable
    and parent.toolTip.description==" <RED>ContextMenu_Embarrassed")

__fresh()
__ownedObject=__booth
parent=__option(__menu(),"ContextMenu_Play_DJBooth")
check("lease_visible_busy",parent and parent.notAvailable
    and parent.iconTexture=="media/ui/djboothNo_icon.png")

__fresh()
__nights=3;__power=false
check("unpowered_station_absent",#__menu().options==0)

print("PASS SAO player DJ menu "..total)
