local difficulty = {}

local fontTitle, fontBtn
local btnEasy = { w = 200, h = 70, x = 0, y = 0 }
local btnNormal = { w = 200, h = 70, x = 0, y = 0 }
local btnHard = { w = 200, h = 70, x = 0, y = 0 }
local btnImpossible = { w = 200, h = 70, x = 0, y = 0 }
local btnBack = { w = 140, h = 55, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function drawSpacedText(text, x, y, w, align, font, spacing, alpha)
    alpha = alpha or 1
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local startX = x
    if align == "center" then
        startX = x + (w - tw) / 2
    elseif align == "right" then
        startX = x + (w - tw)
    end
    local shadow = 2
    love.graphics.setColor(0, 0, 0, alpha * 0.8)
    love.graphics.print(text, startX + shadow, y + shadow)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, startX, y)
end

function difficulty.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    local btnW = 200 * scale
    local btnH = 70 * scale
    local gap = 15 * scale

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

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 80 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function difficulty.resize()
    difficulty.load()
end

function difficulty.draw()
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("SELECT DIFFICULTY", 0, 60 * scale, w, "center", fontTitle, nil, 1)

    local function drawBtn(btn, label, color)
        love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
        love.graphics.rectangle("fill", btn.x + 5*scale, btn.y + 6*scale, btn.w, btn.h, 16*scale, 16*scale)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)
        drawSpacedText(label, btn.x, btn.y + 20*scale, btn.w, "center", fontBtn, nil, 1)
    end

    drawBtn(btnEasy, "EASY", {0.2, 0.6, 0.2})
    drawBtn(btnNormal, "NORMAL", {0.35, 0.15, 0.75})
    drawBtn(btnHard, "HARD", {0.8, 0.2, 0.2})
    drawBtn(btnImpossible, "IMPOSSIBLE", {0.9, 0.0, 0.0})

    -- Back
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function difficulty.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "mode_select"
        return
    end

    if x >= btnEasy.x and x <= btnEasy.x + btnEasy.w and y >= btnEasy.y and y <= btnEasy.y + btnEasy.h then
        playButtonSound()
        _G.difficulty = "easy"
        GameState.current = "game"
        return
    end

    if x >= btnNormal.x and x <= btnNormal.x + btnNormal.w and y >= btnNormal.y and y <= btnNormal.y + btnNormal.h then
        playButtonSound()
        _G.difficulty = "normal"
        GameState.current = "game"
        return
    end

    if x >= btnHard.x and x <= btnHard.x + btnHard.w and y >= btnHard.y and y <= btnHard.y + btnHard.h then
        playButtonSound()
        _G.difficulty = "hard"
        GameState.current = "game"
        return
    end

    if x >= btnImpossible.x and x <= btnImpossible.x + btnImpossible.w and y >= btnImpossible.y and y <= btnImpossible.y + btnImpossible.h then
        playButtonSound()
        _G.difficulty = "impossible"
        GameState.current = "game"
        return
    end
end

function difficulty.touchmoved() end
function difficulty.touchreleased() end

return difficulty
