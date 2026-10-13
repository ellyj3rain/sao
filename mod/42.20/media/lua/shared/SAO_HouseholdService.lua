-- Existing household connections supply native stock. Installation belongs to Generator.
-- Authored SAO behavior; legacy keys below describe saved data, not imported code.
SAO=SAO or {}
SAO.HouseholdService=SAO.HouseholdService or {}
local H=SAO.HouseholdService
local STORE="SurvivorAwareness_HouseholdService"
local loaded,graph,positions={},nil,nil
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<math.huge end
local function coordinate(v)return finite(v)and v%1==0 and math.abs(v)<=2147483647 end
local function key(x,y,z)return tostring(x)..":"..tostring(y)..":"..tostring(z)end
local function localAuthority()return not isClient()and not isServer()end
local function ordering(rows,less)
    if SAO.Ordering and SAO.Ordering.sort then SAO.Ordering.sort(rows,less)
    else -- Small native object lists; insertion does not use the native recursive sorter.
        for i=2,#rows do local v,j=rows[i],i-1;while j>0 and less(v,rows[j])do rows[j+1]=rows[j];j=j-1 end;rows[j+1]=v end
    end
end
local function store()
    local s=ModData.getOrCreate(STORE)
    if s.schema==nil then s.schema=1;s.pieces={} end
    return s.schema==1 and type(s.pieces)=="table"and not getmetatable(s.pieces)and s or nil
end
function H.available()
    -- Availability of private source readers is separate from a physical writer.
    return localAuthority()and getCell()~=nil
end
-- New network parts are actual placed native items, not coordinate-only records.
local partBindings={}
local partTypes={floor="Base.MetalPipe",riser="Base.MetalPipe",valve="SAO.WaterValve",pump="SAO.WaterPump"}
local relationKeys={"schema","id","workId","actorId","world","kind","itemId","itemType","nativeClass","x","y","z","axis","xRotation","yRotation","zRotation","open","enabled"}
local function worldName()
    local ok,value=pcall(function()return getWorld():getWorld()end)
    return ok and type(value)=="string"and #value>0 and value or nil
end
local function partEqual(a,b)
    if type(a)~="table"or getmetatable(a)or type(b)~="table"or getmetatable(b)then return false end
    for _,k in ipairs(relationKeys)do if a[k]~=b[k]then return false end end
    return true
end
function H.partSpec(kind)
    if kind=="source"then return{kind=kind}end
    return partTypes[kind]and {kind=kind,itemType=partTypes[kind]}or nil
end
function H.reservePlayerWorkSequence(body)
    if not H.available()or not body or SAOJavaBridge:isShell(body)or getSpecificPlayer(body:getPlayerNum())~=body then return nil end
    local s=store();local sequence=s and(s.playerWorkSequence or 0)
    if not coordinate(sequence)or sequence<0 then return nil end
    s.playerWorkSequence=sequence+1;return s.playerWorkSequence
end
function H.currentPart(row)
    if type(row)~="table"or getmetatable(row)or row.schema~="sao-water-network-part/1"
        or not partTypes[row.kind]or row.itemType~=partTypes[row.kind]or row.world~=worldName()
        or type(row.id)~="string"or type(row.itemId)~="string"or not coordinate(row.x)or not coordinate(row.y)or not coordinate(row.z)
        or row.axis~="x"and row.axis~="y"then return nil end
    local square=getCell()and getCell():getGridSquare(row.x,row.y,row.z)
    if not square then return nil end
    local objects=square:getWorldObjects();local found
    for i=0,objects:size()-1 do
        local object=objects:get(i);local item=object:getItem()
        if item and tostring(item:getID())==row.itemId and item:getFullType()==row.itemType then
            local native=item:getModData().SAOWaterNetworkPart
            if found or object:getSquare()~=square or item:getWorldItem()~=object or not partEqual(row,native)
                or item:getWorldXRotation()~=row.xRotation or item:getWorldYRotation()~=row.yRotation
                or item:getWorldZRotation()~=row.zRotation or item:getCondition()<=0
                or item:getScriptItem()~=getScriptManager():getItem(item:getFullType())
                or SAOJavaBridge:networkPartClass(object)~=row.nativeClass then return nil end
            found=object
        end
    end
    local prior=partBindings[row.id]
    if prior and prior~=found then return nil end
    if found then partBindings[row.id]=found end
    return found
