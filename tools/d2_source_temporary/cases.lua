if MODE=='vanilla' or MODE=='new' then
 local source=MODE=='vanilla' and VanillaInstrumentsContextMenu or NewInstrumentsContextMenu
 local kindA=MODE=='vanilla' and 'Base.Banjo' or 'Lifestyle.Harmonica'
 local kindB=MODE=='vanilla' and 'Base.Flute' or 'Lifestyle.Harmonica'
 local instrumentA,itemB=item(kindA),item(kindB);instrumentA.owner='A';itemB.owner='B'
 local catA=CATALOGUES['TimedActions/Play'..(MODE=='vanilla' and 'Banjo' or 'Harmonica')..'Tracks']
 local catB=CATALOGUES['TimedActions/Play'..(MODE=='vanilla' and 'Flute' or 'Harmonica')..'Tracks']
 local tracksA=pick(catA,0);local tracksB=pick(catB,2)
 A.data.BanjoLearnedTracks=tracksA;B.data.FluteLearnedTracks=tracksB
 A.data.HarmonicaLearnedTracks=tracksA;B.data.HarmonicaLearnedTracks=tracksB
 local menuA,menuB=menu(),menu()
 -- Controlled reentrant host callback while original actor A is forming its random option.
 local function reenter(key)
  if string.find(key,'ContextMenu_Play_Random_') then source.doBuildMenu(1,menuB,{},itemB,kindB)else HOOK=reenter end
 end
 HOOK=reenter;source.doBuildMenu(0,menuA,{},instrumentA,kindA)
 local optionA=findOption(menuA,'ContextMenu_Play_Random_'..(MODE=='vanilla' and 'Banjo' or 'Harmonica'))
 local optionB=findOption(menuB,'ContextMenu_Play_Random_'..(MODE=='vanilla' and 'Flute' or 'Harmonica'))
 check(optionA and optionB,'both_source_menus_exist')
 check(optionA.args[1]==A and optionA.args[2]==instrumentA and optionA.args[4]==tracksA[1].sound and optionA.args[5]==tracksA[1].length*48,'actor_A_original_callback_payload')
 check(optionB.args[1]==B and optionB.args[2]==itemB and optionB.args[4]==tracksB[1].sound and optionB.args[5]==tracksB[1].length*48,'actor_B_original_callback_payload')
 optionA.callback(optionA.object,unpack(optionA.args));optionB.callback(optionB.object,unpack(optionB.args))
 check(#QUEUED==2 and QUEUED[1].body==A and QUEUED[1].sound==tracksA[1].sound and QUEUED[2].body==B and QUEUED[2].sound==tracksB[1].sound,'original_onAction_receiver_custody')
 check(QUEUED[1].length==tracksA[1].length*48 and QUEUED[2].length==tracksB[1].length*48,'original_source_duration_unchanged')
 check(randomNumber==nil and randomTrack==nil and Length==nil and contextMenu==nil and Type==nil,'no_menu_temporary_globals')
elseif MODE=='danceTime' then
 local a=PlayerIsDancingToMusic:new(A,0);local b=PlayerIsDancingToMusic:new(B,0)
 AnimTime=0;a.AnimTime=17;b.AnimTime=89;a:update();b:update();a:update()
 check(a.AnimDelayEnd==17 and b.AnimDelayEnd==89,'dance_per_actor_delay')
 check(#A.metabolic==2 and #B.metabolic==1,'original_metabolic_dispatch_each_body')
 a.AnimTime=0;a.AnimDelayEnd=120;AnimTime=999;a:update()
 check(a.AnimDelayEnd==120,'zero_source_time_preserves_previous_delay')
 a.actionType='partner';a:update();check(a.AnimDelayEnd==40,'original_non_solo_delay_preserved')
 check(AnimTime==999,'ambient_time_untouched')
elseif MODE=='danceHands' then
 local a=PlayerIsDancingToMusic:new(A,'solo');local b=PlayerIsDancingToMusic:new(B,'solo')
 A.secondary=A.primary
 local function setup(action)
  action.setOverrideHandModels=function()end;action.setActionAnim=function()end;action.action={setUseProgressBar=function()end}
 end
 setup(a);setup(b);a:start();b:start()
 check(A.queries[1].item==A.primary and B.queries[1].item==B.primary,'dance_owned_primary_argument')
 check(a.handItemP==A.primary and a.handItemS==0,'same_item_both_hands_not_double_captured')
 check(b.handItemP==B.primary and b.handItemS==B.secondary,'distinct_hand_capture_preserved')
 check(a.handItemP~=b.handItemP and A.data.IsDancingFull and B.data.IsDancingFull,'independent_source_actor_state')
 a:perform();check(A.data.IsDancingFull==false and B.data.IsDancingFull==true,'original_perform_only_actor_A')
 b:perform();check(B.data.IsDancingFull==false and QUEUE.completed==2,'original_perform_actor_B_and_queue')
 check(handItemP==nil,'no_ambient_hand_created')
elseif MODE=='server' then
 check(nativeEventCount('OnClientCommand')==1,'actual_native_command_subscription')
 local objA=object('Sculpture',10,'A');local objB=object('Sculpture',20,'B')
 SCENES['10:10:0']=square({objA});SCENES['20:10:0']=square({objB})
 objSpriteName='foreign-source-sentinel'
 emitServer('RemoveObject',A,{10,10,0,'A'});emitServer('RemoveObject',B,{20,10,0,'B'})
 check(SERVER_REMOVED[1]==objA and SERVER_REMOVED[2]==objB,'native_event_original_source_target_selection')
 check(objSpriteName=='foreign-source-sentinel','lookup_name_not_global')
 local juke=object('Jukebox',30,'JukeA');SCENES['30:10:0']=square({juke});SCENES['40:10:0']=square({})
 JukeboxLightOn=true
 emitServer('JukeTurnedOn',A,{'disco',30,10,0,'juke-A','beforeplay'});check(CELL_READS==1,'first_original_juke_receiver')
 emitServer('JukeTurnedOn',B,{'disco',40,10,0,'missing-B','beforeplay'})
 check(CELL_READS==1,'missing_second_source_cannot_borrow_first_jukebox')
 check(Jukebox==nil and spriteName==nil,'per_command_selection_not_global')
 check(JukeboxLightOn==true,'shared_light_state_preserved')
elseif MODE=='dj' then
 local centre=object('Booth',10,'ls_djbooth_01_1');local left=object('Booth',9,'ls_djbooth_01_0');local right=object('Booth',11,'ls_djbooth_01_2')
 local sq=square({centre,left,right});SCENES['10:10:0']=sq;centre.getSquare=function()return sq end
 local ma,mb=menu(),menu();DJBoothMenu.doBuildMenu(0,ma,{centre});DJBoothMenu.doBuildMenu(1,mb,{centre})
 local oa=findOption(ma,'ContextMenu_Play_DJBooth');local ob=findOption(mb,'ContextMenu_Play_DJBooth')
 check(oa and ob and oa.notAvailable and ob.notAvailable,'original_headphone_requirements_each_actor')
 check(oa.toolTip.description==' <RED>ContextMenu_Play_DJBooth_NoHeadPhone' and ob.toolTip.description==oa.toolTip.description,'source_refusal_labels_preserved')
 check(description==nil,'DJ_per_call_refusal_label_not_global')
 -- Actual source supported headset makes options available; no source rule bypass.
 local headset={getType=function()return 'Hat_EarMuff_Protectors' end};A.getInventory=function()return {getItems=function()return list({headset})end}end
 local playable=menu();DJBoothMenu.doBuildMenu(0,playable,{centre})
 for _,mode in ipairs({'Slow','Medium','Fast'})do local row=findOption(playable,'ContextMenu_Play_DJBooth_'..mode);check(row and row.args[1]==A and row.args[2]==centre and row.callback==DJBoothMenu.onPlay,'original_DJ_callback_'..mode)end
 local actualHouseMix=false;for _,row in ipairs(CATALOGUES['TimedActions/PlayDJBoothTracks'])do if row.mode=='housemix'then actualHouseMix=true end end
 check((findOption(playable,'ContextMenu_Play_DJBooth_HouseMix')~=nil)==actualHouseMix,'HouseMix_exact_installed_catalogue_availability')
 A.getPerkLevel=function()return 2 end;local low=menu();DJBoothMenu.doBuildMenu(0,low,{centre})
 check(findOption(low,'ContextMenu_Play_DJBooth_Medium').toolTip.description==' <RED>ContextMenu_Play_DJBooth_MediumNo' and findOption(low,'ContextMenu_Play_DJBooth_Fast').toolTip.description==' <RED>ContextMenu_Play_DJBooth_FastNo','low_skill_source_labels_preserved')
 check(contextMenu1==nil and contextMenu2==nil and contextMenu3==nil and contextMenu4==nil and descriptionM==nil and descriptionF==nil,'DJ_label_globals_absent')
 check(A.data.WantsToDance and B.data.WantsToDance,'original_per_person_wants_to_dance_preserved')
else error('unknown mode')end
PROVEN=true
