-- credits.lua – кредиты
local ui = require("ui")
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

function credits.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnBack.w, btnBack.h = ui.wideButton(w, h, scale)
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - btnBack.h - 24 * scale

    local titleSize = math.max(36, 56 * scale)
    local textSize  = math.max(20, 32 * scale)
    local btnSize   = ui.buttonFontSize(scale)

    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontText  = love.graphics.newFont("Fredoka-Bold.ttf", textSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function credits.resize()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnBack.w, btnBack.h = ui.wideButton(w, h, scale)
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - btnBack.h - 24 * scale

    local titleSize = math.max(36, 56 * scale)
    local textSize  = math.max(20, 32 * scale)
    local btnSize   = ui.buttonFontSize(scale)

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

    ui.drawSpacedText("CREDITS", 0, y, w, "center", fontTitle)
    y = y + 80 * scale

    ui.drawSpacedText("Developers:", 0, y, w, "center", fontText)
    y = y + 55 * scale
    ui.drawSpacedText("Dima Saraev – Creator (10 years)", 0, y, w, "center", fontText)
    y = y + 50 * scale
    ui.drawSpacedText("Dima Gustenyov – Owner (11 years)", 0, y, w, "center", fontText)

    -- Кнопка в стиле лобби
    ui.drawButton(btnBack, "BACK", hoverBtn == "back", nil, fontBtn)
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
