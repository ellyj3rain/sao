-- Personally observed hobby requirements use the existing exact SourceUse owner.
SAO = SAO or {}
SAO.LeisureAcquisition = SAO.LeisureAcquisition or {}
local A = SAO.LeisureAcquisition
local OWNERS = { ["SAO.Leisure"]="Leisure", ["SAO.LeisureExercise"]="LeisureExercise",
    ["SAO.LeisureArt"]="LeisureArt", ["SAO.LeisureMusic"]="LeisureMusic",
    ["SAO.LeisureGames"]="LeisureGames", ["SAO.LeisureRadio"]="LeisureRadio",
    ["SAO.LeisureLifestyle"]="LeisureLifestyle" }
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function plain(v)
    if type(v)~="table" then return v end
    local out={} for k,x in pairs(v) do out[k]=plain(x) end return out
end
local function live(id,body)
    return SAO.Needs and SAO.Needs.ownsRecoveryBody(id,body) and SAO.Needs.workAvailable(body)
end
function A.requirements(id,body,itemType)
    if not live(id,body) or type(itemType)~="string" or not SAOJavaBridge
        or not SAOJavaBridge.leisureMaterialRequirements then return {} end
    local ok,rows=pcall(function() return SAOJavaBridge:leisureMaterialRequirements(body,itemType) end)
    if not ok or type(rows)~="table" then return {} end
    local out={}
    for _,row in ipairs(rows) do
        if type(row)=="table" and OWNERS[row.owner] and row.itemType==itemType
            and type(row.family)=="string" and type(row.activity)=="string"
            and type(row.sourceId)=="string" and type(row.revision)=="string"
            and type(row.requirementId)=="string"
            and (row.role=="playable-item" or row.role=="material") then
            -- Station supplies have meaning only in a context this person acquired.
            local provider=SAO[OWNERS[row.owner]]
            local contextual=row.role=="playable-item"
            if contextual and provider and provider.playableRequirementAvailable then
                local accepted,value=pcall(provider.playableRequirementAvailable,id,body,plain(row))
                contextual=accepted and value==true
            end
            if row.role=="material" and provider and provider.materialRequirementAvailable then
                local accepted,value=pcall(provider.materialRequirementAvailable,id,body,plain(row))
                contextual=accepted and value==true
            end
            if contextual then out[#out+1]=plain(row) end
        end
    end
    return out
end
function A.offers(id,body)
    if not live(id,body) or not SAO.WorldSources or not SAO.Perception
        or not SAO.ProceduralPlanning then return {} end
    local out,seen={},{}
    for placeId,belief in pairs(SAO.Perception.knownPlaces(id,true) or {}) do
        if finite(belief.cx) and finite(belief.cy) and belief.z==math.floor(body:getZ()) then
            local place={id=placeId,sourceId=belief.sourceId,cx=belief.cx,cy=belief.cy,z=belief.z,
                minX=belief.minX,minY=belief.minY,maxX=belief.maxX,maxY=belief.maxY}
            local options=SAO.WorldSources.actionOptions(place,"leisure-material",id,body,1,"standing","acquire")
            for _,option in ipairs(options and options.options or {}) do
                local p=option.parameters
                if (p.sourceKind=="ground" or p.sourceKind=="container")
                    and SAO.ProceduralPlanning.leisureAcquisitionAvailable(id,p.sourceId,p.itemId,p.revision) then
                    for _,requirement in ipairs(A.requirements(id,body,p.itemType)) do
                        local key="acquire:"..option.id..":"..requirement.owner..":"..requirement.requirementId
                        if not seen[key] then
                            seen[key]=true
                            out[#out+1]={id=key,option=option,place=plain(place),requirement=requirement,
                                family=requirement.family,activity=requirement.activity,
                                itemKey=tostring(p.itemId),itemType=p.itemType,sourceId=p.sourceId,
                                distance=(p.sourceX-body:getX())^2+(p.sourceY-body:getY())^2}
                        end
                    end
                end
            end
        end
    end
    if SAO.Perception.sortEvidence then
        SAO.Perception.sortEvidence(out,function(a,b) return a.distance<b.distance
            or a.distance==b.distance and a.id<b.id end)
    end
    return out
end
function A.begin(id,body,row)
    if not live(id,body) or type(row)~="table" or not row.option or not row.requirement then return false end
    local exact
    for _,current in ipairs(A.offers(id,body)) do if current.id==row.id then exact=current;break end end
    if not exact then return false end
    for _,key in ipairs({"sourceId","itemId","itemType","revision","fingerprint"}) do
        if exact.option.parameters[key]~=row.option.parameters[key] then return false end
    end
    for _,key in ipairs({"owner","activity","sourceId","revision","requirementId","role"}) do
        if exact.requirement[key]~=row.requirement[key] then return false end
    end
    local purpose,step,place=SAO.ProceduralPlanning.planLeisureAcquisition(id,body,exact.option,exact.requirement,exact.place)
    local p=exact.option.parameters
    local started=purpose and step and SAO.SourceUse and SAO.SourceUse.beginAcquisition(id,body,place,p.category,{
        purposeId=purpose.id,purposeStepId=step.id,sourceId=p.sourceId,itemId=p.itemId,
        itemType=p.itemType,sourceRevision=p.revision})
    return started==true,purpose and purpose.id
end
-- A source receipt establishes custody. Only a fresh owner offer establishes use.
function A.acquiredPurpose(id,body,ownerName,offer)
    if not live(id,body) or not OWNERS[ownerName] or type(offer)~="table" then return nil end
    local candidates={}
    local items=SAOJavaBridge and SAOJavaBridge:privateCarriedItems(body)
    for index=0,(items and items:size() or 0)-1 do
        local item=items:get(index);local itemId=tostring(item:getID());local itemType=item:getFullType()
        local bound=offer.itemId and tostring(offer.itemId)==itemId and offer.itemType==itemType
            or offer.itemType==itemType and (offer.itemKey==itemId or offer.itemKey=="item:"..itemId..":"..itemType
                or offer.itemKey=="item:"..itemType..":"..itemId)
            or offer.mediaItemKey=="item:"..itemId..":"..itemType and offer.mediaItemType==itemType
            or offer.batteryItemKey=="item:"..itemId..":"..itemType and offer.batteryItemType==itemType
        for _,material in pairs(offer.materials or {}) do
            if material.id==itemId and material.itemType==itemType then bound=true end
        end
        if bound then
            local purpose=SAO.ProceduralPlanning.leisureAcquiredPurpose(id,itemId,itemType,ownerName,offer.activity)
            if purpose then candidates[#candidates+1]=purpose end
        end
    end
    return candidates[1]
end
