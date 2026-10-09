require "music/NMAlbumPackBuilder"

local function build(label, sound)
    return { label = label, sound = sound }
end

-- Base-mod example:
-- This shows the same album-builder path that child packs should use.
-- Edit the track rows, item IDs, or cover paths here only if the base OST itself changes.
local album = {
    module = "NewMusic",
    id = "ProjectZomboidOST",
    title = "Project Zomboid OST",
    trackSource = {
        explicit = {
            -- Base-media labels intentionally use UI_* keys so the default OST mirrors child-pack translation behavior.
            a = {
                build("UI_NM_PZOST_MainTheme", "NMZomboidTheme2"),
                build("UI_NM_PZOST_Alone", "NMZomboidAlone"),
                build("UI_NM_PZOST_Barricading", "NMZomboidBarricading"),
                build("UI_NM_PZOST_Chase", "NMZomboidChase"),
                build("UI_NM_PZOST_DesperateEscape", "NMZomboidDesperateEscape"),
                build("UI_NM_PZOST_FightOrFlight", "NMZomboidFightOrFlight"),
                build("UI_NM_PZOST_Guitar", "NMZomboidGuitar"),
                build("UI_NM_PZOST_Low", "NMZomboidLow"),
                build("UI_NM_PZOST_MaybeNot", "NMZomboidMaybeNot"),
                build("UI_NM_PZOST_MaybeWeCanWinThis", "NMZomboidMaybeWeCanWinThis"),
                build("UI_NM_PZOST_Misc", "NMZomboidMisc"),
                build("UI_NM_PZOST_Piano", "NMZomboidPiano"),
                build("UI_NM_PZOST_Introduction", "NMZomboidPreface"),
            },
            b = {
                build("UI_NM_PZOST_PZ", "NMZomboidPZ"),
                build("UI_NM_PZOST_AmbientRaider", "NMZomboidRaider"),
                build("UI_NM_PZOST_Run", "NMZomboidRun"),
                build("UI_NM_PZOST_SayingGoodbye", "NMZomboidSayingGoodbye"),
                build("UI_NM_PZOST_TheHorde", "NMZomboidTheHorde"),
                build("UI_NM_PZOST_TheInevitable", "NMZomboidTheInevitable"),
                build("UI_NM_PZOST_TheZombieThreat", "NMZomboidTheZombieThreat"),
                build("UI_NM_PZOST_TheyWereOnceHere", "NMZomboidTheyWereOnceHere"),
                build("UI_NM_PZOST_TuneDeath", "NMZomboidTuneDeath"),
                build("UI_NM_PZOST_WhatWasLost", "NMZomboidWhatWasLost"),
                build("UI_NM_PZOST_WhereIsEveryone", "NMZomboidWhereIsEveryone"),
                build("UI_NM_PZOST_WorkFast", "NMZomboidWorkFast"),
                build("UI_NM_PZOST_Active", "NMZomboidActive"),
                build("UI_NM_PZOST_Tense", "NMZomboidTense"),
            },
        },
    },
    media = {
        cassette = {
            mode = "split",
            items = {
                a = "CassettePZOSTA",
                b = "CassettePZOSTB",
                containerEmpty = "CassettePZOSTCaseEmpty",
                containerFull = "CassettePZOSTCaseFull",
            },
        },
        vinyl = {
            mode = "split",
            items = {
                a = "VinylPZOSTA",
                b = "VinylPZOSTB",
                containerEmpty = "JacketPZOSTEmpty",
                containerFull = "JacketPZOSTFull",
            },
        },
        cd = {
            mode = "split",
            items = {
                a = "CDPZOSTA",
                b = "CDPZOSTB",
                containerEmpty = "CDPZOSTCoverEmpty",
                containerFull = "CDPZOSTCoverFull",
            },
        },
    },
    coverGroups = {
        {
            mode = "fallback",
            texture = "WorldItems/Vinyl/HR/World_NM_MainCover_Zomboid",
            includePlayable = { "cassette", "cd" },
            includeContainers = { "cassette", "cd" },
            includeEmptyContainers = { "cassette", "cd" },
        },
        {
            mode = "linked",
            texture = "WorldItems/Vinyl/World_NM_Zomboid_Vinyl",
            includePlayable = { "vinyl" },
            includeContainers = { "vinyl" },
        },
        {
            mode = "linked",
            texture = "WorldItems/Vinyl/World_NM_Zomboid_Vinyl_Empty",
            includeEmptyContainers = { "vinyl" },
        },
    },
}

NMAlbumPackBuilder.registerAlbum(album)
