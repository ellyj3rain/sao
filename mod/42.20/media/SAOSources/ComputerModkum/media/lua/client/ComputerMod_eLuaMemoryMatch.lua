require "ISUI/ISPanel"

PZMemoryMatchGame = ISPanel:derive("PZMemoryMatchGame")

local memorySymbols = {"A", "B", "C", "D", "E", "F", "G", "H"}

local function shuffleCards(cards)
    for i = #cards, 2, -1 do
        local j = ZombRand(i) + 1
        cards[i], cards[j] = cards[j], cards[i]
    end
end

local function drawBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZMemoryMatchGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZMemoryMatchGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.animationTick = 0
    self.flipDelay = 0
    self.matchFlash = 0
    self.missFlash = 0
    self.firstPick = nil
    self.secondPick = nil
    self.matches = 0
    self.moves = 0
    self.score = 0
    self.cards = {}
    local pool = {}
    for i = 1, #memorySymbols do
        pool[#pool + 1] = memorySymbols[i]
        pool[#pool + 1] = memorySymbols[i]
    end
    shuffleCards(pool)
    for i = 1, 16 do
        self.cards[i] = {symbol = pool[i], open = false, matched = false}
    end
end

function PZMemoryMatchGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZMemoryMatchGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZMemoryMatchGame:getCardLayout()
    local boardSize = math.min(self.width - 34, self.height - 62)
    local cardSize = math.floor((boardSize - 24) / 4)
    local startX = math.floor((self.width - (cardSize * 4 + 24)) / 2)
    local startY = 44
    return startX, startY, cardSize
end

function PZMemoryMatchGame:getCardAt(x, y)
    local startX, startY, cardSize = self:getCardLayout()
    for row = 0, 3 do
        for col = 0, 3 do
            local index = row * 4 + col + 1
            local cx = startX + col * (cardSize + 8)
            local cy = startY + row * (cardSize + 8)
            if x >= cx and x <= cx + cardSize and y >= cy and y <= cy + cardSize then
                return index
            end
        end
    end
    return nil
end

function PZMemoryMatchGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    if self.flipDelay > 0 then return true end
    local index = self:getCardAt(x, y)
    if not index then return true end
    local card = self.cards[index]
    if not card or card.open or card.matched then return true end
    card.open = true
    if not self.firstPick then
        self.firstPick = index
    else
        self.secondPick = index
        self.moves = self.moves + 1
        local first = self.cards[self.firstPick]
        if first and first.symbol == card.symbol then
            first.matched = true
            card.matched = true
            self.matches = self.matches + 1
            self.score = self.score + 100 + math.max(0, 40 - self.moves)
            self.matchFlash = 8
            self:playSound("ComputerBallHit")
            self.firstPick = nil
            self.secondPick = nil
            if self.matches >= 8 then
                self.gameState = "WIN"
                self.score = self.score + 500
                self:playWinSound()
            end
        else
            self.flipDelay = 34
            self.missFlash = 8
        end
    end
    return true
end

function PZMemoryMatchGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.matchFlash = math.max(0, (self.matchFlash or 0) - 1)
    self.missFlash = math.max(0, (self.missFlash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 4, 4)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    if activated and self.flipDelay <= 0 then
        local startX, startY, cardSize = self:getCardLayout()
        self:onMouseDown(startX + (selectedX - 1) * (cardSize + 8) + cardSize / 2, startY + (selectedY - 1) * (cardSize + 8) + cardSize / 2)
    end
    if self.flipDelay > 0 then
        self.flipDelay = self.flipDelay - 1
        if self.flipDelay <= 0 then
            if self.firstPick and self.cards[self.firstPick] then self.cards[self.firstPick].open = false end
            if self.secondPick and self.cards[self.secondPick] then self.cards[self.secondPick].open = false end
            self.firstPick = nil
            self.secondPick = nil
        end
    end
end

function PZMemoryMatchGame:drawCard(x, y, size, card, index)
    local pulse = 0.05 + math.abs(math.sin((self.animationTick + index * 7) * 0.05)) * 0.06
    if card.matched then
        self:drawRect(x + 1, y + 2, size, size, 0.24, 0, 0, 0)
        self:drawRect(x, y, size, size, 1, 0.04, 0.18, 0.12)
        drawBorder(self, x, y, size, size, 1, 0.34, 0.72, 0.46)
        self:drawText(card.symbol, x + size * 0.5 - 4, y + size * 0.5 - 8, 0.62, 0.86, 0.62, 1, UIFont.Medium)
    elseif card.open then
        self:drawRect(x + 1, y + 2, size, size, 0.24, 0, 0, 0)
        self:drawRect(x, y, size, size, 1, 0.62, 0.58, 0.36)
        drawBorder(self, x, y, size, size, 1, 0.12, 0.10, 0.06)
        self:drawText(card.symbol, x + size * 0.5 - 4, y + size * 0.5 - 8, 0.03, 0.03, 0.02, 1, UIFont.Medium)
    else
        self:drawRect(x + 1, y + 2, size, size, 0.26, 0, 0, 0)
        self:drawRect(x, y, size, size, 1, 0.018 + pulse, 0.030 + pulse, 0.072 + pulse)
        drawBorder(self, x, y, size, size, 1, 0.20, 0.28, 0.46)
        self:drawRect(x + 5, y + 5, size - 10, 1, 0.55, 0.40, 0.46, 0.72)
        self:drawRect(x + 5, y + size - 6, size - 10, 1, 0.35, 0.40, 0.46, 0.72)
        self:drawText("MEM", x + size * 0.5 - 12, y + size * 0.5 - 7, 0.54, 0.62, 0.82, 1, UIFont.Small)
    end
end

function PZMemoryMatchGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.008, 0.010, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.28, 0.34, 0.48)
    self:drawText("MEMORY.EXE", 10, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("MOVES " .. tostring(self.moves), 110, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("MATCH " .. tostring(self.matches) .. "/8", 186, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), self.width - 92, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZMemoryMatchGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.008, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.28, 0.34, 0.48)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZMemoryMatchGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZMemoryMatchGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.010, 0.012, 0.022)
    self:drawHud()
    local startX, startY, cardSize = self:getCardLayout()
    local boardW = cardSize * 4 + 24
    local boardH = cardSize * 4 + 24
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.030, 0.034, 0.046)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.006, 0.008, 0.014)
    if self.matchFlash and self.matchFlash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.matchFlash / 100, 0.34, 0.72, 0.42)
    end
    if self.missFlash and self.missFlash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.missFlash / 110, 0.72, 0.42, 0.20)
    end
    for row = 0, 3 do
        for col = 0, 3 do
            local index = row * 4 + col + 1
            local x = startX + col * (cardSize + 8)
            local y = startY + row * (cardSize + 8)
            self:drawCard(x, y, cardSize, self.cards[index], index)
        end
    end
    local selectedX = math.max(1, math.min(4, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(4, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cardSize + 8), startY + (selectedY - 1) * (cardSize + 8), cardSize, cardSize)
    if self.gameState == "WIN" then
        self:drawOverlay("BOARD CLEARED", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZMemoryMatchGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
