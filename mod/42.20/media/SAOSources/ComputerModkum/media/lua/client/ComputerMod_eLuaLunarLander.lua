require "ISUI/ISPanel"

PZLunarLanderGame = ISPanel:derive("PZLunarLanderGame")

local function drawPixelLine(panel, x1, y1, x2, y2, a, r, g, b)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(math.abs(dx), math.abs(dy))
    if steps < 1 then
        panel:drawRect(x1, y1, 2, 2, a or 1, r or 1, g or 1, b or 1)
        return
    end
    for i = 0, steps do
        local t = i / steps
        local px = x1 + dx * t
        local py = y1 + dy * t
        panel:drawRect(px, py, 2, 2, a or 1, r or 1, g or 1, b or 1)
    end
end

function PZLunarLanderGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZLunarLanderGame:buildTerrain()
    local h = self.height
    local padHalf = 30 + ZombRand(13)
    local padCenter = 150 + ZombRand(math.max(1, self.width - 300))
    local padY = h - (94 + ZombRand(20))
    local padX1 = padCenter - padHalf
    local padX2 = padCenter + padHalf

    self.pad = {x1 = padX1, x2 = padX2, y = padY}
    self.terrain = {
        {x = 0, y = h - (34 + ZombRand(10))},
        {x = 42 + ZombRand(12), y = h - (58 + ZombRand(16))},
        {x = 96 + ZombRand(14), y = h - (46 + ZombRand(14))},
        {x = padX1 - (68 + ZombRand(16)), y = padY - (22 + ZombRand(20))},
        {x = padX1 - (24 + ZombRand(8)), y = padY - (6 + ZombRand(8))},
        {x = padX1, y = padY},
        {x = padX2, y = padY},
        {x = padX2 + (26 + ZombRand(10)), y = padY - (6 + ZombRand(10))},
        {x = padX2 + (82 + ZombRand(18)), y = padY - (18 + ZombRand(24))},
        {x = self.width, y = h - (36 + ZombRand(12))}
    }
end

function PZLunarLanderGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.animationTick = 0
    self.crashFlash = 0
    self.ship = {
        x = self.width * 0.28,
        y = 46,
        vx = 0,
        vy = 0,
        angle = 0,
        fuel = 100
    }
    self.stars = {}
    self.score = 0
    self:buildTerrain()
    for i = 1, 44 do
        self.stars[i] = {
            x = (i * 37 + ZombRand(21)) % self.width,
            y = (i * 61 + ZombRand(17)) % math.max(1, self.height - 130),
            size = (i % 3 == 0) and 2 or 1,
            pulse = 0.55 + (ZombRand(35) / 100)
        }
    end
end

function PZLunarLanderGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZLunarLanderGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZLunarLanderGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZLunarLanderGame:getGroundY(x)
    local points = self.terrain
    for i = 1, #points - 1 do
        local a = points[i]
        local b = points[i + 1]
        if x >= a.x and x <= b.x then
            local span = math.max(1, b.x - a.x)
            local t = (x - a.x) / span
            return a.y + (b.y - a.y) * t
        end
    end
    return self.height - 24
end

function PZLunarLanderGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.crashFlash = math.max(0, (self.crashFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.ship.angle = self.ship.angle - 0.05
    end
    if ComputerModGameInput.isDown(self, "right") then
        self.ship.angle = self.ship.angle + 0.05
    end

    local thrusting = ComputerModGameInput.isDown(self, "up") and self.ship.fuel > 0
    if thrusting then
        self.ship.vx = self.ship.vx + math.sin(self.ship.angle) * 0.035
        self.ship.vy = self.ship.vy - math.cos(self.ship.angle) * 0.055
        self.ship.fuel = math.max(0, self.ship.fuel - 0.45)
    end

    self.ship.vy = self.ship.vy + 0.028
    self.ship.x = self.ship.x + self.ship.vx
    self.ship.y = self.ship.y + self.ship.vy
    self.ship.vx = self.ship.vx * 0.995

    if self.ship.x < 12 then
        self.ship.x = 12
        self.ship.vx = math.abs(self.ship.vx) * 0.4
    elseif self.ship.x > self.width - 12 then
        self.ship.x = self.width - 12
        self.ship.vx = -math.abs(self.ship.vx) * 0.4
    end

    local footY = self.ship.y + 11
    local groundY = self:getGroundY(self.ship.x)
    if footY >= groundY then
        local gentle = math.abs(self.ship.vx) <= 0.55 and math.abs(self.ship.vy) <= 0.75
        local aligned = math.abs(self.ship.angle) <= 0.18
        local onPad = self.ship.x >= self.pad.x1 and self.ship.x <= self.pad.x2 and math.abs(groundY - self.pad.y) <= 0.2
        if gentle and aligned and onPad then
            self.gameState = "WIN"
            self.score = math.floor(self.ship.fuel * 10)
            self.ship.y = groundY - 11
            self.ship.vx = 0
            self.ship.vy = 0
            self.ship.angle = 0
            self:playWinSound()
        else
            self.gameState = "GAMEOVER"
            self.ship.y = groundY - 11
            self.crashFlash = 18
            self:playGameOverSound()
        end
    end
end

function PZLunarLanderGame:drawShip()
    local x = self.ship.x
    local y = self.ship.y
    local sinA = math.sin(self.ship.angle)
    local cosA = math.cos(self.ship.angle)
    local noseX = x + sinA * 10
    local noseY = y - cosA * 10
    local leftX = x - cosA * 6 - sinA * 5
    local leftY = y - sinA * 6 + cosA * 5
    local rightX = x + cosA * 6 - sinA * 5
    local rightY = y + sinA * 6 + cosA * 5
    drawPixelLine(self, leftX, leftY, noseX, noseY, 1, 0.92, 0.92, 0.96)
    drawPixelLine(self, rightX, rightY, noseX, noseY, 1, 0.92, 0.92, 0.96)
    drawPixelLine(self, leftX, leftY, rightX, rightY, 1, 0.92, 0.92, 0.96)
    drawPixelLine(self, leftX, leftY, leftX - cosA * 7, leftY - sinA * 7, 1, 0.72, 0.72, 0.78)
    drawPixelLine(self, rightX, rightY, rightX + cosA * 7, rightY + sinA * 7, 1, 0.72, 0.72, 0.78)
    if ComputerModGameInput.isDown(self, "up") and self.ship.fuel > 0 and self.gameState == "PLAYING" then
        local flameX = x - sinA * 11
        local flameY = y + cosA * 11
        drawPixelLine(self, x - sinA * 6, y + cosA * 6, flameX, flameY, 1, 1, 0.68, 0.22)
        drawPixelLine(self, x - sinA * 4 - cosA * 2, y + cosA * 4 - sinA * 2, flameX - cosA * 2, flameY - sinA * 2, 0.9, 1, 0.38, 0.12)
        drawPixelLine(self, x - sinA * 4 + cosA * 2, y + cosA * 4 + sinA * 2, flameX + cosA * 2, flameY + sinA * 2, 0.9, 1, 0.82, 0.32)
    end
end

function PZLunarLanderGame:drawHud()
    local altitude = math.max(0, math.floor(self:getGroundY(self.ship.x) - (self.ship.y + 11)))
    local angleDeg = math.floor(math.deg(self.ship.angle))
    self:drawRect(0, 0, self.width, 25, 1, 0.006, 0.010, 0.018)
    self:drawRect(0, 24, self.width, 1, 1, 0.34, 0.36, 0.44)
    self:drawText("LANDER.EXE", 10, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText("FUEL " .. tostring(math.floor(self.ship.fuel)), 110, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText("ALT " .. tostring(altitude), 184, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText(string.format("V %.2f", self.ship.vy), self.width - 132, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText("ANG " .. tostring(angleDeg), self.width - 66, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
end

function PZLunarLanderGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.05, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.34, 0.36, 0.44)
    self:drawText(title, boxX + 10, boxY + 19, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.72, 0.74, 0.84, 1, UIFont.Small)
end

function PZLunarLanderGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZLunarLanderGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.010, 0.022)
    self:drawRect(0, 25, self.width, self.height * 0.26, 0.12, 0.14, 0.18, 0.30)
    self:drawRect(0, self.height * 0.30, self.width, self.height * 0.18, 0.08, 0.10, 0.12, 0.24)
    for i = 1, #self.stars do
        local star = self.stars[i]
        local pulse = 0.82 + math.abs(math.sin((self.animationTick + i * 5) * 0.04)) * star.pulse
        self:drawRect(star.x, star.y, star.size, star.size, math.min(1, pulse), 0.74, 0.76, 0.86)
    end
    self:drawHud()
    if self.crashFlash and self.crashFlash > 0 then
        self:drawRect(0, 25, self.width, self.height - 25, self.crashFlash / 100, 0.82, 0.14, 0.10)
    end

    for i = 1, #self.terrain - 1 do
        local a = self.terrain[i]
        local b = self.terrain[i + 1]
        drawPixelLine(self, a.x, a.y, b.x, b.y, 1, 0.56, 0.56, 0.62)
        self:drawRect(a.x, a.y, math.max(1, b.x - a.x), self.height - a.y, 0.16, 0.18, 0.16, 0.13)
    end
    local padGlow = 0.5 + math.abs(math.sin((self.animationTick or 0) * 0.08)) * 0.4
    self:drawRect(self.pad.x1 - 2, self.pad.y - 4, self.pad.x2 - self.pad.x1 + 4, 8, 0.16, 0.34, 0.72, 0.34)
    self:drawRect(self.pad.x1, self.pad.y - 2, self.pad.x2 - self.pad.x1, 4, 0.75 + padGlow * 0.2, 0.34, 0.72, 0.34)
    self:drawText("PAD", self.pad.x1 + math.floor((self.pad.x2 - self.pad.x1) * 0.5) - 12, self.pad.y - 16, 0.60, 0.82, 0.60, 1, UIFont.Small)
    local safeText = math.abs(self.ship.vx) <= 0.55 and math.abs(self.ship.vy) <= 0.75 and math.abs(self.ship.angle) <= 0.18 and "SAFE APPROACH" or "STABILIZE SHIP"
    local safeColor = safeText == "SAFE APPROACH" and {0.60, 0.82, 0.60} or {0.82, 0.72, 0.48}
    self:drawText(safeText, self.width * 0.5 - 44, 28, safeColor[1], safeColor[2], safeColor[3], 1, UIFont.Small)

    self:drawShip()

    if self.gameState == "WIN" then
        self:drawOverlay("LANDING CONFIRMED", "SCORE " .. tostring(self.score))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("CRASH LANDING", "FUEL " .. tostring(math.floor(self.ship.fuel)))
    end
    self:drawScanlines()
end

function PZLunarLanderGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
