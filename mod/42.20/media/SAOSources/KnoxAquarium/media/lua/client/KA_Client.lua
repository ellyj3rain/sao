require 'KA_Core'
local K=KnoxAquarium
local sprites={}
local tracked=setmetatable({}, {__mode='k'})
local applied=setmetatable({}, {__mode='k'})
local swimClock=0
local function requestTexture(state)
    local tex=getTexture('media/textures/'..state..'.png')
    if tex and tex:isReady() and not tex:isFailure() then return tex end
end

-- true only when the texture does not exist at all (nil or a failed load), as
-- opposed to one that is still on its way. Remembered, so a missing file is
-- not looked up again every animation frame.
local missing={}
local function textureMissing(state)
    if missing[state] then return true end
    local tex=getTexture('media/textures/'..state..'.png')
    if not tex or tex:isFailure() then missing[state]=true; return true end
    return false
end

-- What to draw when a tank's intended art does not exist: that tank's plain
-- art at the same facing, then the original tank's, then the original tank at
-- facing 0 - which has shipped in every release. nil if none of those exist
-- (or the only candidate is the state that just failed).
function K.fallbackStateFor(d,failed)
    local rot=K.rotation(d)
    local prefix=rot==0 and '' or ('KA_rot'..rot..'/')
    local tier=K.tierOf(d)
    local wet=(tonumber(d and d.water) or 0)>0 and not K.isDry(d)
    local look=wet and 'water' or 'empty'
    for _,candidate in ipairs({prefix..tier.art..look, prefix..'KA_'..look, 'KA_'..look, 'KA_empty'}) do
        if candidate~=failed and not textureMissing(candidate) then return candidate end
    end
    return nil
end
Events.OnGameStart.Add(function()
    -- The display tank's second-tile part is saved as a vanilla industrial
    -- sprite and only turns invisible once this texture is ready. Warm it first
    -- so a part never shows that placeholder while its tile loads.
    requestTexture('KA_part')
    for rotation=0,3 do
        local prefix=rotation==0 and '' or ('KA_rot'..rotation..'/')
        for _,state in ipairs({'KA_empty','KA_low','KA_water'}) do requestTexture(prefix..state) end
        for _,level in ipairs({'full_','low_'}) do
            for count=1,4 do for frame=0,31 do requestTexture(prefix..'KA_swim/'..level..count..'_'..frame) end end
        end
        for count=1,K.maxAnimals do for frame=0,31 do requestTexture(prefix..'KA_dry/'..count..'_'..frame) end end
        -- the large tank's own art, driven by its tier rather than hardcoded
        -- every tier beyond the standard one, driven by its own art fields
        for _,tier in pairs(K.tankTiers) do
            if tier.art and tier.art~='KA_' then
                for _,state in ipairs({'empty','low','water'}) do requestTexture(prefix..tier.art..state) end
                for count=1,tier.maxFish do
                    local variants=tier.fishVariants or {false}
                    for _,variant in ipairs(variants) do
                        for frame=0,31 do requestTexture(prefix..tier.swim..'full_'..count..(variant and ('_'..variant) or '')..'_'..frame) end
                    end
                end
            end
        end
    end
end)
-- ------------------------------------------------------------- fish overlays
-- IsoObject.overlaySprite draws a second sprite over an object. It is a render
-- field: save() never writes it, so an overlay adds nothing to the save, needs
-- no second world object, and cannot be picked up or duplicated. Vanilla drives
-- it from Lua the same way for painted signs.
--
-- setOverlaySprite takes a NAME, looked up in IsoSpriteManager, so each overlay
-- sprite is built here and registered under its own name the first time it is
-- used. If any of that is unavailable the whole overlay path switches off for
-- the session and tanks fall back to their built-in fish art.
local overlaySprites={}
local overlayWorks=nil          -- nil = untried, false = unavailable this session