end
function H.partsAt(x,y,z)
    local out={};local s=store();if not s then return out end
    for _,row in pairs(s.pieces)do
        if row.x==x and row.y==y and row.z==z and H.currentPart(row)then out[#out+1]=row end
    end
    return out
end
function H.currentInstalledItem(worldItem)
    local q=worldItem and worldItem:getSquare();local item=worldItem and worldItem:getItem()
    if not q or not item or item:getWorldItem()~=worldItem then return false end
    for _,part in ipairs(H.partsAt(q:getX(),q:getY(),q:getZ()))do
        if part.itemId==tostring(item:getID())and H.currentPart(part)==worldItem then return true end
    end
    return false
end
function H.networkStockAvailable(item)
    -- An unresolved retained claim is unavailable stock, never proof of an installation.
    if not item or item:getModData().SAOWaterNetworkPart~=nil then return false end
    local worldItem=item:getWorldItem()
    return not worldItem or H.currentInstalledItem(worldItem)~=true
end
function H.commitPart(actorId,work,object,definition)
    local owner=SAO.NetworkWork
    if not H.available()or not owner or not owner.mutationCurrent
        or owner.mutationCurrent(actorId,work,object,definition)~=true then return false end
    local item=object and object:getItem();local q=object and object:getSquare();local s=store()
    if not s or not item or not q or item:getWorldItem()~=object or not q:getWorldObjects():contains(object)
        or not H.partSpec(definition.kind)or item:getFullType()~=partTypes[definition.kind]
        or s.pieces[work.id]then return false end
    for _,prior in pairs(s.pieces)do
        if prior.x==q:getX()and prior.y==q:getY()and prior.z==q:getZ()and(prior.axis==definition.axis or definition.kind=="riser")
            and (prior.kind=="riser")== (definition.kind=="riser")and H.currentPart(prior)then return false end
    end
    local row={schema="sao-water-network-part/1",id=work.id,workId=work.id,actorId=actorId,world=work.world,
        kind=definition.kind,itemId=tostring(item:getID()),itemType=item:getFullType(),x=q:getX(),y=q:getY(),z=q:getZ(),
        nativeClass=SAOJavaBridge:networkPartClass(object),axis=definition.axis,xRotation=item:getWorldXRotation(),yRotation=item:getWorldYRotation(),zRotation=item:getWorldZRotation(),
        open=true,enabled=true}
    if item:getModData().SAOWaterNetworkPart~=nil then return false end
    local marker={};for k,v in pairs(row)do marker[k]=v end
    item:getModData().SAOWaterNetworkPart=marker;s.pieces[row.id]=row;partBindings[row.id]=object
    return H.currentPart(row)==object
end
function H.changePart(actorId,work,row,object,operation)
    local owner=SAO.NetworkWork
    if not owner or not owner.mutationCurrent or owner.mutationCurrent(actorId,work,object,row)~=true
        or H.currentPart(row)~=object then return false end
    if operation=="close"and row.kind=="valve"and row.open==true then row.open=false
    elseif operation=="open"and row.kind=="valve"and row.open==false then row.open=true
    elseif operation=="activate"and row.kind=="pump"and row.enabled==false then row.enabled=true
    elseif operation=="deactivate"and row.kind=="pump"and row.enabled==true then row.enabled=false
    else return false end
    local marker=object:getItem():getModData().SAOWaterNetworkPart
    marker.open,marker.enabled=row.open,row.enabled
    return true
end
function H.currentBuiltEndpoint(x,y,z)
    local s=store()
    if not H.available()or not s or not coordinate(x)or not coordinate(y)or not coordinate(z)
        or not getCell():getGridSquare(x,y,z)then return false end
    for _,part in pairs(s.pieces)do
        if H.currentPart(part)then
            local bx,by,bz=part.x,part.y,part.z
            if part.kind=="riser"then bz=bz+1
            elseif part.axis=="x"then bx=bx+1 else by=by+1 end
            if part.x==x and part.y==y and part.z==z or bx==x and by==y and bz==z then return true end
        end
    end
    return false
end
function H.changeSource(actorId,work,object,definition,include)
    local owner=SAO.NetworkWork
    if not owner or owner.mutationCurrent(actorId,work,object,definition)~=true then return false end
    local q=object and object:getSquare();local fc=object and object:getFluidContainer()
    if not q or not fc or not q:getObjects():contains(object)or q:getCell()~=getCell()
        or not finite(fc:getCapacity())or fc:getCapacity()<=0 or not finite(fc:getAmount())or fc:getAmount()<0 then return false end
    if H.currentBuiltEndpoint(q:getX(),q:getY(),q:getZ())~=true or H.isIncluded(object)==include then return false end
    object:getModData().SAOHouseholdSource=include
    return H.isIncluded(object)==include
end
function H.retirePart(actorId,work,row,object)
    local owner=SAO.NetworkWork;local s=store()
    if not s or not owner or not owner.removalCurrent or owner.removalCurrent(actorId,work,row,object)~=true then return false end
    if s.pieces[row.id]~=row then return false end
    s.pieces[row.id]=nil;partBindings[row.id]=nil
    local item=object and object:getItem()
    if item and partEqual(row,item:getModData().SAOWaterNetworkPart)then item:getModData().SAOWaterNetworkPart=nil end
    return true
end
local function footprints(p)
    if p.kind=="floor"then return{{p.x,p.y,p.z}}end
    local dx,dy=p.north and 0 or -1,p.north and -1 or 0
    return{{p.x,p.y,p.z},{p.x+dx,p.y+dy,p.z},{p.x,p.y,p.z+1},{p.x+dx,p.y+dy,p.z+1}}
end
local function legacyPiece(row,kind)
    if type(row)~="table"or getmetatable(row)or not coordinate(row.x)or not coordinate(row.y)or not coordinate(row.z)
        or kind=="wall"and type(row.north)~="boolean"then return nil end
    return{x=row.x,y=row.y,z=row.z,kind=kind,north=kind=="wall"and row.north or nil}
end
function H.refreshTopology()
    local s=store();if not s then return false end
    local legacy=ModData.get and ModData.get("LGExtendedPlumbing")
    if legacy~=nil and(type(legacy)~="table"or getmetatable(legacy)or type(legacy.floors)~="table"or type(legacy.walls)~="table")then graph,positions=nil,nil;return false end
    local nodes,edges,parts,legacyTiles={},{},{},{}
    local function node(x,y,z)
        local id=key(x,y,z);nodes[id]=nodes[id]or{x=x,y=y,z=z};edges[id]=edges[id]or{};return id
    end
    local function edge(a,b)edges[a][b]=true;edges[b][a]=true end
    local seen={}
    local function old(rows,kind)
        for _,raw in pairs(rows or{})do
            local p=legacyPiece(raw,kind);if not p then return false end
            local id=key(p.x,p.y,p.z)..":"..kind..(kind=="wall"and(p.north and":N"or":W")or"")
            if seen[id]then return false end;seen[id]=true
            p.id=id;p.origin="legacy-lgep-data";p.tiles=footprints(p);parts[#parts+1]=p
            local first
            for _,v in ipairs(p.tiles)do local n=node(v[1],v[2],v[3]);legacyTiles[n]=true;if first then edge(first,n)else first=n end end
        end
        return true
    end
    if legacy and(not old(legacy.floors,"floor")or not old(legacy.walls,"wall"))then graph,positions=nil,nil;return false end
    for id in pairs(legacyTiles)do local p=nodes[id]
        for dx=-1,1 do for dy=-1,1 do local n=key(p.x+dx,p.y+dy,p.z);if legacyTiles[n]then edge(id,n)end end end
    end
    for _,row in pairs(s.pieces)do
        local object=H.currentPart(row)
        if object then
            local a=node(row.x,row.y,row.z);local b
            if row.kind=="riser"then b=node(row.x,row.y,row.z+1)
            elseif row.axis=="x"then b=node(row.x+1,row.y,row.z)else b=node(row.x,row.y+1,row.z)end
            local powered=row.kind~="pump"or row.enabled==true and object:getSquare():haveElectricity()==true
            if row.kind~="valve"or row.open==true then if powered then edge(a,b)end end
            parts[#parts+1]={id=row.id..":"..row.kind..":"..tostring(row.open)..":"..tostring(powered),owned=true,object=object,powered=powered,
                row=row,tiles={{nodes[a].x,nodes[a].y,nodes[a].z},{nodes[b].x,nodes[b].y,nodes[b].z}}}
        end
    end
    graph={nodes=nodes,edges=edges,parts=parts};positions=nodes;return true
end
function H.connection(x,y,z)
    if not H.available()or not coordinate(x)or not coordinate(y)or not coordinate(z)or not H.refreshTopology()then return nil end
    local start=key(x,y,z);if not positions[start]then return nil end
    local queue,seen={start},{[start]=true};local cursor=1
    while queue[cursor]do local n=queue[cursor];for next in pairs(graph.edges[n])do if not seen[next]then seen[next]=true;queue[#queue+1]=next end end;cursor=cursor+1 end
    local tiles,rows,owned,pumps={},{},false,{}
    for _,n in ipairs(queue)do local p=positions[n];local q=getCell():getGridSquare(p.x,p.y,p.z);if not q then return nil end
        tiles[n]={x=p.x,y=p.y,z=p.z,square=q}
    end
    for _,p in ipairs(graph.parts)do
        local a,b=p.tiles[1],p.tiles[#p.tiles]
        if seen[key(a[1],a[2],a[3])]and seen[key(b[1],b[2],b[3])]then
            rows[#rows+1]=p.id;if p.owned then owned=true;if p.row.kind=="pump"and p.powered==true then pumps[#pumps+1]=p.object end end
        end
    end
    ordering(rows,function(a,b)return a<b end)
    return{structure="sao-pipe:"..table.concat(rows,";"),tiles=tiles,owned=owned,pumps=pumps}
end
function H.edgeOccupied(site)
    for _,part in ipairs(H.partsAt(site.x,site.y,site.z))do
        if(part.axis==site.axis or site.kind=="riser")and(part.kind=="riser")== (site.kind=="riser")then return true end
    end
    return false
end
function H.pumpCurrent(object)
    local q=object and object:getSquare()
    if not q or not q:getWorldObjects():contains(object)then return false end
    for _,part in ipairs(H.partsAt(q:getX(),q:getY(),q:getZ()))do
        if part.kind=="pump"and part.enabled==true and H.currentPart(part)==object then return true end
    end
    return false
end
function H.isIncluded(object)
    local d=object and object:getModData()
    if not d then return false end
    if d.SAOHouseholdSource~=nil then return d.SAOHouseholdSource==true end
    return d.LGEPInclude==true
end
function H.isPumped(object)
    local q=object and object:getSquare()
    return H.isIncluded(object)and q~=nil and q:haveElectricity()==true
end
local function live(object,square)
    return object and square and object:getSquare()==square and square:getCell()==getCell()
        and getCell():getGridSquare(square:getX(),square:getY(),square:getZ())==square
        and square:getObjects():contains(object)
end
local function members(connection)
    local rows,seen={},{}
    for _,tile in pairs(connection.tiles)do
        local objects=tile.square:getObjects()
        for i=0,objects:size()-1 do
            local object=objects:get(i)
            local fc=object and object:getFluidContainer()
            if fc and H.isIncluded(object)and live(object,tile.square)then
                if seen[object]then return nil end
                seen[object]=true
                local data=object:getModData()
                local reserve=data.SAOHouseholdReserve
                if reserve==nil then reserve=data.LGEPReserve end
                rows[#rows+1]={object=object,fluid=fc,x=tile.x,y=tile.y,z=tile.z,
                    reserve=reserve==true,
                    id=key(tile.x,tile.y,tile.z)..":"..object:getObjectIndex()}
            end
        end
    end
    ordering(rows,function(a,b)if a.reserve~=b.reserve then return not a.reserve end;return a.id<b.id end)
    return rows
end
function H.supplyGroup(x,y,z)
    local c=H.connection(x,y,z);if not c then return nil end
    return members(c),c.structure
end
function H.fuelGroup(x,y,z)
    local all,structure=H.supplyGroup(x,y,z)
    if not all then return nil end
    local rows={}
    for _,row in ipairs(all)do
        -- Type remains observable after exhaustion; amounts are not topology.
        local typeName=row.object:getModData().SAOHouseholdChannel
        if typeName=="fuel"or row.fluid:isPureFluid(Fluid.Petrol)then rows[#rows+1]=row end
    end
    return rows,structure
end
function H.isGeneratorPlumbed(generator)
    if not generator then return false end
    if generator:getModData().SAOHouseholdFuelConnection==true then return true end
    local ok,value=pcall(function()return LGEE and LGEE.isGeneratorPlumbed and LGEE.isGeneratorPlumbed(generator)end)
    return ok and value==true
end
function H.canPlumbGenerator(x,y,z)
    local group=H.fuelGroup(x,y,z)
    return group~=nil and #group>0
end
function H.isForeignGenerator(generator)
    if not generator then return true end
    local ok,itemType=pcall(function()return generator:getGeneratorItemType()end)
    -- The selected producer serves registered vanilla machines, not unknown custom engines.
    return not ok or type(itemType)~="string"or itemType:sub(1,5)~="Base."
end
function H.producer(generator)
    local q=generator and generator:getSquare()
    if not live(generator,q)or H.isForeignGenerator(generator)then return nil end
    local owned=H.fuelGroup(q:getX(),q:getY(),q:getZ())
    if not owned or #owned==0 then return nil end
    if not LGEE then return "sao" end
    if not LGEE.isGeneratorPlumbed then
        if LGEE.buildingFuelGroup then return nil end;return "sao"
    end
    local selected,connected=pcall(LGEE.isGeneratorPlumbed,generator)
    if not selected then return nil end
    if connected~=true then return "sao" end
    if not LGEE.buildingFuelGroup then return nil end
    local ok,external=pcall(LGEE.buildingFuelGroup,q:getX(),q:getY(),q:getZ())
    if not ok or type(external)~="table"or #external==0 then return nil end
    local members={};for _,row in ipairs(owned)do members[row.object]=true end
    for _,row in ipairs(external)do
        if not members[row.object]or not live(row.object,row.object:getSquare())then return nil end
    end
    return "external-lgee"
end
function H.active(generator)return H.available()and H.producer(generator)=="sao"end
function H.connectGenerator(generator,character,wrench)
    local q=generator and generator:getSquare()
    if not H.available()or not live(generator,q)or not generator:isConnected()or generator:isActivated()
        or H.isForeignGenerator(generator)or H.isGeneratorPlumbed(generator)
        or not H.canPlumbGenerator(q:getX(),q:getY(),q:getZ())then return false end
    if H.producer(generator)~="sao"then return false end
    generator:getModData().SAOHouseholdFuelConnection=true
    loaded[generator]=q
    return true
end
local function transferFuel(generator)
    local q=generator:getSquare()
    if not H.active(generator)or not live(generator,q)or not generator:isConnected()or not H.isGeneratorPlumbed(generator)
        or H.isForeignGenerator(generator)then return end
    local old,capacity=generator:getFuel(),generator:getMaxFuel()
    if not finite(old)or not finite(capacity)or old<0 or capacity<=old then return end
    local group=H.fuelGroup(q:getX(),q:getY(),q:getZ());if not group then return end
    for _,m in ipairs(group)do
        if generator:getFuel()>=capacity then break end
        if live(m.object,m.object:getSquare())and m.object:getFluidContainer()==m.fluid and m.fluid:isPureFluid(Fluid.Petrol)then
            local before=m.fluid:getAmount()
            local beforeFuel=generator:getFuel()
            local wanted=math.min(before,capacity-beforeFuel)
            if finite(before)and wanted>0 then
                m.fluid:removeFluid(wanted)
                local after=m.fluid:getAmount();local debit=before-after
                if finite(after)and debit>0 and debit<=wanted+0.0001 then
                    generator:setFuel(generator:getFuel()+debit)
                    generator:getModData().SAOHouseholdLastFuel={before=beforeFuel,after=generator:getFuel(),debit=debit}
                    m.object:getModData().SAOHouseholdChannel="fuel"
                end
            end
        end
    end
end
local function waterOnly(fc)
    -- This channel carries native water-bearing mixtures. Mechanical transfer
    -- preserves all components; native drinking owns safety and purification.
    return fc and(fc:contains(Fluid.Water)or fc:contains(Fluid.TaintedWater))
end
function H.waterProducer(source)
    local q=source and source:getSquare()
    if not live(source,q)or not H.isIncluded(source)then return nil end
    -- An installed plumbing producer may still draw the same native source
    -- even when its electricity companion is absent.
    if not LGEP then return "sao" end
    if not LGEP.supplyGroupFor then
        if source:getModData().LGEPInclude==true then return nil end;return "sao"
    end
    local ok,group=pcall(LGEP.supplyGroupFor,q:getX(),q:getY(),q:getZ())
    if not ok then return nil end
    if type(group)~="table"then if source:getModData().LGEPInclude==true then return nil end;return "sao"end
    for _,row in ipairs(group)do
        if row.object==source then return live(row.object,q)and "external-lgep"or nil end
    end
    return "sao"
end
local function nativeHeader(object,connection)
    local q=object and object:getSquare()
    if not connection or not live(object,q)or not object:getFluidContainer()then return false end
    if object:getModData().SAOHouseholdHeader==true then return true end
    for _,tile in pairs(connection.tiles)do
        if tile.z<q:getZ()then
            local objects=tile.square:getObjects()
            for i=0,objects:size()-1 do
                local fixture=objects:get(i)
                if live(fixture,tile.square)and fixture:getUsesExternalWaterSource()
                    and fixture:FindExternalWaterSource()==object then return true end
            end
        end
    end
    return false
end
-- Newly built networks use their real powered pump or gravity. The item is
-- hardware; all water remains in native source and receiving containers.
local function transferNetworkWater(connection)
    if not connection or not connection.owned then return end
    local group=members(connection);if not group then return end
    local powered=#connection.pumps>0
    for _,source in ipairs(group)do
        if H.waterProducer(source.object)=="sao"and waterOnly(source.fluid)and source.fluid:getAmount()>0 then
            for _,receiver in ipairs(group)do
                if receiver.object~=source.object and nativeHeader(receiver.object,connection)
                    and(source.z>receiver.z or powered and receiver.z>=source.z)
                    and live(source.object,source.object:getSquare())and source.object:getFluidContainer()==source.fluid
                    and live(receiver.object,receiver.object:getSquare())and receiver.object:getFluidContainer()==receiver.fluid
                    and(receiver.fluid:getAmount()==0 or waterOnly(receiver.fluid))
                    and FluidContainer.CanTransfer(source.fluid,receiver.fluid)then
                    local before,gainBefore=source.fluid:getAmount(),receiver.fluid:getAmount()
                    local wanted=math.min(before,receiver.fluid:getFreeCapacity())
                    if finite(wanted)and wanted>0 then
                        source.fluid:transferTo(receiver.fluid,wanted)
                        local debit,gain=before-source.fluid:getAmount(),receiver.fluid:getAmount()-gainBefore
                        if finite(debit)and finite(gain)and math.abs(debit-gain)<=.0001 then
                            receiver.object:getModData().SAOHouseholdLastLift={debit=debit,gain=gain}
                        end
                    end
                end
            end
        end
    end
end
local function liftWater(generator)
    local q=generator:getSquare()
    if not H.available()or not live(generator,q)or not generator:isConnected()or not generator:isActivated()
        or generator:getFuel()<=0 or not H.isGeneratorPlumbed(generator)or H.isForeignGenerator(generator)then return end
    local connection=H.connection(q:getX(),q:getY(),q:getZ());if not connection then return end
    local group=members(connection);if not group then return end
    for _,source in ipairs(group)do
        if H.waterProducer(source.object)=="sao"and H.isPumped(source.object)and waterOnly(source.fluid)and source.fluid:getAmount()>0 then
            for _,header in ipairs(group)do
                local marked=nativeHeader(header.object,connection)
                if marked and header.z>source.z and header.object~=source.object
                    and live(header.object,header.object:getSquare())and header.object:getFluidContainer()==header.fluid
                    and(header.fluid:getAmount()==0 or waterOnly(header.fluid))
                    and FluidContainer.CanTransfer(source.fluid,header.fluid)then
                    local beforeSource,beforeHeader=source.fluid:getAmount(),header.fluid:getAmount()
                    source.fluid:transferTo(header.fluid,math.min(beforeSource,header.fluid:getFreeCapacity()))
                    local debit,gain=beforeSource-source.fluid:getAmount(),header.fluid:getAmount()-beforeHeader
                    if finite(debit)and finite(gain)and math.abs(debit-gain)<=0.0001 then
                        header.object:getModData().SAOHouseholdLastLift={debit=debit,gain=gain}
                    end
                end
            end
        end
    end
end
function H.ownsWaterReceiver(object)
    if not H.available()or not object or not object:getUsesExternalWaterSource()then return false end
    local q=object:getSquare();if not live(object,q)then return false end
    local c=H.connection(q:getX(),q:getY(),q:getZ())
    local source=object:FindExternalWaterSource()
    local sq=source and source:getSquare()
    return c~=nil and live(source,sq)and c.tiles[key(sq:getX(),sq:getY(),sq:getZ())]~=nil
        and nativeHeader(source,c)
end
function H.purificationSampleCapacity()
    local sample=FluidContainer.CreateContainer()
    local capacity=sample:getCapacity();FluidContainer.DisposeContainer(sample)
    return finite(capacity)and capacity>0 and capacity or nil
end
function H.tick()
    if not H.available()then return end
    local visited={};local s=store()
    for _,part in pairs(s and s.pieces or{})do
        if H.currentPart(part)then
            local connection=H.connection(part.x,part.y,part.z)
            if connection and not visited[connection.structure]then
                visited[connection.structure]=true;transferNetworkWater(connection)
            end
        end
    end
    for object,square in pairs(loaded)do
        if not live(object,square)then loaded[object]=nil
        else transferFuel(object);liftWater(object)end
    end
end
function H.observeSquare(square)
    if not square or square:getCell()~=getCell()then return end
    local objects=square:getObjects()
    for i=0,objects:size()-1 do
        local object=objects:get(i)
        if instanceof(object,"IsoGenerator")and H.isGeneratorPlumbed(object)then loaded[object]=square end
    end
end
if Events then
    if Events.LoadGridsquare then
        if H.onSquare then Events.LoadGridsquare.Remove(H.onSquare)end
        H.onSquare=H.observeSquare;Events.LoadGridsquare.Add(H.onSquare)
    end
    if Events.OnTick then
        if H.onTick then Events.OnTick.Remove(H.onTick)end
        H.onTick=H.tick;Events.OnTick.Add(H.onTick)
    end
    if Events.OnInitGlobalModData then
        if H.onInit then Events.OnInitGlobalModData.Remove(H.onInit)end
        H.onInit=function()loaded={};partBindings={};graph,positions=nil,nil;H.refreshTopology()end
        Events.OnInitGlobalModData.Add(H.onInit)
    end
end
return H
