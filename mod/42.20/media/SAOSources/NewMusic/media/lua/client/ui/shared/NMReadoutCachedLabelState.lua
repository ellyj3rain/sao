require "ui/shared/NMReadoutLabelState"

NMReadoutCachedLabelState = NMReadoutCachedLabelState or {}

local function countLabelCache(window, key)
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, tostring(key or ""), 1)
    end
end

local function rectKey(rect)
    return table.concat({
        tostring(rect and rect.x or 0),
        tostring(rect and rect.y or 0),
        tostring(rect and rect.w or 0),
        tostring(rect and rect.h or 0),
    }, ":")
end

local function identityKey(parts)
    if type(parts) ~= "table" then
        return tostring(parts or "")
    end
    local values = {}
    for i = 1, #parts do
        values[#values + 1] = tostring(parts[i] or "")
    end
    return table.concat(values, ":")
end

local function stateIdentityKey(state)
    if type(state) ~= "table" then
        return ""
    end
    return table.concat({
        tostring(state.mediaFullType or ""),
        tostring(state.trackIndex or ""),
        tostring(state.mediaDisplayName or ""),
    }, ":")
end

local function nextPagerDueMs(window, nowMs)
    local pager = window and window._nmReadoutPager or nil
    local pages = pager and pager.pages or nil
    if type(pages) ~= "table" or #pages <= 1 then
        return nil
    end
    local dwellMs = NMReadoutOverflowPager and NMReadoutOverflowPager.getPageDwellMs
        and tonumber(NMReadoutOverflowPager.getPageDwellMs())
        or 5000
    return (tonumber(pager.pageStartMs) or tonumber(nowMs) or 0) + dwellMs
end

function NMReadoutCachedLabelState.build(window, options)
    if not window then
        return nil
    end
    local opts = type(options) == "table" and options or {}
    local rect = opts.rect
    if not rect then
        return nil
    end

    local padX = tonumber(opts.padX) or 0
    local contentW = tonumber(opts.contentW)
    if contentW == nil then
        contentW = math.max(1, math.floor((tonumber(rect.w) or 0) - (padX * 2)))
    else
        contentW = math.max(1, math.floor(contentW))
    end

    local nowMs = tonumber(opts.nowMs) or 0
    local cacheName = tostring(opts.cacheName or "default")
    local explicitFullText = tostring(opts.fullText or "")
    local preResolutionKey = table.concat({
        tostring(explicitFullText),
        identityKey(opts.stateIdentityParts),
        stateIdentityKey(opts.state),
        tostring(opts.fallbackText or ""),
        tostring(contentW),
        rectKey(rect),
        identityKey(opts.identityParts),
    }, "|")

    window._nmReadoutCachedLabelState = window._nmReadoutCachedLabelState or {}
    local cached = window._nmReadoutCachedLabelState[cacheName]
    if type(cached) == "table" and cached.key == preResolutionKey then
        local nextDue = tonumber(cached.nextPageDueMs)
        if nextDue == nil or nowMs < nextDue then
            countLabelCache(window, "readout_label_cache_full_text_skip")
            countLabelCache(window, "readout_label_cache_hit")
            return cached.value
        end
        countLabelCache(window, "readout_label_cache_page_due")
    elseif cached ~= nil then
        countLabelCache(window, "readout_label_cache_input_changed")
    end

    local fullText = explicitFullText
    if fullText == "" and opts.state ~= nil then
        fullText = NMReadoutLabelState.resolveFullText(opts.state, opts.fallbackText)
    elseif fullText == "" then
        fullText = tostring(opts.fallbackText or "")
    end
    if opts.emptyAsNil == true and fullText == "" then
        return nil
    end

    local pageText = NMReadoutOverflowPager and NMReadoutOverflowPager.resolvePagedText
        and NMReadoutOverflowPager.resolvePagedText(opts.pagerHost or window, fullText, contentW, nowMs)
        or fullText
    local labelState = {
        text = tostring(pageText or ""),
        fullText = fullText,
        contentW = contentW,
        rect = rect,
        color = opts.color,
    }
    window._nmReadoutCachedLabelState[cacheName] = {
        key = preResolutionKey,
        nextPageDueMs = nextPagerDueMs(opts.pagerHost or window, nowMs),
        value = labelState,
    }
    countLabelCache(window, "readout_label_cache_miss")
    return labelState
end

return NMReadoutCachedLabelState
