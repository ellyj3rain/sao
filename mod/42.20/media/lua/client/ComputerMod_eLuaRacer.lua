-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZRacerGame = ISPanel:derive("PZRacerGame")

function PZRacerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZRacerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.crashPulse = 0
    self.flashTick = 0
    self.roadOffset = 0
    self.spawnTick = 0
    self.laneCount = 4
    self.roadLeft = 0.18
    self.roadWidth = 0.64
    self.roadTop = 0.05
    self.roadBottom = 0.95
    self.laneWidth = self.roadWidth / self.laneCount
    self.traffic = {}
    self.score = 0
    self.distance = 0
    self.nearMisses = 0
    self.player = {
        lane = 1,
        laneOffset = 0,
        targetLane = 1,
        speed = 0.030,
        targetSpeed = 0.030,
        minSpeed = 0.020,
        maxSpeed = 0.056
    }
    self.leftHeld = false
    self.rightHeld = false
end

function PZRacerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZRacerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZRacerGame:clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZRacerGame:getLaneCenter(lane)
    return (self.roadLeft + self.laneWidth * lane + self.laneWidth * 0.5) * self.width
end

function PZRacerGame:getCarWidth()
    return math.floor(self.laneWidth * self.width * 0.54)
end

function PZRacerGame:getCarHeight()
    return math.floor(self.height * 0.14)
end

function PZRacerGame:getPlayerY()
    return self.height * 0.79
end

