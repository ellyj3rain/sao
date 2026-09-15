-- SAO_MedicalWindow - the reading, on screen.
-- ---------------------------------------------------------------------------
-- A renderer for `SAO_Medical.readingOf` and nothing else. The
-- judgement about what an examiner can tell lives in that module,
-- which loads in a bare VM and is bordered there; this file is the
-- part that needs the game's UI and therefore cannot be.
--
-- The window is the game's own idiom, the same base `[A25]` chose for
-- the County Ledger and the same one the neighbour's panels derive
-- from: title bar, drag, close.

require "ISUI/ISCollapsableWindow"

SAO = SAO or {}

SAOMedicalWindow = ISCollapsableWindow:derive("SAOMedicalWindow")
SAOMedicalWindow.instance = nil

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium

function SAOMedicalWindow:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = "Looking them over"
    o.resizable = false
    o.lines = {}
    o.who = ""
    o.neuroLoad = 0
    o.showGraph = false
    return o
end

function SAOMedicalWindow:render()
    ISCollapsableWindow.render(self)
    local x = 12
    local y = self:titleBarHeight() + 8
    self:drawText(self.who, x, y, 0.9, 0.9, 0.9, 1, FONT_M)
    y = y + 22
    if #self.lines == 0 then
        self:drawText("You cannot get a look at them.",
            x, y, 0.6, 0.6, 0.6, 1, FONT_S)
        return
    end
    for _, line in ipairs(self.lines) do
        self:drawText(line, x, y, 0.82, 0.82, 0.82, 1, FONT_S)
        y = y + 18
    end
    if self.showGraph and self.neuroLoad and self.neuroLoad > 0 then
        y = y + 4
        self:drawText("Brain Inflammatory Load:", x, y, 0.75, 0.75, 0.75, 1, FONT_S)
        y = y + 16
        local barW = self.width - 24
        local barH = 8
        self:drawRect(x, y, barW, barH, 0.5, 0.15, 0.15, 0.15)
        self:drawRectBorder(x, y, barW, barH, 0.8, 0.35, 0.35, 0.35)
        local fillW = math.floor(barW * math.max(0.0, math.min(1.0, self.neuroLoad)))
        if fillW > 0 then
            local r = 0.6 + 0.4 * self.neuroLoad
            local g = 0.8 * (1.0 - self.neuroLoad)
            self:drawRect(x + 1, y + 1, fillW - 2, barH - 2, 0.8, r, g, 0.15)
        end
    end
end

---Open the window on one person, read by one examiner.
function SAO.showMedical(playerObj, id)
    local rec = SAO.Identity and SAO.Identity.get(id) or nil
    if not rec then return end

    local skill = SAO.Medical.skillOf(playerObj)
    local hours = 0
    pcall(function() hours = SAO.History.countyHours() end)
    local lines = SAO.Medical.readingOf(rec, skill, hours)

    local neuroLoad = 0
    pcall(function()
        if SAO.Neuro and SAO.Neuro.isActive and SAO.Neuro.isActive() then
            neuroLoad = SAO.Neuro.loadOf(rec)
        end
    end)
    local showGraph = (neuroLoad >= 0.15 and skill >= SAO.Medical.CAN_PLACE_IT)

    if SAOMedicalWindow.instance then
        SAOMedicalWindow.instance:removeFromUIManager()
        SAOMedicalWindow.instance = nil
    end
    local extraH = showGraph and 36 or 0
    local w = SAOMedicalWindow:new(120, 160, 340, 60 + 18 * (#lines + 1) + extraH)
    w:initialise()
    w:addToUIManager()
    w.who = SAO.Identity.knownName(rec) or tostring(id)
    w.lines = lines
    w.neuroLoad = neuroLoad
    w.showGraph = showGraph
    SAOMedicalWindow.instance = w
end
