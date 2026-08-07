-- credits.lua – кредиты
local credits = {}

local fontTitle, fontText, fontBtn
local btnBack = { w = 200, h = 60, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local hoverBtn = nil
local animTime = 0

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 800 end
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

function credits.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnBack.w = 220 * scale
    btnBack.h = 65 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 120 * scale

    local titleSize = math.max(36, 56 * scale)
    local textSize  = math.max(20, 32 * scale)
    local btnSize   = math.max(22, 34 * scale)

    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontText  = love.graphics.newFont("Fredoka-Bold.ttf", textSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function credits.resize()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnBack.w = 220 * scale
    btnBack.h = 65 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 120 * scale

    local titleSize = math.max(36, 56 * scale)
    local textSize  = math.max(20, 32 * scale)
    local btnSize   = math.max(22, 34 * scale)

    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontText  = love.graphics.newFont("Fredoka-Bold.ttf", textSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function credits.update(dt)
    animTime = animTime + dt
end

function credits.draw()
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()
    local y = 80 * scale

    drawSpacedText("CREDITS", 0, y, w, "center", fontTitle)
    y = y + 80 * scale

    drawSpacedText("Developers:", 0, y, w, "center", fontText)
    y = y + 55 * scale
    drawSpacedText("Dima Saraev – Creator (10 years)", 0, y, w, "center", fontText)
    y = y + 50 * scale
    drawSpacedText("Dima Gustenyov – Owner (11 years)", 0, y, w, "center", fontText)

    local function drawButton(btn, text, isHover)
        local r, g, b = 0.25, 0.72, 0.68
        if isHover then
            r, g, b = 0.30, 0.78, 0.74
        end
        
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(math.max(3, 4 * scale))
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        
        drawSpacedText(text, btn.x, btn.y + 18*scale, btn.w, "center", fontBtn, nil, 1)
    end

    drawButton(btnBack, "BACK", hoverBtn == "back")
end

function credits.mousemoved(x, y)
    if isMobile then return end
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnBack) then
        hoverBtn = "back"
    else
        hoverBtn = nil
    end
end

function credits.touchpressed(id, x, y)
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnBack) then
        playButtonSound()
        GameState.current = "lobby"
    end
end

function credits.touchmoved(id, x, y)
    if isMobile then
        local function isInside(btn)
            return x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h
        end
        
        if isInside(btnBack) then
            hoverBtn = "back"
        else
            hoverBtn = nil
        end
    end
end

function credits.touchreleased(id, x, y)
    if isMobile then
        hoverBtn = nil
    end
end

return credits
