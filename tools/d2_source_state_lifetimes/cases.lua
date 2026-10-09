if MODE=='juke'then
 local squares={}
 local function square(x)
  local objects={};local sq={getObjects=function()return list(objects)end,AddTileObject=function(_,v)objects[#objects+1]=v end}
  local md=nativeData();md.OnOff='on';md.savedFact='plain-source-state'
  local props={has=function(_,s)return s=='CustomName'end,get=function()return 'Jukebox'end}
  local jukebox={getSprite=function()return {getProperties=function()return props end,getName=function()return 'Juke'end}end,
   getModData=function()return md end,getX=function()return x end,getY=function()return 10 end,getZ=function()return 0 end,getCell=function()return NATIVE_CELL end,transmitModData=function()end}
  objects[1]=jukebox;squares[x]=sq
  return sq,jukebox,objects,function(value)md=value end
 end
 getCell=function()return {getGridSquare=function(_,x)return squares[x]end}end
 IsoLightSource={new=nativeLight}
 IsoObject={new=function(sq,sprite)local name;return {getSpriteName=function()return sprite end,getSprite=function()return {getName=function()return sprite end,getProperties=function()return {has=function()return false end}end}end,setName=function(_,s)name=s end,getName=function()return name end,transmitModData=function()end}end}
 local sq,A,a,reloadA=square(10);local sqB,B,b=square(20)
 local function on(x)emitServer('JukeTurnedOn',{}, {'source',x,10,0})end
 JukeboxLightOn=nil;on(10);on(20)
 check(nativeLampCount()==2 and #a==2 and #b==2,'distinct_object_native_light_lifetimes')
 local lightA=A:getModData().MainLight;local lightB=B:getModData().MainLight
 check(lightA~=lightB,'native_light_handles_distinct')
 check(JukeboxLightOn==nil,'source_never_creates_shared_light_flag')
 JukeboxLightOn='foreign-sentinel'
 on(10);check(nativeLampCount()==2 and #a==2,'same_object_no_duplicate_light_or_overlay')
 nativeDiscardCellLights();on(10);on(20)
 check(nativeLampCount()==2 and A:getModData().MainLight~=lightA and B:getModData().MainLight~=lightB,'stale_native_cell_handles_require_current_membership')
 lightA=A:getModData().MainLight
 NATIVE_CELL:removeLamppost(lightA);A:getModData().MainLight=false
 on(10);check(nativeLampCount()==2 and A:getModData().MainLight~=lightA and #a==2,'source_stop_then_restart_keeps_overlay_unique')
 local loaded=nativeSaveLoad(A:getModData());check(loaded.MainLight==nil and loaded.savedFact=='plain-source-state','native_save_drops_light_userdata_preserves_plain_state')
 nativeDiscardCellLights();reloadA(loaded);local loadedB=nativeSaveLoad(B:getModData());B:getModData().MainLight=false
 on(10);on(20);check(nativeLampCount()==2 and #a==2 and #b==2,'load_rebuilds_current_lamps_without_saved_flag_authority')
 check(JukeboxLightOn=='foreign-sentinel','ambient_light_flag_never_owned')
 on(999);check(nativeLampCount()==2,'missing_source_no_effect')
elseif MODE=='mirror'then
 local preview=nativeBindPreview();local A=nativeWearer('A');local B=nativeWearer('B');local originalA=nativeMakeup('original-A');local originalB=nativeMakeup('original-B')
 A:setWornItem('Makeup',originalA);B:setWornItem('Makeup',originalB)
 local oldA={foreign='previous'};local oldB=nil;previousMakeUp=oldA;resetPlayerModel=oldB
 local cb=function()end
 INTERLEAVE=function()preview({{item='B-first'},{item='B-second'}},B,cb,1,'FullFace',false,'default')end
 preview({{item='A-first'},{item='A-second'}},A,cb,1,'FullFace',false,'default')
 check(A:getWornItem('Makeup')==originalA and B:getWornItem('Makeup')==originalB,'native_interleaved_preview_restores_each_worn_snapshot')
 check(A:nativeWornCount()==1 and B:nativeWornCount()==1,'native_no_preview_items_retained')
 check(previousMakeUp==oldA and resetPlayerModel==oldB,'preview_transaction_does_not_publish_foreign_state')
 local C=nativeWearer('C');preview({{item='C-single'}},C,cb,1,'FullFace',false,'default')
 check(C:nativeWornCount()==0,'empty_native_worn_snapshot_restored')
 preview({},A,cb,1,'FullFace',false,'default');check(A:getWornItem('Makeup')==originalA,'empty_catalogue_no_worn_change')
 preview({{item='A-next'}},A,cb,1,'FullFace',false,'default');check(A:getWornItem('Makeup')==originalA,'subsequent_preview_owns_fresh_snapshot')
 local function panel(character,prefix)
  local rows={};for i=1,10 do rows[i]={item=prefix..i}end
  return {character=character,pagesTotal=2,currentPage=1,menuSkin='default',makeupList={fullface=rows},onClickMakeupPreview=LSMirrorMenu.onClickMakeupPreview,
   BOarrowUPButton={setEnable=function()end}}
 end
 local pa=panel(A,'public-A');local pb=panel(B,'public-B');local button={internal='Arrow_MakeupFull',setEnable=function()end}
 INTERLEAVE=function()LSMirrorMenu.onClickArrowDOWN(pb,button)end
 LSMirrorMenu.onClickArrowDOWN(pa,button)
 check(pa.currentPage==2 and pb.currentPage==2,'original_public_arrow_callback_invokes_preview_transaction')
 check(A:getWornItem('Makeup')==originalA and B:getWornItem('Makeup')==originalB,'native_public_callback_keeps_independent_original_wear')
elseif MODE=='tub'then
 local function body(id)return {id=id,getInventory=function()return {getSoapList=function()return list({})end,getItems=function()return list({})end}end,
 getHumanVisual=function()return {getBlood=function()return 0 end}end,isTimedActionInstant=function()return false end}end
 local tub={getOverlaySprite=function()return nil end,getModData=function()return {movableData={}}end}
 overlayDirtSpriteSub2='foreign2';overlayDirtSpriteSub3='foreign3'
 local A=body('A');local B=body('B');local a=LSUseTub:new(A,tub,tub,'fixtures_bathroom_01_26','fixtures_bathroom_01_27',true,true,false)
 local b=LSUseTub:new(B,tub,tub,'fixtures_bathroom_01_26','fixtures_bathroom_01_27',true,true,false)
 check(a.overlayDirtSpriteSub2==false and a.overlayDirtSpriteSub3==false,'constructor_owns_both_dirt_fields')
 check(b.overlayDirtSpriteSub2==false and b.overlayDirtSpriteSub3==false,'second_action_owns_independent_dirt_fields')
 a.overlayDirtSpriteSub2='owned-A';check(b.overlayDirtSpriteSub2==false,'action_mutation_cannot_leak_to_peer')
 check(a.character==A and b.character==B and a.maxTime==-1 and b.maxTime==-1,'source_constructor_actor_and_duration_preserved')
 check(overlayDirtSpriteSub2=='foreign2' and overlayDirtSpriteSub3=='foreign3','constructor_never_writes_ambient_dirt_fields')
 local queue={};ISTimedActionQueue={add=function(action)queue[#queue+1]=action end};local prep={new=function(_,character)return {preparationHost=true,character=character}end}
 require=function(name)if name=='TimedActions/LSUseTub'then return LSUseTub end;return prep end
 BathContextMenu.walkToFront=function()return true end
 BathContextMenu.onAction({},A,tub,tub,10,'fixtures_bathroom_01_26','fixtures_bathroom_01_27',false,'IsUse',false)
 check(#queue==2 and queue[2].character==A and queue[2].overlayDirtSpriteSub2==false and queue[2].overlayDirtSpriteSub3==false,'original_bath_caller_constructs_exact_owned_action')
 BathContextMenu.onAction({},B,tub,tub,10,'fixtures_bathroom_01_26','fixtures_bathroom_01_27',false,'IsUse',false)
 check(#queue==4 and queue[4].character==B and queue[4]~=queue[2],'original_bath_caller_retains_separate_action_instances')
 BathContextMenu.walkToFront=function()return false end
 BathContextMenu.onAction({},A,tub,tub,10,'fixtures_bathroom_01_26','fixtures_bathroom_01_27',false,'IsUse',false)
 check(#queue==4,'original_bath_failed_route_does_not_prepare_use')
end
PROVEN=true
