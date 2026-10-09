require "ISUI/ISPanel"

PZPongGame = ISPanel:derive("PZPongGame")

function PZPongGame:initialise()
    ISPanel.initialise(self)
    self:buildBackdrop()
    self:resetGame()
end

function PZPongGame:buildBackdrop()
    self.backdrop = {}
    for i = 1, 28 do
        self.backdrop[#self.backdrop + 1] = {
            x = ZombRand(1000) / 1000,
            y = ZombRand(1000) / 1000,
            s = 1 + ZombRand(3),
            a = 0.10 + (ZombRand(40) / 100)
        }
    end
end

function PZPongGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.flashTick = 0
    self.hitFlash = 0
    self.scorePulse = 0
    self.shake = 0
    self.ballTrail = {}
    self.particles = {}
    self.ball = {
        x = 0.5,
        y = 0.5,
        dx = (ZombRand(2) == 0 and -0.017 or 0.017),
        dy = (ZombRand(2) == 0 and -0.011 or 0.011),
        size = 0.026
    }
    self.paddle = {x = 0.045, y = 0.5 - 0.09, width = 0.016, height = 0.19, speed = 0.024}
    self.cpu = {x = 0.939, y = 0.5 - 0.09, width = 0.016, height = 0.19, speed = 0.0135, error = 0, delay = 0}
    self.score = 0
    self.cpuScore = 0
    self.targetScore = 7
end

function PZPongGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZPongGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZPongGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZPongGame:clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZPongGame:update()
    self.flashTick = self.flashTick + 1
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self.scorePulse = math.max(0, (self.scorePulse or 0) - 1)
    self.shake = math.max(0, (self.shake or 0) - 1)
    self:updateParticles()

    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "up") then
        self.paddle.y = self.paddle.y - self.paddle.speed
    elseif ComputerModGameInput.isDown(self, "down") then
        self.paddle.y = self.paddle.y + self.paddle.speed
    end

    self.paddle.y = self:clamp(self.paddle.y, 0.035, 1 - self.paddle.height - 0.035)
    self:gameTick()
end

function PZPongGame:resetBall(direction)
    self.ball.x = 0.5
    self.ball.y = 0.5
    self.ball.dx = direction or (self.ball.dx > 0 and -0.017 or 0.017)
    self.ball.dy = (ZombRand(2) == 0 and -0.011 or 0.011)
    self.ballTrail = {}
    self.cpu.error = (ZombRand(180) - 90) / 560
    self.cpu.delay = 4 + ZombRand(12)
end

function PZPongGame:updateCpu()
    if self.cpu.delay and self.cpu.delay > 0 then
        self.cpu.delay = self.cpu.delay - 1
        return
    end
    local ballCenterY = self.ball.y + self.ball.size * 0.5
    local cpuCenterY = self.cpu.y + self.cpu.height * 0.5
    local trackingTarget = ballCenterY + self.cpu.error
    local deadzone = 0.034

    if math.abs(cpuCenterY - trackingTarget) > deadzone then
        if cpuCenterY < trackingTarget then
            self.cpu.y = self.cpu.y + self.cpu.speed
        else
            self.cpu.y = self.cpu.y - self.cpu.speed
        end
    end

    if self.ball.dx < 0 then
        self.cpu.y = self.cpu.y + ((0.5 - self.cpu.height * 0.5) - self.cpu.y) * 0.010
    end

    self.cpu.y = self:clamp(self.cpu.y, 0.035, 1 - self.cpu.height - 0.035)
end

function PZPongGame:pushTrail()
    table.insert(self.ballTrail, 1, {x = self.ball.x, y = self.ball.y, s = self.ball.size})
    if #self.ballTrail > 12 then
        table.remove(self.ballTrail)
    end
end

function PZPongGame:emitParticles(x, y, r, g, b, count)
    for i = 1, count do
        local life = 16 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1200) - 600) / 42000,
            vy = (ZombRand(1200) - 600) / 42000,
            r = r,
            g = g,
            b = b,
            life = life,
            maxLife = life
        }
    end
