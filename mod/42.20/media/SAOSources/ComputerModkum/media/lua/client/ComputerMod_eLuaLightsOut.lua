require "ISUI/ISPanel"

PZLightsOutGame = ISPanel:derive("PZLightsOutGame")

local function drawLightsBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZLightsOutGame:initialise()
    ISPanel.initialise(self)
    self.bestMoves = nil
    self:resetGame()
end

function PZLightsOutGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.flash = 0
    self.moves = 0
    self.board = {}
    for y = 1, 5 do
        self.board[y] = {}
        for x = 1, 5 do
            self.board[y][x] = false
        end
    end
    local shuffles = 8 + ZombRand(8)
    for i = 1, shuffles do
        self:toggleCell(ZombRand(5) + 1, ZombRand(5) + 1, false)
    end
    if self:isSolved() then
        self:toggleCell(3, 3, false)
    end
end

function PZLightsOutGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZLightsOutGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZLightsOutGame:isSolved()
    for y = 1, 5 do
        for x = 1, 5 do
            if self.board[y][x] then return false end
        end
    end
    return true
end

function PZLightsOutGame:toggleOne(x, y)
    if not self.board[y] or self.board[y][x] == nil then return end
    self.board[y][x] = not self.board[y][x]
end

function PZLightsOutGame:toggleCell(x, y, countMove)
    self:toggleOne(x, y)
    self:toggleOne(x - 1, y)
    self:toggleOne(x + 1, y)
    self:toggleOne(x, y - 1)
    self:toggleOne(x, y + 1)
    if countMove then
        self.moves = self.moves + 1
        self.flash = 6
        self:playSound("ComputerBallHit")
        if self:isSolved() then
            self.gameState = "WIN"
            if not self.bestMoves or self.moves < self.bestMoves then
                self.bestMoves = self.moves
            end
            self:playWinSound()
        end
    end
end

function PZLightsOutGame:getBoardLayout()
    local usableW = math.max(1, self.width - 44)
    local usableH = math.max(1, self.height - 78)
    local gap = math.max(2, math.floor(math.min(usableW, usableH) * 0.012))
    local cell = math.floor((math.min(usableW, usableH) - gap * 4) / 5)
    cell = math.max(14, cell)
    local boardW = cell * 5 + gap * 4
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 42 + math.floor((usableH - boardH) / 2)
    return x, y, cell, gap, boardW, boardH
end

function PZLightsOutGame:getCellAt(mx, my)
    local startX, startY, cell, gap = self:getBoardLayout()
    for y = 1, 5 do
        for x = 1, 5 do
            local cx = startX + (x - 1) * (cell + gap)
            local cy = startY + (y - 1) * (cell + gap)
            if mx >= cx and mx <= cx + cell and my >= cy and my <= cy + cell then
                return x, y
            end
        end
    end
    return nil, nil
end

function PZLightsOutGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local cx, cy = self:getCellAt(x, y)
    if cx then
        self:toggleCell(cx, cy, true)
    end
    return true
end

function PZLightsOutGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 5, 5)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        self:toggleCell(selectedX, selectedY, true)
    end
end

function PZLightsOutGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.008, 0.014, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.24, 0.40, 0.38)
    self:drawText("LIGHTS.EXE", 10, 7, 0.58, 0.78, 0.72, 1, UIFont.Small)
    self:drawText("MOVES " .. tostring(self.moves), 112, 7, 0.58, 0.78, 0.72, 1, UIFont.Small)
    local best = self.bestMoves and tostring(self.bestMoves) or "--"
    self:drawText("BEST " .. best, self.width - 80, 7, 0.58, 0.78, 0.72, 1, UIFont.Small)
end

function PZLightsOutGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 218)
    local boxH = 74
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.03, 0.05, 0.05)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.012, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.24, 0.40, 0.38)
    self:drawText(title, boxX + 10, boxY + 18, 0.62, 0.84, 0.72, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 40, 0.82, 0.74, 0.48, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": NEW BOARD", boxX + 10, boxY + 57, 0.62, 0.84, 0.72, 1, UIFont.Small)
end

function PZLightsOutGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZLightsOutGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.012, 0.016)
    self:drawHud()
    local startX, startY, cell, gap, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.022, 0.028, 0.032)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.004, 0.008, 0.010)
    drawLightsBorder(self, startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.22, 0.38, 0.36)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.flash / 100, 0.66, 0.78, 0.46)
    end
    for y = 1, 5 do
        for x = 1, 5 do
            local cx = startX + (x - 1) * (cell + gap)
            local cy = startY + (y - 1) * (cell + gap)
            local lit = self.board[y][x]
            if lit then
                local pulse = math.abs(math.sin((self.tick + x * 3 + y * 7) * 0.08)) * 0.10
                self:drawRect(cx + 1, cy + 2, cell, cell, 0.25, 0, 0, 0)
                self:drawRect(cx, cy, cell, cell, 1, 0.70 + pulse, 0.54 + pulse, 0.18)
                drawLightsBorder(self, cx, cy, cell, cell, 1, 0.94, 0.82, 0.36)
                self:drawRect(cx + 5, cy + 5, math.max(1, cell - 10), 2, 0.52, 1, 0.94, 0.52)
            else
                self:drawRect(cx + 1, cy + 2, cell, cell, 0.24, 0, 0, 0)
                self:drawRect(cx, cy, cell, cell, 1, 0.018, 0.034, 0.038)
                drawLightsBorder(self, cx, cy, cell, cell, 1, 0.10, 0.20, 0.20)
                self:drawRect(cx + 4, cy + cell - 6, math.max(1, cell - 8), 1, 0.36, 0.22, 0.36, 0.34)
            end
        end
    end
    local selectedX = math.max(1, math.min(5, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(5, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cell + gap), startY + (selectedY - 1) * (cell + gap), cell, cell)
    if self.gameState == "WIN" then
        self:drawOverlay("PANEL CLEARED", "MOVES " .. tostring(self.moves))
    end
    self:drawScanlines()
end

function PZLightsOutGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
