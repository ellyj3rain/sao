-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
--[[ Knox Aquarium - optional compatibility with Fishing Overhaul BR.

    Workshop id 3784235810, mod id "PeixesBRExpansion", by gadinho.

    There is deliberately very little in this file, and that is the point. That
    mod registers its species into the base game's own Fishing.fishes list and
    gives each item its own 3D model on the item, both of which are the normal
    Build 42 way to do those things. KA_FishRegistry reads the first and
    KA_Fish3D reads the second, so every one of its species is picked up by the
    generic code with nothing species-specific written down anywhere.

    So this file does not adapt anything. It detects the mod, records what it
    contributed, and gives the interface something to say. If that mod changes
    its species list, adds species or renames them, nothing here needs editing.
    If it is not installed, nothing here does anything at all.

    NOTHING in this file writes to that mod's tables, files or items.
]]
-- K.registerOverlaySpecies lives in the registry. Required explicitly rather than
-- relying on another shared file happening to load it first.
require 'KA_FishRegistry'
KnoxAquarium = KnoxAquarium or {}
local K = KnoxAquarium

K.compat = K.compat or {}
local C = {id = 'PeixesBRExpansion', name = 'Fishing Overhaul BR', present = false, species = 0}
K.compat.peixesBR = C

-- Items from that mod live in these script modules. Used only to count what it
-- contributed for the interface and the log line - never to gate behaviour, so
-- a module renamed in a future version costs a wrong number in a log line and
-- nothing else.
C.modules = {PeixesBRX = true, PeixesBR = true, AnglerBR = true, TigerBR = true}

