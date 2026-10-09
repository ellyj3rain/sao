local function check(name, good)
    assert(good, "WEEKONE_SANDBOX_UI:" .. name)
end

SAO = {Log = {line = function() end}, Seams = {wentDark = function() end}}
assert(loadstring(__sources["Owned:D2Catalog"], "d2-catalog"))()
assert(loadstring(__sources["Owned:WeekOneCatalog"], "weekone-catalog"))()
require = function(name)
    if name == "SAO_SourceSandboxPages" then return SAO.SourceSandboxPages end
    if name == "SAO_WeekOneSandboxPages" then return SAO.WeekOneSandboxPages end
    error("unexpected require " .. tostring(name))
end
getText = function(key) return key end

local selected = {}
getSandboxOptions = function()
    return {getOptionByName = function(_, id)
        if selected[id] then
            return {getPageName = function() return selected[id] end}
        end
    end}
end
local function panelFor(page)
    local panel = {controls = {}, labels = {}}
    for _, setting in ipairs(page.settings) do
        panel.controls[setting.name] = {page = page.name,
            isTickBox = true, enable = true, disabledOptions = {},
            disableOption = function(self, name, value)
                self.disabledOptions[name] = value
            end}
        panel.labels[setting.name] = {setColor = function() end}
    end
    panel.prerender = function() end
    return panel
end
ServerSettingsScreen = {getSandboxSettingsTable = function() return {} end}
function ServerSettingsScreen:create()
    local category = {name = "Sandbox"}
    local listbox = {items = {{item = {category = category}}}}
    function listbox:removeItemByIndex(index)
        table.remove(self.items, index)
    end
    self.pageEdit = {listbox = listbox, controls = {Sandbox = {}}}
    function self.pageEdit:createPanel(_, page)
        local panel = panelFor(page)
        for id, control in pairs(panel.controls) do
            self.controls.Sandbox[id] = control
        end
        return panel
    end
    for _, page in ipairs(__activePages) do
        listbox.items[#listbox.items + 1] = {item = {page = page,
            panel = self.pageEdit:createPanel(category, page)}}
    end
end
SandboxOptionsScreen = {create = function(self)
    self.listbox = {items = {}}
    for _, page in ipairs(__activePages) do
        self.listbox.items[#self.listbox.items + 1] = {item = {panel = panelFor(page)}}
    end
end}
MainScreen = {instance = {createWorld = false}}
assert(loadstring(__sources["Owned:Sandbox"], "sao-sandbox"))()
local Sb = SAO.Sandbox

local ids = {}
for id in pairs(SAO.WeekOneSandboxPages.options) do ids[#ids + 1] = id end
table.sort(ids)
check("all_24_ids", #ids == 24)
check("variant_creator_owned", SAO.WeekOneSandboxPages.options["BanditsWeekOne.Variant"] == nil)

local function scenario(name, order)
    local pages = {}
    selected = {}
    local function put(id, page)
        pages[#pages + 1] = {name = getText("Sandbox_" .. page), settings = {{name = id}}}
    end
    for _, id in ipairs(ids) do
        local rule = SAO.WeekOneSandboxPages.options[id]
        if order == "sao-only" then
            put(id, rule.ownedPage)
            selected[id] = rule.ownedPage
        elseif order == "source-first" then
            put(id, rule.originalPage)
            put(id, rule.ownedPage)
            selected[id] = rule.ownedPage
        else
            put(id, rule.ownedPage)
            put(id, rule.originalPage)
            selected[id] = rule.originalPage
        end
    end
    __activePages = pages
    local visible, removed = Sb.coalesceSourcePages(pages)
    check(name .. "_remove_count", removed == (order == "sao-only" and 0 or 24))
    local count = {}
    for _, page in ipairs(visible) do
        if page then
            for _, setting in ipairs(page.settings) do
                count[setting.name] = (count[setting.name] or 0) + 1
                check(name .. "_owned_page_" .. setting.name,
                    page.name == getText("Sandbox_" .. SAO.WeekOneSandboxPages.options[setting.name].ownedPage))
                check(name .. "_owned_label_" .. setting.name,
                    setting.translatedName == "Sandbox_SAO_WeekOne_Control_"
                        .. setting.name:match("^BanditsWeekOne%.(.+)$"))
            end
        end
    end
    for _, id in ipairs(ids) do
        check(name .. "_single_" .. id, count[id] == 1)
    end
    local screen = setmetatable({}, {__index = ServerSettingsScreen})
    screen:create()
    local displayed = {}
    for _, row in ipairs(screen.pageEdit.listbox.items) do
        local page = row.item.page
        if page then
            for _, setting in ipairs(page.settings) do
                displayed[setting.name] = (displayed[setting.name] or 0) + 1
                check(name .. "_server_page_" .. setting.name,
                    page.name == getText("Sandbox_" .. SAO.WeekOneSandboxPages.options[setting.name].ownedPage))
                check(name .. "_server_binding_" .. setting.name,
                    screen.pageEdit.controls.Sandbox[setting.name].page == page.name)
            end
        end
    end
    for _, id in ipairs(ids) do
        check(name .. "_server_single_" .. id, displayed[id] == 1)
    end
end

scenario("sao-only", "sao-only")
scenario("source-first", "source-first")
scenario("source-last", "source-last")

-- New-world controls stay visible, but the creator is the final producer
-- selection. An existing world retains its saved editable controls.
local strikePage = {name = "Sandbox_SAO_WeekOne_Events",
    settings = {{name = "BanditsWeekOne.EventFinalSolution"}}}
local saoPage = {name = "Sandbox_SurvivorAwareness",
    settings = {{name = "SurvivorAwareness.WeekOneNuke"}}}
__activePages = {strikePage, saoPage}
MainScreen.instance.createWorld = true
local newScreen = setmetatable({}, {__index = SandboxOptionsScreen})
newScreen:create()
for _, row in ipairs(newScreen.listbox.items) do
    local panel = row.item.panel
    panel:prerender()
    for id, control in pairs(panel.controls) do
        check("creator_controls_visible_" .. id, control ~= nil)
        check("creator_controls_later_choice_" .. id,
            control.enable == false and control.disabledOptions[""] == true
            and control.tooltip == "Sandbox_SAO_WeekOne_CreatorChoice")
    end
end
MainScreen.instance.createWorld = false
local existingScreen = setmetatable({}, {__index = SandboxOptionsScreen})
existingScreen:create()
for _, row in ipairs(existingScreen.listbox.items) do
    local panel = row.item.panel
    panel:prerender()
    for id, control in pairs(panel.controls) do
        check("existing_world_editable_" .. id,
            control.enable == true and control.disabledOptions[""] == nil)
    end
end
print("PASS Week One sandbox UI 24 controls, three registration orders, creator strike display")
