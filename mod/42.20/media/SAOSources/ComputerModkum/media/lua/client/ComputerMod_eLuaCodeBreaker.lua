require "ISUI/ISPanel"

PZCodeBreakerGame = ISPanel:derive("PZCodeBreakerGame")

local codeColors = {
    {r = 0.72, g = 0.26, b = 0.20},
    {r = 0.18, g = 0.58, b = 0.34},
    {r = 0.22, g = 0.36, b = 0.72},
    {r = 0.76, g = 0.62, b = 0.18},
    {r = 0.58, g = 0.30, b = 0.64}
}

local function drawCodeBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZCodeBreakerGame:initialise()
    ISPanel.initialise(self)
    self.bestRows = nil
    self:resetGame()
end

function PZCodeBreakerGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.gameOverSoundPlayed = false
    self.tick = 0
    self.flash = 0
    self.row = 1
    self.secret = {}
    self.rows = {}
    for i = 1, 4 do
        self.secret[i] = ZombRand(#codeColors) + 1
    end
    for y = 1, 8 do
        self.rows[y] = {guess = {1, 1, 1, 1}, exact = nil, near = nil}
    end
end

function PZCodeBreakerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZCodeBreakerGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZCodeBreakerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZCodeBreakerGame:getLayout()
    local rowH = math.max(22, math.floor((self.height - 72) / 8))
    local peg = math.max(14, math.min(22, rowH - 6))
    local startX = math.max(12, math.floor((self.width - 228) / 2))
    local startY = 36
    local checkX = startX + 156
    local resultX = startX + 118
    return startX, startY, rowH, peg, resultX, checkX
end

function PZCodeBreakerGame:getPegAt(mx, my)
    local startX, startY, rowH, peg = self:getLayout()
    local y = startY + (self.row - 1) * rowH
    if my < y or my > y + rowH then return nil end
    for i = 1, 4 do
        local x = startX + (i - 1) * (peg + 8)
        if mx >= x and mx <= x + peg and my >= y + 3 and my <= y + 3 + peg then
            return i
        end
    end
    return nil
end

function PZCodeBreakerGame:getCheckRect()
    local startX, startY, rowH, peg, resultX, checkX = self:getLayout()
    return {x = checkX, y = startY + (self.row - 1) * rowH + 3, w = 58, h = peg}
end

function PZCodeBreakerGame:evaluateGuess(guess)
    local exact = 0
    local near = 0
    local secretUsed = {}
    local guessUsed = {}
    for i = 1, 4 do
        if guess[i] == self.secret[i] then
            exact = exact + 1
            secretUsed[i] = true
            guessUsed[i] = true
        end
    end
    for i = 1, 4 do
        if not guessUsed[i] then
            for j = 1, 4 do
                if not secretUsed[j] and guess[i] == self.secret[j] then
                    near = near + 1
                    secretUsed[j] = true
                    guessUsed[i] = true
                    break
                end
            end
        end
    end
    return exact, near
end

function PZCodeBreakerGame:submitGuess()
    if self.gameState ~= "PLAYING" then return end
    local current = self.rows[self.row]
    local exact, near = self:evaluateGuess(current.guess)
    current.exact = exact
    current.near = near
    self.flash = 6
    self:playSound("ComputerBallHit")
    if exact >= 4 then
        self.gameState = "WIN"
        if not self.bestRows or self.row < self.bestRows then
            self.bestRows = self.row
        end
        self:playWinSound()
    elseif self.row >= 8 then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
    else
        self.row = self.row + 1
        for i = 1, 4 do
            self.rows[self.row].guess[i] = current.guess[i]
        end
    end
end

function PZCodeBreakerGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local peg = self:getPegAt(x, y)
    if peg then
        local row = self.rows[self.row]
        row.guess[peg] = (row.guess[peg] % #codeColors) + 1
        self:playSound("ComputerBallHit")
        return true
    end
    local button = self:getCheckRect()
    if x >= button.x and x <= button.x + button.w and y >= button.y and y <= button.y + button.h then
        self:submitGuess()
    end
    return true
end

function PZCodeBreakerGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, _, activated = ComputerModGameInput.updateGridSelection(self, 5, 1)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        if selectedX <= 4 then
            local row = self.rows[self.row]
            row.guess[selectedX] = (row.guess[selectedX] % #codeColors) + 1
            self:playSound("ComputerBallHit")
        else
            self:submitGuess()
        end
    end
end

function PZCodeBreakerGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.010, 0.010, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.30, 0.32, 0.46)
    self:drawText("CODEBRK.EXE", 10, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("ROW " .. tostring(self.row) .. "/8", 118, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    local best = self.bestRows and tostring(self.bestRows) or "--"
    self:drawText("BEST " .. best, self.width - 78, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZCodeBreakerGame:drawPeg(x, y, size, colorIndex, dim)
    local color = codeColors[colorIndex] or codeColors[1]
    local shade = dim and 0.48 or 1
    self:drawRect(x + 1, y + 2, size, size, 0.22, 0, 0, 0)
    self:drawRect(x, y, size, size, 1, color.r * shade, color.g * shade, color.b * shade)
    drawCodeBorder(self, x, y, size, size, 1, 0.10, 0.10, 0.12)
    if size > 16 then
        self:drawRect(x + 4, y + 4, math.max(1, size - 8), 2, 0.32, 1, 1, 0.86)
    end
end

function PZCodeBreakerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 228)
    local boxH = 82
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.008, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.32, 0.46)
    self:drawText(title, boxX + 10, boxY + 17, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 37, 0.80, 0.76, 0.52, 1, UIFont.Small)
    for i = 1, 4 do
        self:drawPeg(boxX + 10 + (i - 1) * 24, boxY + 55, 16, self.secret[i], false)
    end
end

function PZCodeBreakerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZCodeBreakerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.008, 0.010, 0.018)
    self:drawHud()
    local startX, startY, rowH, peg, resultX, checkX = self:getLayout()
    local panelW = math.min(self.width - 24, 232)
    self:drawRect(startX - 8, startY - 6, panelW, rowH * 8 + 12, 1, 0.030, 0.032, 0.046)
    drawCodeBorder(self, startX - 8, startY - 6, panelW, rowH * 8 + 12, 1, 0.24, 0.28, 0.42)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 8, startY - 6, panelW, rowH * 8 + 12, self.flash / 100, 0.52, 0.62, 0.86)
    end
    for r = 1, 8 do
        local rowY = startY + (r - 1) * rowH
        if r == self.row and self.gameState == "PLAYING" then
            self:drawRect(startX - 4, rowY, panelW - 8, rowH - 1, 0.22, 0.34, 0.40, 0.52)
        end
        self:drawText(tostring(r), startX - 22, rowY + 6, 0.62, 0.68, 0.86, 1, UIFont.Small)
        for i = 1, 4 do
            self:drawPeg(startX + (i - 1) * (peg + 8), rowY + 3, peg, self.rows[r].guess[i], r > self.row and self.gameState == "PLAYING")
        end
        if self.rows[r].exact then
            self:drawText("X" .. tostring(self.rows[r].exact), resultX, rowY + 5, 0.82, 0.78, 0.58, 1, UIFont.Small)
            self:drawText("N" .. tostring(self.rows[r].near), resultX + 34, rowY + 5, 0.62, 0.82, 0.66, 1, UIFont.Small)
        end
    end
    if self.gameState == "PLAYING" then
        local button = self:getCheckRect()
        self:drawRect(button.x, button.y, button.w, button.h, 1, 0.18, 0.20, 0.32)
        drawCodeBorder(self, button.x, button.y, button.w, button.h, 1, 0.48, 0.52, 0.72)
        self:drawText("CHECK", button.x + 9, button.y + math.floor(button.h / 2) - 6, 0.82, 0.86, 0.92, 1, UIFont.Small)
        local selectedX = math.max(1, math.min(5, tonumber(self.gamepadSelectionX) or 1))
        if selectedX <= 4 then
            ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (peg + 8), startY + (self.row - 1) * rowH + 3, peg, peg)
        else
            ComputerModGameInput.drawGamepadSelection(self, button.x, button.y, button.w, button.h)
        end
    end
    if self.gameState == "WIN" then
        self:drawOverlay("CODE OPENED", "ROW " .. tostring(self.row))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("ACCESS DENIED", "CODE WAS")
    end
    self:drawScanlines()
end

function PZCodeBreakerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
