-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZSnakeGame = ISPanel:derive("PZSnakeGame")

function PZSnakeGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:resetGame()
end

function PZSnakeGame:layoutBoard()
    self.cols = 28
    self.rows = 18
    local topSpace = math.max(32, math.floor(self.height * 0.12))
    local bottomSpace = 14
    local usableW = math.max(1, self.width - 28)
    local usableH = math.max(1, self.height - topSpace - bottomSpace)
    self.gridSize = math.max(4, math.floor(math.min(usableW / self.cols, usableH / self.rows)))
    self.boardW = self.gridSize * self.cols
    self.boardH = self.gridSize * self.rows
    self.boardX = math.floor((self.width - self.boardW) / 2)
    self.boardY = topSpace + math.floor((usableH - self.boardH) / 2)
    self.layoutW = self.width
    self.layoutH = self.height
end

function PZSnakeGame:resetGame()
    self:layoutBoard()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.gridGlow = 0
    self.foodPulse = 0
    self.turnPulse = 0
    self.particles = {}
    self.snake = {}
    local startX = math.floor(self.cols / 2)
    local startY = math.floor(self.rows / 2)
    table.insert(self.snake, {x = startX, y = startY})
    table.insert(self.snake, {x = startX - 1, y = startY})
    table.insert(self.snake, {x = startX - 2, y = startY})
    table.insert(self.snake, {x = startX - 3, y = startY})
    self.dx = 1
    self.dy = 0
    self.nextDx = 1
    self.nextDy = 0
    self.inputRegistered = false
    self.food = {x = 0, y = 0}
    self.score = 0
    self.tickCounter = 0
    self.speed = 4.2
    self:spawnFood()
end

function PZSnakeGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZSnakeGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZSnakeGame:spawnFood()
    local tries = 0
    local valid = false
    while not valid and tries < 800 do
        tries = tries + 1
        self.food.x = ZombRand(self.cols)
        self.food.y = ZombRand(self.rows)
        valid = true
        for i = 1, #self.snake do
            if self.snake[i].x == self.food.x and self.snake[i].y == self.food.y then
                valid = false
                break
            end
        end
    end
end

function PZSnakeGame:update()
    self.foodPulse = (self.foodPulse + 1) % 80
    self.gridGlow = (self.gridGlow + 1) % 120
    self.turnPulse = math.max(0, (self.turnPulse or 0) - 1)
    self:updateParticles()

    if self.gameState == "GAMEOVER" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if not self.inputRegistered then
        if ComputerModGameInput.isDown(self, "up") and self.dy == 0 then
            self.nextDx = 0
            self.nextDy = -1
            self.inputRegistered = true
            self.turnPulse = 8
        elseif ComputerModGameInput.isDown(self, "down") and self.dy == 0 then
            self.nextDx = 0
            self.nextDy = 1
            self.inputRegistered = true
            self.turnPulse = 8
        elseif ComputerModGameInput.isDown(self, "left") and self.dx == 0 then
            self.nextDx = -1
            self.nextDy = 0
            self.inputRegistered = true
            self.turnPulse = 8
        elseif ComputerModGameInput.isDown(self, "right") and self.dx == 0 then
            self.nextDx = 1
            self.nextDy = 0
            self.inputRegistered = true
            self.turnPulse = 8
        end
    end

    self.tickCounter = self.tickCounter + 1
    if self.tickCounter >= self.speed then
        self.tickCounter = 0
        self:gameTick()
    end
end

function PZSnakeGame:gameTick()
    self.dx = self.nextDx
    self.dy = self.nextDy
    self.inputRegistered = false

    local head = self.snake[1]
    local newX = head.x + self.dx
    local newY = head.y + self.dy

    if newX < 0 or newX >= self.cols or newY < 0 or newY >= self.rows then
        self:gameOver()
        return
    end

    for i = 1, #self.snake do
        if newX == self.snake[i].x and newY == self.snake[i].y then
            self:gameOver()
            return
        end
    end

    table.insert(self.snake, 1, {x = newX, y = newY})

    if newX == self.food.x and newY == self.food.y then
        self.score = self.score + 10
        self.speed = math.max(2.1, self.speed - 0.10)
        self:emitFoodParticles(newX, newY)
        self:playSound("ComputerBallHit")
        self:spawnFood()
    else
        table.remove(self.snake)
    end
end

function PZSnakeGame:gameOver()
    self.gameState = "GAMEOVER"
    if self.score > self.highscore then
        self.highscore = self.score
    end
    self:emitFoodParticles(self.snake[1].x, self.snake[1].y)
    self:playGameOverSound()
