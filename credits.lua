local credits = {}

local fontTitle, fontText, fontBtn
local btnBack = { w = 200, h = 60, x = 0, y = 0 }

-- Draw text with a shadow effect (no per‑character loop)
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
    local w, h = love.graphics.getDimensions()
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 100
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", 48)
    fontText  = love.graphics.newFont("Fredoka-Bold.ttf", 28)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", 30)
end

function credits.resize()
    local w, h = love.graphics.getDimensions()
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 100
end

function credits.draw()
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local y = 100

    drawSpacedText("=== CREDITS ===", 0, y, w, "center", fontTitle)
    y = y + 80

    drawSpacedText("Developers:", 0, y, w, "center", fontText)
    y = y + 50
    drawSpacedText("Dima Saraev – Creator (10 years)", 0, y, w, "center", fontText)
    y = y + 45
    drawSpacedText("Dima Gustenyov – Owner (11 years)", 0, y, w, "center", fontText)
    y = y + 70

    drawSpacedText("Music:", 0, y, w, "center", fontText)
    y = y + 50
    drawSpacedText('"Sneaky Snitch" by Kevin MacLeod', 0, y, w, "center", fontText)
    y = y + 40
    drawSpacedText("(incompetech.com)", 0, y, w, "center", fontText)
    y = y + 40
    drawSpacedText("Licensed under Creative Commons: By Attribution 3.0", 0, y, w, "center", fontText)

    -- Back button
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4, btnBack.y + 5, btnBack.w, btnBack.h, 14, 14)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14, 14)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14, 14)
    drawSpacedText("Back", btnBack.x, btnBack.y + 16, btnBack.w, "center", fontBtn)
end

function credits.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        GameState.current = "lobby"
    end
end

function credits.touchmoved() end
function credits.touchreleased() end

return credits