local function overlayNamed(state)
    local cached=overlaySprites[state]
    if cached then return cached end
    -- A texture that is not loaded YET is not a failure. Asking for it starts
    -- the load; the next frame will find it ready. Two things this must never
    -- do: raise an error for an expected condition - the first version called
    -- error() here, which with Break On Error switched on halts the game - or
    -- cache the miss, which would blank that species for the whole session.
    -- Returns nil,true while the texture is still loading and nil,false when
    -- it does not exist: the caller waits for the first and falls back for the
    -- second.
    local tex=getTexture('media/textures/'..state..'.png')
    if not tex or tex:isFailure() then return nil, false end
    if not tex:isReady() then return nil, true end
    local ok=pcall(function()
        local sprite=IsoSprite.new()
        sprite:LoadSingleTexture('media/textures/'..state..'.png')
        sprite:setName(state)
        IsoSpriteManager.instance:getNamedMap():put(state,sprite)
    end)
    if not ok then return nil, false end
    overlaySprites[state]=state
    return state
end

-- Ask for every frame of an overlay at once, the first time it is needed. The
-- frames are separate textures and each used to be requested only when the
-- animation reached it, so a new fish spent its whole first loop (~4 s) waiting
-- on one frame after another.
local preloaded={}
local function preloadOverlay(d)
    local first=K.overlayKey and K.overlayKey(d,0)
    if not first or preloaded[first] then return end
    preloaded[first]=true
    for f=0,31 do
        local key=K.overlayKey(d,f)
        if key then getTexture('media/textures/'..key..'.png') end
    end
end

local function applyOverlay(obj,d,frame)
    if overlayWorks==false then return false end
    local state=K.overlayKey and K.overlayKey(d,frame) or nil
    -- MULTIPLAYER: always pass transmit=false. The short overloads -
    -- setOverlaySprite(name) and setOverlaySprite(name,r,g,b,a) - pass TRUE, and
    -- with transmit on, a client sends an UpdateOverlaySprite packet to the server
    -- on every call, which the server relays to every other client (B42.20
    -- IsoObject.setOverlaySprite(String,float,float,float,float,boolean)). This is
    -- a per-client animation frame, so that meant a packet per tank per frame,
    -- and each player's frame overwriting everybody else's - fish jittering
    -- between two players' clocks. The overlay is purely local decoration; it
    -- draws exactly the same without being broadcast. Single player never takes
    -- either network branch, so it is unaffected.
    if not state then
        -- nothing to draw; clear any overlay this tank had
        pcall(function() obj:setOverlaySprite(nil,false) end)
        return false
    end
    local named, loading = overlayNamed(state)
    if not named then
        -- REPORTED: adding a fish to the large tank showed that fish AND a
        -- generic fish for a few seconds. A frame still loading returned plain
        -- false here, so the tank switched to its own art - which has a generic
        -- fish in it - while the object kept the PREVIOUS overlay frame. Now a
        -- frame that is on its way returns "waiting": the tank keeps drawing
        -- what belongs under the overlay and the fish holds its last frame.
        -- Only a texture that does not exist at all falls back to the generic
        -- fish, so a tank is never left looking empty.
        if loading then preloadOverlay(d) end
        return false, loading
    end
    -- NO colour of its own (Jay, 2026-09-11: "why are the main fish glowing").
    -- Read from IsoObject.renderOverlaySprites (B42.20): when an overlay HAS a
    -- colour, the game throws away the tank's own lighting and draws the overlay
    -- at that colour times the tile's plain light level - a different, brighter
    -- recipe than the tank and its own fish get, so gadinho's fish glowed. The
    -- (name, transmit) overload passes -1, which leaves overlaySpriteColor nil,
    -- and a nil colour means the overlay is lit with exactly the tank's lighting.
    -- transmit stays false (see above).
    local ok=pcall(function() obj:setOverlaySprite(state,false) end)
    if not ok then
        if overlayWorks==nil then
            print('[KnoxAquarium] fish overlays unavailable; using built-in tank art')
        end
        overlayWorks=false
        return false
    end
    overlayWorks=true
    return true
end

-- Belt and braces: the overlay is decoration. If anything in it goes wrong the
-- tank must still draw, so the caller can never see an error from it.
local applyOverlayInner=applyOverlay
applyOverlay=function(obj,d,frame)
    -- both results: (drawn, waiting). Returning only the first dropped
    -- "waiting" and brought the generic-fish flash straight back.
    local ok,result,waiting=pcall(applyOverlayInner,obj,d,frame)
    if ok then return result, waiting end
    if overlayWorks~=false then
        overlayWorks=false
        print('[KnoxAquarium] fish overlays disabled this session: '..tostring(result))
    end
    return false
end

