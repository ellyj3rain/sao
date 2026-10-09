-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
--[[ Knox Aquarium - beta test tools.

    These are the same tools that were in the world menu before, moved intact
    into the one "Fish Tank" entry so they stop adding a second top-level option
    to every right-click. Nothing was removed: this is still the whole set.

    KA_Menu decides WHEN they appear - single-player, or an admin in
    multiplayer - and only inside a menu that had a reason to exist anyway, so
    they never show up on somebody's fridge.

    0.13.0: the first version of this file still carried two lines from the old
    handler that built the menu on a variable called `context`, which does not
    exist in here. Every time the tools were shown the menu raised on a nil and
    stopped half built. The submenu is now built on `parent` only.
]]
require 'KA_Core'
local K = KnoxAquarium

function K.addBetaTools(parent, player, sq, tank)
    if not K.betaToolsAllowed(player) then return end
    local root = parent:addOption('Beta tools')
    local debugMenu = ISContextMenu:getNew(parent)
    parent:addSubMenu(root, debugMenu)
    local function option(label,command)
        debugMenu:addOption(label,player,function(p) K.send(p,command,sq) end)
    end
    option('Give complete starter kit (small tank)','debug_kit')
    local tankRoot=debugMenu:addOption('Give a TANK kit...')
    local tankMenu=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(tankRoot,tankMenu)
    for _,entry in ipairs({
        {'1. SMALL Aquarium  (20 L, 4 fish of any size)','debug_kit_small'},
        {'2. LARGE Aquarium  (200 L, planted, 2 big fish)','debug_kit_large'},
        {'3. DISPLAY Aquarium  (400 L, wide, 4 big fish)','debug_kit_display'},
        {'ALL THREE tanks + fish for each','debug_kit_all'},
    }) do
        local command=entry[2]
        tankMenu:addOption(entry[1],player,function(p) K.send(p,command,sq) end)
    end
    local artRoot=debugMenu:addOption('Spawn fish WITH TANK ART...')
    local artMenu=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(artRoot,artMenu)
    local artNames={}
    for _,variant in pairs(K.overlaySpecies or {}) do table.insert(artNames,variant) end
    table.sort(artNames)
    artMenu:addOption('ONE OF EACH ('..#artNames..' species)',player,function(p) K.send(p,'debug_art_all',sq) end)
    for _,variant in ipairs(artNames) do
        local command='debug_art_'..variant
        artMenu:addOption(variant:sub(1,1):upper()..variant:sub(2),player,function(p) K.send(p,command,sq) end)
    end
    local rankRoot=debugMenu:addOption('Spawn fish BIGGEST first...')
    local rankMenu=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(rankRoot,rankMenu)
    for pageNum=1,6 do
        local command='debug_rank_'..pageNum
        rankMenu:addOption('#'..((pageNum-1)*5+1)..'-'..(pageNum*5)..' longest species',player,
            function(p) K.send(p,command,sq) end)
    end
    rankMenu:addOption('Print the whole ranking to console',player,function(p) K.send(p,'debug_rank_list',sq) end)
    local sizeRoot=debugMenu:addOption('Spawn fish BY SIZE...')
    local sizeMenu=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(sizeRoot,sizeMenu)
    for _,entry in ipairs({
        {'SMALL  (to 30 cm)','debug_class_1'},
        {'MEDIUM (31-60 cm)','debug_class_2'},
        {'LARGE  (61-120 cm)','debug_class_3'},
        {'EXTRA LARGE (over 120 cm)','debug_class_4'},
    }) do
        local command=entry[2]
        sizeMenu:addOption(entry[1],player,function(p) K.send(p,command,sq) end)
    end
    option('Give rejection / boundary test kit','debug_cases')
    option('Give 20 litres of water','debug_water')
    option('Give fishing rod, tackle and bait','debug_gear')
    local fishRoot=debugMenu:addOption('Spawn test fish...')
    local fishMenu=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(fishRoot,fishMenu)
    for _,entry in ipairs({{'Live (normal skill deadline)','live'},{'Live (expires in 1 game minute)','short'},{'Expired','expired'},{'Exactly 30 cm','boundary'},{'31 cm (over the old 30 cm limit)','oversize'},{'Cooked','cooked'},{'Burnt','burnt'},{'Rotten','rotten'},{'Unmarked ordinary fish','unmarked'}}) do
        local command='debug_fish_'..entry[2]
        fishMenu:addOption(entry[1],player,function(p) K.send(p,command,sq) end)
    end
    local critterRoot=debugMenu:addOption('Spawn live animal...')
    local critterMenu=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(critterRoot,critterMenu)
    for _,entry in ipairs({{'Grey rat','debug_rat'},{'White rat','debug_rat_white'},{'Female rat','debug_ratfemale'},
                           {'Male mouse','debug_mouse'}, {'Female mouse','debug_mousefemale'},
                           {'Mouse pup','debug_mousepups'}, {'Baby rat','debug_ratbaby'}}) do
        local command=entry[2]
        critterMenu:addOption(entry[1],player,function(p) K.send(p,command,sq) end)
    end
    option('Expire spawned test fish','debug_expire')
    option('Print test status','debug_status')
    if tank then
        option('Set water to full','debug_full')
        option('Set water to just under full','debug_partial')
        option('Switch tank to dry habitat','debug_dry')
        option('Switch tank back to water','debug_wet')
        option('Refresh appearance / sync','debug_refresh')
        local reset=debugMenu:addOption('Reset this tank...')
        local confirm=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(reset,confirm)
        confirm:addOption('Discard tank contents and water',player,function(p) K.send(p,'debug_reset',sq) end)
    end
    local cleanup=debugMenu:addOption('Clean up spawned supplies...')
    local confirm=ISContextMenu:getNew(debugMenu); debugMenu:addSubMenu(cleanup,confirm)
    confirm:addOption('Delete unequipped test items in main inventory',player,function(p) K.send(p,'debug_cleanup',sq) end)
end
