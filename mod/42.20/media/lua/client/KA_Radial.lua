-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
require 'KA_Core'
require 'ISUI/ISPanel'
require 'ISUI/ISRadialMenu'
require 'ISUI/ISUIHandler'
local K=KnoxAquarium
function K.nearestTank(player)
    if not player or player:isDead() or player:getVehicle() then return nil end
    local best, distance
    for x=math.floor(player:getX())-1,math.floor(player:getX())+1 do
        for y=math.floor(player:getY())-1,math.floor(player:getY())+1 do
            local sq=getCell():getGridSquare(x,y,player:getZ())
            if sq and not sq:isBlockedTo(player:getSquare()) then
                for i=0,sq:getObjects():size()-1 do
                    local obj=sq:getObjects():get(i)
                    local md=K.modDataOf(obj) or {}
                    -- standing by either half of a two-tile tank reaches it
                    local tank=md.KnoxAquarium and obj or (md.KnoxAquariumPart and K.masterOf and K.masterOf(obj)) or nil
                    if tank then
                        local d=(player:getX()-x-.5)^2+(player:getY()-y-.5)^2
                        if not distance or d<distance then best=tank;distance=d end
                    end
                end
            end
        end
    end
    return best
end
function K.radialEntries(player,obj,page)
    local d=obj:getModData().KnoxAquarium
    local entries={}
    local function add(title,detail,command,icon,go,item,fishId)
        table.insert(entries,{title=title,label=title..(detail and ('\n'..detail) or ''),command=command,icon=icon or 'inspect',page=go,item=item,fishId=fishId})
    end
    local empty=#d.fish==0 and d.water<=0
    if page=='water' or page=='fish' or page=='drainTo' then
        local items=player:getInventory():getItems()
        for i=0,items:size()-1 do
            local item=items:get(i)
            if page=='water' and K.waterSource(item) then
                add(item:getName(),string.format('Pour up to %.2f L into the tank.',math.max(0,math.min(K.cap(d)-d.water,item:getFluidContainer():getAmount()))),'fill','water',nil,item)
            elseif page=='drainTo' and item:getFluidContainer() and (item:getFluidContainer():isEmpty() or K.waterSource(item)) and item:getFluidContainer():getFreeCapacity()>0 then
                add(item:getName(),string.format('Collect up to %.2f L from the tank.',math.min(d.water,item:getFluidContainer():getFreeCapacity())),'drainTo','drain',nil,item)
            elseif page=='fish' and item:getModData().KnoxAquariumFish then
                local ok,reason=K.canAdd(d,item,K.now())
                local mins=math.max(0,math.ceil((item:getModData().KnoxAquariumFish.expires-K.now())*60))
                add(item:getName(),ok and ('Alive: '..mins..' game minutes left.') or reason,ok and 'add' or 'explain','fish',nil,item)
            end
        end
        if #entries==0 then
            local reason=page=='water' and 'Carry a container of water in your main inventory.' or (page=='fish' and 'Carry a freshly caught, live fish in your main inventory.' or 'Carry an empty or partly filled water container in your main inventory.')
            add('No suitable items',reason,'notice',page=='fish' and 'fish' or 'water')
        end
    elseif page=='residents' then
        for i,fish in ipairs(d.fish) do
            local id=K.fishId(fish,i)
            add('Fish '..i..': '..fish.name,fish.length..' cm. Choose to retrieve or discard.',nil,'fish_list','resident|'..id,nil,id)
        end
        if #entries==0 then add('Tank is empty','Add a live fish after filling the tank to 20 L.','notice','fish_list') end
    elseif string.sub(page,1,9)=='resident|' then
        local id=string.sub(page,10);local fish=K.findFish(d,id)
        if fish then
            if fish.snapshot then add('Take fish out','Return '..fish.name..' alive to your inventory. Its transport timer starts.','retrieve','retrieve',nil,nil,id)
            else add('Older saved fish','This prototype fish has no saved item data. It can be discarded, but not retrieved.','notice','inspect') end
            add('Discard this fish','Permanently remove this fish. Confirmation follows.',nil,'remove','discardOne|'..id,nil,id)
        else add('Fish already removed','Close and reopen Manage fish to refresh the list.','notice','fish_list') end
    elseif string.sub(page,1,11)=='discardOne|' then
        add('Confirm discard','Permanently delete this one fish. No item is returned.','discardOne','remove',nil,nil,string.sub(page,12))
    elseif page=='move' then
        -- The same rule as the server: nothing alive inside, AND no water.
        -- 2026-09-15 per Jay, after a live MP test: water blocks Pick up again,
        -- same as fish/animals (see K.tankEmpty and the server pack comment for
        -- the history of this rule flipping back and forth).
        local canPack=K.tankEmpty(d)
        add('Pick up tank',canPack and 'Put the empty tank in your inventory. Right-click it there to place it again.'
            or (K.occupied(d) and 'Take any fish or animal out first.' or 'Drain the tank before picking it up.'),
            canPack and 'pack' or 'notice','pack')
        add('Rotate tank','Turn the tank 90 degrees clockwise. Works with fish and water still in it.','rotate','rotate')
    elseif page=='animalsAdd' then
        local items=player:getInventory():getItems()
        for i=0,items:size()-1 do
            local item=items:get(i)
            if K.isLiveAnimal(item) then
                local ok,reason=K.canAddAnimal(d,item)
                add(K.animalName(item),ok and 'Move this animal into the habitat. It comes back out exactly as it went in.' or reason,
                    ok and 'addAnimal' or 'explainAnimal','fish',nil,item)
            end
        end
        if #entries==0 then add('No animal to hand','Carry a small live animal - a rat or a mouse - in your main inventory.','notice','fish') end
    elseif page=='residentAnimals' then
        for _,entry in ipairs(K.animals(d)) do
            add(entry.name,'Take '..entry.name..' back out and into your inventory.','retrieveAnimal','retrieve',nil,nil,entry.id)
        end
        if #entries==0 then add('Habitat is empty','Add a small live animal from your main inventory.','notice','fish_list') end
    elseif page=='species' then
        local locked=K.tankSpecies(d)
        add('Community tank',locked and 'Any species goes in. Your biggest fish is the one drawn properly.'
            or 'Already a community tank.',locked and 'setSpecies' or 'notice','fish',nil,nil,'')
        local names={}
        for itemType,variant in pairs(K.overlaySpecies or {}) do table.insert(names,{itemType,variant}) end
        table.sort(names,function(a,b) return a[2]<b[2] end)
        for _,entry in ipairs(names) do
            local itemType,variant=entry[1],entry[2]
            local ok,why=K.canSetSpecies(d,itemType)
            local label=variant:sub(1,1):upper()..variant:sub(2)
            add(locked==itemType and (label..' (current)') or label,
                ok and ('Only '..variant..' go in, and every one is drawn properly.') or why,
                ok and 'setSpecies' or 'notice','fish',nil,nil,itemType)
        end
        if #names==0 then add('No species artwork','No species with its own tank artwork is available.','notice','fish') end
    elseif page=='habitat' then
        local dry=K.isDry(d)
        local canSwitch,why=K.canSetMode(d,dry and 'water' or 'dry')
        add(dry and 'Switch to water' or 'Switch to dry habitat',
            canSwitch and (dry and ('Take '..K.cap(d)..' litres and live fish again.') or 'Keep a small live animal instead of fish. No water.') or why,
            canSwitch and 'setMode' or 'notice',dry and 'water' or 'pack',nil,nil,dry and 'water' or 'dry')
    elseif page=='options' then
        if K.tierOf(d).overlayDir then
            local locked=K.tankSpecies(d)
            add('Tank species',locked and ('Set up for '..K.speciesName(locked)
                ..'. Every fish is drawn properly. Change or clear it here.')
                or 'Community tank: any species, but only your biggest fish is drawn properly. Set a species to fix that.',
                nil,'fish','species')
        end
        add('Habitat mode',K.isDry(d) and 'Currently a dry habitat for a small animal. Switch back to water here.' or 'Currently a water tank for fish. Switch to a dry habitat here.',nil,'options','habitat')
        if not K.isDry(d) then
            add('Drain water',#d.fish==0 and 'Collect the water in a container or discard it.' or 'Take out the fish before draining the tank.',#d.fish>0 and 'notice' or nil,'drain',#d.fish==0 and 'drain' or nil)
        end
        add(K.animationPaused and 'Resume animation' or 'Pause animation','Visual setting for all tanks on this client. Fish remain alive.','toggleAnimation',K.animationPaused and 'play' or 'pause')
        if K.betaToolsAllowed(player) then add('Test tools','Spawn supplies and change tank state for testing.',nil,'debug','debug') end
    elseif page=='drain' then
        if #d.fish==0 then
            add('Save the water','Choose a container in your main inventory.',nil,'drain','drainTo')
            add('Discard water','Empty the tank without keeping the water. Confirmation follows.',nil,'remove','discardWater')
        else add('Fish still in tank','Take out the fish before draining the tank.','notice','fish_list') end
    elseif page=='discardWater' then add('Confirm drain','Discard all water. This cannot be undone.','empty','drain')
    elseif page=='debug' then
        if K.betaToolsAllowed(player) then
            for _,v in ipairs({
                {'Starter supplies','20 L water, fishing gear, bait and five live fish.','debug_kit','debug'},
                {'All three tanks','Small, Large and Display aquarium kits, plus fish for each.','debug_kit_all','pack'},
                {'Display tank kit','The wide 400 L display aquarium plus two big fish.','debug_kit_display','pack'},
                {'Large tank kit','The 200 L planted aquarium plus two big fish.','debug_kit_large','pack'},
                {'Fish with tank art','One of each species that has its own artwork in the tank.','debug_art_all','fish'},
                {'Top 5 longest','The five longest species in this game, biggest first.','debug_rank_1','fish'},
                {'Next 5 longest','Species 6 to 10 by length.','debug_rank_2','fish'},
                {'Small fish','Three of the smallest species this game has. Fits any tank.','debug_class_1','fish'},
                {'Medium fish','Three species that grow to 31-60 cm.','debug_class_2','fish'},
                {'Large fish','Three species that grow to 61-120 cm. Needs a big tank.','debug_class_3','fish'},
                {'Extra large fish','Three species over 120 cm. Needs a big tank.','debug_class_4','fish'},
                {'Test fish cases','Expired, cooked, oversized and other rejection cases.','debug_cases','fish_list'},
                {'Give water','Add two full 10 L buckets to your inventory.','debug_water','water'},
                {'Fishing supplies','Add a rod, tackle and bait.','debug_gear','debug'},
                {'Give live fish','Add one eligible fish with a normal transport timer.','debug_fish_live','fish'},
                {'Give a rat','Spawn a live grey rat in your inventory, for testing a dry habitat.','debug_rat','fish'},
                {'Give a mouse','Spawn a live mouse in your inventory, for testing a dry habitat.','debug_mouse','fish'},
                {'Give a female mouse','Spawn a live female mouse.','debug_mousefemale','fish'},
                {'Give a female rat','Spawn a live female rat.','debug_ratfemale','fish'},
                {'Give a mouse pup','Spawn a live mouse pup.','debug_mousepups','fish'},
                {'Give a baby rat','Spawn a live baby rat.','debug_ratbaby','fish'},
                {'Make tank dry','Switch this empty tank straight to a dry habitat.','debug_dry','pack'},
                {'Make tank water','Switch this empty tank back to a water tank.','debug_wet','water'},
                {'One-minute fish','Add a fish that expires after one game minute.','debug_fish_short','fish'},
                {'Fill instantly','Set tank water to 20 L. Uses no inventory water.','debug_full','water'},
                {'Nearly full tank','Set water to 19.5 L to test the fill requirement.','debug_partial','water'},
                {'Expire test fish','End the timer on spawned fish in your main inventory.','debug_expire','remove'},
                {'Show debug info','Report skill, timers and saved tank state.','debug_status','inspect'},
                {'Refresh display','Refresh the tank image and request synchronization.','debug_refresh','options'}
            }) do add(v[1],v[2],v[3],v[4]) end
            add('Reset test tank','Discard every fish and all water. Confirmation follows.',nil,'remove','reset')
            add('Remove test items','Delete unequipped test supplies in main inventory. Confirmation follows.',nil,'remove','cleanup')
        end
    elseif page=='reset' then add('Confirm tank reset','Permanently discard every fish and all water.','debug_reset','remove')
    elseif page=='cleanup' then add('Confirm cleanup','Delete only marked, unequipped test items from your main inventory.','debug_cleanup','remove')
    elseif page=='discard' then add('Confirm discard all','Permanently delete all fish. No items are returned.','release','remove')
    else
        if K.isDry(d) then
            add('Inspect tank',string.format('Dry habitat. %d / %d animals. Open the full list.',#K.animals(d),K.maxAnimals),'inspect','inspect')
            add('Add animal','Choose a small live animal in your main inventory: a rat or a mouse.',nil,'fish','animalsAdd')
            add('Manage animals','Take an animal back out of the habitat.',nil,'fish_list','residentAnimals')
        else
            add('Inspect tank',string.format('%.1f / %d L water. %d / %d fish. Open the full fish list.',d.water,K.cap(d),#d.fish,K.fishCap(d)),'inspect','inspect')
            local cap=K.cap(d)
            add('Add water',d.water<cap and 'Choose a water container from your main inventory.' or string.format('The tank is full: %d / %d L.',cap,cap),d.water>=cap and 'notice' or nil,'water',d.water<cap and 'water' or nil)
            local lengthCap=K.tierOf(d).maxIndividualLength
            add('Add live fish','Choose a live fish in your main inventory. '
                ..(lengthCap and ('Maximum length: '..lengthCap..' cm.') or 'Any size.'),nil,'fish','fish')
            add('Manage fish','Select one resident to take out or discard.',nil,'fish_list','residents')
        end
        add('Move tank','Pick up or rotate an empty aquarium.',nil,'pack','move')
        add('Tank options','Drain water, pause animation or open test tools.',nil,'options','options')
    end
    return entries
end

K.wheels={}
function K.icon(name) return getTexture('media/textures/KA_icons/'..name..'.png') end
-- Trim to a pixel budget rather than a character count: proportional fonts make
-- 22 characters anything between 70 and 150 pixels wide.
function K.caption(label,maxWidth)
    local text=string.match(label,'[^\n]+') or label
    maxWidth=maxWidth or 150
    local tm=getTextManager()
    if tm:MeasureStringX(UIFont.Small,text)<=maxWidth then return text end
    while #text>1 and tm:MeasureStringX(UIFont.Small,string.sub(text,1,#text-1)..'...')>maxWidth do
        text=string.sub(text,1,#text-1)
    end
    return string.sub(text,1,math.max(1,#text-1))..'...'
end
function K.wrapText(text,maxWidth,maxLines)
    local tm=getTextManager();local lines={};local current=''
    for word in string.gmatch(text,'%S+') do
        local candidate=current=='' and word or (current..' '..word)
        if current~='' and tm:MeasureStringX(UIFont.Small,candidate)>maxWidth then
            table.insert(lines,current);current=word
        else current=candidate end
    end
    if current~='' then table.insert(lines,current) end
    if #lines==0 then lines[1]='' end
    if maxLines and #lines>maxLines then
        while #lines>maxLines do table.remove(lines) end
        lines[maxLines]=K.caption(lines[maxLines],maxWidth)
    end
    return lines
end
-- The wheel is drawn by the Java RadialMenu, so the slice order and the bearing it
-- puts slice 1 at are not ours to assume. Ask the Java object which slice owns a
-- point, sweep the ring, and average each slice's bearings into a unit vector.
-- Vectors rather than angles: no atan2, which behaves identically under Kahlua and
-- under the standalone Lua the tests run on. Falls back to an even ring when the
-- answers are missing or not evenly spaced.
function K.sliceDirections(menu,count)
    local sx,sy={},{}
    if count>0 then
        pcall(function()
            local cx=menu.width/2;local cy=menu.height/2
            local r=((menu.innerRadius or 70)+(menu.outerRadius or 180))/2
            for step=0,179 do
                local a=step*math.pi*2/180
                local index=menu.javaObject:getSliceIndexFromMouse(cx+math.cos(a)*r,cy+math.sin(a)*r)
                if type(index)=='number' and index>=0 and index<count then
                    local i=index+1
                    sx[i]=(sx[i] or 0)+math.cos(a);sy[i]=(sy[i] or 0)+math.sin(a)
                end
            end
        end)
    end
    local directions={}
    local usable=count>0
    for i=1,count do
        local length=math.sqrt((sx[i] or 0)^2+(sy[i] or 0)^2)
        if length<0.001 then usable=false;break end
        directions[i]={x=sx[i]/length,y=sy[i]/length}
    end
    -- Two slices pointing the same way mean the probe was not understood. An even
    -- ring may not match the icons, but it is always readable; overlapping labels
    -- are not.
    if usable and count>1 then
        local closest=math.cos((math.pi*2/count)*0.5)
        for i=1,count do
            for j=i+1,count do
                if directions[i].x*directions[j].x+directions[i].y*directions[j].y>closest then
                    usable=false;break
                end
            end
            if not usable then break end
        end
    end
    if not usable then
        directions={}
        for i=1,count do
            local a=-math.pi/2+(i-1)*math.pi*2/count
            directions[i]={x=math.cos(a),y=math.sin(a)}
        end
    end
    return directions
end
function K.wheelIcon(entry)
    if entry.icon then return K.icon(entry.icon) end
    local key=entry.page or entry.command or 'inspect'
    if string.find(key,'debug',1,true) or key=='reset' or key=='cleanup' then return K.icon('debug') end
    if string.find(key,'fish',1,true) then return K.icon('fish') end
    if string.find(key,'water',1,true) or key=='fill' then return K.icon('water') end
    if key=='pack' then return K.icon('pack') end
    if key=='release' then return K.icon('remove') end
    return K.icon('inspect')
end
-- ISRadialMenu is drawn by a Java RadialMenu element that never calls a Lua
-- render, so labels cannot be painted onto the wheel itself. They go on a
-- separate panel added directly after it, which therefore draws on top of it.
-- The panel takes no mouse events, so every click still reaches the wheel.
K.wheelOverlays={}
local function ensureOverlayClass()
    if KAWheelOverlay then return KAWheelOverlay end
    -- ISPanel is not guaranteed to exist while the main menu loads mods.
    if not ISPanel then return nil end
    KAWheelOverlay=ISPanel:derive('KAWheelOverlay')
    local GAP=16      -- clear space between the wheel edge and its labels
    local PILL=20     -- label height

    function KAWheelOverlay:new(menu)
        local o=ISPanel:new(0,0,760,640)
        setmetatable(o,self);self.__index=self
        o.menu=menu
        o.background=false
        o.backgroundColor={r=0,g=0,b=0,a=0}
        o.borderColor={r=0,g=0,b=0,a=0}
        o.moveWithMouse=false
        o:setWantMouseEvents(false)
        return o
    end

    function KAWheelOverlay:instantiate()
        ISPanel.instantiate(self)
        self.javaObject:setConsumeMouseEvents(false)
    end

    function KAWheelOverlay:align()
        local menu=self.menu
        if not menu then return end
        self:setX(math.floor(menu:getX()+menu.width/2-self.width/2))
        self:setY(math.floor(menu:getY()+menu.height/2-self.height/2))
    end

    -- A label anchored at a fixed radius can still clip the wheel with its inner
    -- corner at some angles. Slide it straight out until all four corners clear.
    local function clearOfWheel(x,y,w,h,cx,cy,minimum,ux,uy)
        for _=1,30 do
            local nearest=math.huge
            local corners={{x,y},{x+w,y},{x,y+h},{x+w,y+h}}
            for _,corner in ipairs(corners) do
                nearest=math.min(nearest,math.sqrt((corner[1]-cx)^2+(corner[2]-cy)^2))
            end
            if nearest>=minimum then break end
            x=x+ux*4;y=y+uy*4
        end
        return x,y
    end

    function KAWheelOverlay:hoveredSlice()
        local menu=self.menu
        if not menu or not menu.javaObject then return -1 end
        local ok,index=pcall(function()
            return menu.javaObject:getSliceIndexFromMouse(menu:getMouseX(),menu:getMouseY())
        end)
        if ok and type(index)=='number' and index>=0 then return index+1 end
        return -1
    end

    function KAWheelOverlay:prerender()
        if self.menu and self.menu:isReallyVisible() then self:align() end
    end

    function KAWheelOverlay:render()
        local menu=self.menu
        if not menu or not menu:isReallyVisible() then return end
        local captions=menu.captions or {}
        local count=#captions
        if count==0 then return end
        local outer=menu.outerRadius or 180
        local cx=(menu:getX()+menu.width/2)-self:getX()
        local cy=(menu:getY()+menu.height/2)-self:getY()
        local tm=getTextManager()
        local hovered=self:hoveredSlice()

        local tank=menu.aquarium
        if tank and tank:getObjectIndex()>=0 then
            local d=tank:getModData().KnoxAquarium
            if d then
                local header=string.format('AQUARIUM     %.1f / %d litres     %d / %d fish',
                    d.water or 0,K.cap(d),#(d.fish or {}),K.fishCap(d))
                local w=tm:MeasureStringX(UIFont.Small,header)+24
                local y=cy-outer-GAP-PILL-12
                self:drawRect(cx-w/2,y,w,PILL,.90,.05,.09,.12)
                self:drawRectBorder(cx-w/2,y,w,PILL,.40,.42,.78,.86)
                self:drawTextCentre(header,cx,y+3,.86,.96,1,1,UIFont.Small)
            end
        end

        local directions=menu.sliceDirections or K.sliceDirections({},count)
        for i=1,count do
            local dir=directions[i] or {x=0,y=-1}
            local text=captions[i] or ''
            local w=tm:MeasureStringX(UIFont.Small,text)+14
            local px=cx+dir.x*(outer+GAP)
            local py=cy+dir.y*(outer+GAP)-PILL/2
            local x
            if dir.x>0.30 then x=px
            elseif dir.x<-0.30 then x=px-w
            else x=px-w/2 end
            x,py=clearOfWheel(x,py,w,PILL,cx,cy,outer+6,dir.x,dir.y)
            if i==hovered then
                self:drawRect(x,py,w,PILL,.95,.13,.42,.50)
                self:drawRectBorder(x,py,w,PILL,.90,.44,.88,.96)
                self:drawTextCentre(text,x+w/2,py+3,1,1,1,1,UIFont.Small)
            else
                self:drawRect(x,py,w,PILL,.82,.05,.09,.12)
                self:drawRectBorder(x,py,w,PILL,.32,.35,.62,.70)
                self:drawTextCentre(text,x+w/2,py+3,.78,.88,.94,1,UIFont.Small)
            end
        end

        -- No description panel. The labels already name every action, and a
        -- blocked action still explains itself when you click it. A permanent
        -- block of instructional text under the wheel was just noise.
    end

    return KAWheelOverlay
end
K.ensureOverlayClass=ensureOverlayClass

function K.getWheelOverlay(player,menu)
    local class=ensureOverlayClass()
    if not class then return nil end
    local index=player:getPlayerNum()
    if not K.wheelOverlays[index] then
        local overlay=class:new(menu);overlay:initialise()
        K.wheelOverlays[index]=overlay
    end
    K.wheelOverlays[index].menu=menu
    return K.wheelOverlays[index]
end

function K.hideWheelOverlay(index)
    local overlay=K.wheelOverlays[index]
    if overlay then overlay:removeFromUIManager() end
end

function K.getWheel(player)
    local index=player:getPlayerNum()
    if not K.wheels[index] then
        local menu=ISRadialMenu:new(0,0,70,180,index);menu:initialise()
        -- Every close path in ISRadialMenu funnels through undisplay: a click on a
        -- slice, a click outside, the V key again, and the joypad buttons.
        local closeWheel=menu.undisplay
        menu.undisplay=function(self)
            K.hideWheelOverlay(index)
            return closeWheel(self)
        end
        K.wheels[index]=menu
    end
    return K.wheels[index]
end

function K.showWheel(player,obj,page,offset)
    if not obj or obj:getObjectIndex()<0 then return end
    page=page or 'main';offset=offset or 0
    local menu=K.getWheel(player)
    menu:clear();menu:center()
    local entries=K.radialEntries(player,obj,page)
    menu.aquarium=obj;menu.captions={};menu.details={}
    local function choose(entry)
        if entry.page then K.showWheel(player,obj,entry.page);return end
        if entry.command=='notice' then
            player:Say(entry.label)
        elseif entry.command=='toggleAnimation' then K.animationPaused=not K.animationPaused
        elseif entry.command=='inspect' then
            local d=obj:getModData().KnoxAquarium;local names={}
            for _,f in ipairs(d.fish) do table.insert(names,f.name) end
            K.showInspection(player,obj)
        elseif entry.command=='explainAnimal' then
            local _,reason=K.canAddAnimal(obj:getModData().KnoxAquarium,entry.item)
            player:Say(reason or 'Select this animal again to add it.')
        elseif entry.command=='explain' then
            local _,reason=K.canAdd(obj:getModData().KnoxAquarium,entry.item,K.now());player:Say(reason or 'Select this fish again to add it.')
        else K.send(player,entry.command,obj:getSquare(),entry.item,entry.fishId) end
    end
    for i=offset+1,math.min(offset+6,#entries) do
        local entry=entries[i]
        local icon=K.wheelIcon(entry)
        menu:addSlice(entry.title or entry.label,icon,choose,entry)
        table.insert(menu.details,entry.label)
        table.insert(menu.captions,K.caption(entry.title or entry.label))
    end
    if offset+6<#entries then menu:addSlice('Next page',K.icon('next'),K.showWheel,player,obj,page,offset+6);table.insert(menu.captions,'More');table.insert(menu.details,'Next page') end
    if offset>0 then menu:addSlice('Previous page',K.icon('back'),K.showWheel,player,obj,page,math.max(0,offset-6));table.insert(menu.captions,'Previous');table.insert(menu.details,'Previous page')
    elseif page~='main' then menu:addSlice('Back to aquarium',K.icon('back'),K.showWheel,player,obj,'main',0);table.insert(menu.captions,'Back');table.insert(menu.details,'Return to the main aquarium wheel') end
    menu:addSlice('Close',K.icon('close'),function() end);table.insert(menu.captions,'Close');table.insert(menu.details,'Close the wheel without changing anything')
    menu.sliceDirections=K.sliceDirections(menu,#menu.captions)
    menu:addToUIManager();menu:setVisible(true)
    -- Added after the wheel so it renders above it; re-added on every page change
    -- so it can never fall behind.
    local overlay=K.getWheelOverlay(player,menu)
    if overlay then
        overlay:removeFromUIManager()
        overlay:align()
        overlay:addToUIManager();overlay:setVisible(true)
    end
end
-- Route the existing V binding only when a tank is reachable. All other key
-- events retain the vanilla behavior, including V inside a vehicle.
Events.OnGameStart.Add(function()
    if K.radialHooksInstalled then return end
    K.radialHooksInstalled=true
    local start=ISUIHandler.onKeyStartPressed
    local release=ISUIHandler.onKeyPressed
    Events.OnKeyStartPressed.Remove(start);Events.OnKeyPressed.Remove(release)
    local captured=false
    local onStart=function(key)
        if getCore():isKey('VehicleRadialMenu',key) then
            -- Anything going wrong in the aquarium half must never take V away
            -- from vehicles and emotes: on an error, fall through to vanilla.
            local ok,handled=pcall(function()
                local player=getSpecificPlayer(0);local tank=K.nearestTank(player)
                if not tank then return false end
                local menu=K.getWheel(player)
                if menu:isReallyVisible() then menu:undisplay() else K.showWheel(player,tank) end
                return true
            end)
            captured=ok and handled==true
            if captured then return end
        end
        start(key)
    end
    local onRelease=function(key)
        if getCore():isKey('VehicleRadialMenu',key) and captured then captured=false;return end
        release(key)
    end
    Events.OnKeyStartPressed.Add(onStart)
    Events.OnKeyPressed.Add(onRelease)
    -- Publish the wrappers where vanilla keeps its handlers. Another mod that
    -- later does the same swap then removes OUR wrapper from the event and calls
    -- it, so the chain stays single - instead of removing nothing (vanilla's
    -- function is no longer registered) and calling vanilla a second time, which
    -- opens and closes the V wheel in one key press.
    ISUIHandler.onKeyStartPressed=onStart
    ISUIHandler.onKeyPressed=onRelease
end)
