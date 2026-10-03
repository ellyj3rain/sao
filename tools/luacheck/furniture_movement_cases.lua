local F,M=FurniturePushPull,SAO.FurnitureMovement
check("installed_adapter_admitted",M.install()==true)
local function last() local rows=M.outcomes();return rows[#rows] end
local function action(c,o,d,kind)
 return setmetatable({character=c,mode=kind,sourceX=o.square.x,sourceY=o.square.y,sourceZ=o.square.z,spriteName=o.name,
  destX=d.x,destY=d.y,destZ=d.z,backX=c.square.x,backY=c.square.y,backZ=c.square.z},
  {__index=kind=='push' and ISFurniturePushPullEffortAction or ISFurniturePullCommitAction})
end
local function advance() __now=__now+FurniturePushPull.PUSH_MOVE_DELAY_MS;__event('OnTick') end
local c,o,s,d,item,nested=__reset()
check("installed_pull_complete",action(c,o,d,'pull'):complete()==true)
local moved=F.findObject(d.x,d.y,d.z,o.name)
check("pull_measured_completion",last().status=='completed' and moved~=o and o.square==nil and __pickups==1 and __placements==1)
check("exact_content_and_nested_identity",moved.containers[1]:contains(item) and item.nested==nested and item.md.identity==1 and o.containers[1].items:size()==0)
local copied=M.outcomes();copied[#copied].status='forged'
check("outcomes_are_detached",last().status=='completed')
c,o,s,d,item=__reset()
local before=#M.outcomes()
check("installed_push_complete_queues",action(c,o,d,'push'):complete()==true and M.pendingCount()==1 and c.effects==1)
check("delayed_push_has_no_premature_completion",#M.outcomes()==before and __pickups==0 and o.square==s)
__now=__now+259;__event('OnTick')
check("delay_preserved",__pickups==0 and M.pendingCount()==1)
__now=__now+1;__event('OnTick')
check("delayed_push_measured_once",last().status=='completed' and __pickups==1 and M.pendingCount()==0)
advance()
check("installed_pending_queue_not_duplicated",__pickups==1 and __placements==1 and #M.outcomes()==before+1)
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();s.objects:remove(o) -- stale native receiver retains its old square
local replacement=__object(s,o.name)
advance()
check("same_sprite_replacement_refused",replacement.square==s and __pickups==0 and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();o.containers[1]:Remove(item);o.containers[1]:AddItem(__item(1))
advance()
check("same_id_content_substitution_refused",__pickups==0 and o.square==s and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();c.dead=true;advance()
check("dead_actor_refused",__pickups==0 and o.square==s and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();M.reset('world-change');advance()
check("reset_cancels_pending",__pickups==0 and M.pendingCount()==0 and o.square==s)
c,o,s,d,item=__reset();__failPlace=true
check("placement_failure_not_completed",F.executeMove(c,o,d)==false and last().status~='completed')
check("failed_placement_rescues_exact_item",c.inventory:contains(item) and item:getContainer()==c.inventory)
c,o,s,d,item=__reset();__omitContainer=true
check("incomplete_content_restore_not_completed",F.executeMove(c,o,d)==false and last().status~='completed')
check("incomplete_restore_rescues_exact_item",c.inventory:contains(item))
c,o,s,d,item=__reset()
check("unbound_direct_relocation_refused",F.executeServerMove(c,o,d)==false and __pickups==0)
c,o,s,d,item=__reset();__npc=true
check("npc_not_admitted_as_player",F.executeMove(c,o,d)==false and __pickups==0)
c,o,s,d,item=__reset();o.name='location_business_office_generic_01_40'
local partner=__object(__square(10,9,0),'location_business_office_generic_01_41');__square(11,9,0)
local otherItem=__item(3);partner.containers[1]:AddItem(otherItem)
before=#M.outcomes()
check("nested_execute_move_delegate",F.executeMove(c,o,d)==true)
check("nested_delegate_one_result",#M.outcomes()==before+1 and last().status=='completed' and __pickups==2 and __placements==2)
check("linked_desk_exact_contents",F.findObject(11,10,0,o.name).containers[1]:contains(item) and F.findObject(11,9,0,partner.name).containers[1]:contains(otherItem))
c,o,s,d,item=__reset();__active.TakeABathAndShowerNew=true;o.name='fixtures_bathroom_01_24'
__tfc.Registered['10-10-0']={amount=4,capacity=100}
check("wet_bath_refused_before_effect",F.executeMove(c,o,d)==false and __pickups==0 and o.square==s)
__tfc.Registered={}
c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={['10_10_0']={x=10,y=10,z=0,w=0,wmax=10000}}}
check("empty_wp_fixture_moves",F.executeMove(c,o,d)==true)
check("wp_owner_source_destination_reconciled",__wp.Barrels['10_10_0']==nil and __wp.Barrels['11_10_0']~=nil)
c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={['10_10_0']={x=10,y=10,z=0,w=1000,wmax=10000}}}
check("virtual_water_refused_before_effect",F.executeMove(c,o,d)==false and __pickups==0 and __wp.Barrels['10_10_0']~=nil)

c,o,s,d,item=__reset()
item.kind='InventoryContainer';item.inventory=__container();item.inventory:AddItem(nested)
function item:getInventory() return self.inventory end
action(c,o,d,'push'):complete();item.inventory:Remove(nested);item.inventory:AddItem(__item(2));advance()
check("nested_content_substitution_refused",__pickups==0 and o.square==s and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();__now=12000;__event('OnTick')
check("expired_push_no_native_effect",last().status=='expired' and __pickups==0 and M.pendingCount()==0)
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();__now=999;__event('OnTick')
check("clock_rewind_refuses",last().status=='expired' and __pickups==0)
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();__cell={getGridSquare=function() return nil end};advance()
check("replacement_world_refuses",__pickups==0 and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();action(c,o,d,'push'):complete()
check("same_actor_one_pending_owner",M.pendingCount()==1 and c.effects==1)
advance()
check("same_actor_one_physical_move",__pickups==1 and __placements==1)

c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();local obstacle=__object(d,'fixtures_other_01_0');advance()
check("destination_changed_refuses",__pickups==0 and obstacle.square==d and last().status~='completed')
c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={['10_10_0']={x=10,y=10,z=0,w=0,wmax=10000,m='Water',custom='retained'}}}
check("wp_scalar_metadata_preserved",F.executeMove(c,o,d)==true and __wp.Barrels['11_10_0'].m=='Water' and __wp.Barrels['11_10_0'].custom=='retained')
c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={['10_10_0']={x=10,y=10,z=0,w=0,wmax=10000},['11_10_0']={x=11,y=10,z=0,w=300,wmax=10000}}}
check("unrelated_destination_registration_preserved",F.executeMove(c,o,d)==false and __pickups==0 and __wp.Barrels['11_10_0'].w==300)
c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={['10_10_0']={x=10,y=10,z=0,w=0,wmax=10000,m='Water'}}}
action(c,o,d,'push'):complete();__wp.Barrels['10_10_0'].m='Changed';advance()
check("delayed_registry_change_refused",__pickups==0 and __wp.Barrels['10_10_0'].m=='Changed')
c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={}}
local add=WPServer.Commands.BarrelAdd;WPServer.Commands.BarrelAdd=nil
check("missing_wp_authority_refuses",F.executeMove(c,o,d)==false and __pickups==0)
WPServer.Commands.BarrelAdd=add

c,o,s,d,item=__reset();__active.Waterpipes=true;o.name='carpentry_02_120';o.capacity=100;o.amount=0
__wp={Barrels={['10_10_0']={x=10,y=10,z=0,w=0,wmax=10000}}}
__afterPlacement=function() __wp.Barrels['11_10_0']={x=11,y=10,z=0,w=400,wmax=10000} end
check("midmove_registry_change_preserved",F.executeMove(c,o,d)==false and last().status=='partial' and __wp.Barrels['11_10_0'].w==400 and __wp.Barrels['10_10_0']~=nil)

c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();c.present=false;advance()
check("unloaded_actor_refused",__pickups==0 and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();c.cell={};advance()
check("foreign_actor_cell_refused",__pickups==0 and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();__squares['9:10:0']=nil;advance()
check("detached_actor_square_refused",__pickups==0 and last().status~='completed')
c,o,s,d,item=__reset();o.name='location_business_office_generic_01_40'
partner=__object(__square(10,9,0),'location_business_office_generic_01_41');__square(11,9,0)
action(c,o,d,'push'):complete();partner.square.objects:remove(partner);__object(__square(10,9,0),partner.name);advance()
check("replaced_footprint_member_refused",__pickups==0 and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete()
local membersOriginal=F.getFurnitureMembers
F.getFurnitureMembers=function(object,props)
 local members=membersOriginal(object,props)
 members[#members+1]={object=o,square=s,sprite=o:getSprite()};return members
end
advance();F.getFurnitureMembers=membersOriginal
check("expanded_footprint_refused",__pickups==0 and last().status~='completed')
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete()
local other=__object(__square(20,10,0));local otherDest=__square(21,10,0)
local otherActor=__character();otherActor.square=__square(19,10,0)
action(otherActor,other,otherDest,'push'):complete()
__afterPlacement=function() M.reset('native-callback-reset') end
local resetOk=pcall(advance)
check("reset_during_native_callback_is_bounded",resetOk and M.pendingCount()==0 and __pickups==1 and o.square==s and last().status=='partial')

c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();M.reset({nativeHandle=o})
check("reset_non_scalar_reason_sanitized",last().reason=='unspecified' and last().status=='cancelled' and M.pendingCount()==0)
c,o,s,d,item=__reset()
action(c,o,d,'push'):complete();M.reset(string.rep('x',1000))
check("reset_reason_bounded",type(last().reason)=='string' and #last().reason==160 and M.pendingCount()==0)
