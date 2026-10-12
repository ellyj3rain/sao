local function check(k,v)__check(k,v==true)end
local R,A=SAO.FurnitureRelocation,SAO.FurnitureRelocationAction
for _,family in ipairs({'single','grid','linked'})do for _,filled in ipairs({false,true})do
 __fixture(family,filled)
 local label=family..(filled and '_filled' or '_empty')
 local source=__objects[1];local destination=__cell:getGridSquare(11,20,0)
 local b=R.bind(__body,source,destination,'push')
 if not b then
  print('BIND_DIAGNOSTIC',label,__body:isDead(),__body:isExistInTheWorld(),__body:getCell()==__cell,
   tostring(__body:getCurrentSquare()),tostring(R.props(source)),tostring(R.members(source)),tostring(destination:getFloor()),
   tostring(source:getSquare():isSomethingTo(destination)))
  local p=R.props(source);if p then print('PROPS',p.type,p.isMoveable,p.spriteName,p:canPlaceMoveableInternal(__body,destination,nil,true))end
 end
 check(label..'_native_binding',b~=nil)
 local ok,reason=R.commit(b)
 if not ok then print('COMMIT_DIAGNOSTIC',label,reason) end
 check(label..'_all_members_moved',ok and #b.members==(family=='single' and 1 or 2))
 for i,m in ipairs(b.members)do
  check(label..'_old_member_removed_'..i,m.object:getObjectIndex()==-1)
  check(label..'_new_native_member_'..i,m.placed~=nil and m.placed~=m.object and m.placed:getSquare()==m.target)
  if filled then local item=_G['__item'..(i-1)]
   check(label..'_exact_item_conserved_'..i,m.placed:getContainer():contains(item) and item:getContainer()==m.placed:getContainer())
  end
 end
 check(label..'_commit_replay_inert',R.commit(b)==false)
end end
for _,family in ipairs({'grid','linked'})do for _,point in ipairs({'pickup','place'})do
 __fixture(family,true);local b=R.bind(__body,__objects[1],__cell:getGridSquare(11,20,0),'push')
 local name=point=='pickup' and 'pickUpMoveableInternal' or 'placeMoveableInternal'
 local old=ISMoveableSpriteProps[name];local calls=0
 ISMoveableSpriteProps[name]=function(self,...)
  calls=calls+1;if calls==2 then error('controlled-mid-'..point)end;return old(self,...)
 end
 local ok=R.commit(b);ISMoveableSpriteProps[name]=old
 check(family..'_partial_'..point..'_not_success',ok==false)
 for i,m in ipairs(b.members)do
  check(family..'_partial_'..point..'_member_conserved_'..i,m.object:getObjectIndex()~=-1 or m.placed~=nil or m.carried and __body:getInventory():contains(m.carried))
  local item=_G['__item'..(i-1)]
  if item:getContainer()==nil or not item:getContainer():contains(item) then
   print('PARTIAL_CONTENT_DIAGNOSTIC',family,point,i,item:getID(),tostring(item:getContainer()),__body:getInventory():contains(item))
   local list=__body:getInventory():getItems();for j=0,list:size()-1 do local held=list:get(j);print('HELD_DIAGNOSTIC',held:getID(),held:getFullType(),held==item)end
  end
  check(family..'_partial_'..point..'_original_content_'..i,item:getContainer()~=nil and item:getContainer():contains(item))
  local restored=__itemRoundtrip(item)
  check(family..'_partial_'..point..'_native_content_save_'..i,restored~=nil and restored:getID()==item:getID() and restored:getFullType()==item:getFullType())
  if m.carried and __body:getInventory():contains(m.carried) then
   local member=__itemRoundtrip(m.carried)
   check(family..'_partial_'..point..'_native_member_save_'..i,member~=nil and member:getID()==m.carried:getID() and member:getWorldSprite()==m.carried:getWorldSprite())
  end
 end
 check(family..'_partial_'..point..'_replay_inert',R.commit(b)==false)
end end
__fixture('single',true)
local s=A.session(__body,__objects[1],__cell:getGridSquare(11,20,0),'push')
local a=A:new(s);ISTimedActionQueue.add(a);a._queue=ISTimedActionQueue.getTimedActionQueue(__body)
__nativeAction(a)
check('native_unperformed_complete_refused',a:complete()==false and __objects[1]:getObjectIndex()~=-1)
a.action:setCurrentTime(0);a.action:perform();a.action:complete()
check('native_unfinished_perform_refused',__objects[1]:getObjectIndex()~=-1 and ISTimedActionQueue.getTimedActionQueue(__body).current==a)
a.action:setCurrentTime(s.duration)
a.action:perform();a.action:complete()
check('native_perform_first_moves_once',s.succeeded==true and __objects[1]:getObjectIndex()==-1)
check('native_late_complete_inert',a:complete()==false)
__fixture('single',false)
local rejected=R.bind(__body,__objects[1],__cell:getGridSquare(12,20,0),'push')
check('native_noncardinal_refused',rejected==nil)
__body:setX(15.5);__body:setCurrent(__cell:getGridSquare(15,20,0))
check('native_distant_contact_refused',R.bind(__body,__objects[1],__cell:getGridSquare(11,20,0),'push')==nil)
