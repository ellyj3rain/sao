require "ISUI/ISPanel"

PZMinesweeperGame = ISPanel:derive("PZMinesweeperGame")

local mineNumberPatterns = {
    [1] = {"00100", "01100", "00100", "00100", "00100", "00100", "01110"},
    [2] = {"01110", "10001", "00001", "00010", "00100", "01000", "11111"},
    [3] = {"11110", "00001", "00001", "01110", "00001", "00001", "11110"},
    [4] = {"10010", "10010", "10010", "11111", "00010", "00010", "00010"},
    [5] = {"11111", "10000", "10000", "11110", "00001", "00001", "11110"},
    [6] = {"01110", "10000", "10000", "11110", "10001", "10001", "01110"},
    [7] = {"11111", "00001", "00010", "00100", "01000", "01000", "01000"},
    [8] = {"01110", "10001", "10001", "01110", "10001", "10001", "01110"}
}

function PZMinesweeperGame:initialise()
    ISPanel.initialise(self)
    self.cols = 12
    self.rows = 9
    self.mineCount = 16
    self.bestTime = nil
    self:resetGame()
end

function PZMinesweeperGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.firstClick = true
    self.flags = 0
    self.revealed = 0
    self.timerTicks = 0
    self.winSoundPlayed = false
    self.flash = 0
    self.explodeX = nil
    self.explodeY = nil
    self.grid = {}
    for y = 1, self.rows do
        self.grid[y] = {}
        for x = 1, self.cols do
            self.grid[y][x] = {mine=false, revealed=false, flagged=false, count=0}
        end
    end
end

function PZMinesweeperGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZMinesweeperGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZMinesweeperGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZMinesweeperGame:getCellSize()
    local headerH = math.max(38, math.floor(self.height * 0.14))
    local footerH = 20
    local sizeX = math.floor((self.width - 24) / self.cols)
    local sizeY = math.floor((self.height - headerH - footerH) / self.rows)
    return math.max(8, math.min(sizeX, sizeY)), headerH, footerH
end

function PZMinesweeperGame:getGridOrigin()
    local cell, headerH, footerH = self:getCellSize()
    local gridW = cell * self.cols
    local gridH = cell * self.rows
    local usableH = math.max(1, self.height - headerH - footerH)
    return math.floor((self.width - gridW) / 2), headerH + math.floor((usableH - gridH) / 2), cell
end

function PZMinesweeperGame:cellFromMouse(x, y)
    local ox, oy, cell = self:getGridOrigin()
    local cx = math.floor((x - ox) / cell) + 1
    local cy = math.floor((y - oy) / cell) + 1
    if cx < 1 or cx > self.cols or cy < 1 or cy > self.rows then return nil, nil end
    return cx, cy
end

function PZMinesweeperGame:placeMines(safeX, safeY)
    local placed = 0
    while placed < self.mineCount do
        local x = ZombRand(self.cols) + 1
        local y = ZombRand(self.rows) + 1
        local cell = self.grid[y][x]
        local safe = math.abs(x - safeX) <= 1 and math.abs(y - safeY) <= 1
        if not cell.mine and not safe then
            cell.mine = true
            placed = placed + 1
        end
    end

    for y = 1, self.rows do
        for x = 1, self.cols do
            local count = 0
            for yy = y - 1, y + 1 do
                for xx = x - 1, x + 1 do
                    if self.grid[yy] and self.grid[yy][xx] and self.grid[yy][xx].mine then
                        count = count + 1
                    end
                end
            end
            self.grid[y][x].count = count
        end
    end
end

function PZMinesweeperGame:revealCell(x, y)
    if not self.grid[y] or not self.grid[y][x] then return end
    local cell = self.grid[y][x]
    if cell.revealed or cell.flagged then return end

    cell.revealed = true
    self.revealed = self.revealed + 1

    if cell.mine then
        self.gameState = "GAMEOVER"
        self.explodeX = x
        self.explodeY = y
        self.flash = 16
        self:revealAllMines()
        self:playGameOverSound()
        return
    end

    if cell.count == 0 then
        for yy = y - 1, y + 1 do
            for xx = x - 1, x + 1 do
                if not (xx == x and yy == y) then
                    self:revealCell(xx, yy)
                end
            end
        end
    end

    if self.revealed >= self.cols * self.rows - self.mineCount then
        self.gameState = "WIN"
        self:flagAllMines()
        local time = self:getTimerSeconds()
        if not self.bestTime or time < self.bestTime then
            self.bestTime = time
        end
        self:playWinSound()
    end
end

