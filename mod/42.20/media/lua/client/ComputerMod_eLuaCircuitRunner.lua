-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZCircuitRunnerGame = ISPanel:derive("PZCircuitRunnerGame")

local circuitMaps = {
    {
        "###############",
        "#P....#.....cE#",
        "#.###.#.#####.#",
        "#...#...#.....#",
        "###.#####.###.#",
        "#c..#.....#...#",
        "#.###.###.#.###",
        "#.....#...#..c#",
        "#.#####.###...#",
        "###############"
    },
    {
        "###############",
        "#P..#....#...E#",
        "#.#.#.##.#.#..#",
        "#.#...#..#.#c.#",
        "#.#####.##.####",
        "#.....#....#..#",
        "###.#.####.#.##",
        "#c..#......#c.#",
        "#.########....#",
        "###############"
    },
    {
        "###############",
        "#P....#...c..E#",
        "####..#.#####.#",
        "#.....#.....#.#",
        "#.#########.#.#",
        "#...c.....#...#",
        "#.#####.#.###.#",
        "#.....#.#...c.#",
        "###...#.#####.#",
        "###############"
    }
}

local droneDirections = {
    {x = 1, y = 0},
    {x = -1, y = 0},
    {x = 0, y = 1},
    {x = 0, y = -1}
}

function PZCircuitRunnerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZCircuitRunnerGame:isReservedDroneCell(x, y)
    if self.player and math.abs(self.player.x - x) + math.abs(self.player.y - y) < 5 then return true end
    if self.exit and self.exit.x == x and self.exit.y == y then return true end
    for i = 1, #self.chips do
        if self.chips[i].x == x and self.chips[i].y == y then return true end
    end
    return false
end

function PZCircuitRunnerGame:getOpenNeighborCount(x, y)
    local count = 0
    for i = 1, #droneDirections do
        local dir = droneDirections[i]
        if not self:isWall(x + dir.x, y + dir.y) then
            count = count + 1
        end
    end
    return count
end

