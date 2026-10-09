if MODE=='helper' then
 foreign({'description'});function isClient()return true end;function instanceof()return true end
 function A:getUsername()return 'A' end;function B:getUsername()return 'B' end
 function A:isOutside()return true end;function B:isOutside()return true end
 function A:CanSee()return true end;function A:checkCanSeeClient()return true end
 function B:hasTimedActions()return true end
 LSMPS={getOtherPlayerInfo=function()return{known=true}end}
 local sq={getMovingObjects=function()return list({B})end};local obj={getSquare=function()return sq end};local m=menu()
 local actor,available=CanSeeTargetPlayer({obj},0,m)
 check(actor==B and available==false and m.options[1].notAvailable,'source_interaction_refusal')
 check(m.options[1].toolTip.description==' <RED>Tooltip_LSMP_CantInteract','source_interaction_refusal_label');preserved({'description'})
elseif MODE=='shower' or MODE=='bath' then
 foreign({'description','descriptionC'});LSUtil.objHasWater=function()return false end
 local obj={data={},getFluidAmount=function()return 2 end};function obj:getModData()return self.data end
 local bottom={data={},getModData=function(self)return self.data end,getSprite=function()return{getName=function()return 'fixtures_bathroom_01_24' end,getProperties=function()return{has=function()return true end,get=function(_,key)return key=='GroupName' and 'Large Deluxe' or 'Bath' end}end}end}
 local sq={getObjects=function()return list({bottom})end};function sq:getAdjacentSquare()return self end;obj.getSquare=function()return sq end
 local m=menu();if MODE=='shower' then ShowerContextMenu.doBuildMenu(0,m,{obj},obj,'fixture','Shower','Common',m)else BathContextMenu.doBuildMenu(0,m,{obj},obj,'fixtures_bathroom_01_25','Bath','Large Deluxe',m)end
 check(m.options[1].notAvailable and m.options[1].toolTip.description==' <RED>Tooltip_Shower_NoWater','source_water_refusal');preserved({'description','descriptionC'})
elseif MODE=='cabinet' then
 foreign({'descriptionBT'});CabinetContextMenu.doMirrorOptions=function()end;CabinetContextMenu.doMirrorOptionAppearance=function()end
 local m=menu();CabinetContextMenu.doBuildMenu(0,m,{}, {},'fixture','Cabinet','Medicine',m,{})
 check(m.options[1].notAvailable and m.options[1].toolTip.description==' <RED>Tooltip_H_BrushTeethNoItem','source_cabinet_missing_items_refusal')
 check(m.options[1].args[1]==A,'source_cabinet_actor_custody');preserved({'descriptionBT'})
elseif MODE=='mirror' then
 foreign({'description','descriptionBT'});A.data.lastBrushTeeth=0
 local m=menu();MirrorContextMenu.doMirrorBrushTeethOption({},m,A,{},'Common',{}, {})
 check(m.options[1].notAvailable and m.options[1].toolTip.description==' <RED>Tooltip_H_BrushTeethNoItem','source_mirror_missing_items_refusal')
 A.hasTimedActions=function()return true end;local info=menu();MirrorContextMenu.doBuildMenu(0,info,{}, {},'fixture','Mirror','Common',info,{})
 check(info.options[1].toolTip.description=='Tooltip_Sit_Beauty <RGB:1,1,0>0.1','source_mirror_info_label');preserved({'description','descriptionBT'})
elseif MODE=='yoga' then
 foreign({'objAdjSqr'});local f=nativeLocal('getYogaMat')
 local mat={getSpriteName=function()return 'floors_rugs_01_52' end};local paired={getSpriteName=function()return 'floors_rugs_01_53' end}
 local adjacent={getObjects=function()return list({paired})end};local sq={getObjects=function()return list({mat})end,getE=function()return adjacent end}
 A.getSquare=function()return sq end;B.getSquare=function()return nil end
 check(f(A)==paired and f(B)==false,'source_yoga_exact_adjacent_mat');preserved({'objAdjSqr'})
