require "ISUI/ISPanel"

PZFroggerGame = ISPanel:derive("PZFroggerGame")

function PZFroggerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZFroggerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.cols = 11
    self.rows = 11
    self.originX = 8
    self.originY = 24
    self.boardW = self.width - 16
    self.boardH = self.height - 30
    self.cellW = self.boardW / self.cols
    self.cellH = self.boardH / self.rows
    self.frog = {col = 5, row = 10}
    self.score = 0
    self.moveLock = false
    self.flashTick = 0
    self.goalFlash = 0
    self.deathFlash = 0
    local positionScale = self.boardW / 520
    local objectScale = math.min(self.cellW, self.cellH) / 17
    local speedScale = math.max(0.70, math.min(1.28, objectScale))
    local laneLeft = self.originX
    local function car(x, w)
        local width = math.max(22, math.floor(w * objectScale))
        width = math.min(width, math.floor(self.cellW * 1.16))
        return {x = laneLeft + math.floor(x * positionScale), w = width}
    end
    local function log(x, w)
        local width = math.max(32, math.floor(w * objectScale))
        width = math.min(width, math.floor(self.cellW * 1.95))
        return {x = laneLeft + math.floor(x * positionScale), w = width}
    end
    self.waterLanes = {
        {row = 1, speed = 1.15 * speedScale, logs = {log(0, 70), log(156, 86), log(340, 72)}},
        {row = 2, speed = -1.35 * speedScale, logs = {log(72, 96), log(260, 74), log(428, 92)}}
    }
    self.lanes = {
        {row = 8, speed = 2.45 * speedScale, color = {0.82, 0.26, 0.18}, cars = {car(0, 38), car(132, 34), car(278, 46)}},
        {row = 7, speed = -2.65 * speedScale, color = {0.92, 0.72, 0.20}, cars = {car(64, 48), car(220, 38), car(368, 42)}},
        {row = 6, speed = 2.85 * speedScale, color = {0.32, 0.72, 0.86}, cars = {car(0, 34), car(168, 52), car(332, 34)}},
        {row = 5, speed = -3.00 * speedScale, color = {0.82, 0.44, 0.24}, cars = {car(96, 58), car(302, 38)}},
        {row = 4, speed = 2.55 * speedScale, color = {0.50, 0.38, 0.92}, cars = {car(24, 34), car(186, 50), car(360, 40)}},
        {row = 3, speed = -2.80 * speedScale, color = {0.30, 0.66, 0.30}, cars = {car(78, 42), car(244, 36), car(400, 46)}}
    }
end

function PZFroggerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZFroggerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZFroggerGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZFroggerGame:updateMovingRect(rect, speed)
    rect.x = rect.x + speed
    local left = self.originX
    local right = self.originX + self.boardW
    if speed > 0 and rect.x > right - rect.w then
        rect.x = left
    elseif speed < 0 and rect.x < left then
        rect.x = right - rect.w
    end
end

function PZFroggerGame:getFrogRect()
    local sizeW = math.max(12, math.floor(self.cellW * 0.62))
    local sizeH = math.max(10, math.floor(self.cellH * 0.68))
    local frogX = self.originX + self.frog.col * self.cellW + math.floor((self.cellW - sizeW) * 0.5)
    local frogY = self.originY + self.frog.row * self.cellH + math.floor((self.cellH - sizeH) * 0.5)
    return frogX, frogY, sizeW, sizeH
end

