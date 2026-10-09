require "ISUI/ISPanel"

PZSignalMatchGame = ISPanel:derive("PZSignalMatchGame")

local signalPads = {
    {label = "A", r = 0.58, g = 0.25, b = 0.20},
    {label = "B", r = 0.18, g = 0.48, b = 0.38},
    {label = "C", r = 0.22, g = 0.34, b = 0.62},
    {label = "D", r = 0.66, g = 0.54, b = 0.18}
}

local function drawSignalBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZSignalMatchGame:initialise()
    ISPanel.initialise(self)
    self.highRound = 0
    self:resetGame()
end

function PZSignalMatchGame:resetGame()
    self.gameState = "SHOWING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.tick = 0
    self.score = 0
    self.sequence = {}
    self.inputIndex = 1
    self.showIndex = 1
    self.showTimer = 34
    self.clearTimer = 0
    self.flashTimer = 0
    self.litPad = nil
    self.maxRound = 9
    self:addSignal()
end

function PZSignalMatchGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZSignalMatchGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZSignalMatchGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZSignalMatchGame:addSignal()
    self.sequence[#self.sequence + 1] = ZombRand(4) + 1
    if #self.sequence > self.highRound then
        self.highRound = #self.sequence
    end
end

function PZSignalMatchGame:getPadLayout()
    local usableW = math.max(1, self.width - 64)
    local usableH = math.max(1, self.height - 94)
    local gap = math.max(6, math.floor(math.min(usableW, usableH) * 0.03))
    local pad = math.floor((math.min(usableW, usableH) - gap) / 2)
    pad = math.max(24, pad)
    local boardW = pad * 2 + gap
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 44 + math.floor((usableH - boardH) / 2)
    return x, y, pad, gap, boardW, boardH
end

function PZSignalMatchGame:getPadAt(mx, my)
    local startX, startY, pad, gap = self:getPadLayout()
    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = startX + col * (pad + gap)
        local y = startY + row * (pad + gap)
        if mx >= x and mx <= x + pad and my >= y and my <= y + pad then
            return i
        end
    end
    return nil
end

function PZSignalMatchGame:fail()
    self.gameState = "GAMEOVER"
    self.flashTimer = 16
    self.litPad = nil
    self:playGameOverSound()
end

function PZSignalMatchGame:acceptPad(pad)
    if self.gameState ~= "INPUT" then return end
    self.litPad = pad
    self.flashTimer = 8
    self:playSound("ComputerBallHit")
    if self.sequence[self.inputIndex] ~= pad then
        self:fail()
        return
    end
    self.score = self.score + 20 + #self.sequence * 5
    self.inputIndex = self.inputIndex + 1
    if self.inputIndex > #self.sequence then
        if #self.sequence >= self.maxRound then
            self.gameState = "WIN"
            self.score = self.score + 400
            self:playWinSound()
        else
            self.gameState = "ROUND_CLEAR"
            self.clearTimer = 30
        end
    end
end

function PZSignalMatchGame:onMouseDown(x, y)
    if self.gameState == "GAMEOVER" or self.gameState == "WIN" then
        self:resetGame()
        return true
    end
    local pad = self:getPadAt(x, y)
    if pad then
        self:acceptPad(pad)
    end
    return true
end

function PZSignalMatchGame:update()
    self.tick = (self.tick or 0) + 1
    self.flashTimer = math.max(0, (self.flashTimer or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 2, 2)
    if self.flashTimer <= 0 and self.gameState == "INPUT" then
        self.litPad = nil
    end
    if self.gameState == "GAMEOVER" or self.gameState == "WIN" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    if self.gameState == "INPUT" and activated then
        self:acceptPad((selectedY - 1) * 2 + selectedX)
    end
    if self.gameState == "SHOWING" then
        self.showTimer = self.showTimer - 1
        if self.showTimer > 13 then
            self.litPad = self.sequence[self.showIndex]
        else
            self.litPad = nil
        end
        if self.showTimer <= 0 then
            self.showIndex = self.showIndex + 1
            if self.showIndex > #self.sequence then
                self.gameState = "INPUT"
                self.inputIndex = 1
                self.litPad = nil
            else
                self.showTimer = 30
            end
        end
    elseif self.gameState == "ROUND_CLEAR" then
        self.clearTimer = self.clearTimer - 1
        self.litPad = nil
        if self.clearTimer <= 0 then
            self:addSignal()
            self.showIndex = 1
            self.showTimer = 34
            self.inputIndex = 1
            self.gameState = "SHOWING"
        end
    end
end

function PZSignalMatchGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.010, 0.012, 0.020)
    self:drawRect(0, 25, self.width, 1, 1, 0.30, 0.32, 0.46)
    self:drawText("SIGNAL.EXE", 10, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("ROUND " .. tostring(#self.sequence), 112, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), self.width - 92, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZSignalMatchGame:drawStatusLine()
    local text = "WATCH"
    if self.gameState == "INPUT" then
        text = "REPEAT " .. tostring(self.inputIndex) .. "/" .. tostring(#self.sequence)
    elseif self.gameState == "ROUND_CLEAR" then
        text = "GOOD"
    elseif self.gameState == "GAMEOVER" then
        text = "BAD SIGNAL"
    elseif self.gameState == "WIN" then
        text = "LINK OK"
    end
    self:drawText(text, 10, self.height - 18, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZSignalMatchGame:drawPad(index, x, y, size)
    local pad = signalPads[index]
    local lit = self.litPad == index
    local pulse = lit and 0.26 or math.abs(math.sin((self.tick + index * 9) * 0.05)) * 0.04
    self:drawRect(x + 2, y + 3, size, size, 0.28, 0, 0, 0)
    self:drawRect(x, y, size, size, 1, pad.r + pulse, pad.g + pulse, pad.b + pulse)
    drawSignalBorder(self, x, y, size, size, 1, lit and 0.92 or 0.18, lit and 0.90 or 0.18, lit and 0.70 or 0.20)
    self:drawRect(x + 6, y + 6, math.max(1, size - 12), 2, lit and 0.65 or 0.22, 1, 1, 0.82)
    self:drawText(pad.label, x + math.floor(size * 0.5) - 4, y + math.floor(size * 0.5) - 8, 0.02, 0.02, 0.02, 1, UIFont.Medium)
end

function PZSignalMatchGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.008, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.32, 0.46)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.80, 0.76, 0.52, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZSignalMatchGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZSignalMatchGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.008, 0.010, 0.018)
    self:drawHud()
    local startX, startY, pad, gap, boardW, boardH = self:getPadLayout()
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.030, 0.032, 0.046)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.004, 0.006, 0.014)
    drawSignalBorder(self, startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.24, 0.28, 0.42)
    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        self:drawPad(i, startX + col * (pad + gap), startY + row * (pad + gap), pad)
    end
    local selectedX = math.max(1, math.min(2, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(2, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (pad + gap), startY + (selectedY - 1) * (pad + gap), pad, pad)
    if self.gameState == "GAMEOVER" then
        self:drawOverlay("SEQUENCE LOST", "ROUND " .. tostring(#self.sequence))
    elseif self.gameState == "WIN" then
        self:drawOverlay("SIGNAL LOCKED", "SCORE " .. tostring(self.score))
    end
    self:drawStatusLine()
    self:drawScanlines()
end

function PZSignalMatchGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
