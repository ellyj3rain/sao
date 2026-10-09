require "ISUI/ISPanel"

PZBoxPushGame = ISPanel:derive("PZBoxPushGame")

local boxPushMaps = {
    {
        "##########",
        "#........#",
        "#..B.G...#",
        "#..P.....#",
        "#..B.G...#",
        "#........#",
        "##########"
    },
    {
        "###########",
        "#.........#",
        "#..G.B....#",
        "#..##.##..#",
        "#....P....#",
        "#..##.##..#",
        "#....B.G..#",
        "#.........#",
        "###########"
    },
    {
        "###########",
        "#.........#",
        "#..G.B....#",
        "#.........#",
        "#....P....#",
        "#.........#",
        "#....B.G..#",
        "#.........#",
        "###########"
    }
}

local function drawBoxBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZBoxPushGame:initialise()
    ISPanel.initialise(self)
    self.nextMapIndex = 1
    self:resetGame()
end

function PZBoxPushGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.steps = 0
    self.pushes = 0
    self.moveCooldown = 0
    self.level = self.nextMapIndex or 1
    self.nextMapIndex = (self.level % #boxPushMaps) + 1
    self.grid = {}
    self.boxes = {}
    self.goals = {}
    local source = boxPushMaps[self.level]
    self.rows = #source
    self.cols = string.len(source[1])
    for y = 1, #source do
        self.grid[y] = {}
        for x = 1, string.len(source[y]) do
            local ch = string.sub(source[y], x, x)
            if ch == "P" then
                self.player = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "B" then
                self.boxes[#self.boxes + 1] = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "G" then
                self.goals[#self.goals + 1] = {x = x, y = y}
                self.grid[y][x] = "."
            else
                self.grid[y][x] = ch
            end
        end
    end
end

function PZBoxPushGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZBoxPushGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZBoxPushGame:isWall(x, y)
    return not self.grid[y] or self.grid[y][x] == "#"
end

function PZBoxPushGame:getBoxAt(x, y)
    for i = 1, #self.boxes do
        if self.boxes[i].x == x and self.boxes[i].y == y then
            return i
        end
    end
    return nil
end

function PZBoxPushGame:isGoal(x, y)
    for i = 1, #self.goals do
        if self.goals[i].x == x and self.goals[i].y == y then
            return true
        end
    end
    return false
end

function PZBoxPushGame:isBoxOnGoal(box)
    return box and self:isGoal(box.x, box.y)
end

function PZBoxPushGame:isSolved()
    for i = 1, #self.boxes do
        if not self:isBoxOnGoal(self.boxes[i]) then
            return false
        end
    end
    return true
end

function PZBoxPushGame:tryMove(dx, dy)
    if self.gameState ~= "PLAYING" then return end
    local nx = self.player.x + dx
    local ny = self.player.y + dy
    if self:isWall(nx, ny) then return end
    local boxIndex = self:getBoxAt(nx, ny)
    if boxIndex then
        local bx = nx + dx
        local by = ny + dy
        if self:isWall(bx, by) or self:getBoxAt(bx, by) then return end
        self.boxes[boxIndex].x = bx
        self.boxes[boxIndex].y = by
        self.pushes = self.pushes + 1
        self:playSound("ComputerBallHit")
    end
    self.player.x = nx
    self.player.y = ny
    self.steps = self.steps + 1
    if self:isSolved() then
        self.gameState = "WIN"
        self:playWinSound()
    end
end

function PZBoxPushGame:getBoardLayout()
    local usableW = math.max(1, self.width - 42)
    local usableH = math.max(1, self.height - 76)
    local cell = math.floor(math.min(usableW / self.cols, usableH / self.rows))
    cell = math.max(10, cell)
    local boardW = cell * self.cols
    local boardH = cell * self.rows
    local x = math.floor((self.width - boardW) / 2)
    local y = 40 + math.floor((usableH - boardH) / 2)
    return x, y, cell, boardW, boardH
end

function PZBoxPushGame:update()
    self.tick = (self.tick or 0) + 1
    self.moveCooldown = math.max(0, (self.moveCooldown or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    if self.moveCooldown > 0 then return end
    local dx = 0
    local dy = 0
    if ComputerModGameInput.isDown(self, "left") or ComputerModGameInput.isDown(self, "strafeLeft") then
        dx = -1
    elseif ComputerModGameInput.isDown(self, "right") or ComputerModGameInput.isDown(self, "strafeRight") then
        dx = 1
    elseif ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then
        dy = -1
    elseif ComputerModGameInput.isDown(self, "down") or ComputerModGameInput.isDown(self, "backward") then
        dy = 1
    end
    if dx ~= 0 or dy ~= 0 then
        self:tryMove(dx, dy)
        self.moveCooldown = 10
    end
end

function PZBoxPushGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.012, 0.012, 0.014)
    self:drawRect(0, 25, self.width, 1, 1, 0.38, 0.34, 0.24)
    self:drawText("BOXPUSH.EXE", 10, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("LVL " .. tostring(self.level), 116, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("STEP " .. tostring(self.steps), 174, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("PUSH " .. tostring(self.pushes), self.width - 82, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
end

function PZBoxPushGame:drawCell(x, y, cell, gx, gy)
    local px = x + (gx - 1) * cell
    local py = y + (gy - 1) * cell
    local ch = self.grid[gy] and self.grid[gy][gx] or "#"
    if ch == "#" then
        self:drawRect(px, py, cell, cell, 1, 0.16, 0.16, 0.15)
        drawBoxBorder(self, px, py, cell, cell, 1, 0.36, 0.34, 0.26)
        if cell > 15 then
            self:drawRect(px + 3, py + 3, math.max(1, cell - 6), 1, 0.25, 0.56, 0.52, 0.36)
        end
    else
        self:drawRect(px, py, cell, cell, 1, 0.026, 0.024, 0.022)
        drawBoxBorder(self, px, py, cell, cell, 0.45, 0.10, 0.09, 0.08)
        if self:isGoal(gx, gy) then
            local inset = math.max(4, math.floor(cell * 0.24))
            self:drawRect(px + inset, py + inset, cell - inset * 2, cell - inset * 2, 1, 0.16, 0.42, 0.24)
            drawBoxBorder(self, px + inset, py + inset, cell - inset * 2, cell - inset * 2, 1, 0.42, 0.72, 0.42)
        end
    end
end

function PZBoxPushGame:drawBox(x, y, cell, onGoal)
    local inset = math.max(2, math.floor(cell * 0.12))
    if onGoal then
        self:drawRect(x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.22, 0.52, 0.28)
        drawBoxBorder(self, x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.60, 0.86, 0.52)
    else
        self:drawRect(x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.58, 0.42, 0.20)
        drawBoxBorder(self, x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.88, 0.68, 0.32)
    end
    if cell > 16 then
        self:drawRect(x + inset + 3, y + inset + 3, math.max(1, cell - inset * 2 - 6), 2, 0.36, 0.98, 0.86, 0.55)
    end
end

function PZBoxPushGame:drawPlayer(x, y, cell)
    local inset = math.max(3, math.floor(cell * 0.18))
    self:drawRect(x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.18, 0.54, 0.62)
    drawBoxBorder(self, x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.62, 0.88, 0.92)
    if cell > 14 then
        self:drawRect(x + math.floor(cell * 0.5) - 2, y + inset + 3, 4, 4, 1, 0.90, 0.95, 0.82)
    end
end

function PZBoxPushGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.04, 0.03)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.012, 0.012, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.38, 0.34, 0.24)
    self:drawText(title, boxX + 10, boxY + 19, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.64, 0.86, 0.62, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": NEXT MAP", boxX + 10, boxY + 58, 0.84, 0.78, 0.58, 1, UIFont.Small)
end

function PZBoxPushGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZBoxPushGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.010, 0.010, 0.012)
    self:drawHud()
    local startX, startY, cell, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 8, startY - 8, boardW + 16, boardH + 16, 1, 0.04, 0.036, 0.030)
    self:drawRect(startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.006, 0.006, 0.008)
    drawBoxBorder(self, startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.38, 0.34, 0.24)
    for gy = 1, self.rows do
        for gx = 1, self.cols do
            self:drawCell(startX, startY, cell, gx, gy)
        end
    end
    for i = 1, #self.boxes do
        local box = self.boxes[i]
        self:drawBox(startX + (box.x - 1) * cell, startY + (box.y - 1) * cell, cell, self:isBoxOnGoal(box))
    end
    if self.player then
        self:drawPlayer(startX + (self.player.x - 1) * cell, startY + (self.player.y - 1) * cell, cell)
    end
    if self.gameState == "WIN" then
        self:drawOverlay("WAREHOUSE CLEAR", "PUSHES " .. tostring(self.pushes))
    end
    self:drawScanlines()
end

function PZBoxPushGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