end

function PZPongGame:updateParticles()
    if not self.particles then self.particles = {} end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.96
        p.vy = p.vy * 0.96
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZPongGame:paddleHit(paddle, playerSide)
    local center = self.ball.y + self.ball.size * 0.5
    local paddleCenter = paddle.y + paddle.height * 0.5
    local influence = (center - paddleCenter) / (paddle.height * 0.5)
    if playerSide then
        self.ball.x = paddle.x + paddle.width
        self.ball.dx = math.min(math.abs(self.ball.dx) + 0.0010, 0.032)
        self.ball.dy = self.ball.dy + influence * 0.010
        self:emitParticles(self.ball.x, self.ball.y + self.ball.size * 0.5, 0.38, 0.96, 1, 9)
    else
        self.ball.x = paddle.x - self.ball.size
        self.ball.dx = -math.min(math.abs(self.ball.dx) + 0.0008, 0.030)
        self.ball.dy = self.ball.dy + influence * 0.009
        self.cpu.error = (ZombRand(200) - 100) / 470
        self.cpu.delay = 4 + ZombRand(10)
        self:emitParticles(self.ball.x + self.ball.size, self.ball.y + self.ball.size * 0.5, 1, 0.36, 0.42, 8)
    end
    self.hitFlash = 8
    self:playSound("ComputerBallHit")
end

function PZPongGame:gameTick()
    self:updateCpu()
    self:pushTrail()

    if self.ball.y <= 0.025 then
        self.ball.y = 0.025
        self.ball.dy = math.abs(self.ball.dy)
        self:emitParticles(self.ball.x, self.ball.y, 0.52, 0.72, 1, 3)
    elseif self.ball.y + self.ball.size >= 0.975 then
        self.ball.y = 0.975 - self.ball.size
        self.ball.dy = -math.abs(self.ball.dy)
        self:emitParticles(self.ball.x, self.ball.y + self.ball.size, 0.52, 0.72, 1, 3)
    end

    if self.ball.x <= self.paddle.x + self.paddle.width and self.ball.x + self.ball.size >= self.paddle.x then
        if self.ball.y + self.ball.size >= self.paddle.y and self.ball.y <= self.paddle.y + self.paddle.height and self.ball.dx < 0 then
            self:paddleHit(self.paddle, true)
        end
    end

    if self.ball.x + self.ball.size >= self.cpu.x and self.ball.x <= self.cpu.x + self.cpu.width then
        if self.ball.y + self.ball.size >= self.cpu.y and self.ball.y <= self.cpu.y + self.cpu.height and self.ball.dx > 0 then
            self:paddleHit(self.cpu, false)
        end
    end

    self.ball.dy = self:clamp(self.ball.dy, -0.023, 0.023)
    self.ball.x = self.ball.x + self.ball.dx
    self.ball.y = self.ball.y + self.ball.dy

    if self.ball.x + self.ball.size < -0.02 then
        self.cpuScore = self.cpuScore + 1
        self.scorePulse = 18
        self.shake = 10
        self:playSound("ComputerBallHit")
        if self.cpuScore >= self.targetScore then
            self.gameState = "GAMEOVER"
            self:playGameOverSound()
        else
            self:resetBall(0.017)
        end
    elseif self.ball.x > 1.02 then
        self.score = self.score + 1
        self.scorePulse = 18
        self.shake = 6
        self:playSound("ComputerWinOpen")
        if self.score >= self.targetScore then
            self.gameState = "WIN"
            self:playWinSound()
        else
            self:resetBall(-0.017)
        end
    end
end

function PZPongGame:drawScaledRect(x, y, w, h, a, r, g, b)
    self:drawRect(x * self.width, y * self.height, w * self.width, h * self.height, a, r, g, b)
end

