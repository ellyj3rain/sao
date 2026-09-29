-- Owned pharmacology. The person holds exposure, dependency and elapsed-time
-- state; the native body receives effects only while it is the physical owner.
require "SAO_PharmacologyProfiles"
SAO = SAO or {}
SAO.Pharmacology = SAO.Pharmacology or {}
local Ph = SAO.Pharmacology
local P = SAO.PharmacologyProfiles
local HISTORY_LIMIT, MAX_MINUTES = 64, 360
local MAX_SEQUENCE = 9007199254740991
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function copy(value)
    if type(value)~="table" then return value end
    local out={}; for key,item in pairs(value) do out[key]=copy(item) end
    return out
end
local function hours()
    local ok,value=pcall(function() return SAO.History.countyHours() end)
    return ok and finite(value) and value>=0 and value or nil
end
local function record(id)
    local ok,rec=pcall(function() return SAO.Identity.get(id) end)
    return ok and rec or nil
end
local function bound(rec,body,transaction)
    if not rec or rec.dead or not body then return false end
    if isClient and isClient() then return false end
    local ok,held=pcall(function()
        local owner=SAO.Body
        if not owner or (not transaction and owner.isTransitioning(rec)) or body:isDead() then return false end
        local md=body:getModData()
        if tostring(md.SAOPersonId)~=tostring(rec.id) then return false end
        if rec.bodyOwner==nil then
            return rec.bodyOwnerToken==nil and owner.active[rec.id]==body
                and owner.foreign[rec.id]==nil and md.SAOExternalOwner==nil
                and md.SAOExternalToken==nil and md.ZAOOwned~=true
        end
        return rec.bodyOwner=="ZAO" and type(rec.bodyOwnerToken)=="string"
            and rec.bodyOwnerToken~="" and owner.foreign[rec.id]==body
            and owner.active[rec.id]==nil and md.SAOExternalOwner=="ZAO"
            and md.SAOExternalToken==rec.bodyOwnerToken and md.ZAOOwned==true
    end)
    return ok and held==true
