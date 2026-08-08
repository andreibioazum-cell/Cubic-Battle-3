-- difficulty.lua – выбор сложности (с эффектом наведения)
local ui = require("ui")
local difficulty = {}

local fontTitle, fontBtn
local btnEasy = { w = 200, h = 70, x = 0, y = 0 }
local btnNormal = { w = 200, h = 70, x = 0, y = 0 }
local btnHard = { w = 200, h = 70, x = 0, y = 0 }
local btnImpossible = { w = 200, h = 70, x = 0, y = 0 }
local btnBack = { w = 140, h = 55, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local hoverBtn = nil
local animTime = 0

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

function difficulty.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    local btnW, btnH = ui.wideButton(w, h, scale)
    local gap = 18 * scale

    btnEasy.w = btnW; btnEasy.h = btnH
    btnNormal.w = btnW; btnNormal.h = btnH
    btnHard.w = btnW; btnHard.h = btnH
    btnImpossible.w = btnW; btnImpossible.h = btnH

    local totalH = btnH * 4 + gap * 3
    local startY = (h - totalH) / 2

    btnEasy.x = (w - btnW) / 2
    btnEasy.y = startY

    btnNormal.x = (w - btnW) / 2
    btnNormal.y = startY + btnH + gap

    btnHard.x = (w - btnW) / 2
    btnHard.y = startY + (btnH + gap) * 2

    btnImpossible.x = (w - btnW) / 2
    btnImpossible.y = startY + (btnH + gap) * 3

    btnBack.w = btnW
    btnBack.h = btnH
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - btnBack.h - 24 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = ui.buttonFontSize(scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function difficulty.resize()
    difficulty.load()
end

function difficulty.update(dt)
    animTime = animTime + dt
end

function difficulty.draw()
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    ui.drawSpacedText("SELECT DIFFICULTY", 0, 60 * scale, w, "center", fontTitle, nil, 1)

    -- Кнопки в стиле лобби; цвет сохраняется за каждым уровнем сложности.
    ui.drawButton(btnEasy, "EASY", hoverBtn == "easy", {0.2, 0.6, 0.2}, fontBtn)
    ui.drawButton(btnNormal, "NORMAL", hoverBtn == "normal", {0.2, 0.5, 0.9}, fontBtn)
    ui.drawButton(btnHard, "HARD", hoverBtn == "hard", {0.8, 0.2, 0.2}, fontBtn)
    ui.drawButton(btnImpossible, "IMPOSSIBLE", hoverBtn == "impossible", {0.9, 0.0, 0.0}, fontBtn)
    ui.drawButton(btnBack, "BACK", hoverBtn == "back", {0.2, 0.5, 0.9}, fontBtn)
end

function difficulty.mousemoved(x, y)
    if isMobile then return end
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnEasy) then hoverBtn = "easy"
    elseif isInside(btnNormal) then hoverBtn = "normal"
    elseif isInside(btnHard) then hoverBtn = "hard"
    elseif isInside(btnImpossible) then hoverBtn = "impossible"
    elseif isInside(btnBack) then hoverBtn = "back"
    else hoverBtn = nil end
end

function difficulty.touchpressed(id, x, y)
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnBack) then
        playButtonSound()
        GameState.current = "mode_select"
        return
    end

    if isInside(btnEasy) then
        playButtonSound()
        _G.difficulty = "easy"
        GameState.current = "game"
        return
    end

    if isInside(btnNormal) then
        playButtonSound()
        _G.difficulty = "normal"
        GameState.current = "game"
        return
    end

    if isInside(btnHard) then
        playButtonSound()
        _G.difficulty = "hard"
        GameState.current = "game"
        return
    end

    if isInside(btnImpossible) then
        playButtonSound()
        _G.difficulty = "impossible"
        GameState.current = "game"
        return
    end
end

function difficulty.touchmoved(id, x, y)
    if isMobile then
        local function isInside(btn)
            return x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h
        end
        
        if isInside(btnEasy) then hoverBtn = "easy"
        elseif isInside(btnNormal) then hoverBtn = "normal"
        elseif isInside(btnHard) then hoverBtn = "hard"
        elseif isInside(btnImpossible) then hoverBtn = "impossible"
        elseif isInside(btnBack) then hoverBtn = "back"
        else hoverBtn = nil end
    end
end

function difficulty.touchreleased(id, x, y)
    if isMobile then
        hoverBtn = nil
    end
end

return difficulty