function PZPongGame:drawBackdrop()
    self:drawRect(0, 0, self.width, self.height, 1, 0.015, 0.025, 0.045)
    local bands = 14
    for i = 0, bands do
        local y = (i / bands) * self.height
        local alpha = 0.12 + (i / bands) * 0.08
        self:drawRect(0, y, self.width, math.max(2, self.height / bands), alpha, 0.03, 0.08 + i * 0.006, 0.13 + i * 0.008)
    end
    for i = 1, #self.backdrop do
        local star = self.backdrop[i]
        local twinkle = 0.65 + math.sin((self.flashTick + i * 9) / 18) * 0.35
        self:drawRect(star.x * self.width, star.y * self.height, star.s, star.s, star.a * twinkle, 0.44, 0.88, 1)
    end
    local horizon = self.height * 0.52
    self:drawRect(0, horizon - 1, self.width, 2, 0.55, 0.06, 0.42, 0.56)
    for i = 1, 8 do
        local y = horizon + i * i * 2.2
        if y < self.height then
            self:drawRect(0, y, self.width, 1, 0.22, 0.12, 0.72, 0.86)
        end
    end
    for i = -6, 6 do
        local x = self.width * 0.5 + i * self.width * 0.08
        self:drawRect(x, horizon, 1, self.height - horizon, 0.16, 0.12, 0.72, 0.86)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 0, self.width, self.height, self.hitFlash / 80, 0.42, 0.95, 1)
    end
end

function PZPongGame:drawCourt()
    local dashH = math.max(6, self.height * 0.045)
    local gapH = math.max(5, self.height * 0.030)
    local y = self.height * 0.08
    while y < self.height * 0.92 do
        self:drawRect(self.width * 0.5 - 1, y, 2, dashH, 0.34, 0.85, 0.96, 1)
        y = y + dashH + gapH
    end
    self:drawRect(self.width * 0.025, self.height * 0.035, self.width * 0.95, 2, 0.28, 0.26, 0.72, 0.9)
    self:drawRect(self.width * 0.025, self.height * 0.96, self.width * 0.95, 2, 0.28, 0.26, 0.72, 0.9)
    self:drawRect(self.width * 0.025, self.height * 0.035, 2, self.height * 0.93, 0.18, 0.26, 0.72, 0.9)
    self:drawRect(self.width * 0.973, self.height * 0.035, 2, self.height * 0.93, 0.18, 0.26, 0.72, 0.9)
end