function PZMinesweeperGame:revealAllMines()
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.grid[y][x].mine then
                self.grid[y][x].revealed = true
            end
        end
    end
end

function PZMinesweeperGame:flagAllMines()
    self.flags = self.mineCount
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.grid[y][x].mine then
                self.grid[y][x].flagged = true
            end
        end
    end
end

function PZMinesweeperGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end

    local cx, cy = self:cellFromMouse(x, y)
    if not cx then return true end

    if self.firstClick then
        self:placeMines(cx, cy)
        self.firstClick = false
    end

    self:playSound("ComputerBallHit")
    self:revealCell(cx, cy)
    return true
end

function PZMinesweeperGame:onRightMouseDown(x, y)
    if self.gameState ~= "PLAYING" then return true end
    local cx, cy = self:cellFromMouse(x, y)
    if not cx then return true end

    local cell = self.grid[cy][cx]
    if cell.revealed then return true end
    if not cell.flagged and self.flags >= self.mineCount then return true end

    cell.flagged = not cell.flagged
    if cell.flagged then
        self.flags = self.flags + 1
    else
        self.flags = self.flags - 1
    end
    self:playSound("ComputerBallHit")
    return true
end

function PZMinesweeperGame:update()
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated, secondaryActivated = ComputerModGameInput.updateGridSelection(self, self.cols, self.rows)
    if self.gameState == "PLAYING" and not self.firstClick then
        self.timerTicks = (self.timerTicks or 0) + 1
    end
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and (activated or secondaryActivated) then
        local ox, oy, cell = self:getGridOrigin()
        local targetX = ox + (selectedX - 0.5) * cell
        local targetY = oy + (selectedY - 0.5) * cell
        if secondaryActivated then
            self:onRightMouseDown(targetX, targetY)
        else
            self:onMouseDown(targetX, targetY)
        end
    end
end

function PZMinesweeperGame:getTimerSeconds()
    return math.min(999, math.floor((self.timerTicks or 0) / 30))
end

function PZMinesweeperGame:drawCellFrame(x, y, size, raised)
    if raised then
        self:drawRect(x, y, size, size, 1, 0.47, 0.50, 0.50)
        self:drawRect(x + 1, y + 1, size - 2, size - 2, 1, 0.60, 0.64, 0.64)
        self:drawRect(x, y, size, 2, 1, 0.88, 0.92, 0.90)
        self:drawRect(x, y, 2, size, 1, 0.88, 0.92, 0.90)
        self:drawRect(x + size - 2, y, 2, size, 1, 0.18, 0.20, 0.22)
        self:drawRect(x, y + size - 2, size, 2, 1, 0.18, 0.20, 0.22)
    else
        self:drawRect(x, y, size, size, 1, 0.30, 0.33, 0.34)
        self:drawRect(x + 2, y + 2, size - 4, size - 4, 1, 0.38, 0.42, 0.42)
        self:drawRect(x, y, size, 1, 1, 0.16, 0.18, 0.18)
        self:drawRect(x, y, 1, size, 1, 0.16, 0.18, 0.18)
    end
end

function PZMinesweeperGame:getNumberColor(n)
    if n == 1 then return 0.18, 0.35, 1 end
    if n == 2 then return 0.08, 0.70, 0.20 end
    if n == 3 then return 1, 0.18, 0.14 end
    if n == 4 then return 0.32, 0.22, 0.82 end
    if n == 5 then return 0.72, 0.12, 0.12 end
    if n == 6 then return 0.0, 0.70, 0.76 end
    if n == 7 then return 0.04, 0.04, 0.05 end
    return 0.75, 0.75, 0.75
end

function PZMinesweeperGame:drawMineNumber(n, x, y, size)
    local r, g, b = self:getNumberColor(n)
    local pattern = mineNumberPatterns[n]
    if not pattern then return end

    local block = math.max(1, math.floor(math.min((size - 8) / 5, (size - 8) / 7)))
    local digitW = block * 5
    local digitH = block * 7
    local left = x + math.floor((size - digitW) / 2)
    local top = y + math.floor((size - digitH) / 2)

    for row = 1, #pattern do
        local line = pattern[row]
        for col = 1, string.len(line) do
            if string.sub(line, col, col) == "1" then
                local px = left + (col - 1) * block
                local py = top + (row - 1) * block
                self:drawRect(px + 1, py + 1, block, block, 0.24, 0, 0, 0)
                self:drawRect(px, py, block, block, 1, r, g, b)
            end
        end
    end
end

