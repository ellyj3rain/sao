-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZFlappyGame = ISPanel:derive("PZFlappyGame")

function PZFlappyGame:initialise()
    ISPanel.initialise(self)
    self.bestScore = 0
    self:resetGame()
end

function PZFlappyGame:resetGame()
    self.gameState = "READY"
    self.gameOverSoundPlayed = false
    self.tick = 0
    self.score = 0
    self.bird = {
        x = math.floor(self.width * 0.28),
        y = math.floor(self.height * 0.46),
        velocity = 0
    }
    self.gravity = 0.34
    self.flapPower = -5.9
    self.pipeSpeed = 3.1
    self.pipeGap = 76
    self.pipeWidth = 34
    self.pipeSpacing = 112
    self.groundH = 24
    self.skyOffset = 0
    self.flapHeld = false
    self.pipes = {}
    local firstX = self.width * 0.72
    for i = 1, 3 do
        self:addPipe(firstX + (i - 1) * self.pipeSpacing)
    end
end

function PZFlappyGame:drawSafeRect(x, y, w, h, a, r, g, b)
    local x1 = math.max(0, math.floor(x))
    local y1 = math.max(0, math.floor(y))
    local x2 = math.min(self.width, math.ceil(x + w))
    local y2 = math.min(self.height, math.ceil(y + h))
    if x2 <= x1 or y2 <= y1 then return end
    self:drawRect(x1, y1, x2 - x1, y2 - y1, a, r, g, b)
end

function PZFlappyGame:addPipe(x)
    local minTop = 34
    local maxTop = self.height - self.groundH - self.pipeGap - 38
    local gapY = minTop
    if maxTop > minTop then
        gapY = minTop + ZombRand(maxTop - minTop)
    end
    self.pipes[#self.pipes + 1] = {x = x, gapY = gapY, scored = false}
end

function PZFlappyGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZFlappyGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZFlappyGame:doFlap()
    if self.gameState == "GAMEOVER" then
        self:resetGame()
        return
    end
    if self.gameState == "READY" then
        self.gameState = "PLAYING"
    end
    self.bird.velocity = self.flapPower
    self:playSound("ComputerBirdJump")
end

function PZFlappyGame:updateInput()
    local flapDown = ComputerModGameInput.isDown(self, "action") or ComputerModGameInput.isDown(self, "up")
    if flapDown and not self.flapHeld then
        self:doFlap()
    end
    self.flapHeld = flapDown
end

function PZFlappyGame:updatePipes()
    local rightMost = 0
    for i = #self.pipes, 1, -1 do
        local pipe = self.pipes[i]
        pipe.x = pipe.x - self.pipeSpeed
        if pipe.x > rightMost then rightMost = pipe.x end
        if pipe.x + self.pipeWidth < -4 then
            table.remove(self.pipes, i)
        end
    end
    while #self.pipes < 3 do
        self:addPipe(rightMost + self.pipeSpacing)
        rightMost = rightMost + self.pipeSpacing
    end
end

function PZFlappyGame:checkScoreAndCollision()
    local bx = self.bird.x
    local by = self.bird.y
    local birdW = 18
    local birdH = 14
    local floorY = self.height - self.groundH

    if by - birdH * 0.5 < 0 or by + birdH * 0.5 > floorY then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
        return
    end

    for i = 1, #self.pipes do
        local pipe = self.pipes[i]
        if not pipe.scored and pipe.x + self.pipeWidth < bx - birdW * 0.5 then
            pipe.scored = true
            self.score = self.score + 1
            self:playSound("ComputerBallHit")
            if self.score > self.bestScore then
                self.bestScore = self.score
            end
        end

        local overlapX = bx + birdW * 0.42 > pipe.x and bx - birdW * 0.42 < pipe.x + self.pipeWidth
        if overlapX then
            local topBottom = pipe.gapY
            local bottomTop = pipe.gapY + self.pipeGap
            if by - birdH * 0.42 < topBottom or by + birdH * 0.42 > bottomTop then
                self.gameState = "GAMEOVER"
                self:playGameOverSound()
                return
            end
        end
    end
end

function PZFlappyGame:update()
    self.tick = self.tick + 1
    self.skyOffset = (self.skyOffset + 0.6) % 48
    self:updateInput()

    if self.gameState == "READY" then
        self.bird.y = math.floor(self.height * 0.46) + math.sin(self.tick / 8) * 5
        return
    end

    if self.gameState == "GAMEOVER" then
        return
    end

    self.bird.velocity = self.bird.velocity + self.gravity
    self.bird.y = self.bird.y + self.bird.velocity
    self:updatePipes()
    self:checkScoreAndCollision()
end

function PZFlappyGame:drawPipe(pipe)
    local px = math.floor(pipe.x)
    local topH = pipe.gapY
    local bottomY = pipe.gapY + self.pipeGap
    local bottomH = self.height - self.groundH - bottomY
    local topCapY = math.max(0, topH - 12)
    local topCapH = math.min(12, topH)
    local bottomBodyH = math.max(0, bottomH)
    local bottomDetailH = math.max(0, bottomH - 12)
    self:drawSafeRect(px + 2, 0, self.pipeWidth - 4, topH, 1, 0.10, 0.42, 0.18)
    self:drawSafeRect(px, 0, 3, topH, 1, 0.04, 0.20, 0.09)
    self:drawSafeRect(px + self.pipeWidth - 3, 0, 3, topH, 1, 0.04, 0.20, 0.09)
    if topCapH > 0 then
        self:drawSafeRect(px - 3, topCapY, self.pipeWidth + 6, topCapH, 1, 0.16, 0.58, 0.24)
        self:drawSafeRect(px - 3, topCapY, self.pipeWidth + 6, 2, 1, 0.36, 0.74, 0.34)
    end
    if topH - topCapH > 0 then
        self:drawSafeRect(px + 7, 0, 3, topH - topCapH, 0.30, 0.42, 0.74, 0.38)
    end
    if bottomBodyH > 0 then
        self:drawSafeRect(px + 2, bottomY, self.pipeWidth - 4, bottomBodyH, 1, 0.10, 0.42, 0.18)
        self:drawSafeRect(px, bottomY, 3, bottomBodyH, 1, 0.04, 0.20, 0.09)
        self:drawSafeRect(px + self.pipeWidth - 3, bottomY, 3, bottomBodyH, 1, 0.04, 0.20, 0.09)
        self:drawSafeRect(px - 3, bottomY, self.pipeWidth + 6, 12, 1, 0.16, 0.58, 0.24)
        self:drawSafeRect(px - 3, bottomY, self.pipeWidth + 6, 2, 1, 0.36, 0.74, 0.34)
    end
    if bottomDetailH > 0 then
        self:drawSafeRect(px + 7, bottomY + 12, 3, bottomDetailH, 0.30, 0.42, 0.74, 0.38)
    end
end

function PZFlappyGame:drawBird()
    local bx = self.bird.x
    local by = self.bird.y
    local wingLift = math.sin(self.tick / 3) * 2
    self:drawRect(bx - 10, by - 6, 18, 13, 1, 0.84, 0.62, 0.16)
    self:drawRect(bx - 6, by - 10, 12, 10, 1, 0.94, 0.76, 0.20)
    self:drawRect(bx + 5, by - 3, 8, 4, 1, 0.82, 0.30, 0.14)
    self:drawRect(bx - 6, by + wingLift, 10, 5, 1, 0.70, 0.38, 0.10)
    self:drawRect(bx + 2, by - 7, 2, 2, 1, 0.02, 0.02, 0.02)
end

function PZFlappyGame:drawHud()
    self:drawRect(0, 0, self.width, 24, 1, 0.010, 0.024, 0.036)
    self:drawRect(0, 23, self.width, 1, 1, 0.42, 0.58, 0.62)
    self:drawText("BIRD.EXE", 10, 7, 0.78, 0.90, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 94, 7, 0.78, 0.90, 0.88, 1, UIFont.Small)
    self:drawText("BEST " .. tostring(self.bestScore), self.width - 74, 7, 0.78, 0.90, 0.88, 1, UIFont.Small)
end

function PZFlappyGame:drawMessage(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 72
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor(self.height * 0.35)
    self:drawSafeRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.06, 0.08, 0.08)
    self:drawSafeRect(boxX, boxY, boxW, boxH, 0.98, 0.010, 0.024, 0.036)
    self:drawSafeRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.42, 0.58, 0.62)
    self:drawText(title, boxX + 10, boxY + 19, 0.78, 0.90, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 42, 0.82, 0.78, 0.52, 1, UIFont.Small)
