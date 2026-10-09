-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMTranslations = NMTranslations or {}

local MOD_ID = "NewMusic"
local UI_FORMAT_CACHE_BY_LANGUAGE = {}
local IGUI_FORMAT_CACHE_BY_LANGUAGE = {}
local FORMAT_TEMPLATE_PATH_ROOTS = {
    "media/lua/shared/Translate",
    "common/media/lua/shared/Translate",
    "42/media/lua/shared/Translate"
}

local function trim(value)
    local text = tostring(value or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function getCurrentLanguageCandidates()
    local out = {}
    local seen = {}
    local language = Translator and Translator.getLanguage and Translator.getLanguage() or nil

    local function pushLanguageName(name)
        local key = tostring(name or "")
        if key == "" or seen[key] then
            return
        end
        seen[key] = true
        out[#out + 1] = key
    end

    if language then
        local okName, name = pcall(function() return language:name() end)
        if okName then
            pushLanguageName(name)
        end
        local okBase, base = pcall(function() return language:base() end)
        if okBase then
            pushLanguageName(base)
        end
    end

    pushLanguageName("EN")
    return out
end

local function nowLogMs()
    if getTimestampMs then
        local okMs, ms = pcall(getTimestampMs)
        if okMs then
            return tonumber(ms) or 0
        end
    end
    if getTimestamp then
        local okTs, ts = pcall(getTimestamp)
        if okTs then
            return (tonumber(ts) or 0) * 1000
        end
    end
    return 0
end

local function shouldLogFormatTemplateResolution(fullKey)
    return NMCore
        and NMCore.logChannel
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled("core") == true
        and NMCore.shouldLogEvery
        and NMCore.shouldLogEvery("core.translation_format." .. tostring(fullKey or ""), nowLogMs(), 15000)
end

local function logFormatTemplateResolution(fullKey, sourcePath, usedFallback)
    if not shouldLogFormatTemplateResolution(fullKey) then
        return
    end
    NMCore.logChannel(
        "core",
        "translation_format_template",
        string.format(
            "key=%s source=%s fallback=%s",
            tostring(fullKey or ""),
            tostring(sourcePath or ""),
            tostring(usedFallback == true)
        )
    )
end

local function logFormatFailure(template, fallbackTemplate, err)
    if not shouldLogFormatTemplateResolution(template) then
        return
    end
    NMCore.logChannel(
        "core",
        "translation_format_failure",
        string.format(
            "template=%s fallback=%s error=%s",
            tostring(template or ""),
            tostring(fallbackTemplate or ""),
            tostring(err or "")
        )
    )
end

local function readModTextFile(path)
    if type(getModFileReader) ~= "function" then
        return nil, nil
    end
    local okReader, reader = pcall(SAO.SourceIntegration.reader, MOD_ID, path, false)
    if not okReader or not reader then
        return nil, nil
    end

    local parts = {}
    while true do
        local line = reader:readLine()
        if not line then
            break
        end
        parts[#parts + 1] = tostring(line)
    end
    reader:close()
    return table.concat(parts, "\n"), tostring(path or "")
end

local function readFirstExistingModTextFile(pathSuffix)
    for i = 1, #FORMAT_TEMPLATE_PATH_ROOTS do
        local candidatePath = tostring(FORMAT_TEMPLATE_PATH_ROOTS[i]) .. "/" .. tostring(pathSuffix or "")
        local content, resolvedPath = readModTextFile(candidatePath)
        if tostring(content or "") ~= "" then
            return content, resolvedPath
        end
    end
    return nil, nil
end

local function parseQuotedTranslationEntries(content)
    local parsed = {}
    if tostring(content or "") == "" then
        return parsed
    end

    for key, rawValue in string.gmatch(content, '([%w_]+)%s*=%s*"((\\.|[^"])*)"') do
        local value = rawValue
        value = value:gsub("\\\\", "\1")
        value = value:gsub('\\"', '"')
        value = value:gsub("\\n", "\n")
        value = value:gsub("\\r", "\r")
        value = value:gsub("\\t", "\t")
        value = value:gsub("\1", "\\")
        parsed[key] = value
    end
    return parsed
end

local function loadUiFormatEntriesForLanguage(languageName)
    local key = tostring(languageName or "")
    if key == "" then
        return {}
    end
    local cached = UI_FORMAT_CACHE_BY_LANGUAGE[key]
    if cached then
        return cached
    end

    local pathSuffix = string.format("%s/UI_%s.txt", key, key)
    local content, resolvedPath = readFirstExistingModTextFile(pathSuffix)
    cached = {
        entries = parseQuotedTranslationEntries(content),
        sourcePath = resolvedPath
    }
    UI_FORMAT_CACHE_BY_LANGUAGE[key] = cached
    return cached
end

local function loadIguiFormatEntriesForLanguage(languageName)
    local key = tostring(languageName or "")
    if key == "" then
        return {}
    end
    local cached = IGUI_FORMAT_CACHE_BY_LANGUAGE[key]
    if cached then
        return cached
    end

    local pathSuffix = string.format("%s/IG_UI_%s.txt", key, key)
    local content, resolvedPath = readFirstExistingModTextFile(pathSuffix)
    cached = {
        entries = parseQuotedTranslationEntries(content),
        sourcePath = resolvedPath
    }
    IGUI_FORMAT_CACHE_BY_LANGUAGE[key] = cached
    return cached
end

local function getFormatTemplate(loader, fullKey, fallback)
    local lookupKey = tostring(fullKey or "")
    local languages = getCurrentLanguageCandidates()
    for i = 1, #languages do
        local entries = loader(languages[i])
        local value = entries and entries.entries and entries.entries[lookupKey] or nil
        if tostring(value or "") ~= "" then
            logFormatTemplateResolution(lookupKey, entries and entries.sourcePath or "", false)
            return tostring(value)
        end
    end
    logFormatTemplateResolution(lookupKey, "", true)
    return tostring(fallback or lookupKey)
end

local function getUiFormatTemplate(fullKey, fallback)
    return getFormatTemplate(loadUiFormatEntriesForLanguage, fullKey, fallback)
end

local function getIguiFormatTemplate(fullKey, fallback)
    return getFormatTemplate(loadIguiFormatEntriesForLanguage, fullKey, fallback)
end

function NMTranslations.text(key, fallback)
    local lookupKey = tostring(key or "")
    if lookupKey ~= "" and type(getText) == "function" then
        local ok, resolved = pcall(getText, lookupKey)
        local candidate = tostring(resolved or "")
        if ok and candidate ~= "" and candidate ~= lookupKey then
            return candidate
        end
    end
    return tostring(fallback or lookupKey)
end

-- B42 warns on translator access to keys that still contain printf placeholders,
-- so formatted UI templates are read from this mod's locale files instead of getText().
function NMTranslations.textStringFormat(template, fallbackTemplate, ...)
    local resolvedTemplate = tostring(template or "")
    local resolvedFallback = tostring(fallbackTemplate or "")
    local argCount = select("#", ...)
    if argCount <= 0 then
        if resolvedTemplate ~= "" then
            return resolvedTemplate
        end
        return resolvedFallback
    end

    local args = { ... }
    if resolvedTemplate == "" then
        resolvedTemplate = resolvedFallback
    end

    local ok, formatted = pcall(string.format, resolvedTemplate, unpack(args, 1, argCount))
    if ok and formatted ~= nil then
        return tostring(formatted)
    end

    if resolvedFallback ~= "" then
        local fallbackOk, fallbackFormatted = pcall(string.format, resolvedFallback, unpack(args, 1, argCount))
        if fallbackOk and fallbackFormatted ~= nil then
            logFormatFailure(resolvedTemplate, resolvedFallback, formatted)
            return tostring(fallbackFormatted)
        end
        logFormatFailure(resolvedTemplate, resolvedFallback, fallbackFormatted)
        return resolvedFallback
    end

    logFormatFailure(resolvedTemplate, resolvedFallback, formatted)
    return resolvedTemplate ~= "" and resolvedTemplate or resolvedFallback
end

function NMTranslations.ui(suffix, fallback)
    return NMTranslations.text("UI_NM_" .. tostring(suffix or ""), fallback)
end

function NMTranslations.uiFormatTemplate(suffix, fallback)
    return getUiFormatTemplate("UI_NM_" .. tostring(suffix or ""), fallback)
end

function NMTranslations.uiStringFormat(suffix, fallback, ...)
    return NMTranslations.textStringFormat(NMTranslations.uiFormatTemplate(suffix, fallback), fallback, ...)
end

function NMTranslations.modeTooltip(valueSuffix)
    local label = NMTranslations.ui("ModeLabel")
    local value = NMTranslations.ui(valueSuffix)
    return tostring(label or "") .. " " .. tostring(value or "")
end

function NMTranslations.igui(suffix, fallback)
    return NMTranslations.text("IGUI_NM_" .. tostring(suffix or ""), fallback)
end

function NMTranslations.iguiFormatTemplate(suffix, fallback)
    return getIguiFormatTemplate("IGUI_NM_" .. tostring(suffix or ""), fallback)
end

function NMTranslations.iguiStringFormat(suffix, fallback, ...)
    return NMTranslations.textStringFormat(NMTranslations.iguiFormatTemplate(suffix, fallback), fallback, ...)
end

function NMTranslations.itemName(fullType, fallback)
    local ft = trim(fullType)
    if ft == "" then
        return tostring(fallback or "")
    end
    return NMTranslations.text("ItemName_" .. tostring((ft:gsub("%.", "_"))), fallback or ft)
end

-- Child-pack labels may already be translation keys; resolve those without touching literal labels.
function NMTranslations.trackLabel(label, fallback)
    local text = tostring(label or "")
    if text == "" then
        return tostring(fallback or "")
    end
    if string.sub(text, 1, 3) == "UI_" then
        return NMTranslations.text(text, fallback or text)
    end
    return text
end

function NMTranslations.numberedTrackLabel(rowOrLabel, fallback, trackNumber)
    local rawLabel = rowOrLabel
    local rawFallback = fallback
    local rawTrackNumber = trackNumber
    if type(rowOrLabel) == "table" then
        rawLabel = rowOrLabel.label or rowOrLabel.sound
        rawFallback = fallback or rowOrLabel.sound
        rawTrackNumber = rowOrLabel.trackNumber
    end

    local label = tostring(NMTranslations.trackLabel(rawLabel, rawFallback) or "")
    if label == "" then
        return label
    end

    local numericTrackNumber = tonumber(rawTrackNumber)
    if not numericTrackNumber or numericTrackNumber < 1 then
        return label
    end

    if NMRuntimeConfig and NMRuntimeConfig.getShowTrackNumberPrefix and NMRuntimeConfig.getShowTrackNumberPrefix() ~= true then
        return label
    end

    return string.format("%02d. %s", math.floor(numericTrackNumber), label)
end

return NMTranslations