elseif MODE=='jukebox' then
 foreign({'option'});local f=nativeLocal('doMusicOptions');setmetatable(CATALOGUES,{__index=function(_,name)return{{sound=name,genre=name}}end})
 local a,b=menu(),menu();local ja,jb={},{};f(A,a,a,ja,'switch',false,true);f(B,b,b,jb,'switch',false,true)
 check(#a.children[1].options==15 and #b.children[1].options==15,'source_jukebox_all_genres')
 check(a.children[1].options[1].object==A and a.children[1].options[1].args[1]==ja and b.children[1].options[1].object==B and b.children[1].options[1].args[1]==jb,'two_actor_jukebox_callback_custody');preserved({'option'})
elseif MODE=='sculpt' then
 foreign({'missingItems'});local station={data={style='Wood',stage=1,author='Foreign'}}
 function station:getModData()return self.data end;function station:hasModData()return true end
 local m=menu();SculptingWorkContextMenu.doBuildMenu(0,m,{},station,'fixture','Station','Sculpt',m)
 check(#m.options==2 and m.options[2].args[1]==A and m.options[2].args[2]==station,'source_sculpt_actor_station_custody')
 check(m.options[2].notAvailable,'source_sculpt_foreign_author_refusal');preserved({'missingItems'})
elseif MODE=='explorer' then
 ISWorldMap.IsAllowed=function()return true end
 A.getX=function()return 10 end;A.getY=function()return 10 end
 ISWorldMap.new=function()local m={symbolsUI={},mapAPI={resetView=function()end,centerOn=function()end,setZoom=function()end}};setmetatable(m,{__index=function()return function()end end});return m end
 local reveal=nativeLocal('doRevealMap');ISWorldMap_instance=nil;reveal(A,{})
 check(ISWorldMap_instance==nil,'source_defers_until_native_publication')
 local seen={};local engineMap={setHideUnvisitedAreas=function(_,value)seen[#seen+1]=value end};ISWorldMap_instance=engineMap
 reveal(A,{});reveal(A,{})
 check(ISWorldMap_instance==engineMap,'engine_worldmap_identity_preserved')
 check(#seen==2 and seen[1]==false and seen[2]==true,'source_reveal_toggle_on_native_owner')
elseif MODE=='perfume' then
 local names={'description'};foreign(names)
 local item={getFluidContainer=function()return{getPrimaryFluid=function()return{getFluidTypeString=function()return 'Perfume' end}end,getAmount=function()return 1 end}end}
 local ma,mb=menu(),menu();B.data.LSMoodles.SmellGood.Value=1
 HOOK=function()PerfumeContextMenu.doInventoryMenu(1,mb,{},item)end
 PerfumeContextMenu.doInventoryMenu(0,ma,{},item)
 check(ma.options[1].args[1]==A and mb.options[1].args[1]==B,'two_actor_perfume_payload')
 check(ma.options[1].toolTip.description=='Tooltip_H_PerfumeUse' and mb.options[1].toolTip.description==' <RED>Tooltip_H_PerfumeMax','perfume_source_refusal_labels')
 check(not ma.options[1].notAvailable and mb.options[1].notAvailable,'source_perfume_effect_limit')
 preserved(names)
elseif MODE=='sheet' then
 local names={'contextMenu','description','descriptionR','descriptionBO'};foreign(names)
 local ma,mb=menu(),menu();local ba,bb={},{};local penA,penB={},{}
 local ta,tb={{name='SongA',level=2,isaddon=0}},{{name='SongB',level=3,isaddon=0}}
 HOOK=function()MusicSheetBookContextMenu.doSubMenus('Flute','flute','flute',mb,mb,B,tb,{InscribedSongs={}},bb,penB)end
 MusicSheetBookContextMenu.doSubMenus('Banjo','banjo','banjo',ma,ma,A,ta,{InscribedSongs={}},ba,penA)
 local oa=ma.children[1].options[1];local ob=mb.children[1].options[1]
 check(oa.name=='SongA' and ob.name=='SongB','source_sheet_song_labels')
 check(oa.args[1]==A and oa.args[2]==ba and oa.args[4]==ta[1] and oa.args[6]==penA,'sheet_actor_A_callback_custody')
 check(ob.args[1]==B and ob.args[2]==bb and ob.args[4]==tb[1] and ob.args[6]==penB,'sheet_actor_B_callback_custody')
 preserved(names)
elseif MODE=='ghost' then
 foreign({'_'});local render=NMSlotGhostOverlay.render;local seen={}
 NMSlotGhostManager={getActiveDrag=function()return 'gesture',{moved=true,iconTex='one'}end}
 local panel={drawTextureScaledAspect=function(_,texture)seen[#seen+1]=texture end}
 render(panel);NMSlotGhostManager.getActiveDrag=function()return 'gesture2',{moved=true,iconTex='two'}end;render(panel)
 check(#seen==2 and seen[1]=='one' and seen[2]=='two','discard_preserves_outer_drag_payload');preserved({'_'})
elseif MODE=='plush' then
 foreign({'moodList'});A.getInventory=function()return{getItemCount=function()return 1 end}end;B.getInventory=function()return{getItemCount=function()return 0 end}end
 LSAmbtMng.LSPlushies(A,{completed=true,isActive=true});local first=LSMoodHandler.PerMin.Unhappiness[1]
 LSAmbtMng.LSPlushies(B,{completed=true,isActive=true})
 check(first==-0.27 and LSMoodHandler.PerMin.Unhappiness[1]==first,'source_plush_effect_from_actual_inventory');preserved({'moodList'})
elseif MODE=='piano' then
 foreign({'t'});local f=nativeLocal('getOptionLevelList')
 check(f(2)=='Experienced' and f(8)=='Advanced','source_piano_level_groups');preserved({'t'})
elseif MODE=='hour' then
 foreign({'t','severity'});local f=nativeLocal('HNgetColdSeverity')
 SandboxVars.LSHygiene.ColdSeverity=1;check(f()==5,'source_cold_severity_one');SandboxVars.LSHygiene.ColdSeverity=4;check(f()==20,'source_cold_severity_four');preserved({'t','severity'})
elseif MODE=='interaction' then
 foreign({'doTimedAction','otherPlayer'});local queued={};local once=true
 CATALOGUES.Alpha={new=function(_,src,actor,args)return{kind='Alpha',actor=actor}end};CATALOGUES.Beta={new=function(_,src,actor,args)return{kind='Beta',actor=actor}end}
 ISTimedActionQueue={clear=function()if once then once=false;EndInteractionAlone(false,B,'Beta',{})end end,add=function(action)queued[#queued+1]=action end}
 EndInteractionAlone(false,A,'Alpha',{})
 check(#queued==2 and queued[1].kind=='Beta' and queued[1].actor==B and queued[2].kind=='Alpha' and queued[2].actor==A,'reentrant_action_class_custody');preserved({'doTimedAction','otherPlayer'})
elseif MODE=='aquarium-placement' then
 check(KnoxAquarium.ensurePlacementClass()==nil and KAPlacement==nil,'placement_waits_for_gameplay_base')
 ISBuildingObject=ISBaseObject:derive('ControlledBuildingHost')
 local c=KnoxAquarium.ensurePlacementClass();check(c and c==KAPlacement and c==KnoxAquarium.ensurePlacementClass(),'placement_exact_memoized_publisher')
 check(type(c.tryBuild)=='function' and type(c.rotateKey)=='function','source_placement_native_callback_methods')
elseif MODE=='aquarium-overlay' then
 check(KnoxAquarium.ensureOverlayClass()==nil and KAWheelOverlay==nil,'overlay_waits_for_gameplay_base')
 ISPanel=ISBaseObject:derive('ControlledPanelHost')
 local c=KnoxAquarium.ensureOverlayClass();check(c and c==KAWheelOverlay and c==KnoxAquarium.ensureOverlayClass(),'overlay_exact_memoized_publisher')
 check(type(c.render)=='function' and type(c.hoveredSlice)=='function','source_overlay_callback_methods')
elseif MODE=='computer-event' then
 ComputerModInstallUIState({});local first=ComputerModGameMoodEventHandler;check(type(first)=='function' and nativeEventCount('OnPlayerUpdate')==1,'native_event_once')
 ComputerModInstallUIState({});check(ComputerModGameMoodEventHandler~=first and nativeEventCount('OnPlayerUpdate')==1,'reload_rebinds_handler_without_duplicate_event')
 local hits=0;ComputerModGameMoodEventHandler=function(actor)check(actor==A,'actual_native_event_actor');hits=hits+1 end
 nativeEmitPlayer(A);nativeEmitPlayer(A);check(hits==2,'native_event_reads_current_handler')
elseif MODE=='globalmusic' then
 check(GlobalMusic==REGISTRY and GlobalMusic.Foreign=='preserved','source_music_registry_identity')
 check(GlobalMusic.tsarcraft_music_01_62=='nm_carrier_cassette','source_music_legacy_normalization')
 NMMediaContract.registerMediaTypeAlias('OwnSong','tsarcraft_music_01_64');check(GlobalMusic.OwnSong=='nm_carrier_cd','source_carrier_alias_consumer')
 nativeReload(1);nativeReload(2);nativeReload(3);check(GlobalMusic==REGISTRY and GlobalMusic.Foreign=='preserved' and GlobalMusic.OwnSong=='nm_carrier_cd','music_repeat_bootstrap_preserves_foreign_rows')
elseif MODE=='recmedia' then
 check(RecMedia==REGISTRY,'engine_recording_registry_identity')
 for key,row in pairs(NATIVE_ROWS)do check(RecMedia[key]==row,'native_recording_row_'..key)end
 check(RecMedia.DancingTraining01 and RecMedia.ArtTraining06,'source_recordings_added')
 nativeReload(1);check(RecMedia==REGISTRY and RecMedia.ArtTraining06,'recording_repeat_bootstrap_identity')
else error('unknown source mode '..MODE)end
PROVEN=true
