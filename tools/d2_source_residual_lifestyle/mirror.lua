idxStatic=77;useTattoo=false
IsoDirections={S='S',N='N',W='W',E='E'}
local slots={};for i=1,8 do local s={};function s:getTexture()return self.texture end;function s:setVisible(v)self.visible=v end;function s:setEnable(v)self.enabled=v end;function s:setOnClick(callback,...)self.callback=callback;self.onClickArgs={...}end;function s:setCharacter(v)self.character=v;if INTERLEAVE then local fn=INTERLEAVE;INTERLEAVE=nil;fn()end end;function s:setDirection()end;function s:setZoom()end;function s:setYOffset()end;slots[i]=s end
local categories={{'Face_Tattoo','resetMakeupTattooFace'},{'UpperBody_Tattoo','resetMakeupTattooUB'},{'LowerBody_Tattoo','resetMakeupTattooLB'},{'Back_Tattoo','resetMakeupTattooBack'},{'LeftArm_Tattoo','resetMakeupTattooLA'},{'RightArm_Tattoo','resetMakeupTattooRA'},{'LeftLeg_Tattoo','resetMakeupTattooLL'},{'RightLeg_Tattoo','resetMakeupTattooRL'}}
MakeUpDefinitions={makeup={}};local makeup={};for _,c in ipairs(categories)do makeup[c[1]]=nativeMakeup(c[1],c[1]);MakeUpDefinitions.makeup[#MakeUpDefinitions.makeup+1]={category=c[1],item=c[1]}end
function instanceItem(k)return makeup[k]end
local function wearer(id)
 local w=nativeWearer(id);function w:resetModel()end;function w:isFemale()return false end
 local h={hair='original',color='original',beard='original'};function h:getHairModel()return self.hair end;function h:setHairModel(v)self.hair=v end;function h:getBeardModel()return self.beard end;function h:setBeardModel(v)self.beard=v end;function h:getHairColor()return self.color end;function h:setHairColor(v)self.color=v end;function h:getBeardColor()return self.color end;function h:setBeardColor(v)self.color=v end;function w:getHumanVisual()return h end
 return w
end
getBeardStylesInstance=function()return{FindStyle=function()return{getLevel=function()return 1 end}end}end
local wa,wb=wearer('A'),wearer('B');PLAYERS[0]=wa;PLAYERS[1]=wb
local function window(num)
 local needle=nativeNeedle();local w=LSMirrorMenu:new(0,0,500,500,num,{MakeupTattooNeedle=needle},{},{},{},{})
 w.playermodel=slots[1];w.resetSpecificButton=slots[2];w.resetAllButton=slots[3];w.destroy=function(self)self.destroyed=true end
 return w,needle
end
local getMakeup=nativeLocal('MMgetMakeupBottomOptions');local getHair=nativeLocal('MMgetChangeHairBottomOptions');local getDye=nativeLocal('MMgetDyeHairBottomOptions')
nativeSeedUI(getMakeup,slots);nativeSeedUI(getHair,slots);nativeSeedUI(getDye,slots)
getMakeup({{item='Face_Tattoo'}},wa,LSMirrorMenu.onClickMakeupPreview,1,'Face_Tattoo',false,'LSSims');check(slots[1].onClickArgs[3]==1,'mirror_single_makeup_slot_one');check(wa:nativeWornCount()==0,'mirror_preview_restores_native_absence')
getHair({{getName=function()return 'newhair' end}},wa,LSMirrorMenu.onClickChangeHairPreview,1,false,'LSSims');check(slots[1].onClickArgs[3]==1,'mirror_single_hair_slot_one');check(wa:getHumanVisual():getHairModel()=='original','mirror_hair_preview_restore')
local color={getR=function()return 1 end,getG=function()return 0 end,getB=function()return 0 end};local dye={getFluidContainer=function()return{getColor=function()return color end}end}
getDye({dye},wa,LSMirrorMenu.onClickDyeHairPreview,1,false,'LSSims');check(slots[1].onClickArgs[3]==1,'mirror_single_dye_slot_one');check(wa:getHumanVisual():getHairColor()=='original','mirror_dye_preview_restore')
for _,c in ipairs(categories)do
 local w,needle=window(0);wa:removeWornItem(makeup[c[1]]);local before=needle:getCurrentUsesFloat()
 w:onClickMakeupPreview({onClickArgs={makeup[c[1]],c[1],1,false}});check(w[c[2]]==nil,'mirror_actual_source_captures_absent_'..c[1]);check(wa:getWornItem(makeup[c[1]]:getBodyLocation())==makeup[c[1]],'mirror_actual_native_worn_'..c[1]);w:onConfirmChanges({});check(needle:getCurrentUsesFloat()<before,'mirror_native_needle_consumed_'..c[1]);check(w[c[2]]==0 and w.destroyed,'mirror_confirmation_reset_'..c[1]);wa:removeWornItem(makeup[c[1]])
end
local w,n=window(0);local other,otherNeedle=window(1);local before=n:getCurrentUsesFloat();local otherBefore=otherNeedle:getCurrentUsesFloat()
w:onClickMakeupPreview({onClickArgs={makeup.Face_Tattoo,'Face_Tattoo',1,false}});other:onConfirmChanges({});check(near(otherNeedle:getCurrentUsesFloat(),otherBefore) and near(n:getCurrentUsesFloat(),before),'mirror_two_instances_unchanged_owner')
w:onConfirmChanges({});check(n:getCurrentUsesFloat()<before and near(otherNeedle:getCurrentUsesFloat(),otherBefore),'mirror_selected_instance_consumption');wa:removeWornItem(makeup.Face_Tattoo)
local untouched,untouchedNeedle=window(0);before=untouchedNeedle:getCurrentUsesFloat();untouched:onConfirmChanges({});check(near(untouchedNeedle:getCurrentUsesFloat(),before),'mirror_no_preview_no_charge')
local undone,undoNeedle=window(0);before=undoNeedle:getCurrentUsesFloat();undone:onClickMakeupPreview({onClickArgs={makeup.Face_Tattoo,'Face_Tattoo',1,false}});undone:onResetChange({internal='resetMakeupTattooFace'});undone:onConfirmChanges({});check(near(undoNeedle:getCurrentUsesFloat(),before) and wa:nativeWornCount()==0,'mirror_undone_no_charge')
local original=nativeMakeup('original','Face_Tattoo');wa:setWornItem(original:getBodyLocation(),original);local same,sameNeedle=window(0);before=sameNeedle:getCurrentUsesFloat();same:onClickMakeupPreview({onClickArgs={original,'Face_Tattoo',1,false}});same:onConfirmChanges({});check(near(sameNeedle:getCurrentUsesFloat(),before),'mirror_same_item_no_charge');wa:removeWornItem(original)
local ra,na=window(0);local rb,nb=window(1);local ua,ub=na:getCurrentUsesFloat(),nb:getCurrentUsesFloat();INTERLEAVE=function()rb:onClickMakeupPreview({onClickArgs={makeup.Back_Tattoo,'Back_Tattoo',1,false}})end;ra:onClickMakeupPreview({onClickArgs={makeup.Face_Tattoo,'Face_Tattoo',1,false}});check(ra.resetMakeupTattooFace==nil and rb.resetMakeupTattooBack==nil,'mirror_reentrant_instance_baselines');rb:onConfirmChanges({});ra:onConfirmChanges({});check(na:getCurrentUsesFloat()<ua and nb:getCurrentUsesFloat()<ub,'mirror_reentrant_native_needles');wa:removeWornItem(makeup.Face_Tattoo);wb:removeWornItem(makeup.Back_Tattoo)
check(idxStatic==77 and useTattoo==false,'mirror_foreign_globals_preserved');PROVEN=true
