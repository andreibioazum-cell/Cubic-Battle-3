local credits = {}

local fontTitle, fontText, fontBtn
local btnBack = { w = 200, h = 60, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000        -- для ПК теперь 500
    if isMobile then
        base = 450
    end
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

function credits.load()
    local scale = getScale()

    btnBack.w = 220 * scale
    btnBack.h = 65 * scale
    local w, h = love.graphics.getDimensions()
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
    local scale = getScale()

    btnBack.w = 220 * scale
    btnBack.h = 65 * scale
    local w, h = love.graphics.getDimensions()
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 120 * scale

    local titleSize = math.max(36, 56 * scale)
    local textSize  = math.max(20, 32 * scale)
    local btnSize   = math.max(22, 34 * scale)

    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontText  = love.graphics.newFont("Fredoka-Bold.ttf", textSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function credits.draw()
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()
    local y = 80 * scale

    drawSpacedText("CREDITS", 0, y, w, "center", fontTitle)
    y = y + 80 * scale

    drawSpacedText("Developers:", 0, y, w, "center", fontText)
    y = y + 55 * scale
    drawSpacedText("Dima Saraev – Creator (10 yeаrs)", 0, y, w, "center", fontText)
    y = y + 50 * scale
    drawSpacedText("Dima Gustenyov – Owner (11 yeаrs)", 0, y, w, "center", fontText)
    y = y + 80 * scale

    drawSpacedText("Music:", 0, y, w, "center", fontText)
    y = y + 55 * scale
    drawSpacedText('"Sneaky Snitch" by Kevin MacLeod', 0, y, w, "center", fontText)
    y = y + 45 * scale
    drawSpacedText("(incompetech.com)", 0, y, w, "center", fontText)
    y = y + 45 * scale
    drawSpacedText("Licensed under CC: By Attribution 3.0", 0, y, w, "center", fontText)

    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.8 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("Back", btnBack.x, btnBack.y + 18*scale, btnBack.w, "center", fontBtn)
end

function credits.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "lobby"
    end
end

function credits.touchmoved() end
function credits.touchreleased() end

return credits