function PZFroggerGame:update()
    self.flashTick = self.flashTick + 1
    self.goalFlash = math.max(0, (self.goalFlash or 0) - 1)
    self.deathFlash = math.max(0, (self.deathFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "up") then
        if not self.moveLock then self.frog.row = math.max(0, self.frog.row - 1); self.moveLock = true end
    elseif ComputerModGameInput.isDown(self, "down") then
        if not self.moveLock then self.frog.row = math.min(self.rows - 1, self.frog.row + 1); self.moveLock = true end
    elseif ComputerModGameInput.isDown(self, "left") then
        if not self.moveLock then self.frog.col = math.max(0, self.frog.col - 1); self.moveLock = true end
    elseif ComputerModGameInput.isDown(self, "right") then
        if not self.moveLock then self.frog.col = math.min(self.cols - 1, self.frog.col + 1); self.moveLock = true end
    else
        self.moveLock = false
    end

    local frogX, _, frogW = self:getFrogRect()
    local frogCenter = frogX + frogW * 0.5
    for i = 1, #self.waterLanes do
        local lane = self.waterLanes[i]
        local onLog = false
        for j = 1, #lane.logs do
            local log = lane.logs[j]
            self:updateMovingRect(log, lane.speed)
            if self.frog.row == lane.row and frogCenter >= log.x and frogCenter <= log.x + log.w then
                onLog = true
            end
        end
        if self.frog.row == lane.row and not onLog then
            self.gameState = "GAMEOVER"
            self.deathFlash = 16
            self:playGameOverSound()
            return
        end
    end

    for i = 1, #self.lanes do
        local lane = self.lanes[i]
        for j = 1, #lane.cars do
            local car = lane.cars[j]
            self:updateMovingRect(car, lane.speed)
            if self.frog.row == lane.row then
                local fx, _, fw = self:getFrogRect()
                if fx + fw >= car.x and fx <= car.x + car.w then
                    self.gameState = "GAMEOVER"
                    self.deathFlash = 16
                    self:playGameOverSound()
                    return
                end
            end
        end
    end

    if self.frog.row == 0 then
        self.score = self.score + 1
        self.goalFlash = 12
        self:playSound("ComputerBallHit")
        self.frog.col = 5
        self.frog.row = self.rows - 1
        if self.score >= 5 then
            self.gameState = "WIN"
            self:playWinSound()
        end
    end
end

function PZFroggerGame:laneY(row)
    return self.originY + row * self.cellH
end

function PZFroggerGame:drawCar(car, y, color)
    local x = math.max(self.originX, math.min(car.x, self.originX + self.boardW - car.w - 1))
    local h = math.max(13, math.floor(self.cellH * 0.70))
    local cy = y + math.floor((self.cellH - h) * 0.5)
    self:drawRect(x + 1, cy + 3, car.w, h, 0.30, 0, 0, 0)
    self:drawRect(x, cy + 4, car.w, h - 7, 1, color[1] * 0.78, color[2] * 0.78, color[3] * 0.78)
    self:drawRect(x + 4, cy, car.w - 8, h, 1, color[1], color[2], color[3])
    self:drawRect(x + 5, cy + 4, car.w - 10, math.max(4, math.floor(h * 0.28)), 1, 0.08, 0.10, 0.12)
    self:drawRect(x + 5, cy + 5, car.w - 10, 1, 0.45, 0.62, 0.76, 0.74)
    self:drawRect(x + 3, cy + h - 3, 6, 3, 1, 0.03, 0.03, 0.03)
    self:drawRect(x + car.w - 9, cy + h - 3, 6, 3, 1, 0.03, 0.03, 0.03)
end

function PZFroggerGame:drawLog(log, y)
    local x = math.max(self.originX, math.min(log.x, self.originX + self.boardW - log.w - 1))
    local h = math.max(11, math.floor(self.cellH * 0.55))
    local ly = y + math.floor((self.cellH - h) * 0.5)
    self:drawRect(x + 1, ly + 2, log.w, h, 0.26, 0, 0, 0)
    self:drawRect(x, ly, log.w, h, 1, 0.34, 0.20, 0.10)
    self:drawRect(x + 3, ly + 2, log.w - 6, 2, 0.72, 0.60, 0.38, 0.20)
    self:drawRect(x + 5, ly + h - 4, log.w - 10, 1, 0.40, 0.18, 0.09, 0.05)
    self:drawRect(x + log.w - 8, ly + 2, 4, h - 4, 0.55, 0.16, 0.08, 0.04)
end

function PZFroggerGame:drawFrog()
    local frogX, frogY, frogW, frogH = self:getFrogRect()
    self:drawRect(frogX + 1, frogY + 2, frogW, frogH, 0.28, 0, 0, 0)
    self:drawRect(frogX, frogY, frogW, frogH, 1, 0.22, 0.70, 0.22)
    self:drawRect(frogX + 2, frogY + 2, frogW - 4, math.max(2, math.floor(frogH * 0.32)), 0.45, 0.58, 0.92, 0.40)
    self:drawRect(frogX + 2, frogY + frogH - 4, 4, 4, 1, 0.10, 0.42, 0.10)
    self:drawRect(frogX + frogW - 6, frogY + frogH - 4, 4, 4, 1, 0.10, 0.42, 0.10)
    self:drawRect(frogX + math.floor(frogW * 0.18), frogY + math.floor(frogH * 0.18), 2, 2, 1, 0.02, 0.02, 0.02)
    self:drawRect(frogX + math.floor(frogW * 0.66), frogY + math.floor(frogH * 0.18), 2, 2, 1, 0.02, 0.02, 0.02)
end

function PZFroggerGame:drawHud()
    self:drawRect(0, 0, self.width, 23, 1, 0.008, 0.018, 0.010)
    self:drawRect(0, 22, self.width, 1, 1, 0.20, 0.42, 0.20)
    self:drawText("FROGGER.EXE", 8, 6, 0.60, 0.82, 0.54, 1, UIFont.Small)
    self:drawText("GOALS " .. tostring(self.score) .. "/5", 112, 6, 0.60, 0.82, 0.54, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "movement") .. " MOVE", self.width - 94, 6, 0.48, 0.62, 0.46, 1, UIFont.Small)
