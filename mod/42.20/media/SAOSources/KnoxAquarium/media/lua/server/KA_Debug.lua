require 'KA_Core'
local K=KnoxAquarium
function K.debugAllowed(player)
    return K.betaToolsAllowed(player)
end
-- The biggest species this installation actually has, largest first. Data
-- driven so a fishing mod's species are offered automatically and vanilla still
-- works alone; only Large and Extra large species are returned, since those are
-- what the big tanks are for. This used to be "whatever the standard tank
-- refuses", which stopped meaning anything once the standard tank took every
-- size: it would have handed the big-tank kits no fish at all.
function K.debugBigSpecies(count)
    local out={}
    for _,info in pairs(K.buildFishRegistry() or {}) do
        if info.class and info.class >= K.SIZE.LARGE then
            table.insert(out,info)
        end
    end
    table.sort(out,function(a,b) return (a.maxLength or 0) > (b.maxLength or 0) end)
    local picked={}
    for i=1,math.min(count or 1,#out) do picked[i]=out[i] end
    return picked
end

-- Species of a given size class, biggest first, drawn from whatever this
-- installation actually has. With a fishing mod installed this offers its
-- species; with vanilla alone it offers vanilla's.
function K.debugSpeciesOfClass(class, count)
    local out = {}
    for _, info in pairs(K.buildFishRegistry() or {}) do
        if info.class == class then table.insert(out, info) end
    end
    table.sort(out, function(a, b) return (a.maxLength or 0) > (b.maxLength or 0) end)
    local picked = {}
    for i = 1, math.min(count or 1, #out) do picked[i] = out[i] end
    return picked
end

function K.debugCommand(command,player,obj,reply,sync)
    if not K.debugAllowed(player) then reply(player,'Aquarium debug requires server admin access.'); return end
    local function give(kind,configure)
        local item=instanceItem(kind)
        if not item then reply(player,'Missing item definition: '..kind); return end
        item:getModData().KnoxAquariumDebug=true
        if configure then configure(item) end
        player:getInventory():AddItem(item); sendAddItemToContainer(player:getInventory(),item)
        return item
    end
    local function fish(mode)
        give('Base.YellowPerch',function(item)
            local now=K.now(); local length=mode=='oversize' and 31 or (mode=='boundary' and 30 or 20)
            local expiry=K.deadline(now,player:getPerkLevel(Perks.Fishing))
            if mode=='expired' then expiry=now-1 elseif mode=='short' then expiry=now+1/60 end
            item:setAge(0); item:setName('[TEST '..mode..'] Yellow Perch - '..length..' cm')
            item:getModData().fishing_FishSize=length
            if mode~='unmarked' then item:getModData().KnoxAquariumFish={caught=now,expires=expiry} end
            if mode=='cooked' then item:setCooked(true) end
            if mode=='burnt' then item:setBurnt(true) end
            if mode=='rotten' then item:setAge(item:getOffAgeMax()+10) end
        end)
    end
    local function water(fluid,amount)
        give('Base.BucketWaterDebug',function(item)
            local f=item:getFluidContainer(); f:removeFluid(); f:addFluid(fluid,amount)
        end)
    end
    local function gear()
        for _,kind in ipairs({'Base.FishingRod','Base.FishingLine','Base.PremiumFishingLine','Base.FishingHookBox'}) do give(kind) end
        for i=1,20 do give('Base.Worm') end
    end
    -- Spawn a live animal the same way a trap does: build the IsoAnimal, wrap it
    -- in a Base.Animal inventory item, then take it straight out of the world so
    -- it does not also wander off as a loose creature.
    -- Two different names are in play and they are NOT the same thing:
    --   * the ANIMAL TYPE, which is what IsoAnimal.new takes and what
    --     AnimalDefinitions.animals is keyed by - "rat", "rabdoe", "mousepups"
    --   * the SPECIES GROUP, which AnimalDefinitions.breeds is keyed by -
    --     "rat", "rabbit", "mouse"
    -- There is no animal type called "rabbit" at all; it is only a group name.
    -- Spawning one produced an animal with no body model, and the engine then
    -- died building its visual on the render thread, where a pcall in here
    -- cannot reach it. So validate the TYPE against the game's own definitions
    -- and refuse rather than create something half-formed.
    local function spawnable(kind,group,wanted)
        local defs=AnimalDefinitions
        if not defs then return nil,'animal definitions are not loaded' end
        local animal=defs.animals and defs.animals[kind]
        if not animal or not animal.bodyModel then
            return nil,'"'..kind..'" is not an animal type this build knows about'
        end
        local entry=defs.breeds and defs.breeds[group]
        local breeds=entry and entry.breeds
        if type(breeds)~='table' then return nil,'no breeds defined for '..group end
        if wanted and breeds[wanted] then return wanted end
        local names={}
        for name in pairs(breeds) do table.insert(names,name) end
        table.sort(names)
        if #names==0 then return nil,'no breeds defined for '..group end
        return names[1]
    end

    local function critter(kind,group,wanted,label)
        local breed,why=spawnable(kind,group,wanted)
        if not breed then
            reply(player,'Cannot spawn '..label..': '..why..'.')
            print('[KnoxAquarium] refused to spawn '..tostring(kind)..': '..tostring(why))
            return
        end
        local ok,err=pcall(function()
            local animal=IsoAnimal.new(getCell(),player:getX(),player:getY(),player:getZ(),kind,breed)
            if not animal then error('no animal') end
            animal:setWild(false)
            local item=instanceItem('Base.Animal')
            item:setAnimal(animal)
            item:getModData().KnoxAquariumDebug=true
            player:getInventory():AddItem(item); sendAddItemToContainer(player:getInventory(),item)
            pcall(function() animal:removeFromWorld();animal:removeFromSquare() end)
        end)
        if ok then reply(player,label..' added to your main inventory.')
        else reply(player,'Could not spawn '..label..': '..tostring(err)) end
    end

    -- type, species group, breed, label. Pairings taken from the base game's own
    -- trap definitions, which is where it lists what may be spawned alive.
    local critters={
        debug_rat        ={'rat',       'rat',   'grey',      'Grey rat'},
        debug_rat_white  ={'rat',       'rat',   'white',     'White rat'},
        debug_ratfemale  ={'ratfemale', 'rat',   nil,         'Female rat'},
        debug_mousefemale={'mousefemale', 'mouse', 'white', 'Female mouse'},
        debug_mousepups  ={'mousepups', 'mouse', 'white', 'Mouse pup'},
        debug_ratbaby    ={'ratbaby', 'rat', 'grey', 'Baby rat'},
        debug_mouse      ={'mouse',     'mouse', 'white',     'White mouse'},
    }
    if critters[command] then
        local entry=critters[command]
        critter(entry[1],entry[2],entry[3],entry[4]); return
    end

    -- Spawn a live specimen of a given size class, sized near that species'
    -- maximum so it exercises the tank limits rather than sneaking under them.
    local classNames = {[1]='Small', [2]='Medium', [3]='Large', [4]='Extra large'}
    local wantClass = string.match(command, '^debug_class_(%d)$')
    if wantClass then
        local class = tonumber(wantClass)
        local species = K.debugSpeciesOfClass(class, 3)
        if #species == 0 then
            reply(player, 'No '..(classNames[class] or '?')..' species are registered in this game.')
            return
        end
        for _, info in ipairs(species) do
            local length = math.max(10, math.floor((info.maxLength or 30) * 0.85))
            give(info.itemType, function(it)
                local now = K.now()
                it:getModData().fishing_FishSize = length
                it:getModData().KnoxAquariumFish = {caught=now, expires=K.deadline(now, player:getPerkLevel(Perks.Fishing))}
                it:setName('[TEST '..(classNames[class] or '?')..'] '..info.itemType..' - '..length..' cm')
            end)
        end
        reply(player, 'Added '..#species..' '..(classNames[class] or '?')..' species. '
            ..'Longest: '..math.floor(species[1].maxLength or 0)..' cm when grown.')
        return
    end

    -- Spawn a page of the full ranking, longest species first. Paged because a
    -- hundred fish at once would be unusable, and because a page is a sensible
    -- unit to carry to a tank and try.
    local RANK_PAGE = 5
    local page = string.match(command, '^debug_rank_(%d+)$')
    if page then
        page = tonumber(page)
        local ranked = K.speciesByLength()
        local from, to = (page - 1) * RANK_PAGE + 1, math.min(page * RANK_PAGE, #ranked)
        if from > #ranked then
            reply(player, 'Only '..#ranked..' species are registered in this game.')
            return
        end
        for i = from, to do
            local info = ranked[i]
            local length = math.max(10, math.floor((info.maxLength or 30) * 0.85))
            give(info.itemType, function(it)
                local now = K.now()
                it:getModData().fishing_FishSize = length
                it:getModData().KnoxAquariumFish = {caught=now, expires=K.deadline(now, player:getPerkLevel(Perks.Fishing))}
                it:setName('#'..i..' '..info.itemType..' - '..length..' cm')
            end)
        end
        reply(player, 'Ranked '..from..'-'..to..' of '..#ranked..' species by length. '
            ..'Longest here: '..math.floor(ranked[from].maxLength)..' cm.')
        return
    end
    if command == 'debug_rank_list' then
        local ranked = K.speciesByLength()
        print('[KnoxAquarium] every species, longest first:')
        for i, info in ipairs(ranked) do
            print(string.format('  %3d. %-40s %4d cm  %s', i, info.itemType,
                  math.floor(info.maxLength or 0), K.SIZE_NAME[info.class] or '?'))
        end
        reply(player, 'Printed all '..#ranked..' species to the console, longest first.')
        return
    end

    -- Spawn a species that has its own tank artwork, by name. Driven off the
    -- overlay registry, so a species added later gets an option for free.
    local function giveSpecies(itemType, label)
        local info = K.speciesOf(itemType)
        local length = math.max(10, math.floor(((info and info.maxLength) or 40) * 0.8))
        local item = give(itemType, function(it)
            local now = K.now()
            it:getModData().fishing_FishSize = length
            it:getModData().KnoxAquariumFish = {caught=now, expires=K.deadline(now, player:getPerkLevel(Perks.Fishing))}
            it:setName('[ART] '..(label or itemType)..' - '..length..' cm')
        end)
        return item ~= nil, length
    end

    local wantArt = string.match(command, '^debug_art_(.+)$')
    if wantArt then
        if wantArt == 'all' then
            local n = 0
            for itemType in pairs(K.overlaySpecies or {}) do
                if giveSpecies(itemType) then n = n + 1 end
            end
            reply(player, 'Added one of each of the '..n..' species that have their own tank artwork.')
            return
        end
        for itemType, variant in pairs(K.overlaySpecies or {}) do
            if variant == wantArt then
                local ok, length = giveSpecies(itemType, variant)
                reply(player, ok and ('Added a '..variant..' at '..length..' cm. Put it in a Display Aquarium.')
                    or ('Could not create '..itemType..' - is Fishing Overhaul BR installed?'))
                return
            end
        end
        reply(player, 'No species registered for artwork "'..wantArt..'".')
        return
    end

    local modes={live=true,expired=true,short=true,oversize=true,boundary=true,cooked=true,burnt=true,rotten=true,unmarked=true}
    local mode=string.match(command,'^debug_fish_(.+)$')
    if mode and modes[mode] then fish(mode); reply(player,'Test fish added to main inventory.'); return end
    if command=='debug_kit' then
        water(Fluid.Water,10); water(Fluid.Water,10)
        gear()
        for i=1,5 do fish('live') end
        reply(player,'Kit added: 20 L water, rod, lines, hooks, 20 worms, 5 live fish. Place a free aquarium nearby.')
    elseif command=='debug_cases' then
        for _,m in ipairs({'expired','short','oversize','boundary','cooked','burnt','rotten','unmarked'}) do fish(m) end
        water(Fluid.Water,0.5); water(Fluid.TaintedWater,10); water(Fluid.Petrol,1)
        reply(player,'Edge cases added: fish variants, half-litre water, tainted water and non-water bucket.')
    elseif command=='debug_kit_small' or command=='debug_kit_large'
        or command=='debug_kit_display' or command=='debug_kit_all' then
        -- One clearly named option per tank, plus one that hands over all of
        -- them. Each comes with fish that tank can actually take, so the option
        -- demonstrates the tank rather than just handing over a box.
        local want =
            command=='debug_kit_small'   and {'standard'} or
            command=='debug_kit_large'   and {'large'} or
            command=='debug_kit_display' and {'display'} or
            {'standard','large','display'}
        local given, names = 0, {}
        for _,id in ipairs(want) do
            local tier=K.tankTiers[id]
            if tier and tier.item and K.tierAvailable(tier) then
                if give(tier.item) then given=given+1; table.insert(names,tier.label) end
            end
        end
        -- fish: small ones for the standard tank, big ones for the others
        local wantsBig = command~='debug_kit_small'
        local fishGiven = 0
        if wantsBig then
            for _,species in ipairs(K.debugBigSpecies(2)) do
                local length=math.max(61,math.floor((species.maxLength or 100)*0.7))
                if give(species.itemType,function(it)
                        local now=K.now()
                        it:getModData().fishing_FishSize=length
                        it:getModData().KnoxAquariumFish={caught=now,expires=K.deadline(now,player:getPerkLevel(Perks.Fishing))}
                        it:setName('[TEST] '..(species.itemType or 'Fish')..' - '..length..' cm')
                    end) then fishGiven=fishGiven+1 end
            end
        end
        if command~='debug_kit_large' and command~='debug_kit_display' then
            for i=1,3 do fish('live'); fishGiven=fishGiven+1 end
        end
        water(Fluid.Water,10); water(Fluid.Water,10)
        reply(player,(given>0 and (table.concat(names,', ')..' kit') or 'No tank kit')
            ..' added, with '..fishGiven..' fish and two buckets.'
            ..' Place it, then Test tools, Fill instantly.')
    elseif command=='debug_water' then water(Fluid.Water,10); water(Fluid.Water,10)
    elseif command=='debug_gear' then gear()
    elseif command=='debug_expire' then
        local items=player:getInventory():getItems(); local count=0
        for i=0,items:size()-1 do
            local item=items:get(i); local md=item:getModData()
            if md.KnoxAquariumDebug and md.KnoxAquariumFish then
                md.KnoxAquariumFish.expires=K.now()-1; item:syncItemFields(); count=count+1
            end
        end
        reply(player,'Expired '..count..' test fish in main inventory.')
    elseif command=='debug_cleanup' then
        local items=player:getInventory():getItems(); local count=0
        for i=items:size()-1,0,-1 do
            local item=items:get(i)
            if item:getModData().KnoxAquariumDebug and not player:isEquipped(item) then
                player:getInventory():Remove(item); sendRemoveItemFromContainer(player:getInventory(),item); count=count+1
            end
        end
        reply(player,'Removed '..count..' unequipped test items from main inventory.')
    elseif command=='debug_status' then
        local d=obj and obj:getModData().KnoxAquarium
        local message=string.format('Aquarium debug: skill %d; catch window %.0f min; world %.3f h.',player:getPerkLevel(Perks.Fishing),(K.deadline(0,player:getPerkLevel(Perks.Fishing)))*60,K.now())
        if d then message=message..string.format(' Tank %.2f L, %d fish, schema %s.',d.water,#d.fish,tostring(d.schema)) end
        print('[KnoxAquarium] '..message); reply(player,message)
        -- Everything needed to explain what a tank is actually drawing, written
        -- to console.txt. Reading the sprite state out of the game beats
        -- guessing at it from the outside.
        if K.animationReport then
            for _,line in ipairs(K.animationReport(obj)) do print('[KnoxAquarium] '..line) end
        else
            print('[KnoxAquarium] CLOCK unavailable: the client half did not load')
        end
        if not d then print('[KnoxAquarium] NOTE that click resolved no tank - right-click the tank itself for its full state.') end
        if d then
            local tier=K.tierOf(d)
            print(string.format('[KnoxAquarium] TANK tier=%s rotation=%s water=%.2f/%.2f mode=%s fish=%d animals=%d species=%s',
                tostring(d.tier), tostring(K.rotation(d)), tonumber(d.water) or -1, tier.capacity,
                tostring(d.mode), #(d.fish or {}), #(K.animals(d) or {}), tostring(K.tankSpecies(d))))
            for i,f in ipairs(d.fish or {}) do
                print(string.format('[KnoxAquarium]   fish %d: type=%s length=%s overlayArt=%s',
                    i, tostring(f.type), tostring(f.length), tostring(K.overlaySpecies[f.type])))
            end
            local variant,drawn=K.overlayPlan(d)
            print(string.format('[KnoxAquarium] PLAN variant=%s drawn=%s overlayDir=%s',
                tostring(variant), tostring(drawn), tostring(tier.overlayDir)))
            for _,frame in ipairs({0,7}) do
                local key=K.overlayKey(d,frame)
                print(string.format('[KnoxAquarium] frame %d: overlay=%s under=%s base=%s',
                    frame, tostring(key),
                    tostring(key and K.tankKeyUnderOverlay(d,frame) or '-'),
                    tostring(K.renderKey(d,frame))))
                if key and isServer() then
                    -- a dedicated or hosted server renders nothing and loads no
                    -- textures, so there is nothing true to report here
                    print('[KnoxAquarium]   texture '..key..' -> not checked on a server (clients load textures)')
                elseif key then
                    local ok,tex=pcall(getTexture,'media/textures/'..key..'.png')
                    print(string.format('[KnoxAquarium]   texture %s -> %s',
                        key, (ok and tex) and (tex:isReady() and 'READY' or 'not ready') or 'MISSING'))
                end
            end
        end
    elseif obj then
        local d=obj:getModData().KnoxAquarium
        if command=='debug_dry' then
            if not K.tankEmpty(d) then return reply(player,'Empty the tank first, then switch it to a dry habitat.') end
            -- The test tool obeys the same rule as the real Habitat switch: a
            -- tier with no dry art of its own would be drawn with another tank's.
            if K.tierOf(d).allowsDry==false then
                return reply(player,'A '..K.tierOf(d).label..' cannot be run as a dry habitat yet.')
            end
            d.mode='dry'
        elseif command=='debug_wet' then
            if not K.tankEmpty(d) then return reply(player,'Empty the tank first, then switch it back to water.') end
            d.mode='water'
        elseif command=='debug_full' then d.water=K.cap(d)
        elseif command=='debug_partial' then d.water=K.cap(d)-0.5
        elseif command=='debug_reset' then d.water=0; d.fish={}
        elseif command=='debug_refresh' then -- Synchronize without altering state.
        else return end
        sync(obj); reply(player,'Aquarium test state updated.')
    end
end
