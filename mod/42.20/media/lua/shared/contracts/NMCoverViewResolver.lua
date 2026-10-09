-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMCoverViewResolver = NMCoverViewResolver or {}

local linkedByMedia = {}
local fallbackByMedia = {}
local DEFAULT_NO_COVER_TEXTURE = "WorldItems/Vinyl/World_NM_NoCover"

local function norm(value)
    local s = tostring(value or "")
    if s == "" then
        return ""
    end
    return s
end

local function toTexturePath(textureKeyOrPath)
    local key = norm(textureKeyOrPath)
    if key == "" then
        return ""
    end
    if string.find(key, "/", 1, true) then
        return "media/textures/" .. key .. ".png"
    end
    return "media/textures/" .. key .. ".png"
end

local function scriptIconForFullType(fullType)
    local ft = norm(fullType)
    if ft == "" then
        return ""
    end
    local item = ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem
        and ScriptManager.instance:FindItem(ft) or nil
    if item and item.getIcon then
        return norm(item:getIcon())
    end
    return ""
end

local function numericSuffix(value)
    local s = norm(value)
    local num = string.match(s, "(%d+)$")
    if not num then
        return nil
    end
    return tonumber(num)
end

local function resolveBaseCoverFromToken(token)
    local t = norm(token)
    if t == "" then
        return nil, nil
    end

    if t == "NM_CDCover_Blank" then
        return "WorldItems/Vinyl/HR/World_NM_CDCover_Blank_HR", "fallback"
    end
    if t == "NM_CDCover_Empty" then
        return "WorldItems/Vinyl/HR/World_NM_CDCover_Empty_HR", "fallback"
    end

    if t == "NM_Jacket18_empty" then return "WorldItems/Vinyl/World_NM_Cover18_Vinyl_Empty", "linked" end
    if t == "NM_Jacket19_empty" then return "WorldItems/Vinyl/World_NM_Cover19_Vinyl_Empty", "linked" end
    if t == "NM_Jacket20_empty" then return "WorldItems/Vinyl/World_NM_Cover20_Vinyl_Empty", "linked" end
    if t == "NM_Jacket21_empty" then return "WorldItems/Vinyl/World_NM_Cover21_Vinyl_Empty", "linked" end
    if t == "NM_Jacket18" then return "WorldItems/Vinyl/World_NM_Cover18_Vinyl", "linked" end
    if t == "NM_Jacket19" then return "WorldItems/Vinyl/World_NM_Cover19_Vinyl", "linked" end
    if t == "NM_Jacket20" then return "WorldItems/Vinyl/World_NM_Cover20_Vinyl", "linked" end
    if t == "NM_Jacket21" then return "WorldItems/Vinyl/World_NM_Cover21_Vinyl", "linked" end

    local idx = numericSuffix(t)
    if idx and idx >= 1 and idx <= 17 then
        if string.find(t, "NM_Case", 1, true)
            or string.find(t, "NM_CDCover", 1, true)
            or string.find(t, "NM_Jacket", 1, true)
            or string.find(t, "NM_Cover", 1, true)
            or string.find(t, "NM_Cassette", 1, true) then
            return "WorldItems/Vinyl/World_NM_Cover" .. tostring(idx), "linked"
        end
    end
    return nil, nil
end

local function resolveBaseCoverForFullType(fullType)
    local ft = norm(fullType)
    if ft == "" then
        return nil, nil
    end
    local icon = scriptIconForFullType(ft)
    local texture, mode = resolveBaseCoverFromToken(icon)
    if texture and texture ~= "" then
        return texture, mode
    end
    local typeName = ft
    local dot = string.find(typeName, "%.")
    if dot then
        typeName = string.sub(typeName, dot + 1)
    end
    return resolveBaseCoverFromToken(typeName)
end

function NMCoverViewResolver.registerLinkedCover(mediaFullType, vinylTexturePath)
    local media = norm(mediaFullType)
    local texture = norm(vinylTexturePath)
    if media == "" or texture == "" then
        return
    end
    linkedByMedia[media] = texture
end

function NMCoverViewResolver.registerFallbackCover(mediaFullType, hrTexturePath)
    local media = norm(mediaFullType)
    local texture = norm(hrTexturePath)
    if media == "" or texture == "" then
        return
    end
    fallbackByMedia[media] = texture
end

