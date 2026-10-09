NMReadoutOverflowPager = NMReadoutOverflowPager or {}

local PAGE_DWELL_MS = 5000

local function utf8Chars(text)
    local s = tostring(text or "")
    local chars = {}
    local i = 1
    local n = #s
    while i <= n do
        local b = string.byte(s, i)
        local step = 1
        if b then
            if b >= 240 and b <= 247 and (i + 3) <= n then
                step = 4
            elseif b >= 224 and b <= 239 and (i + 2) <= n then
                step = 3
            elseif b >= 192 and b <= 223 and (i + 1) <= n then
                step = 2
            end
        end
        chars[#chars + 1] = string.sub(s, i, math.min(i + step - 1, n))
        i = i + step
    end
    return chars
end

local function utf8Len(text)
    return #utf8Chars(text)
end

local function utf8Sub(text, startIdx, endIdx)
    local chars = utf8Chars(text)
    local first = math.max(1, math.floor(tonumber(startIdx) or 1))
    local last = endIdx == nil and #chars or math.floor(tonumber(endIdx) or #chars)
    if first > #chars or last < first then
        return ""
    end
    if last > #chars then
        last = #chars
    end
    return table.concat(chars, "", first, last)
end

local function measure(text)
    local tm = getTextManager and getTextManager() or nil
    if not tm or not tm.MeasureStringX then
        return utf8Len(text) * 6
    end
    return tonumber(tm:MeasureStringX(UIFont.Small, tostring(text or ""))) or 0
end

local function fits(text, maxWidth)
    return measure(text) <= (tonumber(maxWidth) or 0)
end

local function longestPrefixFit(text, maxWidth)
    local s = tostring(text or "")
    if s == "" then return "" end
    local lo, hi = 1, utf8Len(s)
    local best = ""
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local candidate = utf8Sub(s, 1, mid)
        if fits(candidate, maxWidth) then
            best = candidate
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return best
end

local function buildPages(fullText, contentW)
    local text = tostring(fullText or "")
    if text == "" then
        return { "" }
    end
    if fits(text, contentW) then
        return { text }
    end

    local pages = {}
    local n = utf8Len(text)
    local i = 1
    while i <= n do
        local remaining = utf8Sub(text, i)
        local prefix
        if i == 1 then
            prefix = longestPrefixFit(remaining, contentW - measure("..."))
            if prefix == "" then prefix = utf8Sub(remaining, 1, 1) end
            pages[#pages + 1] = prefix .. "..."
            i = i + utf8Len(prefix)
        else
            local room = contentW - measure("......")
            if room < 1 then room = 1 end
            prefix = longestPrefixFit(remaining, room)
            if prefix == "" then prefix = utf8Sub(remaining, 1, 1) end
            i = i + utf8Len(prefix)
            if i > n then
                pages[#pages + 1] = "..." .. prefix
            else
                pages[#pages + 1] = "..." .. prefix .. "..."
            end
        end
    end
    if #pages < 1 then
        pages[1] = text
    end
    return pages
end

function NMReadoutOverflowPager.resolvePagedText(panel, fullText, contentWidth, nowMs)
    local text = tostring(fullText or "")
    local width = math.max(1, math.floor(tonumber(contentWidth) or 1))
    local now = tonumber(nowMs) or 0
    panel._nmReadoutPager = panel._nmReadoutPager or {}
    local pager = panel._nmReadoutPager

    local textChanged = pager.fullText ~= text
    local widthChanged = pager.contentWidth ~= width
    if textChanged or widthChanged or type(pager.pages) ~= "table" then
        pager.fullText = text
        pager.contentWidth = width
        pager.pages = buildPages(text, width)
        pager.pageIndex = 1
        pager.pageStartMs = now
    end

    local pages = pager.pages or { text }
    if #pages <= 1 then
        return pages[1] or text
    end

    local start = tonumber(pager.pageStartMs) or now
    local elapsed = math.max(0, now - start)
    local step = math.floor(elapsed / PAGE_DWELL_MS)
    local idx = ((tonumber(pager.pageIndex) or 1) - 1 + step) % #pages + 1
    if step > 0 then
        pager.pageIndex = idx
        pager.pageStartMs = now - (elapsed % PAGE_DWELL_MS)
    end
    return pages[idx] or text
end

function NMReadoutOverflowPager.getPageDwellMs()
    return PAGE_DWELL_MS
end
