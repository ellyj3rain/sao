-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

local asteroidTexture = getTexture("media/textures/asteroid.png")

PZAsteroidsGame = ISPanel:derive("PZAsteroidsGame")

function PZAsteroidsGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:buildStarfield()
    self:resetGame()
end

function PZAsteroidsGame:buildStarfield()
    self.stars = {}
    for i = 1, 58 do
        self.stars[#self.stars + 1] = {
            x = ZombRand(1000) / 1000,
            y = ZombRand(1000) / 1000,
            s = 1 + ZombRand(2),
            a = 0.25 + ZombRand(55) / 100
        }
    end
end

function PZAsteroidsGame:spawnRock(radius)
    local rock = {vx = (ZombRand(100) - 50) / 30, vy = (ZombRand(100) - 50) / 30, r = radius, spin = ZombRand(100)}
    rock.x = radius + ZombRand(math.max(1, self.width - radius * 2))
    rock.y = radius + ZombRand(math.max(1, self.height - radius * 2))
    return rock
end

function PZAsteroidsGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.flashTick = 0
    self.hitFlash = 0
    self.ship = {x = self.width * 0.5, y = self.height * 0.6, a = -1.57, vx = 0, vy = 0}
    self.bullets = {}
    self.rocks = {}
    self.particles = {}
    self.score = 0
    self.fireCooldown = 0
    self.thrustGlow = 0
    for i = 1, 6 do
        self.rocks[#self.rocks + 1] = self:spawnRock(11 + ZombRand(10))
    end
end

function PZAsteroidsGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZAsteroidsGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZAsteroidsGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZAsteroidsGame:wrap(obj)
    if obj.x < 0 then obj.x = self.width end
    if obj.x > self.width then obj.x = 0 end
    if obj.y < 0 then obj.y = self.height end
    if obj.y > self.height then obj.y = 0 end
end

function PZAsteroidsGame:wrapRock(rock)
    local r = rock.r or 10
    if rock.x < r then rock.x = self.width - r end
    if rock.x > self.width - r then rock.x = r end
    if rock.y < r then rock.y = self.height - r end
    if rock.y > self.height - r then rock.y = r end
end

function PZAsteroidsGame:limitShipSpeed()
    local speed = math.sqrt(self.ship.vx * self.ship.vx + self.ship.vy * self.ship.vy)
    if speed > 4.4 then
        local scale = 4.4 / speed
        self.ship.vx = self.ship.vx * scale
        self.ship.vy = self.ship.vy * scale
    end
end

function PZAsteroidsGame:emitParticles(x, y, count, r, g, b)
    for i = 1, count do
        local life = 14 + ZombRand(20)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1000) - 500) / 160,
            vy = (ZombRand(1000) - 500) / 160,
            life = life,
            maxLife = life,
            r = r,
            g = g,
            b = b
        }
    end
end

function PZAsteroidsGame:updateParticles()
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