-- Counts what the renderer actually did, so a frozen tank can be told apart
-- from a tank that is being repainted every frame and simply not redrawn.
K.animStats = {calls=0, sameState=0, notReady=0, spriteChanged=0, ticks=0}

-- ---------------------------------------------------------------- collision
-- Reported: you can walk through the tank, or half into it.
--
-- A square is solid when one of ITS OBJECTS' sprites carries the flag;
-- IsoGridSquare.RecalcProperties clears the square and rebuilds it from
-- IsoObject.getProperties(), which returns the sprite's own container. So the
-- flag goes on the sprites this mod builds at runtime - never on a vanilla
-- sprite, because those are shared and flagging "carpentry_02_8" would turn
-- every carpentry tile in Knox County solid.
--
-- The flag is `solidtrans`, the one vanilla tables, counters and shelves use:
-- it blocks movement and pathing but not sight. (0.12 used `solid`, the wall
-- flag, which also blocks line of sight - wrong for a glass tank.)
--
-- Multiplayer too, since 0.13.0. 0.12 left MP alone to avoid client and server
-- disagreeing - but they already disagreed. Every tank is created on the
-- server from the vanilla table sprite "carpentry_02_8", which IS solidtrans,
-- so the server has always treated a tank's tile as blocked; only the client,
-- whose runtime sprite dropped the flag, let the player walk in. Putting the
-- same flag back on the client is what makes the two sides agree.
--
-- Nothing is written to the save: sprite properties are runtime state, and
-- removing a tank un-solidifies its tile because the square is rebuilt from
-- whatever objects remain.
local solidWorks=nil

local function makeSolid(sprite)
    if solidWorks==false or not sprite then return end
    local ok=pcall(function()
        local props=sprite:getProperties()
        if props then props:set(IsoFlagType.solidtrans) end
    end)
    if not ok then
        if solidWorks~=false then
            solidWorks=false
            print('[KnoxAquarium] tank collision unavailable this session; tanks stay walk-through')
        end
    end
end

local function refreshCollision(obj)
    if solidWorks==false then return end
    pcall(function()
        local sq=obj:getSquare()
        if sq then sq:RecalcAllWithNeighbours(true) end
    end)
end

-- ------------------------------------------------------- loot highlight
-- Reported: fish inside a tank light up like an item dropped on the ground.
--
-- Cause: a tank is created from the vanilla table sprite, which declares a
-- "desk" container, so the game gives every tank a desk container when it is
-- placed (IsoObject.addToWorld -> createContainersFromSpriteProperties). The
-- loot window then treats the tank as a container it can select, and outlines
-- the selected container out in the world - the tank AND the fish drawn over
-- it - in the world-item highlight colour.
--
-- ISInventoryPage.OnObjectHighlighted is vanilla's own way to say "another
-- piece of code owns this object's highlight": the loot window checks it and
-- leaves such objects alone. Registering tanks there - and nothing else - stops
-- the glow without touching any other container, any item on the ground, or
-- any other mod. The container itself is left in place: tanks have carried it
-- since 0.7.0, a player may have put something in it, and the game would give
-- it straight back on the next load anyway.
local optedOut=setmetatable({}, {__mode='k'})

local function optOutOfLootHighlight(obj)
    if optedOut[obj] then return end
    local page=rawget(_G,'ISInventoryPage')
    if not (page and page.OnObjectHighlighted) then return end
    for n=0,getNumActivePlayers()-1 do
        pcall(function()
            obj:setHighlighted(n,false)
            obj:setOutlineHighlight(n,false)
            obj:setOutlineHlAttached(n,false)
            page.OnObjectHighlighted(n,obj,true)
        end)
    end
    optedOut[obj]=true
end

-- Hand the object back when it is no longer ours to watch, so vanilla's table
-- does not keep a reference to a tank that has been removed or left behind.
local function releaseLootHighlight(obj)
    if not optedOut[obj] then return end
    optedOut[obj]=nil
    local page=rawget(_G,'ISInventoryPage')
    if not (page and page.OnObjectHighlighted) then return end
    for n=0,getNumActivePlayers()-1 do
        pcall(function() page.OnObjectHighlighted(n,obj,false) end)
    end
end