function PZMinesweeperGame:drawFlag(px, py, size)
    local poleW = math.max(2, math.floor(size * 0.10))
    local poleX = px + math.floor(size * 0.34)
    local poleY = py + math.floor(size * 0.18)
    self:drawRect(poleX, poleY, poleW, math.floor(size * 0.58), 1, 0.04, 0.04, 0.04)
    self:drawRect(poleX + poleW, poleY, math.floor(size * 0.42), math.floor(size * 0.26), 1, 0.88, 0.04, 0.06)
    self:drawRect(poleX + poleW, poleY + math.floor(size * 0.26), math.floor(size * 0.27), math.max(2, math.floor(size * 0.11)), 1, 0.62, 0.02, 0.04)
    self:drawRect(px + math.floor(size * 0.24), py + math.floor(size * 0.78), math.floor(size * 0.52), math.max(2, math.floor(size * 0.09)), 1, 0.04, 0.04, 0.04)
end

function PZMinesweeperGame:drawMine(px, py, size, exploded)
    if exploded then
        self:drawRect(px + 2, py + 2, size - 4, size - 4, 1, 0.76, 0.08, 0.08)
    end
    local cx = px + math.floor(size * 0.5)
    local cy = py + math.floor(size * 0.5)
    local r = math.max(4, math.floor(size * 0.26))
    self:drawRect(cx - r, cy - r, r * 2, r * 2, 1, 0.03, 0.03, 0.035)
    self:drawRect(cx - 1, py + math.floor(size * 0.18), 2, math.floor(size * 0.64), 1, 0.03, 0.03, 0.035)
    self:drawRect(px + math.floor(size * 0.18), cy - 1, math.floor(size * 0.64), 2, 1, 0.03, 0.03, 0.035)
    self:drawRect(cx - math.floor(r * 0.7), cy - math.floor(r * 0.7), math.max(2, math.floor(r * 0.55)), math.max(2, math.floor(r * 0.45)), 0.85, 0.88, 0.88, 0.82)
end

function PZMinesweeperGame:drawHeaderBox(x, y, w, h, label, value, r, g, b)
    self:drawRect(x, y, w, h, 1, 0.08, 0.09, 0.10)
    self:drawRect(x + 2, y + 2, w - 4, h - 4, 1, 0.015, 0.025, 0.030)
    self:drawRect(x, y, w, 2, 1, r, g, b)
    self:drawText(label, x + 7, y + 4, 0.62, 0.70, 0.70, 1, UIFont.Small)
    self:drawText(value, x + 7, y + 17, r, g, b, 1, UIFont.Small)
end

function PZMinesweeperGame:drawStatusFace(x, y, size)
    self:drawRect(x, y, size, size, 1, 0.44, 0.46, 0.46)
    self:drawRect(x + 2, y + 2, size - 4, size - 4, 1, 0.92, 0.78, 0.18)
    local eyeY = y + math.floor(size * 0.33)
    self:drawRect(x + math.floor(size * 0.28), eyeY, 3, 3, 1, 0.04, 0.04, 0.04)
    self:drawRect(x + math.floor(size * 0.64), eyeY, 3, 3, 1, 0.04, 0.04, 0.04)
    if self.gameState == "WIN" then
        self:drawRect(x + math.floor(size * 0.24), y + math.floor(size * 0.62), math.floor(size * 0.52), 3, 1, 0.04, 0.24, 0.04)
        self:drawRect(x + math.floor(size * 0.30), y + math.floor(size * 0.66), math.floor(size * 0.40), 2, 1, 0.04, 0.24, 0.04)
    elseif self.gameState == "GAMEOVER" then
        self:drawRect(x + math.floor(size * 0.28), y + math.floor(size * 0.66), math.floor(size * 0.48), 2, 1, 0.24, 0.04, 0.04)
    else
        self:drawRect(x + math.floor(size * 0.30), y + math.floor(size * 0.63), math.floor(size * 0.40), 2, 1, 0.04, 0.04, 0.04)
        self:drawRect(x + math.floor(size * 0.30), y + math.floor(size * 0.63), 2, 3, 1, 0.04, 0.04, 0.04)
        self:drawRect(x + math.floor(size * 0.68), y + math.floor(size * 0.63), 2, 3, 1, 0.04, 0.04, 0.04)
    end
end

function PZMinesweeperGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.22, 0.25, 0.26)
    for i = 0, 10 do
        local y = i * self.height / 10
        self:drawRect(0, y, self.width, math.max(2, self.height / 12), 0.10, 0.38, 0.42, 0.42)
    end
    if self.flash and self.flash > 0 then
        self:drawRect(0, 0, self.width, self.height, self.flash / 40, 1, 0.06, 0.04)
    end