function PZAsteroidsGame:update()
    self.flashTick = ((self.flashTick or 0) + 1) % 240
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self:updateParticles()

    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.ship.a = self.ship.a - 0.11
    end
    if ComputerModGameInput.isDown(self, "right") then
        self.ship.a = self.ship.a + 0.11
    end
    if ComputerModGameInput.isDown(self, "up") then
        self.ship.vx = self.ship.vx + math.cos(self.ship.a) * 0.22
        self.ship.vy = self.ship.vy + math.sin(self.ship.a) * 0.22
        self.thrustGlow = 4
    else
        self.thrustGlow = math.max(0, self.thrustGlow - 1)
    end
    if ComputerModGameInput.isDown(self, "down") then
        self.ship.vx = self.ship.vx * 0.92
        self.ship.vy = self.ship.vy * 0.92
    end

    self.ship.x = self.ship.x + self.ship.vx
    self.ship.y = self.ship.y + self.ship.vy
    self.ship.vx = self.ship.vx * 0.96
    self.ship.vy = self.ship.vy * 0.96
    self:limitShipSpeed()
    self:wrap(self.ship)

    if self.fireCooldown > 0 then
        self.fireCooldown = self.fireCooldown - 1
    end
    if ComputerModGameInput.isDown(self, "action") and self.fireCooldown <= 0 then
        self.fireCooldown = 8
        self.bullets[#self.bullets + 1] = {
            x = self.ship.x + math.cos(self.ship.a) * 10,
            y = self.ship.y + math.sin(self.ship.a) * 10,
            vx = self.ship.vx + math.cos(self.ship.a) * 6.4,
            vy = self.ship.vy + math.sin(self.ship.a) * 6.4,
            life = 34
        }
        self:playSound("ComputerLaserShot")
    end

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.x = bullet.x + bullet.vx
        bullet.y = bullet.y + bullet.vy
        bullet.life = bullet.life - 1
        if bullet.life <= 0 or bullet.x < 2 or bullet.x > self.width - 2 or bullet.y < 2 or bullet.y > self.height - 2 then
            table.remove(self.bullets, i)
        end
    end

    for i = #self.rocks, 1, -1 do
        local rock = self.rocks[i]
        rock.x = rock.x + rock.vx
        rock.y = rock.y + rock.vy
        rock.spin = (rock.spin or 0) + 1
        self:wrapRock(rock)

        local dx = rock.x - self.ship.x
        local dy = rock.y - self.ship.y
        if dx * dx + dy * dy < (rock.r + 7) * (rock.r + 7) then
            self.gameState = "GAMEOVER"
            if self.score > self.highscore then self.highscore = self.score end
            self:emitParticles(self.ship.x, self.ship.y, 24, 0.82, 0.72, 0.45)
            self:playGameOverSound()
            return
        end

        for j = #self.bullets, 1, -1 do
            local bullet = self.bullets[j]
            local bx = rock.x - bullet.x
            local by = rock.y - bullet.y
            if bx * bx + by * by < rock.r * rock.r then
                self.score = self.score + 15
                self.hitFlash = 5
                self:emitParticles(rock.x, rock.y, 12, 0.60, 0.62, 0.66)
                self:playSound("ComputerBallHit")
                table.remove(self.bullets, j)
                if rock.r > 11 then
                    for k = 1, 2 do
                        local split = self:spawnRock(math.max(8, math.floor(rock.r * 0.62)))
                        split.x = rock.x
                        split.y = rock.y
                        split.vx = (ZombRand(100) - 50) / 22
                        split.vy = (ZombRand(100) - 50) / 22
                        self.rocks[#self.rocks + 1] = split
                    end
                end
                table.remove(self.rocks, i)
                break
            end
        end
    end

    if #self.rocks == 0 then
        self.gameState = "WIN"
        if self.score > self.highscore then self.highscore = self.score end
        self:playWinSound()
    end
end

function PZAsteroidsGame:drawHud()
    self:drawRect(0, 0, self.width, 24, 1, 0.006, 0.008, 0.018)
    self:drawRect(0, 23, self.width, 1, 1, 0.28, 0.30, 0.42)
    self:drawText("ASTEROIDS.EXE", 10, 7, 0.70, 0.74, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 138, 7, 0.70, 0.74, 0.88, 1, UIFont.Small)
    self:drawText("ROCKS " .. tostring(#self.rocks), self.width - 74, 7, 0.70, 0.74, 0.88, 1, UIFont.Small)
end

function PZAsteroidsGame:drawShip()
    local sx = self.ship.x
    local sy = self.ship.y
    local nx = math.cos(self.ship.a)
    local ny = math.sin(self.ship.a)
    local wx = math.cos(self.ship.a + 1.57)
    local wy = math.sin(self.ship.a + 1.57)
    self:drawRect(sx + nx * 8 - 2, sy + ny * 8 - 2, 4, 4, 1, 0.86, 0.90, 0.95)
    self:drawRect(sx - wx * 6 - 2, sy - wy * 6 - 2, 4, 4, 1, 0.56, 0.66, 0.82)
    self:drawRect(sx + wx * 6 - 2, sy + wy * 6 - 2, 4, 4, 1, 0.56, 0.66, 0.82)
    self:drawRect(sx - 3, sy - 3, 6, 6, 1, 0.70, 0.78, 0.88)
    if self.thrustGlow > 0 then
        self:drawRect(sx - nx * 9 - 2, sy - ny * 9 - 2, 4, 4, 1, 0.94, 0.56, 0.20)
        self:drawRect(sx - nx * 14 - 1, sy - ny * 14 - 1, 2, 2, 0.70, 0.94, 0.80, 0.24)
    end
end

function PZAsteroidsGame:drawRock(rock)
    if asteroidTexture then
        self:drawTextureScaled(asteroidTexture, rock.x - rock.r, rock.y - rock.r, rock.r * 2, rock.r * 2, 0.92, 0.72, 0.72, 0.72)
    else
        self:drawRect(rock.x - rock.r, rock.y - rock.r, rock.r * 2, rock.r * 2, 1, 0.36, 0.36, 0.40)
    end
    self:drawRect(rock.x - rock.r * 0.55, rock.y - rock.r * 0.25, rock.r * 0.72, 2, 0.28, 0.88, 0.88, 0.82)
    self:drawRect(rock.x + rock.r * 0.10, rock.y + rock.r * 0.32, rock.r * 0.42, 2, 0.20, 0.22, 0.22, 0.24)
    self:drawRect(rock.x - 1, rock.y - 1, 2, 2, 0.36, 0.12, 0.12, 0.14)
end

function PZAsteroidsGame:drawParticles()
    for i = 1, #self.particles do
        local p = self.particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        self:drawRect(p.x, p.y, math.max(2, math.floor(alpha * 4)), math.max(2, math.floor(alpha * 4)), alpha, p.r, p.g, p.b)
    end
end

function PZAsteroidsGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 78
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.05, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.008, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.28, 0.30, 0.42)
    self:drawText(title, boxX + 10, boxY + 20, 0.70, 0.74, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 42, 0.78, 0.78, 0.60, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 59, 0.70, 0.74, 0.88, 1, UIFont.Small)
end

function PZAsteroidsGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZAsteroidsGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.008, 0.020)
    for i = 1, #self.stars do
        local star = self.stars[i]
        local alpha = star.a * (0.72 + math.sin(((self.flashTick or 0) + i * 7) / 24) * 0.20)
        self:drawRect(star.x * self.width, star.y * self.height, star.s, star.s, alpha, 0.70, 0.72, 0.82)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 24, self.width, self.height - 24, self.hitFlash / 100, 0.58, 0.58, 0.72)
    end

    self:drawHud()

    for i = 1, #self.rocks do
        self:drawRock(self.rocks[i])
    end

    for i = 1, #self.bullets do
        local bullet = self.bullets[i]
        self:drawRect(bullet.x - 1, bullet.y - 1, 3, 3, 1, 0.92, 0.84, 0.44)
    end

    self:drawParticles()
    self:drawShip()

    if self.gameState == "WIN" then
        self:drawOverlay("SECTOR CLEAR", "SCORE " .. tostring(self.score))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("SHIP LOST", "BEST " .. tostring(math.max(self.highscore, self.score)))
    end

    self:drawScanlines()
end

function PZAsteroidsGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
