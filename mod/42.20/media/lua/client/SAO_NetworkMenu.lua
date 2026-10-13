-- Human interaction uses the same native producer and held means.
require "SAO_NetworkWork"
SAO=SAO or {};SAO.NetworkMenu=SAO.NetworkMenu or {}
local M,N,H=SAO.NetworkMenu,SAO.NetworkWork,SAO.HouseholdService
local function choose(body,step,item,tool,part,object)
 return N.begin("native-player/"..body:getPlayerNum(),body,step,
  {localPlayer=true,item=item,tool=tool,part=part,object=object})
end
function M.fill(player,context,worldobjects,test)
 if test or isClient()or isServer()then return end
 local body=getSpecificPlayer(player);local tool=body and body:getPrimaryHandItem()
 if not body or not tool or tool:isBroken()or not(tool:getType()=="PipeWrench"or tool:hasTag(ItemTag.PIPE_WRENCH))then return end
 local sites={};local seen={}
 for _,object in ipairs(worldobjects or{})do
  local square=object and object:getSquare()
  if square then
   local x,y,z=square:getX(),square:getY(),square:getZ();local key=x..":"..y..":"..z
   if not seen[key]then seen[key]=true;sites[#sites+1]={x=x,y=y,z=z}end
  end
 end
 for _,q in ipairs(sites)do
  local square=body:getCell():getGridSquare(q.x,q.y,q.z)
  local connection=H.connection(q.x,q.y,q.z)
  if square and connection and connection.owned then
   local objects=square:getObjects()
   for i=0,objects:size()-1 do
    local object=objects:get(i);local source=SAOJavaBridge:networkFluidObservation(body,object)
    if source then
     local operation=source.included and"detach"or"attach"
     local step={owner="SAO.ResourceProduction",productionKind="network-operation",operation=operation,source=source,
      site={kind="source",axis="x",x=q.x,y=q.y,z=q.z,revision=source.revision},
      itemId=tostring(tool:getID()),itemType=tool:getFullType(),toolItemId=tostring(tool:getID()),toolItemType=tool:getFullType()}
     context:addOption(operation=="attach"and"Connect container to water network"or"Disconnect container from water network",
      body,choose,step,tool,tool,nil,object)
    end
   end
  end
  for _,kind in ipairs({"floor","riser","valve","pump"})do for _,axis in ipairs({"x","y"})do
   local site=SAOJavaBridge:networkSite(body,kind,axis,q.x,q.y,q.z)
   if site and not H.edgeOccupied(site)then
    local item=body:getInventory():getFirstType(site.itemType)
    if item and item:getCondition()>0 and not item:getIsCraftingConsumed()and item:getWorldItem()==nil then
     local step={owner="SAO.ResourceProduction",productionKind="network-operation",operation="place",site=site,
      itemId=tostring(item:getID()),toolItemId=tostring(tool:getID()),toolItemType=tool:getFullType()}
     context:addOption("Install "..(kind=="floor"and"water pipe"or kind=="riser"and"vertical water pipe"or kind=="valve"and"water valve"or"water pump")
      .." ("..(axis=="x"and"east-west"or"north-south")..")",body,choose,step,item,tool)
    end
   end
  end end
  for _,part in ipairs(H.partsAt(q.x,q.y,q.z))do
   local object=H.currentPart(part);local site=SAOJavaBridge:networkSite(body,part.kind,part.axis,q.x,q.y,q.z)
   if object and site then
    local operations={"remove"}
    if part.kind=="valve"then operations[#operations+1]=part.open and"close"or"open"end
    if part.kind=="pump"then operations[#operations+1]=part.enabled and"deactivate"or"activate"end
    for _,operation in ipairs(operations)do
     local step={owner="SAO.ResourceProduction",productionKind="network-operation",operation=operation,site=site,
      itemId=part.itemId,toolItemId=tostring(tool:getID()),toolItemType=tool:getFullType()}
     context:addOption(operation=="remove"and"Recover water hardware"or operation=="close"and"Close water valve"
      or operation=="open"and"Open water valve"or operation=="activate"and"Enable water pump"or"Disable water pump",
      body,choose,step,nil,tool,part,object)
    end
   end
  end
 end
end
if Events and Events.OnFillWorldObjectContextMenu then
 if M.onFill then Events.OnFillWorldObjectContextMenu.Remove(M.onFill)end
 M.onFill=M.fill;Events.OnFillWorldObjectContextMenu.Add(M.onFill)
end
return M
