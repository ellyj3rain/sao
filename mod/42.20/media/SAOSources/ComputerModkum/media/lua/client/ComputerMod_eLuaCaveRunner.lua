require "ISUI/ISPanel"

PZCaveRunnerGame = ISPanel:derive("PZCaveRunnerGame")

local function clampCaveValue(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function caveRectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function drawCaveRect(panel, x, y, w, h, a, r, g, b)
    if w <= 0 or h <= 0 then return end
    local x1 = clampCaveValue(x, 0, panel.width)
    local y1 = clampCaveValue(y, 0, panel.height)
    local x2 = clampCaveValue(x + w, 0, panel.width)
    local y2 = clampCaveValue(y + h, 0, panel.height)
    if x2 <= x1 or y2 <= y1 then return end
    panel:drawRect(x1, y1, x2 - x1, y2 - y1, a, r, g, b)
end

function PZCaveRunnerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZCaveRunnerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.animationTick = 0
    self.crystalFlash = 0
    self.crashFlash = 0
    self.score = 0
    self.bonusScore = 0
    self.distance = 0
    self.speed = 2.4
    self.ship = {x = 64, y = self.height * 0.5, vy = 0}
    self.segments = {}
    self.crystals = {}
    self.spawnCursor = 0
    self.gapCenter = self.height * 0.5
    self.gapSize = math.max(92, self.height * 0.36)
    for i = 1, 24 do
        self:addSegment((i - 1) * 24)
    end
end

function PZCaveRunnerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZCaveRunnerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZCaveRunnerGame:addSegment(x)
    self.gapCenter = self.gapCenter + ZombRand(-24, 25)
    self.gapCenter = clampCaveValue(self.gapCenter, 72, self.height - 62)
    self.gapSize = clampCaveValue(self.gapSize + ZombRand(-8, 7), 72, math.max(88, self.height * 0.36))
    local topH = math.max(22, self.gapCenter - self.gapSize * 0.5)
    local bottomY = math.min(self.height - 18, self.gapCenter + self.gapSize * 0.5)
    self.segments[#self.segments + 1] = {x = x, topH = topH, bottomY = bottomY}
    if ZombRand(100) < 28 then
        self.crystals[#self.crystals + 1] = {x = x + 10, y = self.gapCenter + ZombRand(-24, 25)}
    end
end

function PZCaveRunnerGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.crystalFlash = math.max(0, (self.crystalFlash or 0) - 1)
    self.crashFlash = math.max(0, (self.crashFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    local thrust = 0
    if ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then thrust = thrust - 0.72 end
    if ComputerModGameInput.isDown(self, "down") or ComputerModGameInput.isDown(self, "backward") then thrust = thrust + 0.72 end
    self.ship.vy = (self.ship.vy + thrust + 0.055) * 0.9
    self.ship.y = self.ship.y + self.ship.vy
    self.speed = math.min(5.6, 2.4 + self.distance / 1600)
    self.distance = self.distance + self.speed
    self.score = math.floor(self.distance / 8) + (self.bonusScore or 0)

    local maxX = 0
    for i = #self.segments, 1, -1 do
        local seg = self.segments[i]
        seg.x = seg.x - self.speed
        if seg.x > maxX then maxX = seg.x end
        if seg.x < -28 then
            table.remove(self.segments, i)
        end
    end
    while maxX < self.width + 36 do
        maxX = maxX + 24
        self:addSegment(maxX)
    end

    for i = #self.crystals, 1, -1 do
        local crystal = self.crystals[i]
        crystal.x = crystal.x - self.speed
        if caveRectsOverlap(self.ship.x - 10, self.ship.y - 8, 20, 16, crystal.x - 5, crystal.y - 5, 10, 10) then
            self.bonusScore = (self.bonusScore or 0) + 120
            self.score = self.score + 120
            self.crystalFlash = 7
            self:playSound("ComputerBallHit")
            table.remove(self.crystals, i)
        elseif crystal.x < -12 then
            table.remove(self.crystals, i)
        end
    end

    if self.ship.y < 30 or self.ship.y > self.height - 18 then
        self.gameState = "GAMEOVER"
        self.crashFlash = 16
        self:playGameOverSound()
        return
    end
    for i = 1, #self.segments do
        local seg = self.segments[i]
        if seg.x < self.ship.x + 10 and seg.x + 24 > self.ship.x - 10 then
            if self.ship.y - 8 < seg.topH or self.ship.y + 8 > seg.bottomY then
                self.gameState = "GAMEOVER"
                self.crashFlash = 16
                self:playGameOverSound()
                return
            end
        end
    end
end

function PZCaveRunnerGame:drawShip()
    local x = self.ship.x
    local y = self.ship.y
    self:drawRect(x - 9, y - 6, 18, 12, 1, 0.16, 0.52, 0.58)
    self:drawRect(x + 1, y - 10, 10, 20, 1, 0.42, 0.74, 0.78)
    self:drawRect(x - 15, y - 3, 7, 6, 1, 0.86, 0.46, 0.12)
    self:drawRect(x + 10, y - 2, 5, 4, 1, 0.72, 0.86, 0.86)
    self:drawRect(x - 17, y - 1, 4, 2, 0.65, 0.90, 0.62, 0.16)
end

function PZCaveRunnerGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.006, 0.016, 0.014)
    self:drawRect(0, 25, self.width, 1, 1, 0.24, 0.42, 0.34)
    self:drawText("CAVE.EXE", 10, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 92, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText("SPD " .. tostring(math.floor(self.speed * 10)), self.width - 64, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZCaveRunnerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.07, 0.05)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.016, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.24, 0.42, 0.34)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZCaveRunnerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZCaveRunnerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.018, 0.014)
    self:drawHud()
    if self.crystalFlash and self.crystalFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.crystalFlash / 100, 0.32, 0.72, 0.64)
    end
    if self.crashFlash and self.crashFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.crashFlash / 90, 0.82, 0.12, 0.08)
    end
    for i = 1, #self.segments do
        local seg = self.segments[i]
        local shade = 0.12 + (i % 4) * 0.02
        drawCaveRect(self, seg.x, 26, 25, seg.topH - 26, 1, 0.08, shade + 0.12, 0.12)
        drawCaveRect(self, seg.x, seg.bottomY, 25, self.height - seg.bottomY, 1, 0.08, shade + 0.12, 0.12)
        drawCaveRect(self, seg.x, seg.topH - 3, 25, 3, 1, 0.24, 0.54, 0.36)
        drawCaveRect(self, seg.x, seg.bottomY, 25, 3, 1, 0.24, 0.54, 0.36)
        if i % 3 == 0 then
            drawCaveRect(self, seg.x + 5, 30, 3, math.max(0, seg.topH - 40), 0.14, 0.44, 0.62, 0.48)
            drawCaveRect(self, seg.x + 14, seg.bottomY + 8, 3, math.max(0, self.height - seg.bottomY - 18), 0.12, 0.44, 0.62, 0.48)
        end
    end
    for i = 1, #self.crystals do
        local crystal = self.crystals[i]
        local pulse = math.abs(math.sin((self.animationTick + i * 8) * 0.1)) * 0.24
        drawCaveRect(self, crystal.x - 5, crystal.y - 5, 10, 10, 1, 0.28, 0.7 + pulse, 1)
        drawCaveRect(self, crystal.x - 2, crystal.y - 8, 4, 16, 0.7, 0.8, 1, 1)
    end
    self:drawShip()
    if self.gameState == "GAMEOVER" then
        self:drawOverlay("RUN ENDED", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZCaveRunnerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