-- Some other vanilla path may un-register an object it once highlighted. If a
-- tank is found lit, put the opt-out back.
local function keepUnhighlighted(obj)
    for n=0,getNumActivePlayers()-1 do
        local lit=false
        pcall(function() lit=obj:isHighlighted(n) or obj:isOutlineHighlight(n) end)
        if lit then
            optedOut[obj]=nil
            optOutOfLootHighlight(obj)
            return
        end
    end
end

-- ---------------------------------------------------- two-tile tank parts
-- The display tank stands on two tiles. Its second tile holds a small part
-- object (created by the server) whose only job is to be solid. The server
-- makes it from a vanilla sprite that is solidtrans and nothing else - no
-- container, not movable - and here it is drawn as nothing at all.
local partSprite=nil
local cleanupAsked=setmetatable({}, {__mode='k'})

local function getPartSprite()
    if partSprite then return partSprite end
    if not requestTexture('KA_part') then return nil end
    local sprite=IsoSprite.new()
    sprite:LoadSingleTexture('media/textures/KA_part.png')
    -- Named after the vanilla sprite for anything that reads names. NOTE: this
    -- does NOT decide what a save records. IsoObject.save writes the sprite's
    -- numeric id (B42.20), and a runtime IsoSprite has id 20000000, which is
    -- registered to nothing. On a server this never matters - the server keeps
    -- the real vanilla sprite and saves that. In SINGLE PLAYER the client is the
    -- saving game, so a part (and a tank, below) that was drawn when the chunk
    -- saved loads back with no sprite at all until this file draws it again. It
    -- loads fine and is redrawn at once while the mod is installed; see the
    -- uninstall notes for what that means if the mod is removed.
    sprite:setName(K.PART_SPRITE or 'KA_part')
    makeSolid(sprite)
    partSprite=sprite
    return sprite
end

-- ------------------------------------------- display tank: the depth split
-- Why the display tank draws its near section from its second tile, and the
-- numbers it uses: K.tankTiers.display.depthSplit (KA_FishRegistry).
--   splitOwner[part] = the tank whose near section that part is drawing
--   splitPart[tank]  = the part a tank is drawing its near section on
local splitOwner=setmetatable({}, {__mode='k'})
local splitPart=setmetatable({}, {__mode='k'})
local applyAppearance   -- defined below; a part asks its tank to redraw it

-- Core.getTileScale is static: reach it through the class (see K.ghostOffsetsFor).
local function tileScale()
    local s=Core and Core.getTileScale and Core.getTileScale()
    if type(s)=='number' and s>0 then return s end
    return 2
end

-- Draw `sprite` at the tank's own anchor from `holder`, which stands dx,dy tiles
-- from the tank, with its depth nudged `lift` levels*96 nearer. The game adds
-- renderYOffset*tileScale to the screen offset as well as to the depth
-- (IsoObject.render, IsoSprite.renderCurrentAnim, B42.20), so the same amount
-- comes back off offsetY here: the picture does not move, only the depth does.
local function placeSprite(holder,d,sprite,dx,dy,lift)
    local offX, offY = K.offsetsFor(d)
    local s=tileScale()
    holder:setOffsetX(offX + (dx - dy) * 32 * s)
    holder:setOffsetY(offY + (dx + dy) * 16 * s - lift * s)
    holder:setRenderYOffset(lift)
    holder:setSprite(sprite)
end

local function applyPart(obj)
    -- A part drawing its tank's near section keeps that sprite; refreshing its
    -- square must not put the invisible placeholder back over it.
    local owner=splitOwner[obj]
    if owner and owner:getObjectIndex()>=0 and splitPart[owner]==obj and K.masterOf(obj)==owner then
        optOutOfLootHighlight(obj)
        -- something replaced its sprite: the tank draws its section again
        local od=K.tankData(owner)
        if od and obj:getSprite()==nil then applyAppearance(owner,od) end
        return
    end
    splitOwner[obj]=nil
    local sprite=getPartSprite()
    if not sprite then return end
    if obj:getSprite()~=sprite then
        obj:setSprite(sprite)
        refreshCollision(obj)
    end
    optOutOfLootHighlight(obj)
    -- A part whose tank is gone - a tank destroyed some other way than Pick up
    -- - would be an invisible wall. Ask the server to remove it, but only when
    -- the tank's own tile is loaded, so a chunk edge is never mistaken for a
    -- missing tank.
    if cleanupAsked[obj] then return end
    local p=K.partData(obj)
    if not p then return end
    local cell=getCell()
    if not cell or not cell:getGridSquare(p.x,p.y,p.z) then return end
    if K.masterOf(obj) then return end
    local player=getSpecificPlayer(0)
    local sq=obj:getSquare()
    if player and sq and math.abs(player:getX()-sq:getX())<=K.placeRange
       and math.abs(player:getY()-sq:getY())<=K.placeRange and player:getZ()==sq:getZ() then
        cleanupAsked[obj]=true
        K.send(player,'cleanupPart',sq)
    end
