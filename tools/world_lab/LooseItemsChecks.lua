-- Real native items/world objects; controlled geometry, unloaded lookup and refusal injections.
local checks = 0
local function empty(value) for _ in pairs(value) do return false end return true end
local function check(ok, name)
    assert(ok, name); checks = checks + 1; print("PASS " .. name)
end
local clock, world, loaded, square, calls, mode, allocations = 2, "isolated-floor-save", true, nil, 0, nil, 0
local function noop() end
beginExport, flushExports, applyInitialNeeds, applyInitialThreats = noop, noop, noop, noop
applyResourceObjectives, applyHorseTravel, applyMobileHousehold, liveInspection = noop, noop, noop, noop
function isGamePaused() return true end
function getWorld() return {getWorld = function() return world end} end
function getGameTime() return {getWorldAgeHours = function() return clock end} end
local config, journal, owner
local function row()
    return {id="floor-harmonica",siteId="home",x=128,y=128,z=1,fullType="Base.Harmonica",count=2}
end
function instanceItem(fullType)
    allocations = allocations + 1
    local attempt = journal.situationReceipt and journal.situationReceipt.initialLooseItems
        and journal.situationReceipt.initialLooseItems.placements[config.situation.initialLooseItems[1].id]
    check(attempt and attempt.status=="attempted" and attempt.items[tostring(allocations)]
        and attempt.items[tostring(allocations)].status=="attempted", "journal_precedes_native_allocation")
    if mode=="missing-item" then return nil end
    if mode=="foreign-type" then fullType="Base.Notebook" end
    local item=__item(fullType)
    __lastFixtureItem=item
    if mode=="reused-id" then item:setID(42) end
    return item
end
function getCell()
    return {getGridSquare=function(_,x,y,z)
        if not loaded then return nil end
        return square
    end}
end
local function reset()
    clock,world,loaded,calls,mode,allocations=2,"isolated-floor-save",true,0,nil,0
    square=__square(1);__fault(square,0);config={definitionSha256=string.rep("a",64),situation={initialLooseItems={row()}}}
    journal={};owner=LoadPlacement(config,journal)
end
local function receipt() return journal.situationReceipt.initialLooseItems.placements[config.situation.initialLooseItems[1].id] end
reset();loaded=false;owner.tick()
check(empty(journal) and allocations==0,"unloaded_square_no_journal_or_allocation")
loaded=true;owner.tick()
local placed=journal.situationReceipt and journal.situationReceipt.initialLooseItems
    and journal.situationReceipt.initialLooseItems.placements[config.situation.initialLooseItems[1].id]
if placed and placed.status~="completed" then
    print("PLACEMENT_REFUSAL "..tostring(receipt().reason).." worldCount="..square:getWorldObjects():size())
    local w=__lastFixtureItem and __lastFixtureItem:getWorldItem()
    print("NATIVE_ITEM "..tostring(__lastFixtureItem).." world="..tostring(w).." square="..tostring(w and w:getSquare()==square))
end
check(placed and placed.status=="completed" and placed.created==2 and square:getWorldObjects():size()==2,"actual_tick_places_exact_native_objects")
local first=square:getWorldObjects():get(0):getItem()
check(first:getFullType()=="Base.Harmonica" and first:getWorldItem():getSquare()==square
    and receipt().items["1"].itemId==tostring(first:getID()),"exact_native_type_id_world_square")
local frozen=owner.encode(journal);owner.tick()
check(owner.encode(journal)==frozen and allocations==2 and square:getWorldObjects():size()==2,"repeat_tick_does_not_duplicate")
journal=__roundtrip(journal);owner=LoadPlacement(config,journal);owner.tick()
check(owner.encode(journal)==frozen and allocations==2,"native_serialized_reload_no_duplicate")
square:getWorldObjects():clear();square:getObjects():remove(first:getWorldItem());first:setWorldItem(nil)
owner.tick();check(allocations==2 and receipt().status=="completed","later_acquisition_never_respawns")
for _,key in ipairs({"definitionSha256","save","configuration"}) do
    local original=journal.situationReceipt.initialLooseItems[key]
    journal.situationReceipt.initialLooseItems[key]="foreign"
    local ok=pcall(owner.tick);check(not ok and allocations==2,"reject_foreign_"..key)
    journal.situationReceipt.initialLooseItems[key]=original
end
local original=receipt().fullType;receipt().fullType="Base.Notebook"
check(not pcall(owner.tick) and allocations==2,"reject_foreign_receipt_type");receipt().fullType=original
reset();loaded=false;owner.tick();__fault(square,1);loaded=true;owner.tick()
check(receipt().status=="refused" and allocations==0 and square:getWorldObjects():size()==0,"missing_floor_refused_before_allocation")
for ground=2,4 do
    reset();__fault(square,ground);owner.tick()
    check(receipt().status=="refused" and allocations==0,"unsupported_ground_"..ground)
end
for _,failure in ipairs({"missing-item","foreign-type","reused-id","throw-after-drop","foreign-return","foreign-id","foreign-square"}) do
    reset();mode=failure
    local physical={['throw-after-drop']=5,['foreign-return']=6,['foreign-id']=7,['foreign-square']=8}
    if physical[failure] then __fault(square,physical[failure]) end
    owner.tick()
    check(receipt().status=="ambiguous" and receipt().created<2,"native_refusal_"..failure)
    local count=allocations;local bodies=square:getWorldObjects():size()
    journal=__roundtrip(journal);owner=LoadPlacement(config,journal);mode=nil;owner.tick()
    check(allocations==count and square:getWorldObjects():size()==bodies,"no_retry_after_"..failure)
end
reset();owner.tick();receipt().status="attempted";receipt().items["2"].status="attempted"
journal=__roundtrip(journal);owner=LoadPlacement(config,journal);owner.tick()
check(receipt().status=="ambiguous" and receipt().reason=="interrupted-native-attempt" and allocations==2,"interrupted_journal_never_repeats_prefix")
reset();config.situation=nil;owner.tick();check(empty(journal),"omitted_configuration_no_write")
print("LOOSE_ITEM_CHECKS "..checks)
