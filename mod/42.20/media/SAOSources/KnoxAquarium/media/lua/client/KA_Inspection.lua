require 'ISUI/ISCollapsableWindow'
require 'ISUI/ISRichTextPanel'
require 'ISUI/ISButton'
require 'KA_Core'
require 'KA_Fish3D'
local K=KnoxAquarium

-- Keep game names from being read as rich-text markup.
local function plain(name) return string.gsub(tostring(name or ''),'[<>]','') end

local function describeSpecies(record)
    local species=K.speciesOf(record)
    if not species then return nil end
    local bits={}
    if species.class then table.insert(bits,(K.SIZE_NAME[species.class] or '?')..' species') end
    if species.maxLength then table.insert(bits,'grows to '..math.floor(species.maxLength)..' cm') end
    if #bits==0 then return nil end
    return table.concat(bits,', ')
end

function K.showInspection(player,obj)
    if K.inspection then
        if K.inspection.kaViewer then pcall(function() K.inspection.kaViewer:remove() end) end
        K.inspection:removeFromUIManager()
    end
    local d=obj:getModData().KnoxAquarium
    local dry=K.isDry(d)

    -- The 3D panel only appears for a water tank that actually has a fish in it
    -- whose species ships a model. Everything else keeps the original layout, so
    -- a missing 3D scene can never cost the player the text they always had.
    local residents = (not dry) and d.fish or {}
    local wants3D = false
    if #residents>0 and K.fish3D and rawget(_G,'ISUI3DScene') then
        for _,fish in ipairs(residents) do
            if fish.type and K.fish3D.hasModel(fish.type) then wants3D=true; break end
        end
    end

    local width = wants3D and 700 or 460
    local win=ISCollapsableWindow:new(120,120,width,360)
    win:initialise();win:setTitle(dry and 'Knox Aquarium - Dry habitat' or 'Knox Aquarium - Fish and water');win:addToUIManager()
    local textWidth = wants3D and 330 or 436
    local panel=ISRichTextPanel:new(12,34,textWidth,306)
    panel:initialise();panel.autosetheight=false;panel:ignoreHeightChange();win:addChild(panel);panel:addScrollBars();panel.clip=true

    local text
    if dry then
        local animals=K.animals(d)
        text=string.format('Dry habitat - no water. <LINE> Animals: %d / %d (small animals only: rat, mouse) <LINE> <LINE> ',#animals,K.maxAnimals)
        for i,entry in ipairs(animals) do
            text=text..i..'. '..plain(entry.name)..(entry.kind and (' ('..plain(entry.kind)..')') or '')
                ..' <LINE> Living here. Take it out from Manage animals. <LINE> <LINE> '
        end
        if #animals==0 then text=text..'Nobody living here yet. Add a small live animal from your main inventory. <LINE> <LINE> ' end
        text=text..'Take every animal out before picking the tank up.'
    else
        local tier=K.tierOf(d)
        -- The original tank has no size limit, so there is no number to show.
        local lengthCap=tier.maxIndividualLength
        text=string.format('Water: %.1f / %d litres <LINE> Fish: %d / %d (%s) <LINE> <LINE> ',
            d.water,tier.capacity,#d.fish,tier.maxFish,
            lengthCap and ('maximum '..lengthCap..' cm each') or 'any size')
        for i,fish in ipairs(d.fish) do
            text=text..i..'. '..plain(fish.name or 'Fish')..' <LINE> '
            local about=describeSpecies(fish)
            if about then text=text..plain(about)..' <LINE> ' end
            text=text..(fish.snapshot and 'Can be retrieved alive.' or 'Prototype specimen: individual discard available.')..' <LINE> <LINE> '
        end
        if #d.fish==0 then text=text..'No fish yet. Fill to '..tier.capacity..' litres, then add a live catch. <LINE> <LINE> ' end
        text=text..'V beside a tank opens its wheel. Retrieving a fish starts its transport deadline. Empty the tank before removing it.'
    end
    panel.text=text;panel:paginate()

    if wants3D then
        local vx,vy,vw,vh=352,34,336,250
        local viewer=K.fish3D.createViewer(win,vx,vy,vw,vh)
        if not viewer then
            -- The window was widened for a viewer that could not be created.
            -- Put it back so the player never sees a half-empty panel.
            win:setWidth(460)
            panel:setWidth(436)
            panel:paginate()
        end
        if viewer then
            win.kaViewer=viewer
            win.kaIndex=1
            local caption=ISRichTextPanel:new(vx,vy+vh+4,vw,26)
            caption:initialise();caption.autosetheight=false;caption:ignoreHeightChange()
            caption.marginTop=0;caption.clip=true
            win:addChild(caption)

            local function show(index)
                local n=#residents
                if n==0 then return end
                index=((index-1)%n)+1
                win.kaIndex=index
                local fish=residents[index]
                local mounted=viewer:setFish(fish.type)
                local label=plain(fish.name or 'Fish')
                if n>1 then label=index..' / '..n..'  '..label end
                if not mounted then label=label..'  (no model)' end
                caption.text=' <CENTRE> '..label
                caption:paginate()
            end

            if #residents>1 then
                local bw,bh=34,20
                local prev=ISButton:new(vx,vy+vh+32,bw,bh,'<',win,function() show(win.kaIndex-1) end)
                prev:initialise();prev:instantiate();win:addChild(prev)
                local nxt=ISButton:new(vx+vw-bw,vy+vh+32,bw,bh,'>',win,function() show(win.kaIndex+1) end)
                nxt:initialise();nxt:instantiate();win:addChild(nxt)
            end
            show(1)

            -- ISCollapsableWindow:close() only hides the window, and there is
            -- no onClose to hook, so wrap close on this instance to drop the
            -- model rather than leave it mounted on a hidden scene.
            local inherited=win.close
            win.close=function(self)
                if self.kaViewer then pcall(function() self.kaViewer:remove() end); self.kaViewer=nil end
                if inherited then inherited(self) end
            end
        end
    end

    K.inspection=win
end