-- Species that ship overlay art. Each entry is one rendered fish; anything not
-- listed simply uses the tank's built-in fish, so this list can grow a species
-- at a time without touching the renderer or the tank sprites.
-- KNOWN GAPS, 2026-09-09. Three of his species have no usable mesh+texture pair:
--     Base.PeixesBR_Traira, Base.PeixesBR_Tilapia, Base.PeixesBR_Dourado
-- Their WorldStaticModel does not resolve to a model file this mod can find.
-- gadinho is fixing them on his side. They are deliberately ABSENT from the
-- table below, which is the safe state: a species with no entry is drawn by the
-- tank's own art like any vanilla fish, in every tier, at every fish count. The
-- same is true of any species he adds in future, so this mod cannot break when
-- his updates. compat_test.lua asserts exactly that.
--
-- To add them once he ships the models: re-run the species scan, re-render, and
-- regenerate this table. No code changes.
C.overlays = {
    -- Generated from Fishing Overhaul BR's own item scripts: every species
    -- whose WorldStaticModel resolves to a mesh AND a texture. The variant is
    -- the item's short name, lowercased, which is also the sprite folder name.
    -- Nothing here is hand-written, so regenerating after he adds species is a
    -- rebuild, not an edit.
    ['AnglerBR.FatBass']                = 'fatbass',
    ['AnglerBR.KingCrab']               = 'kingcrab',
    ['AnglerBR.Sharptooth']             = 'sharptooth',
    ['Base.PeixesBR_Arapaima']          = 'peixesbrarapaima',
    ['Base.PeixesBR_Arqueiro']          = 'peixesbrarqueiro',
    ['Base.PeixesBR_Arraia']            = 'peixesbrarraia',
    ['Base.PeixesBR_Aruana']            = 'peixesbraruana',
    ['Base.PeixesBR_Pintado']           = 'peixesbrpintado',
    ['Base.PeixesBR_Piranha']           = 'peixesbrpiranha',
    ['Base.PeixesBR_PiranhaPreta']      = 'peixesbrpiranhapreta',
    ['Base.PeixesBR_PiranhaVioleta']    = 'peixesbrpiranhavioleta',
    ['Base.PeixesBR_Tambaqui']          = 'peixesbrtambaqui',
    ['Base.PeixesBR_Tucunare']          = 'peixesbrtucunare',
    ['PeixesBRX.AguaViva']              = 'aguaviva',
    ['PeixesBRX.AmurSleeper']           = 'amursleeper',
    ['PeixesBRX.ArcticChar']            = 'arcticchar',
    ['PeixesBRX.Asp']                   = 'asp',
    ['PeixesBRX.Barbel']                = 'barbel',
    ['PeixesBRX.BigmouthBuffalo']       = 'bigmouthbuffalo',
    ['PeixesBRX.BlackBullhead']         = 'blackbullhead',
    ['PeixesBRX.Bleak']                 = 'bleak',
    ['PeixesBRX.BlueBream']             = 'bluebream',
    ['PeixesBRX.Bowfin']                = 'bowfin',
    ['PeixesBRX.BrookSilverside']       = 'brooksilverside',
    ['PeixesBRX.BrownTrout']            = 'browntrout',
    ['PeixesBRX.Burbot']                = 'burbot',
    ['PeixesBRX.Camarao']               = 'camarao',
    ['PeixesBRX.Chub']                  = 'chub',
    ['PeixesBRX.Cisco']                 = 'cisco',
    ['PeixesBRX.CommonBream']           = 'commonbream',
    ['PeixesBRX.CommonCarp']            = 'commoncarp',
    ['PeixesBRX.CommonNase']            = 'commonnase',
    ['PeixesBRX.CrucianCarp']           = 'cruciancarp',
    ['PeixesBRX.Dace']                  = 'dace',
    ['PeixesBRX.DanubeSalmon']          = 'danubesalmon',
    ['PeixesBRX.DanubeSturgeon']        = 'danubesturgeon',
    ['PeixesBRX.ElectricYellowCichlid'] = 'electricyellowcichlid',
    ['PeixesBRX.EmeraldShiner']         = 'emeraldshiner',
    ['PeixesBRX.EuropeanBitterling']    = 'europeanbitterling',
    ['PeixesBRX.EuropeanBullhead']      = 'europeanbullhead',
    ['PeixesBRX.EuropeanEel']           = 'europeaneel',
    ['PeixesBRX.EuropeanMinnow']        = 'europeanminnow',
    ['PeixesBRX.EuropeanPikeperch']     = 'europeanpikeperch',
    ['PeixesBRX.EuropeanSmelt']         = 'europeansmelt',
    ['PeixesBRX.EuropeanWhitefish']     = 'europeanwhitefish',
    ['PeixesBRX.FrontosaCichlid']       = 'frontosacichlid',
    ['PeixesBRX.GiantGourami']          = 'giantgourami',
    ['PeixesBRX.GizzardShad']           = 'gizzardshad',
    ['PeixesBRX.GoldenShiner']          = 'goldenshiner',
    ['PeixesBRX.GrassCarp']             = 'grasscarp',
    ['PeixesBRX.Grayling']              = 'grayling',
    ['PeixesBRX.GuadalupeBass']         = 'guadalupebass',
    ['PeixesBRX.Gudgeon']               = 'gudgeon',
    ['PeixesBRX.Huchen']                = 'huchen',
    ['PeixesBRX.Ide']                   = 'ide',
    ['PeixesBRX.Koi']                   = 'koi',
    ['PeixesBRX.KokaneeSalmon']         = 'kokaneesalmon',
    ['PeixesBRX.LakeTrout']             = 'laketrout',
    ['PeixesBRX.LongnoseGar']           = 'longnosegar',
    ['PeixesBRX.LongnoseSucker']        = 'longnosesucker',
    ['PeixesBRX.Lula']                  = 'lula',
    ['PeixesBRX.MonkeyGoby']            = 'monkeygoby',
    ['PeixesBRX.Mooneye']               = 'mooneye',
    ['PeixesBRX.MozambiqueTilapia']     = 'mozambiquetilapia',
    ['PeixesBRX.NilePerch']             = 'nileperch',
    ['PeixesBRX.NileTilapia']           = 'niletilapia',
    ['PeixesBRX.NorthernPike']          = 'northernpike',
    ['PeixesBRX.NorthernSnakehead']     = 'northernsnakehead',
    ['PeixesBRX.Oscar']                 = 'oscar',
    ['PeixesBRX.PeacockCichlid']        = 'peacockcichlid',
    ['PeixesBRX.PrussianCarp']          = 'prussiancarp',
    ['PeixesBRX.PumpkinseedSunfish']    = 'pumpkinseedsunfish',
    ['PeixesBRX.RainbowTrout']          = 'rainbowtrout',
    ['PeixesBRX.RedbreastSunfish']      = 'redbreastsunfish',
    ['PeixesBRX.Roach']                 = 'roach',
    ['PeixesBRX.RockBass']              = 'rockbass',
    ['PeixesBRX.Rudd']                  = 'rudd',
    ['PeixesBRX.Ruffe']                 = 'ruffe',
    ['PeixesBRX.Sabrefish']             = 'sabrefish',
    ['PeixesBRX.SacramentoPerch']       = 'sacramentoperch',
    ['PeixesBRX.SilverCarp']            = 'silvercarp',
    ['PeixesBRX.SpottedGar']            = 'spottedgar',
    ['PeixesBRX.Sterlet']               = 'sterlet',
    ['PeixesBRX.Sunbleak']              = 'sunbleak',
    ['PeixesBRX.Tench']                 = 'tench',
    ['PeixesBRX.ThreadfinShad']         = 'threadfinshad',
    ['PeixesBRX.VimbaBream']            = 'vimbabream',
    ['PeixesBRX.VolgaUndermouth']       = 'volgaundermouth',
    ['PeixesBRX.Warmouth']              = 'warmouth',
    ['PeixesBRX.Weatherfish']           = 'weatherfish',
    ['PeixesBRX.WelsCatfish']           = 'welscatfish',
    ['PeixesBRX.WhiteBream']            = 'whitebream',
    ['PeixesBRX.WhiteSucker']           = 'whitesucker',
    ['PeixesBRX.WhitefinGudgeon']       = 'whitefingudgeon',
    ['PeixesBRX.YellowBass']            = 'yellowbass',
    ['PeixesBRX.Zander']                = 'zander',
    ['TigerBR.Tigerfish']               = 'tigerfish',
}