end

function PZFlappyGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawSafeRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZFlappyGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.34, 0.62, 0.74)
    for band = 0, 9 do
        local y = band * self.height / 9
        self:drawSafeRect(0, y, self.width, math.max(2, self.height / 24), 0.10, 0.20, 0.42, 0.52)
    end
    for i = 0, 7 do
        local x = i * 48 - self.skyOffset
        self:drawSafeRect(x + 5, 34, 28, 8, 0.26, 0.88, 0.92, 0.90)
        self:drawSafeRect(x + 18, 28, 22, 10, 0.26, 0.88, 0.92, 0.90)
    end

    for i = 1, #self.pipes do
        self:drawPipe(self.pipes[i])
    end

    self:drawRect(0, self.height - self.groundH, self.width, self.groundH, 1, 0.36, 0.24, 0.12)
    self:drawRect(0, self.height - self.groundH, self.width, 5, 1, 0.14, 0.46, 0.18)
    for i = 0, self.width, 18 do
        self:drawSafeRect(i - (self.skyOffset % 18), self.height - self.groundH + 10, 9, 3, 0.55, 0.82, 0.66, 0.28)
    end

    self:drawBird()
    self:drawHud()

    if self.gameState == "READY" then
        self:drawMessage("BIRD.EXE READY", ComputerModGameInput.getInputLabel(self, "action") .. "/" .. ComputerModGameInput.getInputLabel(self, "up") .. ": FLAP")
    elseif self.gameState == "GAMEOVER" then
        self:drawMessage("BIRD.EXE STOPPED", ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART")
    end

    self:drawScanlines()
end

function PZFlappyGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
