require "ui/shared/NMReadoutOverflowPager"
require "ui/shared/NMReadoutTextResolver"

-- Canonical shared ui_render helper for paged readout label state.
NMReadoutLabelState = NMReadoutLabelState or {}

function NMReadoutLabelState.resolveFullText(state, fallbackText)
    local fullText = ""
    if NMReadoutTextResolver and NMReadoutTextResolver.resolveReadoutText then
        fullText = tostring(NMReadoutTextResolver.resolveReadoutText(state) or "")
    end
    if fullText == "" then
        fullText = tostring(fallbackText or "")
    end
    return fullText
end

function NMReadoutLabelState.build(window, options)
    local opts = options or {}
    local fullText = tostring(opts.fullText or "")
    if fullText == "" and opts.state ~= nil then
        fullText = NMReadoutLabelState.resolveFullText(opts.state, opts.fallbackText)
    elseif fullText == "" then
        fullText = tostring(opts.fallbackText or "")
    end
    if opts.emptyAsNil == true and fullText == "" then
        return nil
    end

    local contentW = tonumber(opts.contentW)
    if contentW == nil then
        local rect = opts.rect
        local padX = tonumber(opts.padX) or 0
        local rectW = tonumber(rect and rect.w) or 0
        contentW = math.max(1, rectW - (padX * 2))
    else
        contentW = math.max(1, math.floor(contentW))
    end

    local nowMs = tonumber(opts.nowMs) or 0
    local pagerHost = opts.pagerHost or window
    local text = NMReadoutOverflowPager and NMReadoutOverflowPager.resolvePagedText
        and NMReadoutOverflowPager.resolvePagedText(pagerHost, fullText, contentW, nowMs)
        or fullText

    return {
        text = tostring(text or ""),
        fullText = fullText,
        contentW = contentW,
        x = opts.x,
        y = opts.y,
        rect = opts.rect,
        color = opts.color,
    }
end

return NMReadoutLabelState