end

function PZMinesweeperGame:drawHeader()
    local _, headerH = self:getCellSize()
    self:drawRect(6, 6, self.width - 12, headerH - 12, 1, 0.36, 0.39, 0.39)
    self:drawRect(8, 8, self.width - 16, headerH - 16, 1, 0.50, 0.53, 0.53)
    local boxH = math.max(26, headerH - 20)
    local boxY = 12
    self:drawHeaderBox(14, boxY, 78, boxH, "MINES", string.format("%03d", math.max(0, self.mineCount - self.flags)), 1, 0.20, 0.20)
    self:drawHeaderBox(self.width - 92, boxY, 78, boxH, "TIME", string.format("%03d", self:getTimerSeconds()), 0.34, 0.95, 1)
    if self.bestTime then
        self:drawText("BEST " .. string.format("%03d", self.bestTime), self.width - 90, headerH - 15, 0.10, 0.16, 0.16, 1, UIFont.Small)
    end
    local faceSize = math.min(30, math.max(22, boxH))
    self:drawStatusFace(math.floor((self.width - faceSize) / 2), boxY, faceSize)
    if self.gameState == "WIN" then
        self:drawText("CLEARED", math.floor(self.width / 2) - 27, headerH - 15, 0.05, 0.34, 0.10, 1, UIFont.Small)
    elseif self.gameState == "GAMEOVER" then
        self:drawText("BOOM", math.floor(self.width / 2) - 17, headerH - 15, 0.42, 0.04, 0.04, 1, UIFont.Small)
    elseif self.firstClick then
        self:drawText("FIRST CLICK IS SAFE", math.floor(self.width / 2) - 58, headerH - 15, 0.10, 0.16, 0.16, 1, UIFont.Small)
    else
        self:drawText("SCANNING", math.floor(self.width / 2) - 30, headerH - 15, 0.10, 0.16, 0.16, 1, UIFont.Small)
    end
end

function PZMinesweeperGame:drawGrid()
    local ox, oy, cellSize = self:getGridOrigin()
    local gridW = self.cols * cellSize
    local gridH = self.rows * cellSize
    self:drawRect(ox - 6, oy - 6, gridW + 12, gridH + 12, 1, 0.13, 0.15, 0.16)
    self:drawRect(ox - 3, oy - 3, gridW + 6, gridH + 6, 1, 0.58, 0.62, 0.62)
    for y = 1, self.rows do
        for x = 1, self.cols do
            local px = ox + (x - 1) * cellSize
            local py = oy + (y - 1) * cellSize
            local cell = self.grid[y][x]
            self:drawCellFrame(px, py, cellSize - 1, not cell.revealed)
            if cell.revealed then
                if cell.mine then
                    self:drawMine(px, py, cellSize - 1, self.explodeX == x and self.explodeY == y)
                elseif cell.count > 0 then
                    self:drawMineNumber(cell.count, px, py, cellSize)
                else
                    self:drawRect(px + 4, py + 4, cellSize - 9, cellSize - 9, 0.18, 0.60, 0.70, 0.66)
                end
            elseif cell.flagged then
                self:drawFlag(px, py, cellSize - 1)
            end
        end
    end
    local selectedX = math.max(1, math.min(self.cols, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(self.rows, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, ox + (selectedX - 1) * cellSize, oy + (selectedY - 1) * cellSize, cellSize - 1, cellSize - 1)
end

function PZMinesweeperGame:drawFooter()
    if self.gameState ~= "PLAYING" then
        self:drawRect(0, self.height - 19, self.width, 19, 0.72, 0.05, 0.06, 0.065)
        self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. " OR CLICK TO RESTART", math.floor(self.width / 2) - 76, self.height - 16, 0.9, 0.95, 1, 1, UIFont.Small)
    else
        self:drawRect(0, self.height - 14, self.width, 14, 0.28, 0.05, 0.06, 0.065)
        local controls = ComputerModGameInput.hasGamepad(ComputerModGameInput.getPlayer(self)) and "A: REVEAL   X: FLAG" or "LEFT: REVEAL   RIGHT: FLAG"
        self:drawText(controls, math.floor(self.width / 2) - 82, self.height - 13, 0.76, 0.82, 0.82, 1, UIFont.Small)
    end
end

function PZMinesweeperGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.05, 0, 0, 0)
        y = y + 4
    end
end

function PZMinesweeperGame:prerender()
    self:drawBackground()
    self:drawHeader()
    self:drawGrid()
    self:drawFooter()
    self:drawScanlines()
end

function PZMinesweeperGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
