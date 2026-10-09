require "ISUI/ISPanel"

PZPipeLinkGame = ISPanel:derive("PZPipeLinkGame")

local pipeDirs = {
    {x = 0, y = -1, bit = 1, opposite = 3},
    {x = 1, y = 0, bit = 2, opposite = 4},
    {x = 0, y = 1, bit = 4, opposite = 1},
    {x = -1, y = 0, bit = 8, opposite = 2}
}

local pipePuzzles = {
    {
        {5, 3, 6, 5, 6},
        {10, 6, 10, 12, 5},
        {10, 9, 3, 3, 10},
        {6, 5, 10, 6, 5},
        {9, 3, 5, 12, 10}
    },
    {
        {6, 5, 3, 5, 6},
        {6, 12, 6, 10, 5},
        {9, 3, 12, 3, 6},
        {5, 12, 3, 10, 9},
        {9, 3, 12, 9, 10}
    },
    {
        {5, 6, 5, 3, 6},
        {10, 9, 12, 6, 12},
        {12, 6, 10, 9, 3},
        {3, 9, 5, 10, 5},
        {9, 12, 5, 10, 10}
    }
}

local function drawPipeBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

local function rotateMask(mask, turns)
    local value = mask
    for i = 1, turns do
        local nextMask = 0
        if value % 2 >= 1 then nextMask = nextMask + 2 end
        if math.floor(value / 2) % 2 >= 1 then nextMask = nextMask + 4 end
        if math.floor(value / 4) % 2 >= 1 then nextMask = nextMask + 8 end
        if math.floor(value / 8) % 2 >= 1 then nextMask = nextMask + 1 end
        value = nextMask
    end
    return value
end

local function hasPipe(mask, bit)
    return math.floor(mask / bit) % 2 >= 1
end

function PZPipeLinkGame:initialise()
    ISPanel.initialise(self)
    self.bestMoves = nil
    self:resetGame()
end

function PZPipeLinkGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.moves = 0
    self.flash = 0
    self.puzzleIndex = ZombRand(#pipePuzzles) + 1
    self.tiles = {}
    local source = pipePuzzles[self.puzzleIndex]
    for y = 1, 5 do
        self.tiles[y] = {}
        for x = 1, 5 do
            local correct = source[y][x]
            local rot = ZombRand(4)
            self.tiles[y][x] = {base = correct, rot = rot, mask = rotateMask(correct, rot)}
        end
    end
    if self:isSolved() then
        self:rotateTile(3, 3, false)
    end
    self.moves = 0
end

function PZPipeLinkGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZPipeLinkGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZPipeLinkGame:getBoardLayout()
    local usableW = math.max(1, self.width - 46)
    local usableH = math.max(1, self.height - 82)
    local gap = math.max(2, math.floor(math.min(usableW, usableH) * 0.010))
    local cell = math.floor((math.min(usableW, usableH) - gap * 4) / 5)
    cell = math.max(14, cell)
    local boardW = cell * 5 + gap * 4
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 42 + math.floor((usableH - boardH) / 2)
    return x, y, cell, gap, boardW, boardH
end

function PZPipeLinkGame:getTileAt(mx, my)
    local startX, startY, cell, gap = self:getBoardLayout()
    for y = 1, 5 do
        for x = 1, 5 do
            local px = startX + (x - 1) * (cell + gap)
            local py = startY + (y - 1) * (cell + gap)
            if mx >= px and mx <= px + cell and my >= py and my <= py + cell then
                return x, y
            end
        end
    end
    return nil, nil
end

function PZPipeLinkGame:rotateTile(x, y, countMove)
    local tile = self.tiles[y] and self.tiles[y][x]
    if not tile then return end
    tile.rot = (tile.rot + 1) % 4
    tile.mask = rotateMask(tile.base, tile.rot)
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
end

function PZPipeLinkGame:isSolved()
    local startTile = self.tiles[3] and self.tiles[3][1]
    if not startTile or not hasPipe(startTile.mask, 8) then return false end
    local visited = {}
    local queue = {{x = 1, y = 3}}
    while #queue > 0 do
        local node = table.remove(queue, 1)
        local key = tostring(node.x) .. ":" .. tostring(node.y)
        if not visited[key] then
            visited[key] = true
            local tile = self.tiles[node.y] and self.tiles[node.y][node.x]
            if tile then
                if node.x == 5 and node.y == 3 and hasPipe(tile.mask, 2) then
                    return true
                end
                for i = 1, #pipeDirs do
                    local dir = pipeDirs[i]
                    if hasPipe(tile.mask, dir.bit) then
                        local nx = node.x + dir.x
                        local ny = node.y + dir.y
                        local other = self.tiles[ny] and self.tiles[ny][nx]
                        if other and hasPipe(other.mask, pipeDirs[dir.opposite].bit) then
                            queue[#queue + 1] = {x = nx, y = ny}
                        end
                    end
                end
            end
        end
    end
    return false
end

function PZPipeLinkGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local tx, ty = self:getTileAt(x, y)
    if tx then
        self:rotateTile(tx, ty, true)
    end
    return true
end

function PZPipeLinkGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 5, 5)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        self:rotateTile(selectedX, selectedY, true)
    end
end

function PZPipeLinkGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.006, 0.014, 0.014)
    self:drawRect(0, 25, self.width, 1, 1, 0.24, 0.42, 0.34)
    self:drawText("PIPELINK.EXE", 10, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText("TURNS " .. tostring(self.moves), 122, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    local best = self.bestMoves and tostring(self.bestMoves) or "--"
    self:drawText("BEST " .. best, self.width - 78, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZPipeLinkGame:drawPipe(tile, x, y, cell, connected)
    local cx = x + math.floor(cell / 2)
    local cy = y + math.floor(cell / 2)
    local thick = math.max(4, math.floor(cell * 0.20))
    local half = math.floor(thick / 2)
    local r = connected and 0.34 or 0.18
    local g = connected and 0.72 or 0.38
    local b = connected and 0.46 or 0.38
    self:drawRect(cx - half, cy - half, thick, thick, 1, r, g, b)
    if hasPipe(tile.mask, 1) then self:drawRect(cx - half, y + 4, thick, cy - y - 4, 1, r, g, b) end
    if hasPipe(tile.mask, 2) then self:drawRect(cx, cy - half, x + cell - cx - 4, thick, 1, r, g, b) end
    if hasPipe(tile.mask, 4) then self:drawRect(cx - half, cy, thick, y + cell - cy - 4, 1, r, g, b) end
    if hasPipe(tile.mask, 8) then self:drawRect(x + 4, cy - half, cx - x - 4, thick, 1, r, g, b) end
end

function PZPipeLinkGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 224)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.06, 0.04)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.014, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.24, 0.42, 0.34)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.80, 0.78, 0.54, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": NEW GRID", boxX + 10, boxY + 58, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZPipeLinkGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZPipeLinkGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.018, 0.014)
    self:drawHud()
    local startX, startY, cell, gap, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.030, 0.038, 0.032)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.004, 0.008, 0.008)
    drawPipeBorder(self, startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.24, 0.42, 0.34)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.flash / 100, 0.34, 0.72, 0.42)
    end
    for y = 1, 5 do
        for x = 1, 5 do
            local px = startX + (x - 1) * (cell + gap)
            local py = startY + (y - 1) * (cell + gap)
            self:drawRect(px, py, cell, cell, 1, 0.016, 0.028, 0.026)
            drawPipeBorder(self, px, py, cell, cell, 0.7, 0.12, 0.24, 0.22)
            self:drawPipe(self.tiles[y][x], px, py, cell, self.gameState == "WIN")
        end
    end
    local selectedX = math.max(1, math.min(5, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(5, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cell + gap), startY + (selectedY - 1) * (cell + gap), cell, cell)
    self:drawRect(startX - 16, startY + 2 * (cell + gap) + math.floor(cell / 2) - 3, 14, 6, 1, 0.62, 0.82, 0.66)
    self:drawRect(startX + boardW + 2, startY + 2 * (cell + gap) + math.floor(cell / 2) - 3, 14, 6, 1, 0.62, 0.82, 0.66)
    if self.gameState == "WIN" then
        self:drawOverlay("LINK ESTABLISHED", "TURNS " .. tostring(self.moves))
    end
    self:drawScanlines()
end

function PZPipeLinkGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
