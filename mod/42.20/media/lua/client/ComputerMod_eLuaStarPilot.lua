-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZStarPilotGame = ISPanel:derive("PZStarPilotGame")

local function clampValue(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function PZStarPilotGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:resetGame()
end

function PZStarPilotGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.animationTick = 0
    self.hitFlash = 0
    self.damageFlash = 0
    self.score = 0
    self.lives = 3
    self.level = 1
    self.fireCooldown = 0
    self.spawnTimer = 0
    self.collectTimer = 0
    self.player = {x = self.width * 0.5, y = self.height - 42, vx = 0, vy = 0}
    self.bullets = {}
    self.enemies = {}
    self.collectibles = {}
    self.particles = {}
    self.stars = {}
    for i = 1, 58 do
        self.stars[i] = {
            x = (i * 47 + ZombRand(30)) % math.max(1, self.width),
            y = (i * 29 + ZombRand(40)) % math.max(1, self.height),
            speed = 0.4 + (i % 5) * 0.18,
            size = (i % 7 == 0) and 2 or 1
        }
    end
end

function PZStarPilotGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZStarPilotGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZStarPilotGame:spawnEnemy()
    local w = 18 + ZombRand(18)
    local x = 12 + ZombRand(math.max(1, self.width - w - 24))
    local speed = 1.35 + self.level * 0.12 + ZombRand(50) / 100
    self.enemies[#self.enemies + 1] = {x = x, y = -24, w = w, h = 16 + ZombRand(12), speed = speed, phase = ZombRand(100)}
end

function PZStarPilotGame:spawnCollectible()
    local x = 18 + ZombRand(math.max(1, self.width - 36))
    self.collectibles[#self.collectibles + 1] = {x = x, y = -18, speed = 1.1 + ZombRand(40) / 100}
end

function PZStarPilotGame:fire()
    if self.fireCooldown > 0 or self.gameState ~= "PLAYING" then return end
    self.fireCooldown = 11
    self.bullets[#self.bullets + 1] = {x = self.player.x, y = self.player.y - 18}
    self:playSound("ComputerLaserShot")
end

function PZStarPilotGame:emitParticles(x, y, count, r, g, b)
    for i = 1, count do
        local life = 12 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1000) - 500) / 220,
            vy = (ZombRand(1000) - 500) / 220,
            life = life,
            maxLife = life,
            r = r,
            g = g,
            b = b
        }
    end
end

function PZStarPilotGame:updateParticles()
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.94
        p.vy = p.vy * 0.94
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZStarPilotGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self.damageFlash = math.max(0, (self.damageFlash or 0) - 1)
    self:updateParticles()
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    local accelerationX = 0
    local accelerationY = 0
    if ComputerModGameInput.isDown(self, "left") or ComputerModGameInput.isDown(self, "strafeLeft") then accelerationX = accelerationX - 1.15 end
    if ComputerModGameInput.isDown(self, "right") or ComputerModGameInput.isDown(self, "strafeRight") then accelerationX = accelerationX + 1.15 end
    if ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then accelerationY = accelerationY - 0.88 end
    if ComputerModGameInput.isDown(self, "down") or ComputerModGameInput.isDown(self, "backward") then accelerationY = accelerationY + 0.88 end
    self.player.vx = (self.player.vx + accelerationX) * 0.82
    self.player.vy = (self.player.vy + accelerationY) * 0.82
    self.player.x = clampValue(self.player.x + self.player.vx, 18, self.width - 18)
    self.player.y = clampValue(self.player.y + self.player.vy, 54, self.height - 26)
    if self.fireCooldown > 0 then self.fireCooldown = self.fireCooldown - 1 end
    if ComputerModGameInput.isDown(self, "action") then self:fire() end

    for i = 1, #self.stars do
        local star = self.stars[i]
        star.y = star.y + star.speed + self.level * 0.04
        if star.y > self.height then
            star.y = 0
            star.x = ZombRand(math.max(1, self.width))
        end
    end

    self.spawnTimer = self.spawnTimer + 1
    local spawnRate = math.max(18, 45 - self.level * 2)
    if self.spawnTimer >= spawnRate then
        self.spawnTimer = 0
        self:spawnEnemy()
    end

    self.collectTimer = self.collectTimer + 1
    if self.collectTimer >= 95 then
        self.collectTimer = 0
        self:spawnCollectible()
    end

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.y = bullet.y - 5.8
        if bullet.y < -8 then
            table.remove(self.bullets, i)
        end
    end

    for i = #self.collectibles, 1, -1 do
        local item = self.collectibles[i]
        item.y = item.y + item.speed
        if rectsOverlap(self.player.x - 11, self.player.y - 11, 22, 22, item.x - 6, item.y - 6, 12, 12) then
            self.score = self.score + 75
            self.hitFlash = 5
            self:emitParticles(item.x, item.y, 10, 0.34, 0.70, 0.95)
            self:playSound("ComputerBallHit")
            table.remove(self.collectibles, i)
        elseif item.y > self.height + 12 then
            table.remove(self.collectibles, i)
        end
    end

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy.y = enemy.y + enemy.speed
        enemy.x = enemy.x + math.sin((self.animationTick + enemy.phase) * 0.07) * 0.75
        if rectsOverlap(self.player.x - 12, self.player.y - 12, 24, 24, enemy.x, enemy.y, enemy.w, enemy.h) then
            self.lives = self.lives - 1
            self.damageFlash = 10
            self:emitParticles(self.player.x, self.player.y, 16, 0.90, 0.36, 0.20)
            table.remove(self.enemies, i)
            if self.lives <= 0 then
                self.gameState = "GAMEOVER"
                if self.score > self.highscore then self.highscore = self.score end
                self:playGameOverSound()
                return
            end
        else
            local destroyed = false
            for j = #self.bullets, 1, -1 do
                local bullet = self.bullets[j]
                if rectsOverlap(bullet.x - 2, bullet.y - 8, 4, 10, enemy.x, enemy.y, enemy.w, enemy.h) then
                    self.score = self.score + 45
                    self.hitFlash = 4
                    self:emitParticles(enemy.x + enemy.w * 0.5, enemy.y + enemy.h * 0.5, 12, 0.84, 0.42, 0.22)
                    self:playSound("ComputerBallHit")
                    table.remove(self.bullets, j)
                    table.remove(self.enemies, i)
                    destroyed = true
                    break
                end
            end
            if not destroyed and enemy.y > self.height + 18 then
                self.score = self.score + 5
                table.remove(self.enemies, i)
            end
        end
    end

    self.level = 1 + math.floor(self.score / 650)
end

function PZStarPilotGame:drawShip(x, y)
    self:drawRect(x + 1, y - 13, 10, 24, 0.24, 0, 0, 0)
    self:drawRect(x - 5, y - 18, 10, 20, 1, 0.42, 0.62, 0.80)
    self:drawRect(x - 12, y - 4, 24, 10, 1, 0.14, 0.28, 0.54)
    self:drawRect(x - 3, y - 22, 6, 6, 1, 0.76, 0.86, 0.90)
    self:drawRect(x - 8, y + 6, 4, 8, 1, 0.86, 0.44, 0.12)
    self:drawRect(x + 4, y + 6, 4, 8, 1, 0.86, 0.44, 0.12)
    if ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then
        self:drawRect(x - 6, y + 14, 3, 6, 0.80, 0.90, 0.62, 0.18)
        self:drawRect(x + 3, y + 14, 3, 6, 0.80, 0.90, 0.62, 0.18)
    end
end

function PZStarPilotGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.006, 0.008, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.26, 0.32, 0.46)
    self:drawText("PILOT.EXE", 10, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("LIFE " .. tostring(self.lives), 98, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("LVL " .. tostring(self.level), 160, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), self.width - 94, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZStarPilotGame:drawEnemy(enemy)
    self:drawRect(enemy.x + 1, enemy.y + 2, enemy.w, enemy.h, 0.28, 0, 0, 0)
    self:drawRect(enemy.x, enemy.y, enemy.w, enemy.h, 1, 0.48, 0.12, 0.12)
    self:drawRect(enemy.x + 3, enemy.y + 3, enemy.w - 6, enemy.h - 6, 1, 0.72, 0.28, 0.18)
    self:drawRect(enemy.x + 4, enemy.y + 5, enemy.w - 8, 2, 0.45, 1, 0.72, 0.38)
    self:drawRect(enemy.x + enemy.w * 0.5 - 2, enemy.y + enemy.h - 2, 4, 4, 1, 0.92, 0.60, 0.24)
end

function PZStarPilotGame:drawParticles()
    for i = 1, #self.particles do
        local p = self.particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        self:drawRect(p.x, p.y, math.max(2, math.floor(alpha * 4)), math.max(2, math.floor(alpha * 4)), alpha, p.r, p.g, p.b)
    end
end

function PZStarPilotGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.008, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.26, 0.32, 0.46)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZStarPilotGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZStarPilotGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.008, 0.020)
    for i = 1, #self.stars do
        local star = self.stars[i]
        self:drawRect(star.x, star.y, star.size, star.size, 0.82, 0.60, 0.66, 0.82)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.hitFlash / 100, 0.34, 0.58, 0.72)
    end
    if self.damageFlash and self.damageFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.damageFlash / 85, 0.86, 0.12, 0.08)
    end
    self:drawHud()
    for i = 1, #self.collectibles do
        local item = self.collectibles[i]
        self:drawRect(item.x - 6, item.y - 6, 12, 12, 1, 0.04, 0.34, 0.62)
        self:drawRect(item.x - 3, item.y - 3, 6, 6, 1, 0.52, 0.78, 0.90)
    end
    for i = 1, #self.bullets do
        local bullet = self.bullets[i]
        self:drawRect(bullet.x - 1, bullet.y - 8, 2, 10, 1, 0.72, 1, 0.82)
    end
    for i = 1, #self.enemies do
        self:drawEnemy(self.enemies[i])
    end
    self:drawParticles()
    self:drawShip(self.player.x, self.player.y)
    if self.gameState == "GAMEOVER" then
        self:drawOverlay("SHIP LOST", "BEST " .. tostring(math.max(self.highscore, self.score)))
    end
    self:drawScanlines()
end

function PZStarPilotGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