-- Variants that have artwork for a GROUP of fish, not just a single.
--
-- 0.13.0 shipped six: camarao, peixesbrpiranha, lula, peixesbrtucunare,
-- longnosegar and welscatfish. Every other species drew one real fish with the
-- rest left to the tank's own generic art.
--
-- PLAYTEST, 2026-09-15: every species listed in C.overlays now has its group
-- art - Display Aquarium groups of 2, 3 and 4 (KA_dp_ov/<variant>_<n>_<frame>)
-- and Large Aquarium pairs (KA_lg_ov/<variant>_2_<frame>), all four facings.
-- They were rendered with the exact recipe of the six (a re-render of lula came
-- out pixel-identical to what shipped), so this is simply every variant. A tier
-- still caps what it draws (tier.overlayGroupMax), and tools/audit_release.lua
-- walks every tank state and fails the build if any frame is missing.
-- A variant named here with a number lower than 4 is drawn at most that many.
C.overlayGroups = {}
for _, variant in pairs(C.overlays) do C.overlayGroups[variant] = 4 end

function C.registerOverlays()
    local n = 0
    for itemType, variant in pairs(C.overlays) do
        K.registerOverlaySpecies(itemType, variant, C.overlayGroups[variant] or 1)
        n = n + 1
    end
    return n
end

local function detect()
    local ok, mods = pcall(function() return getActivatedMods() end)
    if ok and mods then
        local found = false
        pcall(function() found = mods:contains(C.id) end)
        if found then return true end
    end
    -- Fallback: the mod list can be unavailable in some contexts, so treat its
    -- registered species as proof of presence too.
    for _, info in pairs(K.buildFishRegistry() or {}) do
        if C.modules[info.module] then return true end
        if info.module == 'Base' and string.find(info.itemType, 'PeixesBR', 1, true) then return true end
    end
    return false
end

function C.refresh()
    C.present = detect()
    C.species = 0
    C.largest = nil
    if not C.present then return C end
    for _, info in pairs(K.buildFishRegistry() or {}) do
        local mine = C.modules[info.module]
            or (info.module == 'Base' and string.find(info.itemType, 'PeixesBR', 1, true))
        if mine then
            C.species = C.species + 1
            if info.maxLength and (not C.largest or info.maxLength > C.largest.maxLength) then
                C.largest = info
            end
        end
    end
    return C
end

-- Register the species art NOW, at load, on every side. It used to happen only
-- in OnGameStart below - and OnGameStart is fired by the client's IngameState
-- alone (checked in the B42.20 jar). A dedicated server, and the background
-- server of a hosted game, never fire it, so the SERVER had no species art
-- registered and refused every "species tank" request: K.canSetSpecies runs
-- there. C.overlays is static data shipped with this mod, so registering it
-- before the game starts is safe; a species whose mod is absent simply never
-- turns up as a fish. Registering again below is harmless - same keys.
-- 0.14.1: guarded - this runs at load in a shared file, so it loads on the
-- server too, and nothing here is worth failing a server launch over.
pcall(C.registerOverlays)

if Events and Events.OnGameStart then Events.OnGameStart.Add(function()
    C.refresh()
    local overlays = C.registerOverlays()
    if C.present then
        print('[KnoxAquarium] '..overlays..' species have their own tank artwork.')
        print('[KnoxAquarium] '..C.name..' detected: '..C.species
            ..' of its species registered; item models available to the Inspect viewer.')
    end
end) end
