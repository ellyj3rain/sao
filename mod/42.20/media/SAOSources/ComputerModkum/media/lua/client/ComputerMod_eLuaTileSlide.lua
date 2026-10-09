require "ISUI/ISPanel"

PZTileSlideGame = ISPanel:derive("PZTileSlideGame")

local function drawTileBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZTileSlideGame:initialise()
    ISPanel.initialise(self)
    self.bestMoves = nil
    self:resetGame()
end

function PZTileSlideGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.moves = 0
    self.flash = 0
    self.tiles = {}
    local n = 1
    for y = 1, 4 do
        self.tiles[y] = {}
        for x = 1, 4 do
            if x == 4 and y == 4 then
                self.tiles[y][x] = 0
                self.blankX = x
                self.blankY = y
            else
                self.tiles[y][x] = n
                n = n + 1
            end
        end
    end
    local lastDx = 0
    local lastDy = 0
    for i = 1, 120 do
        local options = {}
        local dirs = {{x = 1, y = 0}, {x = -1, y = 0}, {x = 0, y = 1}, {x = 0, y = -1}}
        for d = 1, #dirs do
            local dir = dirs[d]
            local tx = self.blankX + dir.x
            local ty = self.blankY + dir.y
            if tx >= 1 and tx <= 4 and ty >= 1 and ty <= 4 and not (dir.x == -lastDx and dir.y == -lastDy) then
                options[#options + 1] = dir
            end
        end
        local pick = options[ZombRand(#options) + 1]
        self:moveTileAt(self.blankX + pick.x, self.blankY + pick.y, false)
        lastDx = pick.x
        lastDy = pick.y
    end
    if self:isSolved() then
        self:moveTileAt(3, 4, false)
    end
    self.moves = 0
end

function PZTileSlideGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZTileSlideGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZTileSlideGame:isSolved()
    local n = 1
    for y = 1, 4 do
        for x = 1, 4 do
            if x == 4 and y == 4 then
                if self.tiles[y][x] ~= 0 then return false end
            else
                if self.tiles[y][x] ~= n then return false end
                n = n + 1
            end
        end
    end
    return true
end

function PZTileSlideGame:getBoardLayout()
    local usableW = math.max(1, self.width - 46)
    local usableH = math.max(1, self.height - 80)
    local gap = math.max(2, math.floor(math.min(usableW, usableH) * 0.012))
    local cell = math.floor((math.min(usableW, usableH) - gap * 3) / 4)
    cell = math.max(18, cell)
    local boardW = cell * 4 + gap * 3
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 42 + math.floor((usableH - boardH) / 2)
    return x, y, cell, gap, boardW, boardH
end

function PZTileSlideGame:getCellAt(mx, my)
    local startX, startY, cell, gap = self:getBoardLayout()
    for y = 1, 4 do
        for x = 1, 4 do
            local cx = startX + (x - 1) * (cell + gap)
            local cy = startY + (y - 1) * (cell + gap)
            if mx >= cx and mx <= cx + cell and my >= cy and my <= cy + cell then
                return x, y
            end
        end
    end
    return nil, nil
end

function PZTileSlideGame:moveTileAt(x, y, countMove)
    if math.abs(x - self.blankX) + math.abs(y - self.blankY) ~= 1 then return false end
    self.tiles[self.blankY][self.blankX] = self.tiles[y][x]
    self.tiles[y][x] = 0
    self.blankX = x
    self.blankY = y
    if countMove then
        self.moves = self.moves + 1
        self.flash = 5
        self:playSound("ComputerBallHit")
        if self:isSolved() then
            self.gameState = "WIN"
            if not self.bestMoves or self.moves < self.bestMoves then
                self.bestMoves = self.moves
            end
            self:playWinSound()
        end
    end
    return true
end

function PZTileSlideGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local cx, cy = self:getCellAt(x, y)
    if cx then
        self:moveTileAt(cx, cy, true)
    end
    return true
end

function PZTileSlideGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 4, 4)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        self:moveTileAt(selectedX, selectedY, true)
    end
end

function PZTileSlideGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.012, 0.012, 0.016)
    self:drawRect(0, 25, self.width, 1, 1, 0.38, 0.36, 0.28)
    self:drawText("TILESLD.EXE", 10, 7, 0.82, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("MOVES " .. tostring(self.moves), 116, 7, 0.82, 0.78, 0.58, 1, UIFont.Small)
    local best = self.bestMoves and tostring(self.bestMoves) or "--"
    self:drawText("BEST " .. best, self.width - 78, 7, 0.82, 0.78, 0.58, 1, UIFont.Small)
end

function PZTileSlideGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.04, 0.03)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.012, 0.012, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.38, 0.36, 0.28)
    self:drawText(title, boxX + 10, boxY + 19, 0.82, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.62, 0.86, 0.62, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": SHUFFLE", boxX + 10, boxY + 58, 0.82, 0.78, 0.58, 1, UIFont.Small)
end

function PZTileSlideGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZTileSlideGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.010, 0.010, 0.012)
    self:drawHud()
    local startX, startY, cell, gap, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 8, startY - 8, boardW + 16, boardH + 16, 1, 0.04, 0.036, 0.030)
    self:drawRect(startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.006, 0.006, 0.008)
    drawTileBorder(self, startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.38, 0.36, 0.28)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 4, startY - 4, boardW + 8, boardH + 8, self.flash / 100, 0.72, 0.62, 0.32)
    end
    for y = 1, 4 do
        for x = 1, 4 do
            local value = self.tiles[y][x]
            local px = startX + (x - 1) * (cell + gap)
            local py = startY + (y - 1) * (cell + gap)
            if value == 0 then
                self:drawRect(px, py, cell, cell, 1, 0.016, 0.016, 0.018)
                drawTileBorder(self, px, py, cell, cell, 0.5, 0.12, 0.11, 0.10)
            else
                self:drawRect(px + 1, py + 2, cell, cell, 0.26, 0, 0, 0)
                self:drawRect(px, py, cell, cell, 1, 0.54, 0.44, 0.24)
                drawTileBorder(self, px, py, cell, cell, 1, 0.86, 0.70, 0.34)
                self:drawRect(px + 5, py + 5, math.max(1, cell - 10), 2, 0.36, 0.98, 0.88, 0.56)
                local dx = value < 10 and 4 or 8
                self:drawText(tostring(value), px + math.floor(cell * 0.5) - dx, py + math.floor(cell * 0.5) - 8, 0.02, 0.02, 0.02, 1, UIFont.Medium)
            end
        end
    end
    local selectedX = math.max(1, math.min(4, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(4, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cell + gap), startY + (selectedY - 1) * (cell + gap), cell, cell)
    if self.gameState == "WIN" then
        self:drawOverlay("TILES RESTORED", "MOVES " .. tostring(self.moves))
    end
    self:drawScanlines()
end

function PZTileSlideGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