end

local function refreshParts(sq)
    if not sq then return end
    local objects=sq:getObjects()
    for i=0,objects:size()-1 do
        local obj=objects:get(i)
        if K.partData(obj) then applyPart(obj) end
    end
end

local function spriteFor(state)
    local sprite=sprites[state]
    if sprite then return sprite end
    sprite=IsoSprite.new()
    sprite:LoadSingleTexture('media/textures/'..state..'.png')
    -- A name for anything that reads it. It does not decide what a save
    -- records - see getPartSprite above.
    sprite:setName('carpentry_02_8')
    makeSolid(sprite)
    sprites[state]=sprite
    return sprite
end

-- The part stops drawing a section: the placeholder, no overlay, no depth nudge.
local function releaseSplitPart(part)
    splitOwner[part]=nil
    pcall(function()
        part:setOverlaySprite(nil,false)
        part:setRenderYOffset(0)
        part:setOffsetX(0)
        part:setOffsetY(0)
    end)
    if part:getObjectIndex()>=0 then applyPart(part) end
end

-- The loaded part a split-capable tank can draw its near section on, or nil.
local function splitPartOf(obj,d)
    if not K.tierOf(d).depthSplit or not K.partSquare or not K.partOn then return nil end
    local found=nil
    -- Decoration only: nothing here may stop the tank drawing.
    pcall(function()
        local sq=obj:getSquare()
        local psq=sq and K.partSquare(d,sq)
        found=psq and K.partOn(psq,sq:getX(),sq:getY(),sq:getZ()) or nil
    end)
    return found
end

