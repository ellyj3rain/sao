require "ISUI/ISPanel"

PZBreakoutGame = ISPanel:derive("PZBreakoutGame")

function PZBreakoutGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZBreakoutGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.hitSoundLock = false
    self.flashTick = 0
    self.hitFlash = 0
    self.paddle = {x = self.width * 0.5 - 38, y = self.height - 24, w = 76, h = 8, speed = 7}
    self.ball = {x = self.width * 0.5, y = self.height - 40, dx = 2.9, dy = -3.0, r = 4}
    self.score = 0
    self.rows = 5
    self.cols = 8
    self.ballTrail = {}
    self.bricks = {}
    local brickW = math.floor((self.width - 28) / self.cols)
    for row = 1, self.rows do
        for col = 1, self.cols do
            self.bricks[#self.bricks + 1] = {
                x = 14 + (col - 1) * brickW,
                y = 24 + (row - 1) * 16,
                w = brickW - 4,
                h = 12,
                alive = true,
                tone = row
            }
        end
    end
end

function PZBreakoutGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZBreakoutGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZBreakoutGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZBreakoutGame:pushTrail()
    table.insert(self.ballTrail, 1, {x = self.ball.x, y = self.ball.y})
    if #self.ballTrail > 7 then
        table.remove(self.ballTrail)
    end
end

function PZBreakoutGame:update()
    self.flashTick = ((self.flashTick or 0) + 1) % 240
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.paddle.x = math.max(8, self.paddle.x - self.paddle.speed)
    elseif ComputerModGameInput.isDown(self, "right") then
        self.paddle.x = math.min(self.width - self.paddle.w - 8, self.paddle.x + self.paddle.speed)
    end

    self:pushTrail()
    self.ball.x = self.ball.x + self.ball.dx
    self.ball.y = self.ball.y + self.ball.dy

    if self.ball.x <= 8 then
        self.ball.x = 8
        self.ball.dx = math.abs(self.ball.dx)
    elseif self.ball.x >= self.width - 8 then
        self.ball.x = self.width - 8
        self.ball.dx = -math.abs(self.ball.dx)
    end

    if self.ball.y <= 18 then
        self.ball.y = 18
        self.ball.dy = math.abs(self.ball.dy)
    end

    if self.ball.y >= self.height then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
        return
    end

    if self.ball.y + self.ball.r >= self.paddle.y and self.ball.y <= self.paddle.y + self.paddle.h and self.ball.x >= self.paddle.x and self.ball.x <= self.paddle.x + self.paddle.w then
        self.ball.y = self.paddle.y - self.ball.r
        self.ball.dy = -math.abs(self.ball.dy)
        local offset = (self.ball.x - (self.paddle.x + self.paddle.w * 0.5)) / (self.paddle.w * 0.5)
        self.ball.dx = offset * 4.2
        self.hitFlash = 5
        self:playSound("ComputerBallHit")
    end

    local aliveCount = 0
    for i = 1, #self.bricks do
        local brick = self.bricks[i]
        if brick.alive then
            aliveCount = aliveCount + 1
            if self.ball.x + self.ball.r >= brick.x and self.ball.x - self.ball.r <= brick.x + brick.w and self.ball.y + self.ball.r >= brick.y and self.ball.y - self.ball.r <= brick.y + brick.h then
                brick.alive = false
                self.ball.dy = -self.ball.dy
                self.score = self.score + 10
                aliveCount = aliveCount - 1
                self.hitFlash = 6
                self:playSound("ComputerBallHit")
                break
            end
        end
    end

    if aliveCount == 0 then
        self.gameState = "WIN"
        self:playWinSound()
    end
end

function PZBreakoutGame:drawHud()
    self:drawRect(0, 0, self.width, 24, 1, 0.010, 0.010, 0.018)
    self:drawRect(0, 23, self.width, 1, 1, 0.34, 0.30, 0.46)
    self:drawText("BREAKOUT.EXE", 10, 7, 0.72, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 128, 7, 0.72, 0.68, 0.86, 1, UIFont.Small)
    local bricksLeft = 0
    for i = 1, #self.bricks do
        if self.bricks[i].alive then bricksLeft = bricksLeft + 1 end
    end
    self:drawText("BRICKS " .. tostring(bricksLeft), self.width - 82, 7, 0.72, 0.68, 0.86, 1, UIFont.Small)
end

function PZBreakoutGame:drawBrick(brick)
    local colors = {
        {0.46, 0.22, 0.62},
        {0.34, 0.26, 0.68},
        {0.22, 0.34, 0.66},
        {0.22, 0.48, 0.50},
        {0.54, 0.44, 0.22}
    }
    local c = colors[brick.tone] or colors[1]
    self:drawRect(brick.x + 1, brick.y + 2, brick.w, brick.h, 0.26, 0, 0, 0)
    self:drawRect(brick.x, brick.y, brick.w, brick.h, 1, c[1], c[2], c[3])
    self:drawRect(brick.x, brick.y, brick.w, 2, 1, math.min(1, c[1] + 0.24), math.min(1, c[2] + 0.24), math.min(1, c[3] + 0.24))
    self:drawRect(brick.x, brick.y + brick.h - 2, brick.w, 2, 1, c[1] * 0.55, c[2] * 0.55, c[3] * 0.55)
    self:drawRect(brick.x + 3, brick.y + 4, math.max(2, brick.w - 6), 1, 0.20, 1, 1, 1)
end

function PZBreakoutGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 210)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.04, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.010, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.34, 0.30, 0.46)
    self:drawText(title, boxX + 10, boxY + 19, 0.72, 0.68, 0.86, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.60, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.72, 0.68, 0.86, 1, UIFont.Small)
end

function PZBreakoutGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZBreakoutGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.014, 0.014, 0.024)
    for band = 0, 10 do
        local y = band * self.height / 10
        self:drawRect(0, y, self.width, math.max(2, self.height / 18), 0.08, 0.12, 0.10, 0.18)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 24, self.width, self.height - 24, self.hitFlash / 90, 0.58, 0.48, 0.78)
    end
    self:drawHud()

    for i = #self.ballTrail, 1, -1 do
        local trail = self.ballTrail[i]
        local alpha = 0.04 + ((#self.ballTrail - i) * 0.028)
        self:drawRect(trail.x - self.ball.r, trail.y - self.ball.r, self.ball.r * 2, self.ball.r * 2, alpha, 0.78, 0.72, 0.42)
    end

    for i = 1, #self.bricks do
        local brick = self.bricks[i]
        if brick.alive then
            self:drawBrick(brick)
        end
    end

    self:drawRect(self.paddle.x + 1, self.paddle.y + 2, self.paddle.w, self.paddle.h, 0.35, 0, 0, 0)
    self:drawRect(self.paddle.x, self.paddle.y, self.paddle.w, self.paddle.h, 1, 0.62, 0.62, 0.68)
    self:drawRect(self.paddle.x + 6, self.paddle.y + 2, self.paddle.w - 12, 2, 1, 0.88, 0.88, 0.84)
    self:drawRect(self.ball.x - self.ball.r - 1, self.ball.y - self.ball.r - 1, self.ball.r * 2 + 2, self.ball.r * 2 + 2, 0.18, 1, 1, 1)
    self:drawRect(self.ball.x - self.ball.r, self.ball.y - self.ball.r, self.ball.r * 2, self.ball.r * 2, 1, 0.86, 0.80, 0.42)

    if self.gameState == "WIN" then
        self:drawOverlay("BREAKOUT CLEARED", "SCORE " .. tostring(self.score))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("BALL LOST", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZBreakoutGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
