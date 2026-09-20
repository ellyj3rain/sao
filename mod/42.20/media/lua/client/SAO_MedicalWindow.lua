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
    o.neuroSeries = {}
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
    if self.showGraph and self.neuroSeries and #self.neuroSeries >= 2 then
        y = y + 4
        self:drawText("Brain inflammatory history", x, y,
            0.75, 0.75, 0.75, 1, FONT_S)
        y = y + 16
        local graphW, graphH = self.width - 24, 58
        self:drawRect(x, y, graphW, graphH, 0.5, 0.08, 0.08, 0.08)
        self:drawRectBorder(x, y, graphW, graphH, 0.8, 0.35, 0.35, 0.35)
        self:drawLine2(x, y + graphH * 0.5, x + graphW,
            y + graphH * 0.5, 0.25, 0.45, 0.45, 0.45)
        local firstAt = tonumber(self.neuroSeries[1].atHours) or 0
        local lastAt = tonumber(self.neuroSeries[#self.neuroSeries].atHours) or firstAt
        local span = math.max(0.0001, lastAt - firstAt)
        local priorX, priorY = nil, nil
        for _, point in ipairs(self.neuroSeries) do
            local px = x + ((tonumber(point.atHours) or firstAt) - firstAt)
                / span * graphW
            local load = math.max(0.0, math.min(1.0, tonumber(point.load) or 0))
            local py = y + graphH - load * graphH
            if priorX then
                self:drawLine2(priorX, priorY, px, py, 0.95,
                    0.95, 0.35 + 0.45 * (1.0 - load), 0.12)
            end
            priorX, priorY = px, py
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
    local neuroSeries = {}
    pcall(function()
        if SAO.Neuro and SAO.Neuro.isActive and SAO.Neuro.isActive() then
            neuroLoad = SAO.Neuro.loadOf(rec)
            neuroSeries = SAO.Neuro.series(rec, hours, 14 * 24, 64)
        end
    end)
    local peak = 0
    for _, point in ipairs(neuroSeries) do
        peak = math.max(peak, tonumber(point.load) or 0)
    end
    local showGraph = skill >= SAO.Medical.CAN_PLACE_IT
        and #neuroSeries >= 2 and peak >= 0.05

    if SAOMedicalWindow.instance then
        SAOMedicalWindow.instance:removeFromUIManager()
        SAOMedicalWindow.instance = nil
    end
    local extraH = showGraph and 82 or 0
    local w = SAOMedicalWindow:new(120, 160, 340, 60 + 18 * (#lines + 1) + extraH)
    w:initialise()
    w:addToUIManager()
    w.who = SAO.Identity.knownName(rec) or tostring(id)
    w.lines = lines
    w.neuroLoad = neuroLoad
    w.neuroSeries = neuroSeries
    w.showGraph = showGraph
    SAOMedicalWindow.instance = w
end
