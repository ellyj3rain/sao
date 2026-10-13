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
local function footprints(p)
    if p.kind=="floor"then return{{p.x,p.y,p.z}}end
    local dx,dy=p.north and 0 or -1,p.north and -1 or 0
    return{{p.x,p.y,p.z},{p.x+dx,p.y+dy,p.z},{p.x,p.y,p.z+1},{p.x+dx,p.y+dy,p.z+1}}
end
local function piece(row,kind)
    if type(row)~="table"or getmetatable(row)or not coordinate(row.x)or not coordinate(row.y)or not coordinate(row.z)
        or kind=="wall"and type(row.north)~="boolean"then return nil end
    return{x=row.x,y=row.y,z=row.z,kind=kind,north=kind=="wall"and row.north or nil}
end
function H.refreshTopology()
    local s=store();if not s then return false end
    -- Read existing pipe geometry only. Unknown formats confer no connection.
    local legacy=ModData.get and ModData.get("LGExtendedPlumbing")
    if legacy~=nil and (type(legacy)~="table"or getmetatable(legacy)
        or type(legacy.floors)~="table"or type(legacy.walls)~="table")then graph,positions=nil,nil;return false end
    local rows,seen={},{}
    local function append(raw,kind,origin)
        for _,v in pairs(raw or{})do
            local p=piece(v,kind)
            if not p then return false end
            local id=key(p.x,p.y,p.z)..":"..kind..(kind=="wall"and(p.north and":N"or":W")or"")
            if seen[id]then return false end
            seen[id]=true;p.id=id;p.origin=origin;rows[#rows+1]=p
        end
        return true
    end
    if not append(s.pieces,"floor","sao-existing-network")
        or legacy and(not append(legacy.floors,"floor","legacy-lgep-data")or not append(legacy.walls,"wall","legacy-lgep-data"))then
        graph,positions=nil,nil;return false
    end
    ordering(rows,function(a,b)return a.id<b.id end)
    local index={}
    for i,p in ipairs(rows)do
        p.tiles=footprints(p)
        for _,v in ipairs(p.tiles)do local k=key(v[1],v[2],v[3]);index[k]=index[k]or{};index[k][#index[k]+1]=i end
    end
    graph,positions=rows,index
    return true
end
function H.connection(x,y,z)
    if not H.available()or not coordinate(x)or not coordinate(y)or not coordinate(z)or not H.refreshTopology()then return nil end
    local initial=positions[key(x,y,z)]
    if not initial then return nil end
    local queue,seen={},{}
    for _,i in ipairs(initial)do queue[#queue+1]=i;seen[i]=true end
    local cursor=1
    while queue[cursor]do
        local p=graph[queue[cursor]]
        for _,v in ipairs(p.tiles)do
            for dx=-1,1 do for dy=-1,1 do
                for _,i in ipairs(positions[key(v[1]+dx,v[2]+dy,v[3])]or{})do
                    if not seen[i]then seen[i]=true;queue[#queue+1]=i end
                end
            end end
        end
        cursor=cursor+1
    end
    local tiles,rows={},{}
    for _,i in ipairs(queue)do
        local p=graph[i];rows[#rows+1]=p.id
        for _,v in ipairs(p.tiles)do
            local square=getCell():getGridSquare(v[1],v[2],v[3])
            if not square then return nil end
            tiles[key(v[1],v[2],v[3])]={x=v[1],y=v[2],z=v[3],square=square}
        end
    end
    ordering(rows,function(a,b)return a<b end)
    return{structure="sao-pipe:"..table.concat(rows,";"),tiles=tiles}
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
    return fc and(fc:isPureFluid(Fluid.Water)or fc:isPureFluid(Fluid.TaintedWater))
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
        H.onInit=function()loaded={};graph,positions=nil,nil;H.refreshTopology()end
        Events.OnInitGlobalModData.Add(H.onInit)
    end
end
return H