end

function PZSnakeGame:emitFoodParticles(cellX, cellY)
    for i = 1, 18 do
        local life = 18 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = cellX + 0.5,
            y = cellY + 0.5,
            vx = (ZombRand(1000) - 500) / 1800,
            vy = (ZombRand(1000) - 500) / 1800,
            life = life,
            maxLife = life,
            c = 1 + ZombRand(3)
        }
    end
end

function PZSnakeGame:updateParticles()
    if not self.particles then self.particles = {} end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.92
        p.vy = p.vy * 0.92
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZSnakeGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.012, 0.028, 0.018)
    for i = 0, 14 do
        local y = i * self.height / 14
        self:drawRect(0, y, self.width, math.max(2, self.height / 16), 0.18, 0.02, 0.06 + i * 0.004, 0.035)
    end
    local glow = 0.05 + math.sin(self.gridGlow / 18) * 0.025
    self:drawRect(self.boardX - 8, self.boardY - 8, self.boardW + 16, self.boardH + 16, 0.22 + glow, 0.14, 0.9, 0.34)
    self:drawRect(self.boardX - 5, self.boardY - 5, self.boardW + 10, self.boardH + 10, 1, 0.015, 0.07, 0.035)
end

function PZSnakeGame:drawHud()
    local speedText = "LVL " .. tostring(math.max(1, math.floor((4.4 - self.speed) * 4) + 1))
    self:drawRect(0, 0, self.width, 24, 1, 0.006, 0.020, 0.010)
    self:drawRect(0, 23, self.width, 1, 1, 0.18, 0.42, 0.22)
    self:drawText("SNAKE.EXE", 10, 7, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("SCORE:" .. tostring(self.score), 96, 7, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("BEST:" .. tostring(self.highscore), 188, 7, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText(speedText, self.width - 54, 7, 0.80, 0.78, 0.48, 1, UIFont.Small)
end

function PZSnakeGame:drawBoard()
    self:drawRect(self.boardX, self.boardY, self.boardW, self.boardH, 1, 0.035, 0.11, 0.045)
    for y = 0, self.rows - 1 do
        for x = 0, self.cols - 1 do
            local shade = ((x + y) % 2 == 0) and 0.050 or 0.038
            local px = self.boardX + x * self.gridSize
            local py = self.boardY + y * self.gridSize
            self:drawRect(px, py, self.gridSize - 1, self.gridSize - 1, 1, 0.025, shade + 0.065, 0.035)
            if self.gridSize >= 12 then
                self:drawRect(px, py, self.gridSize - 1, 1, 0.18, 0.14, 0.35, 0.14)
            end
        end
    end
    self:drawRect(self.boardX - 2, self.boardY - 2, self.boardW + 4, 2, 1, 0.18, 0.72, 0.28)
    self:drawRect(self.boardX - 2, self.boardY + self.boardH, self.boardW + 4, 2, 1, 0.05, 0.28, 0.12)
    self:drawRect(self.boardX - 2, self.boardY - 2, 2, self.boardH + 4, 1, 0.18, 0.72, 0.28)
    self:drawRect(self.boardX + self.boardW, self.boardY - 2, 2, self.boardH + 4, 1, 0.05, 0.28, 0.12)
end

function PZSnakeGame:cellRect(cell)
    return self.boardX + cell.x * self.gridSize, self.boardY + cell.y * self.gridSize, self.gridSize
end

function PZSnakeGame:drawSnakeCell(cell, index)
    local px, py, size = self:cellRect(cell)
    local inset = math.max(1, math.floor(size * 0.12))
    local core = math.max(2, size - inset * 2)
    local fade = math.max(0.34, 1 - index * 0.026)
    local pulse = index == 1 and (self.turnPulse or 0) / 42 or 0

    self:drawRect(px + inset - 1, py + inset + 1, core + 2, core + 2, 0.24, 0, 0, 0)
    if index == 1 then
        self:drawRect(px + inset - 2, py + inset - 2, core + 4, core + 4, 0.25 + pulse, 0.34, 1, 0.48)
        self:drawRect(px + inset, py + inset, core, core, 1, 0.32, 0.96, 0.38)
        self:drawRect(px + inset + 2, py + inset + 2, math.max(2, core - 4), math.max(2, math.floor(core * 0.34)), 0.50, 0.84, 1, 0.66)
        local eyeSize = math.max(2, math.floor(size * 0.13))
        local eyeY = py + inset + math.max(2, math.floor(core * 0.24))
        if self.dx ~= 0 then
            local leftEye = self.dx > 0 and px + inset + core - eyeSize * 3 or px + inset + eyeSize
            self:drawRect(leftEye, eyeY, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
            self:drawRect(leftEye, eyeY + eyeSize * 2, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
        else
            local eyeX = px + inset + math.max(2, math.floor(core * 0.25))
            local eyeX2 = px + inset + core - eyeSize - math.max(2, math.floor(core * 0.25))
            local finalY = self.dy > 0 and py + inset + core - eyeSize * 2 or eyeY
            self:drawRect(eyeX, finalY, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
            self:drawRect(eyeX2, finalY, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
        end
    else
        self:drawRect(px + inset, py + inset, core, core, 1, 0.08, 0.34 + fade * 0.40, 0.12)
        self:drawRect(px + inset + 2, py + inset + 2, math.max(2, core - 4), math.max(2, core - 4), 0.48, 0.16, 0.72 + fade * 0.18, 0.22)
    end
end

function PZSnakeGame:drawFood()
    local pulse = 0.45 + math.sin(self.foodPulse / 8) * 0.18
    local px = self.boardX + self.food.x * self.gridSize
    local py = self.boardY + self.food.y * self.gridSize
    local size = self.gridSize
    local inset = math.max(2, math.floor(size * (0.18 - pulse * 0.04)))
    self:drawRect(px + inset - 2, py + inset - 2, size - inset * 2 + 4, size - inset * 2 + 4, 0.22 + pulse * 0.12, 1, 0.28, 0.18)
    self:drawRect(px + inset, py + inset, size - inset * 2, size - inset * 2, 1, 0.92, 0.08, 0.08)
    self:drawRect(px + math.floor(size * 0.46), py + math.floor(size * 0.14), math.max(2, math.floor(size * 0.14)), math.max(2, math.floor(size * 0.20)), 1, 0.12, 0.42, 0.08)
    self:drawRect(px + inset + 2, py + inset + 2, math.max(2, math.floor(size * 0.25)), math.max(2, math.floor(size * 0.18)), 0.8, 1, 0.78, 0.38)
end

function PZSnakeGame:drawParticles()
    local particles = self.particles or {}
    for i = 1, #particles do
        local p = particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        local px = self.boardX + p.x * self.gridSize
        local py = self.boardY + p.y * self.gridSize
        local s = math.max(2, math.floor(self.gridSize * 0.16 * alpha + 1))
        local r, g, b = 0.96, 0.9, 0.2
        if p.c == 2 then r, g, b = 0.40, 1, 0.52 end
        if p.c == 3 then r, g, b = 0.34, 0.90, 1 end
        self:drawRect(px, py, s, s, alpha, r, g, b)
    end
end

function PZSnakeGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.06, 0, 0, 0)
        y = y + 4
    end
end

function PZSnakeGame:drawGameOver()
    local boxW = math.min(self.boardW - 28, 238)
    local boxH = 104
    local boxX = math.floor(self.boardX + (self.boardW - boxW) / 2)
    local boxY = math.floor(self.boardY + (self.boardH - boxH) / 2)
    if boxW < 190 then
        boxW = math.min(self.width - 28, 190)
        boxX = math.floor((self.width - boxW) / 2)
    end

    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.06, 0.10, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.004, 0.018, 0.008)
    self:drawRect(boxX + 4, boxY + 4, boxW - 8, 1, 1, 0.24, 0.46, 0.24)
    self:drawRect(boxX + 4, boxY + boxH - 5, boxW - 8, 1, 1, 0.24, 0.46, 0.24)
    self:drawText("SNAKE.EXE STOPPED", boxX + 10, boxY + 18, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), boxX + 10, boxY + 44, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("BEST  " .. tostring(self.highscore), boxX + 10, boxY + 60, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RUN AGAIN", boxX + 10, boxY + 82, 0.80, 0.78, 0.48, 1, UIFont.Small)
end

function PZSnakeGame:prerender()
    if self.layoutW ~= self.width or self.layoutH ~= self.height then
        self:layoutBoard()
    end

    self:drawBackground()
    self:drawHud()
    self:drawBoard()

    if self.gameState == "PLAYING" then
        self:drawFood()
    end

    for i = #self.snake, 1, -1 do
        self:drawSnakeCell(self.snake[i], i)
    end

    self:drawParticles()

    if self.gameState == "GAMEOVER" then
        self:drawGameOver()
    end

    self:drawScanlines()
end

function PZSnakeGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