function PZCircuitRunnerGame:getDroneSpawnCells()
    local cells = {}
    local backup = {}
    for y = 2, #self.grid - 1 do
        for x = 2, #self.grid[y] - 1 do
            if not self:isWall(x, y) and not self:isReservedDroneCell(x, y) then
                local cell = {x = x, y = y}
                backup[#backup + 1] = cell
                if self:getOpenNeighborCount(x, y) >= 2 then
                    cells[#cells + 1] = cell
                end
            end
        end
    end
    if #cells == 0 then
        return backup
    end
    return cells
end

function PZCircuitRunnerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.tick = 0
    self.chipFlash = 0
    self.deathFlash = 0
    self.moveCooldown = 0
    self.droneCooldown = 0
    self.score = 0
    self.mapIndex = ZombRand(#circuitMaps) + 1
    self.grid = {}
    self.chips = {}
    self.drones = {}
    local source = circuitMaps[self.mapIndex]
    for y = 1, #source do
        self.grid[y] = {}
        for x = 1, string.len(source[y]) do
            local ch = string.sub(source[y], x, x)
            if ch == "P" then
                self.player = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "E" then
                self.exit = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "c" then
                self.chips[#self.chips + 1] = {x = x, y = y, taken = false}
                self.grid[y][x] = "."
            else
                self.grid[y][x] = ch
            end
        end
    end
    self.totalChips = #self.chips
    local spawnCells = self:getDroneSpawnCells()
    local droneCount = math.min(3, #spawnCells)
    for i = 1, droneCount do
        local pick = ZombRand(#spawnCells) + 1
        local cell = table.remove(spawnCells, pick)
        local dir = droneDirections[ZombRand(#droneDirections) + 1]
        self.drones[#self.drones + 1] = {x = cell.x, y = cell.y, dx = dir.x, dy = dir.y, wait = i * 2}
    end
end

function PZCircuitRunnerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZCircuitRunnerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZCircuitRunnerGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZCircuitRunnerGame:isWall(x, y)
    return not self.grid[y] or self.grid[y][x] == "#"
end

function PZCircuitRunnerGame:chipsRemaining()
    local left = 0
    for i = 1, #self.chips do
        if not self.chips[i].taken then
            left = left + 1
        end
    end
    return left
end

function PZCircuitRunnerGame:tryMove(dx, dy)
    local nx = self.player.x + dx
    local ny = self.player.y + dy
    if self:isWall(nx, ny) then return end
    self.player.x = nx
    self.player.y = ny
    for i = 1, #self.chips do
        local chip = self.chips[i]
        if not chip.taken and chip.x == nx and chip.y == ny then
            chip.taken = true
            self.score = self.score + 100
            self.chipFlash = 8
            self:playSound("ComputerBallHit")
        end
    end
    if self.exit and self.exit.x == nx and self.exit.y == ny and self:chipsRemaining() == 0 then
        self.gameState = "WIN"
        self.score = self.score + 500
        self:playWinSound()
    end
    for i = 1, #self.drones do
        if self.drones[i].x == nx and self.drones[i].y == ny then
            self.gameState = "GAMEOVER"
            self.deathFlash = 14
            self:playGameOverSound()
            return
        end
    end
end

function PZCircuitRunnerGame:updateDrones()
    for i = 1, #self.drones do
        local drone = self.drones[i]
        drone.wait = math.max(0, (drone.wait or 0) - 1)
        if drone.wait <= 0 then
            local options = {}
            local forwardX = drone.x + (drone.dx or 0)
            local forwardY = drone.y + (drone.dy or 0)
            if not self:isWall(forwardX, forwardY) then
                options[#options + 1] = {x = drone.dx or 0, y = drone.dy or 0}
                options[#options + 1] = {x = drone.dx or 0, y = drone.dy or 0}
            end
            for d = 1, #droneDirections do
                local dir = droneDirections[d]
                if not self:isWall(drone.x + dir.x, drone.y + dir.y) and not (dir.x == -(drone.dx or 0) and dir.y == -(drone.dy or 0)) then
                    options[#options + 1] = dir
                end
            end
            if #options == 0 then
                for d = 1, #droneDirections do
                    local dir = droneDirections[d]
                    if not self:isWall(drone.x + dir.x, drone.y + dir.y) then
                        options[#options + 1] = dir
                    end
                end
            end
            if #options > 0 then
                local dir = options[ZombRand(#options) + 1]
                drone.dx = dir.x
                drone.dy = dir.y
                drone.x = drone.x + dir.x
                drone.y = drone.y + dir.y
            end
            drone.wait = 1
        end
        if drone.x == self.player.x and drone.y == self.player.y then
            self.gameState = "GAMEOVER"
            self.deathFlash = 14
            self:playGameOverSound()
        end
    end
end

function PZCircuitRunnerGame:update()
    self.tick = (self.tick or 0) + 1
    self.chipFlash = math.max(0, (self.chipFlash or 0) - 1)
    self.deathFlash = math.max(0, (self.deathFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    self.moveCooldown = math.max(0, (self.moveCooldown or 0) - 1)
    self.droneCooldown = math.max(0, (self.droneCooldown or 0) - 1)
    if self.moveCooldown <= 0 then
        if ComputerModGameInput.isDown(self, "left") then
            self:tryMove(-1, 0)
            self.moveCooldown = 8
        elseif ComputerModGameInput.isDown(self, "right") then
            self:tryMove(1, 0)
            self.moveCooldown = 8
        elseif ComputerModGameInput.isDown(self, "up") then
            self:tryMove(0, -1)
            self.moveCooldown = 8
        elseif ComputerModGameInput.isDown(self, "down") then
            self:tryMove(0, 1)
            self.moveCooldown = 8
        end
    end
    if self.droneCooldown <= 0 then
        self:updateDrones()
        self.droneCooldown = 14
    end
end

function PZCircuitRunnerGame:drawNode(cx, cy, size, r, g, b)
    self:drawRect(cx + size * 0.25, cy + size * 0.25, size * 0.5, size * 0.5, 1, r, g, b)
    self:drawRect(cx + size * 0.4, cy, size * 0.2, size, 0.45, r, g, b)
    self:drawRect(cx, cy + size * 0.4, size, size * 0.2, 0.45, r, g, b)
end

function PZCircuitRunnerGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.004, 0.014, 0.016)
    self:drawRect(0, 25, self.width, 1, 1, 0.18, 0.44, 0.40)
    self:drawText("CIRCUIT.EXE", 10, 7, 0.60, 0.84, 0.78, 1, UIFont.Small)
    self:drawText("CHIP " .. tostring(self.totalChips - self:chipsRemaining()) .. "/" .. tostring(self.totalChips), 112, 7, 0.60, 0.84, 0.78, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score or 0), self.width - 92, 7, 0.60, 0.84, 0.78, 1, UIFont.Small)
end

function PZCircuitRunnerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.03, 0.07, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.004, 0.014, 0.016)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.18, 0.44, 0.40)
    self:drawText(title, boxX + 10, boxY + 19, 0.60, 0.84, 0.78, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.60, 0.84, 0.78, 1, UIFont.Small)
end

function PZCircuitRunnerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZCircuitRunnerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.018, 0.020)
    self:drawHud()
    local cols = 15
    local rows = 10
    local cell = math.floor(math.min((self.width - 32) / cols, (self.height - 54) / rows))
    local gridW = cell * cols
    local gridH = cell * rows
    local ox = math.floor((self.width - gridW) * 0.5)
    local oy = 38
    self:drawRect(ox - 4, oy - 4, gridW + 8, gridH + 8, 1, 0.02, 0.18, 0.16)
    self:drawRect(ox, oy, gridW, gridH, 1, 0.004, 0.036, 0.036)
    if self.chipFlash and self.chipFlash > 0 then
        self:drawRect(ox, oy, gridW, gridH, self.chipFlash / 100, 0.58, 0.54, 0.18)
    end
    if self.deathFlash and self.deathFlash > 0 then
        self:drawRect(ox, oy, gridW, gridH, self.deathFlash / 90, 0.82, 0.08, 0.06)
    end
    for y = 1, rows do
        for x = 1, cols do
            local px = ox + (x - 1) * cell
            local py = oy + (y - 1) * cell
            if self.grid[y] and self.grid[y][x] == "#" then
                self:drawRect(px + 1, py + 1, cell - 2, cell - 2, 1, 0.035, 0.24, 0.22)
                self:drawRect(px + 2, py + 2, cell - 4, 2, 0.45, 0.20, 0.66, 0.56)
            else
                self:drawRect(px, py, cell, 1, 0.10, 0.12, 0.50, 0.46)
                self:drawRect(px, py, 1, cell, 0.10, 0.12, 0.50, 0.46)
            end
        end
    end
    local exitColor = self:chipsRemaining() == 0 and {0.28, 1, 0.48} or {0.35, 0.35, 0.35}
    if self.exit then
        self:drawRect(ox + (self.exit.x - 1) * cell + 3, oy + (self.exit.y - 1) * cell + 3, cell - 6, cell - 6, 1, exitColor[1], exitColor[2], exitColor[3])
        self:drawRect(ox + (self.exit.x - 1) * cell + 6, oy + (self.exit.y - 1) * cell + 6, cell - 12, cell - 12, 0.40, 0.01, 0.02, 0.02)
    end
    for i = 1, #self.chips do
        local chip = self.chips[i]
        if not chip.taken then
            self:drawNode(ox + (chip.x - 1) * cell + 4, oy + (chip.y - 1) * cell + 4, cell - 8, 0.96, 0.86, 0.18)
        end
    end
    for i = 1, #self.drones do
        local drone = self.drones[i]
        local px = ox + (drone.x - 1) * cell
        local py = oy + (drone.y - 1) * cell
        self:drawRect(px + 5, py + 5, cell - 10, cell - 10, 1, 0.78, 0.10, 0.10)
        self:drawRect(px + 8, py + 8, cell - 16, cell - 16, 1, 0.96, 0.52, 0.18)
        self:drawRect(px + math.floor(cell * 0.44), py + 3, 2, cell - 6, 0.40, 0.96, 0.52, 0.18)
    end
    local pX = ox + (self.player.x - 1) * cell
    local pY = oy + (self.player.y - 1) * cell
    self:drawRect(pX + 4, pY + 4, cell - 8, cell - 8, 1, 0.14, 0.46, 0.82)
    self:drawRect(pX + 8, pY + 8, cell - 16, cell - 16, 1, 0.56, 0.78, 0.90)
    if self.gameState == "WIN" then
        self:drawOverlay("SYSTEM CLEAR", "SCORE " .. tostring(self.score or 0))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("SHORT CIRCUIT", "CHIP " .. tostring(self.totalChips - self:chipsRemaining()) .. "/" .. tostring(self.totalChips))
    end
    self:drawScanlines()
end

function PZCircuitRunnerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