applyAppearance=function(obj,d)
    local frame=K.frameIndex(math.floor(swimClock*(K.tierOf(d).fps or 8))+obj:getX()*3+obj:getY()*5)
    local rot=K.rotation(d)
    local tier=K.tierOf(d)
    local split=tier.depthSplit
    local part=split and splitPartOf(obj,d) or nil
    -- When an overlay carries the fish, the tank itself is drawn without them.
    -- A split tank carries its overlay on the part, with the near section, so
    -- the fish share that section's depth (see K.tankTiers.display.depthSplit).
    local overlaid, waiting=applyOverlay(part or obj,d,frame)
    -- With an overlay the tank draws whatever the overlay does not: nothing for
    -- a species tank, the remaining occupants for a community tank.
    local state
    if overlaid or waiting then
        if waiting then K.animStats.overlayWaits = (K.animStats.overlayWaits or 0) + 1 end
        state=(rot==0 and '' or ('KA_rot'..rot..'/'))..K.tankKeyUnderOverlay(d,frame)
    else
        state=K.renderKey(d,frame)
    end
    K.animStats.calls = K.animStats.calls + 1
    if part then
        local farKey, nearKey = split.far..state, split.near..state
        if applied[obj]==farKey and splitPart[obj]==part and obj:getSprite()==sprites[farKey]
           and part:getSprite()==sprites[nearKey] and not overlaid then
            K.animStats.sameState = K.animStats.sameState + 1
            return
        end
        if not (requestTexture(farKey) and requestTexture(nearKey)) then
            if not (textureMissing(farKey) or textureMissing(nearKey)) then
                K.animStats.notReady = K.animStats.notReady + 1
                return                    -- still loading: hold the last frame
            end
            -- No split art for this frame (a build without it): draw the tank
            -- whole, with its overlay back on the tank.
            pcall(function() part:setOverlaySprite(nil,false) end)
            part=nil
            overlaid, waiting=applyOverlay(obj,d,frame)
        else
            local lift=split[rot] or {}
            local dx, dy = K.partDelta(d)
            placeSprite(obj,d,spriteFor(farKey),0,0,lift.far or 0)
            placeSprite(part,d,spriteFor(nearKey),dx or 0,dy or 0,lift.near or 0)
            if splitPart[obj]~=part then
                if splitPart[obj] then releaseSplitPart(splitPart[obj]) end
                splitPart[obj]=part
                splitOwner[part]=obj
                pcall(function() obj:setOverlaySprite(nil,false) end)
                refreshCollision(part)
                optOutOfLootHighlight(part)
            end
            local first = applied[obj]==nil
            if applied[obj]~=farKey then K.animStats.spriteChanged = K.animStats.spriteChanged + 1 end
            applied[obj]=farKey
            if first then
                refreshCollision(obj)
                optOutOfLootHighlight(obj)
            end
            return
        end
    end
    if splitPart[obj] then
        releaseSplitPart(splitPart[obj])
        splitPart[obj]=nil
    end
    if applied[obj]==state and obj:getSprite()==sprites[state] and not overlaid then
        K.animStats.sameState = K.animStats.sameState + 1
        return
    end
    if not requestTexture(state) then
        -- A frame still LOADING is waited for (the tank holds its last frame).
        -- A frame that does not EXIST - an unfinished render, a file left out of
        -- a release, a future tier's art - must never leave a tank frozen or, on
        -- its first draw after loading a save, invisible. Draw the tank's own
        -- plain art instead; its fish and animals are untouched either way.
        local fallback=textureMissing(state) and K.fallbackStateFor(d,state) or nil
        if not fallback then
            K.animStats.notReady = K.animStats.notReady + 1
            return
        end
        K.animStats.fallbacks = (K.animStats.fallbacks or 0) + 1
        state=fallback
    end
    -- Where the sprite sits on its tile: per tank and per facing, flush against
    -- the wall behind it (see K.facingOffsets). A display tank drawn whole (no
    -- part loaded yet, or no split art) still gets its depth nudge.
    local lift = tier.wholeLift and tier.wholeLift[rot] or 0
    local first = applied[obj]==nil
    placeSprite(obj,d,spriteFor(state),0,0,lift)
    if applied[obj]~=state then K.animStats.spriteChanged = K.animStats.spriteChanged + 1 end
    applied[obj]=state
    -- Only on the first sprite this tank ever gets: recalculating a square and
    -- its neighbours every animation frame would be wasteful, and the flag does
    -- not change once it is on.
    if first then
        refreshCollision(obj)
        optOutOfLootHighlight(obj)
    end