end

function PZFroggerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.08, 0.05)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.018, 0.008)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.20, 0.42, 0.20)
    self:drawText(title, boxX + 10, boxY + 19, 0.60, 0.82, 0.54, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.76, 0.76, 0.52, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.60, 0.82, 0.54, 1, UIFont.Small)
end

function PZFroggerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZFroggerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.022, 0.062, 0.030)
    self:drawHud()

    self:drawRect(self.originX - 2, self.originY - 2, self.boardW + 4, self.boardH + 4, 1, 0.05, 0.08, 0.05)
    self:drawRect(self.originX, self.originY, self.boardW, self.boardH, 1, 0.05, 0.16, 0.07)
    self:drawRect(self.originX, self:laneY(0), self.boardW, self.cellH - 2, 1, 0.08, 0.28, 0.10)
    for i = 0, 4 do
        local padX = self.originX + i * math.floor(self.boardW / 5) + math.floor(self.cellW * 0.35)
        self:drawRect(padX + 1, self:laneY(0) + 6, self.cellW, self.cellH - 10, 0.28, 0, 0, 0)
        self:drawRect(padX, self:laneY(0) + 4, self.cellW, self.cellH - 10, 1, 0.14, 0.42, 0.16)
    end

    for i = 1, #self.waterLanes do
        local lane = self.waterLanes[i]
        local y = self:laneY(lane.row)
        self:drawRect(self.originX, y, self.boardW, self.cellH - 2, 1, 0.025, 0.095, 0.22)
        local waveX = (self.flashTick * 1.4) % 36
        while waveX < self.boardW do
            self:drawRect(self.originX + waveX, y + math.floor(self.cellH * 0.55), 18, 1, 0.36, 0.28, 0.48, 0.72)
            waveX = waveX + 36
        end
        for j = 1, #lane.logs do
            self:drawLog(lane.logs[j], y)
        end
    end

    self:drawRect(self.originX, self:laneY(9), self.boardW, self.cellH - 2, 1, 0.08, 0.28, 0.10)
    self:drawRect(self.originX, self:laneY(10), self.boardW, self.cellH - 2, 1, 0.08, 0.28, 0.10)

    for i = 1, #self.lanes do
        local lane = self.lanes[i]
        local y = self:laneY(lane.row)
        self:drawRect(self.originX, y, self.boardW, self.cellH - 2, 1, 0.105, 0.108, 0.112)
        local stripeX = (self.flashTick * math.abs(lane.speed) * 0.7) % 52
        while stripeX <= self.boardW - 22 do
            self:drawRect(self.originX + stripeX, y + math.floor(self.cellH * 0.45), 22, 2, 0.32, 0.78, 0.76, 0.58)
            stripeX = stripeX + 52
        end
        for j = 1, #lane.cars do
            self:drawCar(lane.cars[j], y, lane.color)
        end
    end

    self:drawFrog()
    if self.goalFlash and self.goalFlash > 0 then
        self:drawRect(self.originX, self.originY, self.boardW, self.boardH, self.goalFlash / 120, 0.38, 0.72, 0.34)
    end
    if self.deathFlash and self.deathFlash > 0 then
        self:drawRect(self.originX, self.originY, self.boardW, self.boardH, self.deathFlash / 100, 0.80, 0.10, 0.08)
    end

    if self.gameState == "WIN" then
        self:drawOverlay("FROGGER COMPLETE", "GOALS " .. tostring(self.score) .. "/5")
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("FROG LOST", "GOALS " .. tostring(self.score) .. "/5")
    end
    self:drawScanlines()
end

function PZFroggerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
