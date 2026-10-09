-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
ComputerModLocalization = ComputerModLocalization or {}
ComputerModLocalization.defaults = ComputerModLocalization.defaults or {}

local function slug(value)
    local text = tostring(value or "")
    text = string.gsub(text, "[^A-Za-z0-9]+", "_")
    text = string.gsub(text, "^_+", "")
    text = string.gsub(text, "_+$", "")
    return text ~= "" and text or "Value"
end

function ComputerModLocalization.key(namespace, id, field)
    return "IGUI_ComputerMod_Content_" .. slug(namespace) .. "_" .. slug(id) .. "_" .. slug(field)
end

function ComputerModLocalization.text(namespace, id, field, fallback)
    local key = ComputerModLocalization.key(namespace, id, field)
    ComputerModLocalization.defaults[key] = tostring(fallback or "")
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return tostring(value) end
    end
    return tostring(fallback or "")
end

function ComputerModLocalization.getTranslationCatalog()
    return ComputerModLocalization.defaults
end

function ComputerModLocalization.localizeMail(entry)
    if type(entry) ~= "table" then return entry end
    local id = entry.ComputerModLocalizationId
    if not id or id == "" then
        id = tostring(entry.from or "mail") .. "_" .. tostring(entry.subject or entry.id or "message")
        entry.ComputerModLocalizationId = id
    end
    entry.subject = ComputerModLocalization.text("Mail", id, "Subject", entry.subject)
    entry.body = ComputerModLocalization.text("Mail", id, "Body", entry.body)
    return entry
end
