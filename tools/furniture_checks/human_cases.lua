local function check(k,v)__check(k,v==true)end
__fixture('single',true);__human()
local M,R=SAO.FurnitureMenu,SAO.FurnitureRelocation
ISContextMenu={getNew=function(_,parent)
 local menu={options={}}
 function menu:addOption(label,target,callback,...)
  local e={name=label,target=target,callback=callback,args={...}};self.options[#self.options+1]=e;return e
 end
 function menu:addSubMenu(entry,submenu)entry.submenu=submenu end
 return menu
end}
local context=ISContextMenu:getNew()
M.fill(0,context,{__objects[1]},false)
check('human_standalone_context_entry',#context.options==1 and context.options[1].submenu~=nil)
local chosen
for _,e in ipairs(context.options[1].submenu.options)do
 if e.args[2]:getX()==11 and e.args[2]:getY()==20 and e.args[3]=='push' then chosen=e end
end
check('human_native_context_selects_physical_destination',chosen~=nil and chosen.callback(chosen.target,unpack(chosen.args)))
local q=ISTimedActionQueue.getTimedActionQueue(__body);local a=q.current
check('human_actual_native_queue_owns_action',a and a.Type=='SAOFurnitureRelocationAction')
__nativeAction(a);__finish(a)
check('human_native_effect_and_exact_content',a._session.succeeded and __objects[1]:getObjectIndex()==-1 and __item0:getContainer()~=nil)
local qCurrent=q.current;local count=#q.queue;a:complete();a:stop()
check('human_late_callbacks_preserve_queue',q.current==qCurrent and #q.queue==count)
__fixture('single',false);__human()
local foreign={};q.current=foreign;q.queue[1]=foreign
check('human_busy_queue_refused',not M.queue(__body,__objects[1],__cell:getGridSquare(11,20,0),'push') and q.current==foreign)
q.current=nil;q.queue={}
-- Controlled optional callback ports isolate the existing adapter forwarding.
local oldCalls=0
FurniturePushPull={
 getMoveableData=R.props,getFurnitureMembers=R.members,
 getSquare=function(x,y,z)return __cell:getGridSquare(x,y,z)end,
 validateServerMove=function(body,object,mode,destination)return R.bind(body,object,destination,mode)end,
 executeMove=function()oldCalls=oldCalls+1;return false end,
 executeServerMove=function()oldCalls=oldCalls+1;return false end,
 PUSH_MOVE_DELAY_MS=260,applyEndurance=function()end,playMoveFeedback=function()end}
FurniturePushPullClient={playOriginalPushShove=function()end}
check('human_optional_forwarding_installed',SAO.FurnitureMovement.install())
check('human_optional_single_producer',FurniturePushPull.executeMove(__body,__objects[1],__cell:getGridSquare(11,20,0))==false)
-- This legacy callback is a pull commit; the human must have actually retreated.
__position(12.5,20.5)
check('human_optional_native_forwarded_effect',FurniturePushPull.executeMove(__body,__objects[1],__cell:getGridSquare(11,20,0)) and __objects[1]:getObjectIndex()==-1 and oldCalls==0)
local optional=ISContextMenu:getNew();M.fill(0,optional,{__objects[1]},false)
check('human_optional_menu_no_duplicate',#optional.options==0)

-- Real installed walk retirement must not cancel its owned successor.
for _,mode in ipairs({'push','pull'})do
 __fixture('single',true);__human();ISTimedActionQueue.queues[__body]=nil
 __position(8.5,20.5)
 check('human_'..mode..'_approach_walk_queued',M.queue(__body,__objects[1],__cell:getGridSquare(11,20,0),mode))
 local queue=ISTimedActionQueue.getTimedActionQueue(__body);local walk=queue.current
 check('human_'..mode..'_installed_walk',walk.Type=='ISWalkToTimedAction')
 __position(mode=='push' and 9.5 or 11.5,20.5);__nativeAction(walk);__finish(walk)
 local effort=queue.current;local session=effort and effort._session
 check('human_'..mode..'_walk_retired_to_effort',effort and effort.Type=='SAOFurnitureRelocationAction' and queue:indexOf(walk)==-1)
 local length=#queue.queue;walk:stop();walk:perform();walk.onCompleteFunc()
 check('human_'..mode..'_retired_walk_preserves_effort',queue.current==effort and #queue.queue==length and not session.cancelled)
 __nativeAction(effort);__finish(effort)
 if mode=='pull' then
  local retreat=queue.current
  check('human_pull_native_retreat_walk',retreat and retreat.Type=='ISWalkToTimedAction')
  walk:stop();walk:perform();walk.onCompleteFunc()
  check('human_pull_approach_preserves_retreat',queue.current==retreat and not session.cancelled)
  __position(12.5,20.5);__nativeAction(retreat);__finish(retreat)
  local commit=queue.current;length=#queue.queue
  retreat:stop();retreat:perform();retreat.onCompleteFunc()
  check('human_pull_retired_retreat_preserves_commit',queue.current==commit and #queue.queue==length and not session.cancelled)
  __nativeAction(commit);__finish(commit)
 end
 check('human_'..mode..'_walk_chain_exact_effect',session.succeeded and __objects[1]:getObjectIndex()==-1 and __item0:getContainer():contains(__item0))
end
__fixture('single',false);__human();ISTimedActionQueue.queues[__body]=nil;__position(8.5,20.5)
check('human_current_walk_queued',M.queue(__body,__objects[1],__cell:getGridSquare(11,20,0),'push'))
local currentQueue=ISTimedActionQueue.getTimedActionQueue(__body);local currentWalk=currentQueue.current
currentWalk:stop()
check('human_current_walk_cancels_own_session',currentWalk._saoWalkRetired and currentQueue.current==nil and __objects[1]:getObjectIndex()~=-1)