function PZRacerGame:spawnTrafficCar()
    local lane = ZombRand(self.laneCount)
    local tooClose = false
    for i = 1, #self.traffic do
        local car = self.traffic[i]
        if car.lane == lane and car.y < self.height * 0.30 then
            tooClose = true
            break
        end
    end
    if tooClose then return end

    local colorPool = {
        {0.92, 0.34, 0.28},
        {0.24, 0.70, 0.95},
        {0.96, 0.56, 0.18},
        {0.72, 0.38, 0.94},
        {0.84, 0.84, 0.86}
    }
    local color = colorPool[ZombRand(#colorPool) + 1]
    self.traffic[#self.traffic + 1] = {
        lane = lane,
        offset = ((ZombRand(100) - 50) / 50) * self.laneWidth * 0.10,
        y = self.roadTop * self.height + 6,
        speed = 0.020 + ZombRand(18) / 1000,
        color = color,
        passed = false,
        nearMiss = false
    }
end

function PZRacerGame:updatePlayer()
    local leftDown = ComputerModGameInput.isDown(self, "left")
    local rightDown = ComputerModGameInput.isDown(self, "right")

    if leftDown and not self.leftHeld then
        self.player.targetLane = self.player.targetLane - 1
    elseif rightDown and not self.rightHeld then
        self.player.targetLane = self.player.targetLane + 1
    end

    self.leftHeld = leftDown
    self.rightHeld = rightDown

    self.player.targetLane = self:clamp(self.player.targetLane, 0, self.laneCount - 1)

    if ComputerModGameInput.isDown(self, "up") then
        self.player.targetSpeed = math.min(self.player.maxSpeed, self.player.targetSpeed + 0.0014)
    elseif ComputerModGameInput.isDown(self, "down") then
        self.player.targetSpeed = math.max(self.player.minSpeed, self.player.targetSpeed - 0.0017)
    else
        self.player.targetSpeed = self.player.targetSpeed - 0.0002
    end

    self.player.targetSpeed = self:clamp(self.player.targetSpeed, self.player.minSpeed, self.player.maxSpeed)
    self.player.speed = self.player.speed + (self.player.targetSpeed - self.player.speed) * 0.14

    local laneStep = self.player.targetLane - self.player.lane
    local desiredOffset = laneStep * self.laneWidth
    self.player.laneOffset = self.player.laneOffset + desiredOffset * 0.18
    if laneStep ~= 0 and math.abs(self.player.laneOffset) > self.laneWidth * 0.92 then
        self.player.lane = self.player.targetLane
        self.player.laneOffset = 0
    end

    self.distance = self.distance + self.player.speed * 28
    self.score = self.score + self.player.speed * 12
end

function PZRacerGame:updateTraffic()
    self.spawnTick = self.spawnTick + 1
    local spawnRate = math.max(16, 44 - math.floor(self.distance / 180))
    if self.spawnTick >= spawnRate then
        self.spawnTick = 0
        self:spawnTrafficCar()
    end

    local playerY = self:getPlayerY()
    for i = #self.traffic, 1, -1 do
        local car = self.traffic[i]
        local relativeSpeed = (self.player.speed - car.speed)
        local screenSpeed = 5.1 + relativeSpeed * 210
        car.y = car.y + screenSpeed

        if not car.passed and car.y > playerY + 16 then
            car.passed = true
            self.score = self.score + 18
        end

        if car.y > self.height + self:getCarHeight() then
            table.remove(self.traffic, i)
        end
    end
end

function PZRacerGame:checkCollisions()
    local playerX = self:getLaneCenter(self.player.lane) + self.player.laneOffset * self.width
    local playerY = self:getPlayerY()
    local playerW = self:getCarWidth()
    local playerH = self:getCarHeight()

    for i = 1, #self.traffic do
        local car = self.traffic[i]
        local carX = self:getLaneCenter(car.lane) + car.offset * self.width
        local carY = car.y
        local dx = math.abs(playerX - carX)
        local dy = math.abs(playerY - carY)

        if not car.nearMiss and dy < playerH * 0.8 and dx < playerW * 0.95 then
            car.nearMiss = true
            self.nearMisses = self.nearMisses + 1
            self.score = self.score + 8
            self:playSound("ComputerBallHit")
        end

        if dx < playerW * 0.72 and dy < playerH * 0.68 then
            self.gameState = "GAMEOVER"
            self.crashPulse = 24
            self:playGameOverSound()
            return
        end
    end
end

function PZRacerGame:update()
    self.flashTick = self.flashTick + 1
    self.crashPulse = math.max(0, (self.crashPulse or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    self:updatePlayer()
    self:updateTraffic()
    self:checkCollisions()
    self.roadOffset = (self.roadOffset + self.player.speed * self.height * 0.98) % 28
end

function PZRacerGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.025, 0.085, 0.035)
    for i = 0, 10 do
        local y = i * self.height / 10
        local shade = i % 2 == 0 and 0.012 or 0.028
        self:drawRect(0, y, self.width, math.max(2, self.height / 13), 0.45, 0.03 + shade, 0.12 + shade, 0.04)
    end
end

function PZRacerGame:drawScenery()
    local leftXs = {20, 26, 18, 24, 16, 28}
    local rightXs = {self.width - 34, self.width - 26, self.width - 36, self.width - 24, self.width - 30, self.width - 40}
    for i = 1, 6 do
        local y = ((i - 1) * 46 + self.roadOffset * 0.6) % (self.height + 48) - 24
        self:drawRect(leftXs[i], y + 8, 6, 10, 1, 0.40, 0.24, 0.12)
        self:drawRect(leftXs[i] - 10, y - 2, 26, 20, 1, 0.10, 0.42, 0.17)
        self:drawRect(leftXs[i] - 4, y - 8, 14, 12, 1, 0.16, 0.58, 0.22)
        self:drawRect(rightXs[i], y + 8, 6, 10, 1, 0.40, 0.24, 0.12)
        self:drawRect(rightXs[i] - 10, y - 2, 26, 20, 1, 0.10, 0.42, 0.17)
        self:drawRect(rightXs[i] - 4, y - 8, 14, 12, 1, 0.16, 0.58, 0.22)
    end
end

function PZRacerGame:drawRoad()
    local x = self.roadLeft * self.width
    local y = self.roadTop * self.height
    local w = self.roadWidth * self.width
    local h = (self.roadBottom - self.roadTop) * self.height

    self:drawRect(x - 14, y, 14, h, 1, 0.12, 0.12, 0.12)
    self:drawRect(x + w, y, 14, h, 1, 0.12, 0.12, 0.12)
    self:drawRect(x, y, w, h, 1, 0.105, 0.108, 0.110)
    for band = 0, 12 do
        local by = y + band * h / 12
        self:drawRect(x, by, w, math.max(2, h / 20), 0.16, 0.04, 0.04, 0.045)
    end
    local railY = y + self.roadOffset
    while railY < y + h do
        self:drawRect(x - 13, railY, 12, 9, 1, 0.86, 0.86, 0.78)
        self:drawRect(x + w + 1, railY, 12, 9, 1, 0.86, 0.86, 0.78)
        self:drawRect(x - 13, railY + 9, 12, 9, 1, 0.62, 0.10, 0.09)
        self:drawRect(x + w + 1, railY + 9, 12, 9, 1, 0.62, 0.10, 0.09)
        railY = railY + 36
    end

    for i = 1, self.laneCount - 1 do
        local lineX = x + i * self.laneWidth * self.width
        local markY = y + 6 + self.roadOffset
        while markY < y + h - 18 do
            self:drawRect(lineX - 1, markY, 2, 16, 0.78, 0.78, 0.78, 0.68)
            markY = markY + 28
        end
    end
end

function PZRacerGame:drawCarAt(centerX, centerY, color, player)
    local carW = self:getCarWidth()
    local carH = self:getCarHeight()
    local x = math.floor(centerX - carW * 0.5)
    local y = math.floor(centerY - carH * 0.5)
    self:drawRect(x + 1, y + 3, carW, carH, 0.28, 0, 0, 0)
    self:drawRect(x, y + 4, carW, carH - 8, 1, color[1], color[2], color[3])
    self:drawRect(x + 4, y, carW - 8, carH, 1, color[1] * 0.86, color[2] * 0.86, color[3] * 0.86)
    self:drawRect(x + 5, y + 6, carW - 10, math.max(4, carH - 18), 1, 0.10, 0.14, 0.16)
    self:drawRect(x + 6, y + 7, carW - 12, math.max(2, carH - 22), 1, 0.46, 0.62, 0.70)
    self:drawRect(x + 4, y + 2, carW - 8, 2, 1, 0.92, 0.90, 0.72)
    self:drawRect(x - 1, y + 5, 3, 5, 1, 0.08, 0.08, 0.08)
    self:drawRect(x + carW - 2, y + 5, 3, 5, 1, 0.08, 0.08, 0.08)
    self:drawRect(x - 1, y + carH - 10, 3, 5, 1, 0.08, 0.08, 0.08)
    self:drawRect(x + carW - 2, y + carH - 10, 3, 5, 1, 0.08, 0.08, 0.08)
end

function PZRacerGame:drawTraffic()
    for i = 1, #self.traffic do
        local car = self.traffic[i]
        local x = self:getLaneCenter(car.lane) + car.offset * self.width
        self:drawCarAt(x, car.y, car.color, false)
    end
end

function PZRacerGame:drawPlayer()
    local x = self:getLaneCenter(self.player.lane) + self.player.laneOffset * self.width
    self:drawCarAt(x, self:getPlayerY(), {0.98, 0.86, 0.22}, true)
end

function PZRacerGame:drawHUD()
    self:drawRect(0, 0, self.width, 25, 1, 0.010, 0.012, 0.010)
    self:drawRect(0, 24, self.width, 1, 1, 0.42, 0.42, 0.34)
    self:drawText("RACER.EXE", 10, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText("MPH " .. string.format("%03d", math.floor(self.player.speed * 1600)), 102, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(math.floor(self.score)), 184, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText("MISS " .. tostring(self.nearMisses), self.width - 70, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
end

function PZRacerGame:drawOverlay()
    if self.gameState ~= "GAMEOVER" then return end
    local boxW = math.min(self.width - 40, 214)
    local boxH = 82
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.06, 0.05, 0.04)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.006, 0.004)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.42, 0.38, 0.24)
    self:drawText("RACER.EXE CRASH", boxX + 10, boxY + 18, 0.82, 0.76, 0.48, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(math.floor(self.score)), boxX + 10, boxY + 40, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 60, 0.72, 0.74, 0.56, 1, UIFont.Small)
end

function PZRacerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
    if self.crashPulse and self.crashPulse > 0 then
        self:drawRect(0, 0, self.width, self.height, self.crashPulse / 120, 0.88, 0.12, 0.08)
    end
end

function PZRacerGame:prerender()
    self:drawBackground()
    self:drawScenery()
    self:drawRoad()
    self:drawTraffic()
    self:drawPlayer()
    self:drawHUD()
    self:drawOverlay()
    self:drawScanlines()
end

function PZRacerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