end
function Ph.ownsBody(rec,body) return bound(rec,body) end
local function history(s,event)
    s.events[#s.events+1]=event
    if #s.events>HISTORY_LIMIT then
        table.remove(s.events,1);s.dropped=(s.dropped or 0)+1
    end
end
local function seed(rec,key,now)
    local dependent=false
    if SAO.Habits and SAO.Habits.has then
        local ok,held=pcall(SAO.Habits.has,rec.id,key)
        dependent=ok and held==true
    end
    dependent=dependent or (rec.nncWithdrawal and rec.nncWithdrawal[key]==true)
    local last=rec.lastUseHours and rec.lastUseHours[key] or 0
    local clean=finite(last) and math.max(0,now-last)*6 or 0
    return {effect=0,amount=0,counter=dependent and math.min(2880,clean) or 0,
        dependent=dependent==true}
end
-- Legacy keys are read once for save continuity. They are data identifiers;
-- no external registry, callback or driver is invoked.
local LEGACY={
    sedatives={"NnCBenzoEffect","NnCBenzoAmount","NnCTenMinutesBenzoAddict"},
    cocaine={"NnCCokeEffect","NnCCokeAmount","NnCTenMinutesCokeHead"},
    stimulants={"NnCMethEffect","NnCMethAmount","NnCTenMinutesMethHead"},
    opioids={"NnCOpioidEffect","NnCOpioidAmount","NnCTenMinutesOpioidAddict"},
    psychedelics={"NnCMDMAEffect","NnCMDMAAmount","NnCTenMinutesMDMAAddict"},
    cannabis={"NnCWeeeeedEffect",false,"NnCTenMinutesPotHead"},
    steroids={"NnCSteroidEffect","NnCSteroidAmount","NnCTenMinutesSteroidAddict"},
}
local function ensure(rec,body,now,readOnly)
    if not rec or rec.dead or not finite(now) or now<0 or not P then return nil end
    if rec.pharmacology then
        return rec.pharmacology.version==1 and rec.pharmacology or nil
    end
    local s={version=1,minute=math.floor(now*60+0.0000001),families={},
        maintenance=0,issued=0,settled=0,events={},dropped=0,unobservedMinutes=0}
    for _,key in ipairs(P.order) do s.families[key]=seed(rec,key,now) end
    local md=nil
    if bound(rec,body,readOnly) then pcall(function() md=body:getModData() end) end
    if md then
        s.paranoid=P.sensitivityOf(body)
        for _,key in ipairs(P.order) do
            local f,old=s.families[key],LEGACY[key]
            if finite(md[old[1]]) then
                f.effect=clamp(md[old[1]],0,P.families[key].maximum)
            end
            if old[2] and finite(md[old[2]]) then f.amount=clamp(md[old[2]],0,1440) end
            if finite(md[old[3]]) then f.counter=clamp(md[old[3]],-2880,2880) end
        end
        if finite(md.NnCMethadoneEffect) then
            s.maintenance=clamp(md.NnCMethadoneEffect,0,145)
        end
    end
    if not readOnly then rec.pharmacology=s end
    return s
end
local function nativeStats(body)
    local result={}
    local ok=pcall(function()
        local stats=body:getStats()
        for _,name in ipairs(P.stats) do
            local value=stats:get(CharacterStat[name])
            if not finite(value) then error("missing native stat") end
            result[name]=value
        end
    end)
    return ok and result or nil
end
local function receiver(rec,body,s)
    if body then
        local stats=body:getStats()
        return {
            awake=not body:isAsleep(),
            get=function(name) return stats:get(CharacterStat[name]) end,
            set=function(name,value) stats:set(CharacterStat[name],value) end,
            add=function(name,delta)
                if delta>=0 then stats:add(CharacterStat[name],delta)
                else stats:remove(CharacterStat[name],-delta) end
            end,
            head=function(delta)
                local part=body:getBodyDamage():getBodyPart(BodyPartType.Head)
                part:setAdditionalPain(clamp(part:getAdditionalPain()+delta,0,125))
            end,
            painOff=function()
                stats:set(CharacterStat.PAIN,0)
                local parts=body:getBodyDamage():getBodyParts()
                for index=0,parts:size()-1 do
                    local part=parts:get(index)
                    if part:getStiffness()>0 then
                        part:setStiffness(0)
                        body:getFitness():removeStiffnessValue(BodyPartType.ToString(part:getType()))
                    end
                    part:setAdditionalPain(0)
                end
            end,
        }
    end
    local d=s.dormant
    if not d or type(d.stats)~="table" then return nil end
    -- Rest remains its existing owner's work. The dormant caller advances
    -- rest to this minute before advancing pharmacology, so effects compose
    -- on the current fatigue/endurance instead of an old captured baseline.
    if finite(rec.dormantFatigue) then d.stats.FATIGUE=rec.dormantFatigue end
    if finite(rec.dormantEndurance) then d.stats.ENDURANCE=rec.dormantEndurance end
    local function set(name,value)
        local limit=d.limits[name]
        d.stats[name]=clamp(value,limit.minimum,limit.maximum);d.changed[name]=true
        if name=="FATIGUE" then rec.dormantFatigue=d.stats[name] end
        if name=="ENDURANCE" then rec.dormantEndurance=d.stats[name] end
    end
    return {awake=rec.dormantSleeping==false,
        get=function(name) return d.stats[name] end,set=set,
        add=function(name,delta) set(name,d.stats[name]+delta) end,
        head=function(delta) d.headPain=clamp(d.headPain+delta,0,125);d.headChanged=true end,
        painOff=function() set("PAIN",0);d.painOff=true;d.headPain=0 end}
end
local function packet(r,values)
    for _,entry in ipairs(values) do r.add(entry[1],entry[2]) end
end
local function active(s,key)
    local f,rule=s.families[key],P.families[key]
    return f.effect>=rule.activeMin and f.effect<=rule.activeMax
end
local function overloaded(s,key)
    local threshold=P.families[key].overload
    return threshold and s.families[key].amount>threshold or false
end
local function unpleasant(r,amount)
    r.add("UNHAPPINESS",amount);r.add("DISCOMFORT",amount)
end
local function calm(r,all)
    r.set("PANIC",0);r.set("STRESS",0)
    if all then r.set("BOREDOM",0);r.set("UNHAPPINESS",0);r.set("DISCOMFORT",0)
    else r.set("NICOTINE_WITHDRAWAL",0) end
end
local function stimulation(r,key,over,paranoid,hangover)
    if over then
        if key~="psychedelics" then r.add("HUNGER",-.01) end
        packet(r,{{"THIRST",.001},{"FATIGUE",.04},{"ENDURANCE",-.04},{"STRESS",.25}})
        r.set("BOREDOM",0);unpleasant(r,5)
    elseif hangover then
        local change=key=="psychedelics" and .02 or .04
        r.add("FATIGUE",change);r.add("ENDURANCE",-change)
        local grief=key=="psychedelics" and 2 or 3
        r.add("BOREDOM",grief);unpleasant(r,grief)
        if key~="psychedelics" then r.head(3) end
    else
        if key~="psychedelics" then r.add("HUNGER",-.01) end
        packet(r,{{"THIRST",.001},{"FATIGUE",-.01},{"ENDURANCE",.01}})
        r.set("BOREDOM",0)
        if paranoid then r.add("PANIC",25);r.add("STRESS",.25);unpleasant(r,5)
        else r.set("UNHAPPINESS",0);r.set("DISCOMFORT",0) end
    end
end
local function effects(s,r)
    if not r or not r.awake then return end
    local paranoid=s.paranoid==true
    if overloaded(s,"sedatives") then
        packet(r,{{"FATIGUE",.1},{"ENDURANCE",-.1}});unpleasant(r,5)
    elseif active(s,"sedatives") then
        local opioids=s.families.opioids.effect
        if opioids>=2 and opioids<=37 then
            packet(r,{{"FATIGUE",.01},{"ENDURANCE",-.01}})
        elseif r.get("INTOXICATION")>0 then
            packet(r,{{"INTOXICATION",5},{"FATIGUE",.01},{"ENDURANCE",-.01}})
        end
        calm(r,false)
    end
    for _,key in ipairs({"cocaine","stimulants","psychedelics"}) do
        local effect=s.families[key].effect
        local hangover=effect>=1 and effect<=2
        if overloaded(s,key) or active(s,key) or hangover then
            stimulation(r,key,overloaded(s,key),paranoid,hangover)
        end
    end
    if overloaded(s,"opioids") or (active(s,"opioids") and r.get("INTOXICATION")>0) then
        if not overloaded(s,"opioids") then r.add("INTOXICATION",5) end
        packet(r,{{"FATIGUE",.1},{"ENDURANCE",-.1},{"BOREDOM",-5}});unpleasant(r,5)
    elseif active(s,"opioids") then
        packet(r,{{"FATIGUE",.01},{"ENDURANCE",-.01},{"BOREDOM",-5}})
        if paranoid then r.add("PANIC",25);r.add("STRESS",.25);unpleasant(r,5)
        else unpleasant(r,-5) end
    elseif s.families.opioids.effect>=1 and s.families.opioids.effect<=2 then
        packet(r,{{"FATIGUE",.04},{"ENDURANCE",-.04},{"BOREDOM",3}});unpleasant(r,3)
    end
    if active(s,"cannabis") then
        packet(r,{{"HUNGER",.001},{"THIRST",.001},{"FATIGUE",.001},{"ENDURANCE",-.001}})
        if paranoid then r.add("PANIC",25);r.add("STRESS",.25);r.set("BOREDOM",0);unpleasant(r,5)
        else calm(r,true) end
    end
    -- Pain suppression is a native symptom effect, not wound healing.
    if active(s,"cocaine") or active(s,"stimulants") or active(s,"opioids") or active(s,"cannabis") then
        r.painOff()
    end
    if overloaded(s,"steroids") then
        packet(r,{{"ENDURANCE",-.04},{"FATIGUE",.04},{"ANGER",15},{"STRESS",.1},
            {"UNHAPPINESS",15},{"DISCOMFORT",5}})
    elseif active(s,"steroids") then
        packet(r,{{"ENDURANCE",.01},{"FATIGUE",-.01},{"ANGER",paranoid and 10 or 5}})
        if paranoid then r.add("PANIC",25);r.add("STRESS",.25) end
        unpleasant(r,5)
    end
end
local function draw(rec,key,minute,salt,n)
    return SAO.Hash.of(tostring(rec.id),"pharmacology:"..key..":"..minute..":"..salt)%n==0
end
local function withdrawal(rec,s,key,r,minute)
    local f,rule=s.families[key],P.families[key]
    if not r or not r.awake or not f.dependent or not rule.medium
        or (key=="opioids" and s.maintenance>0) then return end
    local mild=f.counter>=rule.mild
    local medium=f.counter>=rule.medium and f.counter<=rule.mild
    local bad=f.counter>=rule.bad and f.counter<=rule.mild
    local function small(head)
        r.add("FATIGUE",.01);r.add("ENDURANCE",-.05)
        if key=="steroids" and head then r.add("UNHAPPINESS",10)
        else r.add("STRESS",.05) end
        if key~="opioids" and key~="steroids" then
            r.add("HUNGER",(key=="sedatives" or key=="psychedelics") and -.01 or .01)
            r.add("THIRST",.01)
        end
        if key=="sedatives" then r.add("PANIC",10)
        elseif head and key~="steroids" then r.head(25) end
    end
    if medium and draw(rec,key,minute,"medium",2) then small(true) end
    if mild and draw(rec,key,minute,"mild",3) then small(false) end
    if bad and draw(rec,key,minute,"bad",5) then
        packet(r,{{"FATIGUE",.05},{"ENDURANCE",-.05},{"STRESS",.05},
            {"UNHAPPINESS",15},{"DISCOMFORT",15}})
        if key~="steroids" then r.add("BOREDOM",15) end
        if key~="opioids" and key~="steroids" then
            r.add("HUNGER",(key=="sedatives" or key=="psychedelics") and -.05 or .05)
            r.add("THIRST",.05)
        end
        if key=="sedatives" then r.add("PANIC",50) end
    end
end
local function dependency(rec,s,key,minute,r,quiet)
    local f,rule=s.families[key],P.families[key]
    local frozen=key=="opioids" and s.maintenance>0
    if not frozen then f.counter=math.min(2880,f.counter+1) end
    f.effect=math.max(0,f.effect-1);f.amount=math.max(0,f.amount-rule.clearance)
    local threshold=2592+SAO.Hash.of(tostring(rec.id),"pharmacology:"..key..":dependency")%288
    local was=f.dependent
    if f.dependent then
        f.counter=math.max(0,f.counter)
        withdrawal(rec,s,key,r,minute)
        if not frozen and f.counter>=threshold then f.dependent=false;f.counter=0 end
    else
        f.counter=math.min(0,f.counter)
        if f.counter<=-threshold then f.dependent=true;f.counter=0 end
    end
    if was~=f.dependent and not quiet then
        rec.habitsGained=rec.habitsGained or {};rec.habitsQuit=rec.habitsQuit or {}
        rec.habitsGained[key]=f.dependent or nil;rec.habitsQuit[key]=not f.dependent or nil
        history(s,{kind="dependency",family=key,dependent=f.dependent,atHours=minute/60})
    end
end
local function hasInfluence(s)
    if s.maintenance>0 then return true end
    for _,key in ipairs(P.order) do
        local f=s.families[key]
        if f.effect>0 or f.amount>0 or f.dependent or f.counter~=0 then return true end
    end
    return false
end
local function advance(rec,body,now,restoring)
    if isClient and isClient() then return false,"server-authority-required" end
    if not finite(now) or now<0 or (body and not bound(rec,body)) then return false,"invalid-owner-time" end
    if not body and not restoring and rec and SAO.Body
        and (SAO.Body.active[rec.id] or SAO.Body.foreign[rec.id]) then
        return false,"live-body-required"
    end
    local s=ensure(rec,body,now)
    if not s then return false,"state-unavailable" end
    if s.fault then return false,"effect-reconciliation-required" end
    if body and s.dormant then return false,"dormant-restore-required" end
    if not body and not s.dormant and s.saved then s.dormant=copy(s.saved) end
    local target=math.floor(now*60+0.0000001)
    if target<s.minute then return false,"clock-regression" end
    local finish=math.min(target,s.minute+MAX_MINUTES)
    local r=receiver(rec,body,s)
    while s.minute<finish do
        local minute=s.minute+1
        local before=body and nativeStats(body) or nil
        -- A native receiver exception may follow a partial physical write.
        -- Retain an explicit fault and never replay that minute silently.
        s.minute=minute
        local applied,reason=pcall(function()
            if minute%10==0 then
                for _,key in ipairs(P.order) do dependency(rec,s,key,minute,r) end
                if s.maintenance>0 then
                    s.maintenance=math.max(0,s.maintenance-1)
                    if s.maintenance==0 and SAO.Habits then
                        SAO.Habits.resumeUse(rec.id,"opioids",minute/60)
                    end
                end
            end
            effects(s,r)
        end)
        if not applied then
            s.fault={minute=minute,detail=string.sub(tostring(reason),1,512)}
            return false,"effect-reconciliation-required"
        end
        if before then
            local after=nativeStats(body)
            local changes={};local changed=false
            if after then
                for _,name in ipairs(P.stats) do
                    if before[name]~=after[name] then
                        changes[name]={before=before[name],after=after[name]};changed=true
                    end
                end
            end
            if changed then
                local receipt={kind="physical-change",minute=minute,atHours=minute/60,
                    observedAtHours=now,stats=changes,exposures=copy(s.lastDoses or {})}
                history(s,copy(receipt))
                if Ph.onNativeChange then pcall(Ph.onNativeChange,tostring(rec.id),copy(receipt)) end
            end
        end
        if not r then s.unobservedMinutes=s.unobservedMinutes+1 end
    end
    s.atHours=s.minute/60
    if body then s.observed={atHours=s.atHours,stats=nativeStats(body)} end
    return finish==target,finish==target and "current" or "catching-up"
end
function Ph.advance(rec,body,now) return advance(rec,body,now,false) end
-- Rest remains an existing owner. Its callback advances to each county-minute
-- boundary before this module composes that minute's physical effects.
function Ph.advanceDormant(rec,now,advanceOwner)
    if type(advanceOwner)~="function" or not finite(now) or not rec or rec.dead
        or (SAO.Body and (SAO.Body.active[rec.id] or SAO.Body.foreign[rec.id])) then
        return false,"invalid-dormant-owner"
    end
    local s=ensure(rec,nil,now)
    if not s then return false,"state-unavailable" end
    if s.fault then return false,"effect-reconciliation-required" end
    local target=math.floor(now*60+0.0000001)
    if target<s.minute then return false,"clock-regression" end
    local finish=math.min(target,s.minute+MAX_MINUTES)
    local cursor=tonumber(rec.dormantPhysiologyAtHours)
        or (s.dormant or s.saved or {}).atHours or s.minute/60
    while s.minute<finish do
        if not hasInfluence(s) then
            if now>cursor and advanceOwner(now-cursor,now,nil)~=true then
                return false,"dormant-owner-refused"
            end
            s.minute=target;s.atHours=target/60
            return true,"current"
        end
        local to=(s.minute+1)/60
        if to>cursor then
            if advanceOwner(to-cursor,to,nil)~=true then return false,"dormant-owner-refused" end
            cursor=to
        end
        local ok,reason=advance(rec,nil,to,false)
        if not ok then return false,reason end
    end
    if finish==target and now>cursor then
        if advanceOwner(now-cursor,now,nil)~=true then return false,"dormant-owner-refused" end
    end
    return finish==target,finish==target and "current" or "catching-up"
end
function Ph.familyForItem(item)
    local ok,name=pcall(function() return item:getFullType() end)
    return ok and P.items[name] and P.items[name].family or nil
end
function Ph.captureUse(id,body,item)
    local rec,now=record(id),hours()
    if not bound(rec,body) then return nil,"invalid-owner" end
    if not now then return nil,"clock-unavailable" end
    local ok,full,itemId,uses=pcall(function()
        if item:getOutermostContainer()~=body:getInventory() then error("foreign item") end
        return item:getFullType(),item:getID(),item:getCurrentUses()
    end)
    if not ok then return nil,"invalid-item-owner" end
    if not P.items[full] then return nil,"unregistered-item" end
    if not finite(uses) or uses<=0 then return nil,"no-native-dose" end
    local current,reason=Ph.advance(rec,body,now)
    if not current then return nil,reason end
    local s=rec.pharmacology
    if s.issued>=MAX_SEQUENCE then return nil,"sequence-exhausted" end
    s.issued=s.issued+1
    return {actorId=tostring(id),sequence=s.issued,body=body,item=item,itemId=itemId,
        itemType=full,beforeUses=uses,atHours=now,settled=false,
        owner=rec.bodyOwner or "SAO",ownerToken=rec.bodyOwnerToken or false}
end
-- Called before the native completion callback consumes the item. A delayed
-- action waits for its existing physiology owner instead of losing a dose's
-- effects because the bounded clock catch-up has not reached completion time.
function Ph.prepareUse(token,body)
    if type(token)~="table" or token.settled then return false,"already-settled" end
    local rec,now=record(token.actorId),hours()
    local s=rec and rec.pharmacology
    if not s or token.sequence<=s.settled or token.sequence>s.issued then return false,"stale-token" end
    if token.body~=body or not bound(rec,body) or not now or now<token.atHours
        or token.owner~=(rec.bodyOwner or "SAO") or token.ownerToken~=(rec.bodyOwnerToken or false) then
        return false,"native-completion-unavailable"
    end
    local ok,exact=pcall(function()
        return token.item:getID()==token.itemId and token.item:getFullType()==token.itemType
            and token.item:getOutermostContainer()==body:getInventory()
            and token.item:getCurrentUses()==token.beforeUses
    end)
    if not ok or not exact then return false,"native-dose-changed" end
    return Ph.advance(rec,body,now)
end
function Ph.interruptUse(token,reason)
    if type(token)~="table" or token.settled then return false end
    local rec=record(token.actorId);local s=rec and rec.pharmacology
    if not s or token.sequence<=s.settled or token.sequence>s.issued then return false end
    token.settled=true;s.settled=token.sequence
    history(s,{kind="use",sequence=token.sequence,itemId=token.itemId,itemType=token.itemType,
        atHours=hours() or token.atHours,status="censored",reason=tostring(reason or "interrupted")})
    return true
end
function Ph.completeUse(token,body,completed)
    if type(token)~="table" or token.settled then return nil,"already-settled" end
    local rec,now=record(token.actorId),hours()
    local s=rec and rec.pharmacology
    if not s or token.sequence<=s.settled or token.sequence>s.issued then return nil,"stale-token" end
    if completed~=true or token.body~=body or not bound(rec,body) or not now or now<token.atHours
        or token.owner~=(rec.bodyOwner or "SAO") or token.ownerToken~=(rec.bodyOwnerToken or false) then
        Ph.interruptUse(token,"native-completion-unavailable");return nil,"native-completion-unavailable"
    end
    local ok,after=pcall(function()
        if token.item:getID()~=token.itemId or token.item:getFullType()~=token.itemType then
            error("item replaced")
        end
        return token.item:getCurrentUses()
    end)
    if not ok or not finite(after) or after<0 or after>=token.beforeUses
        or token.beforeUses-after~=1 then
        Ph.interruptUse(token,"native-dose-not-consumed");return nil,"native-dose-not-consumed"
    end
    if not Ph.advance(rec,body,now) then return nil,"clock-not-current" end
    local profile=P.items[token.itemType]
    local portion=token.beforeUses-after
    token.settled=true;s.settled=token.sequence
    s.lastDoses=s.lastDoses or {};s.lastDoses[profile.family]=token.sequence
    if profile.family=="maintenance" then
        s.maintenance=math.max(s.maintenance,profile.onset*portion)
        if SAO.Habits then SAO.Habits.freezeUse(rec.id,"opioids",now) end
    else
        local f=s.families[profile.family]
        f.effect=f.effect<=0 and profile.onset*portion
            or math.max(f.effect,profile.refresh*portion)
        f.effect=math.min(P.families[profile.family].maximum,f.effect)
        f.amount=math.min(1440,f.amount+profile.amount*portion)
        f.counter=math.max(-2880,f.counter-(f.dependent and profile.dependentUse or profile.use)*portion)
        if SAO.Habits then SAO.Habits.used(rec.id,profile.family,now) end
        if profile.smoked and body:hasTrait(CharacterTrait.SMOKER) then
            body:getStats():set(CharacterStat.NICOTINE_WITHDRAWAL,0)
            body:setTimeSinceLastSmoke(0)
        end
    end
    local receipt={kind="use",sequence=token.sequence,actorId=token.actorId,
        itemId=token.itemId,itemType=token.itemType,atHours=now,status="completed",
        consumed=portion,family=profile.family}
    history(s,copy(receipt));return receipt
end
function Ph.dependent(rec,key)
    local s=rec and rec.pharmacology
    local f=s and s.version==1 and s.families[key]
    return f and f.dependent==true or false
end
function Ph.ownsWithdrawal(rec,key)
    local s=rec and rec.pharmacology
    return s and s.version==1 and s.families[key]~=nil or false
end
function Ph.tier(rec,key)
    local s=rec and rec.pharmacology;local f=s and s.families[key];local rule=P.families[key]
    if not f or not rule or not f.dependent or not rule.medium
        or (key=="opioids" and s.maintenance>0) or f.counter<rule.medium then return nil end
    if f.counter<rule.bad then return "medium" end
    if f.counter<rule.mild then return "bad" end
    return "mild"
end
function Ph.effects(rec)
    local s=rec and rec.pharmacology
    if not s or s.version~=1 then return nil end
    local out={atHours=s.atHours or s.minute/60,active=false,sedating=false,
        stimulating=false,overload=false,withdrawal=false,painSuppressed=false,families={}}
    for _,key in ipairs(P.order) do
        if active(s,key) or overloaded(s,key) then
            out.active=true;out.families[#out.families+1]=key
            if key=="sedatives" or key=="opioids" or key=="cannabis" then out.sedating=true
            else out.stimulating=true end
        end
        if overloaded(s,key) then out.overload=true end
        if Ph.tier(rec,key) then out.withdrawal=true end
    end
    out.painSuppressed=active(s,"cocaine") or active(s,"stimulants")
        or active(s,"opioids") or active(s,"cannabis")
    return out
end
-- The body owner stages this data with the native hibernation snapshot and
-- calls enterDormancy only when that ownership transaction commits.
function Ph.checkpoint(rec,body,now)
    if not bound(rec,body,true) or not finite(now) then return nil end
    local stats=nativeStats(body)
    if not stats then return nil end
    local ok,pain=pcall(function()
        return body:getBodyDamage():getBodyPart(BodyPartType.Head):getAdditionalPain()
    end)
    if not ok or not finite(pain) then return nil end
    local limits={}
    for _,name in ipairs(P.stats) do
        limits[name]={minimum=CharacterStat[name]:getMinimumValue(),
            maximum=CharacterStat[name]:getMaximumValue()}
    end
    local s=ensure(rec,body,now,true)
    if not s or s.fault then return nil end
    return {version=1,actorId=tostring(rec.id),atHours=now,stats=stats,limits=limits,
        headPain=pain,changed={},sleeping=body:isAsleep(),resting=body:isSitOnGround(),
        origin={minute=s.minute,families=copy(s.families),maintenance=s.maintenance,
            paranoid=s.paranoid==true,stats=copy(stats),headPain=pain}}
end
function Ph.validCheckpoint(rec,checkpoint)
    if type(checkpoint)~="table" or checkpoint.version~=1
        or not rec or checkpoint.actorId~=tostring(rec.id)
        or not finite(checkpoint.atHours) or checkpoint.atHours<0
        or not finite(checkpoint.headPain) or type(checkpoint.stats)~="table"
        or type(checkpoint.limits)~="table" or type(checkpoint.sleeping)~="boolean"
        or type(checkpoint.resting)~="boolean"
        or type(checkpoint.origin)~="table" then return false end
    local origin=checkpoint.origin
    if not finite(origin.minute) or origin.minute<0 or origin.minute%1~=0
        or origin.minute>math.floor(checkpoint.atHours*60+0.0000001)
        or not finite(origin.maintenance) or origin.maintenance<0 or origin.maintenance>145
        or type(origin.families)~="table" or type(origin.stats)~="table"
        or not finite(origin.headPain) then return false end
    for _,key in ipairs(P.order) do
        local f=origin.families[key]
        if type(f)~="table" or not finite(f.effect) or f.effect<0 or f.effect>P.families[key].maximum
            or not finite(f.amount) or f.amount<0 or f.amount>1440 or not finite(f.counter)
            or f.counter< -2880 or f.counter>2880 or type(f.dependent)~="boolean" then return false end
    end
    for _,name in ipairs(P.stats) do
        local value,limit=checkpoint.stats[name],checkpoint.limits[name]
        if not finite(value) or type(limit)~="table" or not finite(limit.minimum)
            or not finite(limit.maximum) or limit.minimum>limit.maximum
            or value<limit.minimum or value>limit.maximum or not finite(origin.stats[name])
            or origin.stats[name]<limit.minimum or origin.stats[name]>limit.maximum then return false end
    end
    return true
end
function Ph.commitCheckpoint(rec,checkpoint)
    if not Ph.validCheckpoint(rec,checkpoint) then return false end
    local first=rec.pharmacology==nil
    local s=ensure(rec,nil,checkpoint.atHours)
    if not s or checkpoint.atHours+0.0000001<s.minute/60 then return false end
    if first then
        s.minute=checkpoint.origin.minute;s.families=copy(checkpoint.origin.families)
        s.maintenance=checkpoint.origin.maintenance;s.paranoid=checkpoint.origin.paranoid
    end
    s.saved=copy(checkpoint)
    return true
end
function Ph.enterDormancy(rec,checkpoint)
    if not Ph.commitCheckpoint(rec,checkpoint) then return false end
    local s=rec.pharmacology
    s.dormant=copy(checkpoint)
    return true
end
function Ph.restore(rec,body,now,advanceOwner)
    if not bound(rec,body,true) then return false,"invalid-owner" end
    local s=rec.pharmacology
    if not s then return true end
    local d=s.dormant or s.saved
    if not d then return true end
    if not Ph.validCheckpoint(rec,d) or not finite(now) or now<d.atHours
        or s.fault then return false,"invalid-dormant-origin" end
    if type(advanceOwner)~="function" and now>d.atHours then
        return false,"physiology-owner-required"
    end
    -- One bounded origin replaces a history of synthetic minute observations.
    -- Replay reaches the real restored body; prior dependency events are not
    -- emitted again and replay never creates a felt-experience callback.
    local work=copy(d.origin)
    work.events=copy(s.events);work.dropped=s.dropped
    local historyRec={id=rec.id,habitsGained=copy(rec.habitsGained),habitsQuit=copy(rec.habitsQuit)}
    local r=receiver(rec,body,work)
    local target=math.floor(now*60+0.0000001)
    local cursor=d.atHours
    local resumeAt=nil
    local ok=pcall(function()
        local original=copy(d);original.stats=copy(d.origin.stats);original.headPain=d.origin.headPain
        if advanceOwner and advanceOwner(0,d.atHours,original)~=true then error("owner-origin-refused") end
        local replayed=0
        while work.minute<target and hasInfluence(work) do
            replayed=replayed+1
            -- The admitted counters settle within 2880 ten-minute units plus
            -- the largest maintenance window. Refuse malformed longer state.
            if replayed>(2880+145)*10 then error("origin-horizon-exceeded") end
            local minute=work.minute+1
            local to=minute/60
            if to>cursor then
                if advanceOwner and advanceOwner(to-cursor,to,nil)~=true then error("owner-step-refused") end
                cursor=to
            end
            r.awake=not body:isAsleep()
            if minute%10==0 then
                for _,key in ipairs(P.order) do dependency(historyRec,work,key,minute,r,minute<=s.minute) end
                if work.maintenance>0 then
                    work.maintenance=math.max(0,work.maintenance-1)
                    if work.maintenance==0 and minute>s.minute then resumeAt=to end
                end
            end
            effects(work,r)
            rec.dormantFatigue=r.get("FATIGUE");rec.dormantEndurance=r.get("ENDURANCE")
            work.minute=minute
        end
        if now>cursor and advanceOwner and advanceOwner(now-cursor,now,nil)~=true then
            error("owner-tail-refused")
        end
        work.minute=target
        if s.paranoid and P.sensitivityTrait then
            body:getCharacterTraits():set(P.sensitivityTrait,true)
        end
    end)
    if not ok then return false,"native-restore-refused" end
    s.families=work.families;s.maintenance=work.maintenance;s.minute=target;s.atHours=target/60
    s.events=work.events;s.dropped=work.dropped
    rec.habitsGained=historyRec.habitsGained;rec.habitsQuit=historyRec.habitsQuit
    if resumeAt and SAO.Habits then SAO.Habits.resumeUse(rec.id,"opioids",resumeAt) end
    s.dormant=nil;s.saved=nil;return true
end
function Ph.snapshot(rec)
    local s=rec and rec.pharmacology
    return s and copy(s) or nil
end
return Ph