function NMCoverViewResolver.resolvePath(itemFullType, state)
    local requested = norm(itemFullType)
    if requested == "" then
        return nil
    end

    -- Allow exact fullType mappings first (used for dual-sprite container cases).
    local exactLinked = norm(linkedByMedia[requested])
    if exactLinked ~= "" then
        return toTexturePath(exactLinked), "linked"
    end
    local exactFallback = norm(fallbackByMedia[requested])
    if exactFallback ~= "" then
        return toTexturePath(exactFallback), "fallback"
    end
    local baseDirect, baseMode = resolveBaseCoverForFullType(requested)
    if baseDirect and baseDirect ~= "" then
        return toTexturePath(baseDirect), baseMode or "linked"
    end

    local media = requested
    if NMMediaContract and NMMediaContract.resolveContainerMediaBinding then
        local fromContainer = norm(NMMediaContract.resolveContainerMediaBinding(media))
        if fromContainer ~= "" then
            media = fromContainer
        end
    end

    -- Prefer explicit ejected-media identity when available (dual-sprite container cases).
    local stateEject = norm(state and state.mediaEjectFullType or "")
    if stateEject ~= "" then
        local ejectLinked = norm(linkedByMedia[stateEject])
        if ejectLinked ~= "" then
            return toTexturePath(ejectLinked), "linked"
        end
        local ejectFallback = norm(fallbackByMedia[stateEject])
        if ejectFallback ~= "" then
            return toTexturePath(ejectFallback), "fallback"
        end
        local baseEject, baseEjectMode = resolveBaseCoverForFullType(stateEject)
        if baseEject and baseEject ~= "" then
            return toTexturePath(baseEject), baseEjectMode or "linked"
        end
    end

    if state and tostring(state.mediaFullType or "") ~= "" then
        media = norm(state.mediaFullType)
    end

    local linked = norm(linkedByMedia[media])
    if linked ~= "" then
        return toTexturePath(linked), "linked"
    end

    local fallback = norm(fallbackByMedia[media])
    if fallback ~= "" then
        return toTexturePath(fallback), "fallback"
    end

    local baseMedia, baseMediaMode = resolveBaseCoverForFullType(media)
    if baseMedia and baseMedia ~= "" then
        return toTexturePath(baseMedia), baseMediaMode or "linked"
    end

    -- Last-resort special-case by display label for custom multitrack packs.
    local display = string.lower(norm(state and state.mediaDisplayName or ""))
    if display ~= "" then
        if string.find(display, "now that's what i call tali", 1, true) then
            return toTexturePath("WorldItems/Vinyl/HR/World_NM_CDCover_Blank_HR"), "fallback"
        end
    end

    return toTexturePath(DEFAULT_NO_COVER_TEXTURE), "fallback"
end

function NMCoverViewResolver.debugSnapshot()
    return {
        linked = linkedByMedia,
        fallback = fallbackByMedia
    }
end

-- Base dual-sprite CD cover special-case HR mappings.
NMCoverViewResolver.registerFallbackCover(
    "NewMusic.CDCoverBlank",
    "WorldItems/Vinyl/HR/World_NM_CDCover_Blank_HR"
)
NMCoverViewResolver.registerFallbackCover(
    "NewMusic.CDCoverEmpty",
    "WorldItems/Vinyl/HR/World_NM_CDCover_Empty_HR"
)
NMCoverViewResolver.registerFallbackCover(
    "LifeIsStrange.CDNowThatCoverFull",
    "WorldItems/Vinyl/HR/World_NM_CDCover_Blank_HR"
)
NMCoverViewResolver.registerFallbackCover(
    "LifeIsStrange.CDNowThatCoverEmpty",
    "WorldItems/Vinyl/HR/World_NM_CDCover_Empty_HR"
)

-- Explicit dual-sprite vinyl jacket mappings (state-specific).
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover18",
    "WorldItems/Vinyl/World_NM_Cover18_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket18",
    "WorldItems/Vinyl/World_NM_Cover18_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover18Empty",
    "WorldItems/Vinyl/World_NM_Cover18_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket18Empty",
    "WorldItems/Vinyl/World_NM_Cover18_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover19",
    "WorldItems/Vinyl/World_NM_Cover19_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket19",
    "WorldItems/Vinyl/World_NM_Cover19_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover19Empty",
    "WorldItems/Vinyl/World_NM_Cover19_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket19Empty",
    "WorldItems/Vinyl/World_NM_Cover19_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover20",
    "WorldItems/Vinyl/World_NM_Cover20_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket20",
    "WorldItems/Vinyl/World_NM_Cover20_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover20Empty",
    "WorldItems/Vinyl/World_NM_Cover20_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket20Empty",
    "WorldItems/Vinyl/World_NM_Cover20_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover21",
    "WorldItems/Vinyl/World_NM_Cover21_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket21",
    "WorldItems/Vinyl/World_NM_Cover21_Vinyl"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Cover21Empty",
    "WorldItems/Vinyl/World_NM_Cover21_Vinyl_Empty"
)
NMCoverViewResolver.registerLinkedCover(
    "NewMusic.Jacket21Empty",
    "WorldItems/Vinyl/World_NM_Cover21_Vinyl_Empty"
)