function PZPongGame:drawTrail()
    for i = #self.ballTrail, 1, -1 do
        local entry = self.ballTrail[i]
        local alpha = 0.06 + (i / #self.ballTrail) * 0.16
        self:drawScaledRect(entry.x - 0.003, entry.y - 0.003, entry.s + 0.006, entry.s + 0.006, alpha, 0.25, 0.92, 1)
    end
end

function PZPongGame:drawParticles()
    local particles = self.particles or {}
    for i = 1, #particles do
        local p = particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        local px = p.x * self.width
        local py = p.y * self.height
        local size = math.max(2, math.floor(2 + alpha * 4))
        if px >= -size and px <= self.width + size and py >= -size and py <= self.height + size then
            self:drawRect(px, py, size, size, alpha * 0.85, p.r, p.g, p.b)
        end
    end
end

function PZPongGame:drawPaddleGlow(paddle, r, g, b)
    self:drawScaledRect(paddle.x - 0.007, paddle.y - 0.012, paddle.width + 0.014, paddle.height + 0.024, 0.18, r, g, b)
    self:drawScaledRect(paddle.x - 0.003, paddle.y - 0.005, paddle.width + 0.006, paddle.height + 0.010, 0.32, r, g, b)
    self:drawScaledRect(paddle.x, paddle.y, paddle.width, paddle.height, 1, r, g, b)
    self:drawScaledRect(paddle.x + paddle.width * 0.22, paddle.y + 0.012, paddle.width * 0.30, paddle.height - 0.024, 0.72, 1, 1, 1)
end

function PZPongGame:drawScorePanel()
    local pulse = self.scorePulse and self.scorePulse > 0 and self.scorePulse / 18 or 0
    local y = 8
    local leftX = self.width * 0.5 - 70
    local rightX = self.width * 0.5 + 20
    self:drawRect(leftX - pulse * 2, y - pulse, 54 + pulse * 4, 28 + pulse * 2, 0.64, 0.01, 0.04, 0.08)
    self:drawRect(rightX - pulse * 2, y - pulse, 54 + pulse * 4, 28 + pulse * 2, 0.64, 0.01, 0.04, 0.08)
    self:drawRect(leftX, y, 54, 2, 0.95, 0.4, 0.95, 1)
    self:drawRect(rightX, y, 54, 2, 0.95, 1, 0.38, 0.38)
    self:drawText(tostring(self.score), leftX + 21, y + 3, 0.78, 0.96, 1, 1, UIFont.Large)
    self:drawText(tostring(self.cpuScore), rightX + 21, y + 3, 1, 0.56, 0.48, 1, UIFont.Large)
    self:drawText("PLAYER", 12, 8, 0.56, 0.92, 1, 0.82, UIFont.Small)
    self:drawText("CPU", self.width - 38, 8, 1, 0.56, 0.48, 0.82, UIFont.Small)
end

function PZPongGame:drawBall()
    self:drawScaledRect(self.ball.x - 0.010, self.ball.y - 0.010, self.ball.size + 0.020, self.ball.size + 0.020, 0.16, 0.2, 1, 0.78)
    self:drawScaledRect(self.ball.x - 0.004, self.ball.y - 0.004, self.ball.size + 0.008, self.ball.size + 0.008, 0.42, 0.48, 1, 0.78)
    self:drawScaledRect(self.ball.x, self.ball.y, self.ball.size, self.ball.size, 1, 0.86, 1, 0.82)
    self:drawScaledRect(self.ball.x + self.ball.size * 0.18, self.ball.y + self.ball.size * 0.15, self.ball.size * 0.28, self.ball.size * 0.22, 0.86, 1, 1, 1)
end

function PZPongGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.07, 0, 0, 0)
        y = y + 4
    end
    self:drawRect(0, 0, self.width, 8, 0.25, 0, 0, 0)
    self:drawRect(0, self.height - 8, self.width, 8, 0.25, 0, 0, 0)
end

function PZPongGame:drawOverlay(title, detail, r, g, b)
    local boxW = math.min(self.width - 36, 248)
    local boxH = 112
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 4, boxY - 4, boxW + 8, boxH + 8, 0.25, r, g, b)
    self:drawRect(boxX, boxY, boxW, boxH, 0.92, 0.01, 0.02, 0.04)
    self:drawRect(boxX, boxY, boxW, 3, 1, r, g, b)
    self:drawText(title, boxX + 28, boxY + 22, r, g, b, 1, UIFont.Medium)
    self:drawText(detail, boxX + 44, boxY + 52, 0.9, 0.95, 1, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. " TO RESTART", boxX + 58, boxY + 78, 0.78, 0.9, 1, 1, UIFont.Small)
end

function PZPongGame:prerender()
    self:drawBackdrop()
    self:drawCourt()
    self:drawScorePanel()
    self:drawTrail()
    self:drawParticles()
    self:drawPaddleGlow(self.paddle, 0.40, 0.95, 1)
    self:drawPaddleGlow(self.cpu, 1, 0.34, 0.42)
    self:drawBall()

    if self.gameState == "WIN" then
        self:drawOverlay("VICTORY", "Score " .. tostring(self.score) .. " - " .. tostring(self.cpuScore), 0.34, 1, 0.58)
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("GAME OVER", "Score " .. tostring(self.score) .. " - " .. tostring(self.cpuScore), 1, 0.42, 0.34)
    end

    self:drawScanlines()
end

function PZPongGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
