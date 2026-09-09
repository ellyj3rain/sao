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
end

---Open the window on one person, read by one examiner.
function SAO.showMedical(playerObj, id)
    local rec = SAO.Identity and SAO.Identity.get(id) or nil
    if not rec then return end

    local skill = SAO.Medical.skillOf(playerObj)
    local hours = 0
    pcall(function() hours = SAO.History.countyHours() end)
    local lines = SAO.Medical.readingOf(rec, skill, hours)

    if SAOMedicalWindow.instance then
        SAOMedicalWindow.instance:removeFromUIManager()
        SAOMedicalWindow.instance = nil
    end
    local w = SAOMedicalWindow:new(120, 160, 340, 60 + 18 * (#lines + 1))
    w:initialise()
    w:addToUIManager()
    w.who = SAO.Identity.knownName(rec) or tostring(id)
    w.lines = lines
    SAOMedicalWindow.instance = w
end
