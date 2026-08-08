-- mode_select.lua – выбор режима (с эффектом наведения)
local mode_select = {}

local fontTitle, fontBtn
local btnSingle = { w = 220, h = 75, x = 0, y = 0 }
local btnMulti  = { w = 220, h = 75, x = 0, y = 0 }
local btnBack   = { w = 140, h = 55, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local hoverBtn = nil
local animTime = 0

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
    local o = math.max(1.5, math.floor(2 * (scale or 1)))
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.print(text, startX - o, y)
    love.graphics.print(text, startX + o, y)
    love.graphics.print(text, startX, y - o)
    love.graphics.print(text, startX, y + o)
    love.graphics.print(text, startX - o, y - o)
    love.graphics.print(text, startX + o, y - o)
    love.graphics.print(text, startX - o, y + o)
    love.graphics.print(text, startX + o, y + o)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, startX, y)
end

function mode_select.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    local wideW = math.min(610 * scale, w - 32 * scale)
    local wideH = 100 * scale
    btnSingle.w = wideW; btnSingle.h = wideH
    btnMulti.w  = wideW; btnMulti.h = wideH
    btnBack.w   = wideW; btnBack.h = wideH

    btnSingle.x = (w - btnSingle.w) / 2
    btnSingle.y = h/2 - 180 * scale

    btnMulti.x = (w - btnMulti.w) / 2
    btnMulti.y = btnSingle.y + wideH + 18 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - btnBack.h - 24 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function mode_select.resize()
    mode_select.load()
end

function mode_select.update(dt)
    animTime = animTime + dt
end

function mode_select.draw()
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("SELECT MODE", 0, 120 * scale, w, "center", fontTitle, nil, 1)

    local function drawButton(btn, text, isHover)
        local r, g, b = 0.31, 0.73, 0.72 -- #50BBBA из референса
        if isHover then
            r, g, b = 0.38, 0.80, 0.79
        end

        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(math.max(2, 3 * scale))
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

        drawSpacedText(text, btn.x + 16 * scale, btn.y + (btn.h - fontBtn:getHeight()) / 2, btn.w - 32 * scale, "left", fontBtn, nil, 1)
    end

    drawButton(btnSingle, "SINGLEPLAYER", hoverBtn == "single")
    drawButton(btnMulti, "MULTIPLAYER", hoverBtn == "multi")
    drawButton(btnBack, "BACK", hoverBtn == "back")

    local time = love.timer.getTime()
    local yOffset = math.sin(time * 1.2) * 1.5

    local text = "Online is still being developed, it may be very weak, so don't throw slippers at us."
    love.graphics.setFont(fontBtn)
    local tw = fontBtn:getWidth(text)
    local x = w/2 - tw/2
    local y = btnMulti.y + btnMulti.h + 30 * scale + yOffset

    local pad = 12 * scale
    local btnW = tw + pad * 2
    local btnH = 30 * scale
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", x - pad, y - 4*scale, btnW, btnH, 8*scale, 8*scale)
    love.graphics.setColor(0.15, 0.35, 0.7, 1)
    love.graphics.rectangle("fill", x - pad, y - 4*scale, btnW, btnH, 8*scale, 8*scale)

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(text, x + 2, y + 2)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(text, x, y)
end

function mode_select.mousemoved(x, y)
    if isMobile then return end
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnSingle) then
        hoverBtn = "single"
    elseif isInside(btnMulti) then
        hoverBtn = "multi"
    elseif isInside(btnBack) then
        hoverBtn = "back"
    else
        hoverBtn = nil
    end
end

function mode_select.touchpressed(id, x, y)
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnBack) then
        playButtonSound()
        GameState.current = "lobby"
        return
    end

    if isInside(btnSingle) then
        playButtonSound()
        GameState.current = "difficulty"
        return
    end

    if isInside(btnMulti) then
        playButtonSound()
        if not isMobile then
            love.window.setFullscreen(true, "desktop")
        end
        GameState.current = "game_online"
        return
    end
end

function mode_select.touchmoved(id, x, y)
    if isMobile then
        local function isInside(btn)
            return x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h
        end
        
        if isInside(btnSingle) then
            hoverBtn = "single"
        elseif isInside(btnMulti) then
            hoverBtn = "multi"
        elseif isInside(btnBack) then
            hoverBtn = "back"
        else
            hoverBtn = nil
        end
    end
end

function mode_select.touchreleased(id, x, y)
    if isMobile then
        hoverBtn = nil
    end
end

return mode_select
