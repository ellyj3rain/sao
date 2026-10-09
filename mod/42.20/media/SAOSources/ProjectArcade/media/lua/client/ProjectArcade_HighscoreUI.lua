ProjectArcade_HighscoreUI = ProjectArcade_HighscoreUI or {}

local DIGIT_BASE_W = 64
local DIGIT_BASE_H = 96
local DIGIT_SPACING = 8

local TITLE_MALE   = "pa_highscore_male.png"
local TITLE_FEMALE = "pa_highscore_female.png"

local TITLE_W = 942
local TITLE_H = 121

local SHOW_MS = 2500
local FADE_MS = 250

local active = false
local startMs = 0
local score = 0
local kind = "global" 
local alpha = 0

local screenWidth  = getCore():getScreenWidth()
local screenHeight = getCore():getScreenHeight()

local titleMaleTex, titleFemaleTex = nil, nil
local digitTex = {}

local function tex(path)
    
    return getTexture("media/textures/" .. path)
end

local function ensureTextures()
    if not titleMaleTex then   titleMaleTex   = tex(TITLE_MALE) end
    if not titleFemaleTex then titleFemaleTex = tex(TITLE_FEMALE) end

    if not digitTex[0] then
        digitTex[0] = tex("pa_highscore_number0.png")
        digitTex[1] = tex("pa_highscore_number1.png")
        digitTex[2] = tex("pa_highscore_number2.png")
        digitTex[3] = tex("pa_highscore_number3.png")
        digitTex[4] = tex("pa_highscore_number4.png")
        digitTex[5] = tex("pa_highscore_number5.png")
        digitTex[6] = tex("pa_highscore_number6.png")
        digitTex[7] = tex("pa_highscore_number7.png")
        digitTex[8] = tex("pa_highscore_number8.png")
        digitTex[9] = tex("pa_highscore_number9.png")
    end
end

local function pad5(n)
    n = tonumber(n) or 0
    if n < 0 then n = 0 end
    if n > 99999 then n = 99999 end
    return string.format("%05d", n)
end

local function computeScale()
    
    local sw = screenWidth
    local sh = screenHeight

    local scaleH = sh / 1080
    local scaleW = sw / 1920
    local s = math.min(scaleH, scaleW)
    s = math.max(0.75, math.min(s, 2.0))
    return s
end

local function getTitleTex()
    if kind == "male" then return titleMaleTex end
    if kind == "female" then return titleFemaleTex end
    
    return titleMaleTex
end

local function updateAlpha()
    local now = getTimestampMs()
    local elapsed = now - startMs

    if elapsed >= (FADE_MS + SHOW_MS + FADE_MS) then
        active = false
        alpha = 0
        return
    end

    if elapsed < FADE_MS then
        alpha = elapsed / FADE_MS
    elseif elapsed < (FADE_MS + SHOW_MS) then
        alpha = 1
    else
        local t = elapsed - (FADE_MS + SHOW_MS)
        alpha = 1 - (t / FADE_MS)
    end
end

local function draw()
    if not active then return end

    ensureTextures()
    updateAlpha()
    if not active then return end

    local a = alpha
    if a <= 0 then return end

    local s = computeScale()

    
    local digitW = DIGIT_BASE_W * s
    local digitH = DIGIT_BASE_H * s
    local spacing = DIGIT_SPACING * s

    local titleW = TITLE_W * s
    local titleH = TITLE_H * s

    local totalDigitsW = (5 * digitW) + (4 * spacing)

    
    local blockW = math.max(titleW, totalDigitsW)
    local blockH = titleH + (18 * s) + digitH

    local x0 = (screenWidth - blockW) / 2
    local y0 = (screenHeight - blockH) / 2

    
    local tTex = getTitleTex()
    if tTex then
        local tx = x0 + (blockW - titleW) / 2
        UIManager.DrawTexture(tTex, tx, y0, titleW, titleH, a)
    end

    
    local digits = pad5(score)
    local dx = x0 + (blockW - totalDigitsW) / 2
    local dy = y0 + titleH + (18 * s)

    for i = 1, 5 do
        local d = tonumber(digits:sub(i, i))
        local dTex = digitTex[d]
        if dTex then
            UIManager.DrawTexture(dTex, dx + (i - 1) * (digitW + spacing), dy, digitW, digitH, a)
        end
    end
end


Events.OnPreUIDraw.Add(draw) 


local function onResChange(w, h)
    screenWidth = w
    screenHeight = h
end
Events.OnResolutionChange.Add(onResChange) 


function ProjectArcade_HighscoreUI.Show(newScore, newKind)
    score = tonumber(newScore) or 0
    kind = newKind or "global"
    startMs = getTimestampMs()
    alpha = 0
    active = true
end