end
-- Animation diagnostic. The tank draws nothing new when applyAppearance bails
-- out early, and the usual reason is a texture that never reports ready: it
-- returns BEFORE setSprite, so the tank keeps whatever frame it last managed to
-- load and sits frozen on it. This reports the clock, what the tank last
-- applied, and how many of its 32 frames the engine will actually hand over.
function K.animationReport(obj)
    local lines = {}
    local trackedCount = 0
    for _ in pairs(tracked) do trackedCount = trackedCount + 1 end
    -- Report on SOME tank even when the click did not land on one: a right-click
    -- that resolves no object used to skip this entirely, which wasted a whole
    -- test run.
    if not obj then
        for tank in pairs(tracked) do obj = tank; break end
        table.insert(lines, 'NOTE no tank was clicked; reporting on '
            .. (obj and 'the first tracked tank' or 'nothing - no tank is tracked'))
    end
    table.insert(lines, string.format(
        'CLOCK swimClock=%.3f maxFps=%s paused=%s tracked=%d thisTracked=%s applied=%s',
        swimClock, tostring(K.maxFps), tostring(K.animationPaused),
        trackedCount, tostring(obj and tracked[obj] or false),
        tostring(obj and applied[obj] or 'none')))
    local speed = UIManager.getSpeedControls()
    table.insert(lines, 'SPEED gameSpeed=' .. tostring(speed and speed:getCurrentGameSpeed()))
    table.insert(lines, string.format(
        'STATS ticks=%d applyCalls=%d spriteChanged=%d sameState=%d notReady=%d',
        K.animStats.ticks, K.animStats.calls, K.animStats.spriteChanged,
        K.animStats.sameState, K.animStats.notReady))
    if obj then
        local d = obj:getModData().KnoxAquarium
        if d then
            local live = K.frameIndex(math.floor(swimClock*(K.tierOf(d).fps or 8))+obj:getX()*3+obj:getY()*5)
            table.insert(lines, string.format('LIVE frame=%s key=%s  objX=%s objY=%s',
                tostring(live), tostring(K.renderKey(d, live)),
                tostring(obj:getX()), tostring(obj:getY())))
        end
    end
    if obj then
        local d = obj:getModData().KnoxAquarium
        if d then
            local ready, missing, first = 0, {}, nil
            for frame = 0, 31 do
                local state = K.renderKey(d, frame)
                first = first or state
                if requestTexture(state) then ready = ready + 1
                elseif #missing < 4 then table.insert(missing, state) end
            end
            table.insert(lines, string.format('FRAMES %d/32 of the tank art are ready (e.g. %s)%s',
                ready, tostring(first),
                #missing > 0 and ('; NOT ready: ' .. table.concat(missing, ', ')) or ''))
        end
    end
    return lines
end

function K.refresh(sq)
    if not sq then return end
    local objects=sq:getObjects()
    for i=0,objects:size()-1 do
        local obj=objects:get(i)
        -- runs for every square of every chunk that loads: never give the
        -- walls and floors a mod data table just by looking (K.modDataOf)
        local md=K.modDataOf(obj)
        local d=md and md.KnoxAquarium
        if not md then
            -- nothing of ours on this object
        elseif d then
            tracked[obj]=true;applyAppearance(obj,d)
            -- A two-tile tank's second tile is refreshed with it, so it never
            -- shows the placeholder sprite the server created it with.
            local psq=K.partSquare and K.partSquare(d,sq) or nil
            if psq then refreshParts(psq) end
        elseif md.KnoxAquariumPart then
            applyPart(obj)
        end
    end
end
local function untrack(obj)
    tracked[obj]=nil;applied[obj]=nil
    releaseLootHighlight(obj)
end
Events.OnTick.Add(function()
    local speed=UIManager.getSpeedControls()
    if speed and speed:getCurrentGameSpeed()==0 then return end
    local previous=math.floor(swimClock*K.maxFps)
    if not K.animationPaused then swimClock=swimClock+math.min(.25,getGameTime():getRealworldSecondsSinceLastUpdate()) end
    if math.floor(swimClock*K.maxFps)==previous then return end
    K.animStats.ticks = K.animStats.ticks + 1
    for obj in pairs(tracked) do
        if obj:getObjectIndex()<0 or not obj:getSquare() then untrack(obj)
        else
            local near=false
            for n=0,getNumActivePlayers()-1 do
                local p=getSpecificPlayer(n)
                if p and p:getZ()==obj:getZ() and math.abs(p:getX()-obj:getX())<12 and math.abs(p:getY()-obj:getY())<12 then near=true;break end
            end
            if near then
                local d=obj:getModData().KnoxAquarium
                if d then applyAppearance(obj,d); keepUnhighlighted(obj) end
            else untrack(obj) end
        end
    end
end)
Events.LoadGridsquare.Add(K.refresh)
local function send(player,command,sq,item,fishId,rotation)
    local args={x=sq:getX(),y=sq:getY(),z=sq:getZ(),item=item and item:getID() or nil,fishId=fishId,rotation=rotation}
    -- The host of a co-op game proves it to the server with the code the server
    -- wrote to this machine's disk (KA_Core, co-op host block).
    if isClient() and K.isCoopHostClient() then args.hostToken=K.readHostToken() end
    if isClient() then sendClientCommand(player,'KnoxAquarium',command,args)
    else K.command('KnoxAquarium',command,player,args) end
end
K.send=send
Events.OnServerCommand.Add(function(module,command,args)
    if module~='KnoxAquarium' then return end
    if command=='message' then local p=getPlayer(); if p then p:Say(args.text) end
    elseif command=='refresh' then K.refresh(getCell():getGridSquare(args.x,args.y,args.z)) end
end)
-- Also catches object-data arriving after a refresh message and late multiplayer joins.
Events.EveryOneMinute.Add(function()
    for n=0,getNumActivePlayers()-1 do
        local p=getSpecificPlayer(n)
        if p then
            for x=math.floor(p:getX())-8,math.floor(p:getX())+8 do
                for y=math.floor(p:getY())-8,math.floor(p:getY())+8 do K.refresh(getCell():getGridSquare(x,y,p:getZ())) end
            end
        end
    end
end)
