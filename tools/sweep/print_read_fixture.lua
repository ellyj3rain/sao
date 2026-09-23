-- Controlled engine objects for executing the installed ISReadABook.complete.
-- This host supplies an authored reading encounter, not a sampled play event.
ISBaseTimedAction = { derive = function() return {} end }
require = function() end
SkillBook = {}
isServer = function() return true end
sendServerCommand = function() end
sendSyncPlayerFields = function() end
syncItemFields = function() end
getCore = function() return { getOptionAutoRevealPrintMediaMapLocations = function() return false end } end
SAOPrintReadFixture = {}

function SAOPrintReadFixture.read(id, options)
    options = options or {}
    local readIds, data = {}, { SAOPersonId = id }
    local media = { id = "KnoxKnews", info = options.info or "Print_Media_KnoxKnews_July2_info",
        text = options.text or "Print_Text_KnoxKnews_July2_info" }
    local item = {
        getID = function() return 701 end,
        getFullType = function() return "Base.Newspaper_Knews" end,
        getModData = function() return { printMedia = media } end,
        hasModData = function() return true end,
        setJobDelta = function() end,
        getLearnedRecipes = function() return nil end,
        getSkillTrained = function() return "" end,
        getNumberOfPages = function() return -1 end,
        setAlreadyReadPages = function() end,
    }
    local body = {
        getModData = function() return data end,
        getInventory = function() return { contains = function(_, target)
            return target == item and options.held ~= false end } end,
        ReadLiterature = function()
            if options.replacePerson then data.SAOPersonId = options.replacePerson end
            if options.changeIssue then media.info = "Print_Text_KnoxKnews_July3_info" end
        end,
        addReadPrintMedia = function(_, key)
            if not options.noNativeResult then readIds[key] = true end
        end,
        getReadPrintMedia = function() return { contains = function(_, key)
            return readIds[key] == true end } end,
    }
    SAO.Body = SAO.Body or {}
    local oldGet = SAO.Body.get
    SAO.Body.get = function(key)
        if key == id then return body end
        return oldGet and oldGet(key) or nil
    end
    assert(SAO.WorldKnowledge.installReadingObserver())
    local action = { character = body, item = item, forceStopped = options.stopped }
    local ok, result = pcall(ISReadABook.complete, action)
    SAO.Body.get = oldGet
    if not ok then error(result) end
    return result
end
