local lobby = {}

local btns = {
    play = { w = 220, h = 75, x = 0, y = 0 },
    shop = { w = 220, h = 75, x = 0, y = 0 },
    credits = { w = 160, h = 55, x = 0, y = 0 }  -- новая кнопка
}
local fontTitle, fontSub, fontBtn
local spaceCanvas
local stars = {}

local function mkGrad(w, h)
    return love.graphics.newMesh({
        {0, 0, 0, 0, 0.02, 0.00, 0.10, 1},
        {w, 0, 1, 0, 0.00, 0.05, 0.25, 1},
        {w, h, 1, 1, 0.10, 0.15, 0.45, 1},
        {0, h, 0, 1, 0.05, 0.10, 0.35, 1}
    }, "fan", "static")
end

local function generateStars(w, h)
    stars = {}
    for i = 1, 100 do
        table.insert(stars, {
            x = math.random(w),
            y = math.random(h),
            size = math.random(1, 3),
            alpha = math.random(50, 100) / 100,
            speed = 40 + math.random(80)
        })
    end
end

local function generateSpace(w, h)
    spaceCanvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(spaceCanvas)
    love.graphics.draw(mkGrad(w, h), 0, 0)
    love.graphics.setCanvas()
end

local function place()
    local w, h = love.graphics.getDimensions()
    btns.play.x = w / 2 - btns.play.w - 20
    btns.play.y = h / 2 + 50
    btns.shop.x = w / 2 + 20
    btns.shop.y = h / 2 + 50
    btns.credits.x = w / 2 - btns.credits.w / 2
    btns.credits.y = h / 2 + 140   -- ниже кнопок Play/Shop
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

function lobby.load()
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", 64)
    fontSub   = love.graphics.newFont("Fredoka-Bold.ttf", 22)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", 30)
    local w, h = love.graphics.getDimensions()
    generateSpace(w, h)
    generateStars(w, h)
    place()
end

function lobby.resize(w, h)
    generateSpace(w, h)
    generateStars(w, h)
    place()
end

function lobby.update(dt)
    local w, h = love.graphics.getDimensions()
    for _, s in ipairs(stars) do
        s.x = s.x + s.speed * dt
        s.y = s.y + s.speed * dt
        if s.x > w or s.y > h then
            if math.random() > 0.5 then
                s.x = math.random(-50, 0)
                s.y = math.random(0, h)
            else
                s.x = math.random(0, w)
                s.y = math.random(-50, 0)
            end
        end
    end
end

function lobby.draw()
    love.graphics.setColor(1, 1, 1, 1)
    if spaceCanvas then love.graphics.draw(spaceCanvas, 0, 0) end

    for _, s in ipairs(stars) do
        love.graphics.setColor(1, 1, 1, s.alpha)
        love.graphics.rectangle("fill", s.x, s.y, s.size, s.size)
    end

    drawSpacedText("Cubic Battle", 0, love.graphics.getHeight() / 2 - 150, love.graphics.getWidth(), "center", fontTitle)
    drawSpacedText("Touch & Dodge", 0, love.graphics.getHeight() / 2 - 60, love.graphics.getWidth(), "center", fontSub)

    -- Кнопка Play
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btns.play.x + 5, btns.play.y + 6, btns.play.w, btns.play.h, 16, 16)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btns.play.x, btns.play.y, btns.play.w, btns.play.h, 16, 16)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", btns.play.x, btns.play.y, btns.play.w, btns.play.h, 16, 16)
    drawSpacedText("Play", btns.play.x, btns.play.y + 20, btns.play.w, "center", fontBtn)

    -- Кнопка Shop
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btns.shop.x + 5, btns.shop.y + 6, btns.shop.w, btns.shop.h, 16, 16)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btns.shop.x, btns.shop.y, btns.shop.w, btns.shop.h, 16, 16)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", btns.shop.x, btns.shop.y, btns.shop.w, btns.shop.h, 16, 16)
    drawSpacedText("Shop", btns.shop.x, btns.shop.y + 20, btns.shop.w, "center", fontBtn)

    -- Кнопка Credits
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btns.credits.x + 5, btns.credits.y + 6, btns.credits.w, btns.credits.h, 14, 14)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btns.credits.x, btns.credits.y, btns.credits.w, btns.credits.h, 14, 14)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", btns.credits.x, btns.credits.y, btns.credits.w, btns.credits.h, 14, 14)
    drawSpacedText("Credits", btns.credits.x, btns.credits.y + 14, btns.credits.w, "center", fontBtn)
end

function lobby.touchpressed(id, x, y)
    if x >= btns.play.x and x <= btns.play.x + btns.play.w and y >= btns.play.y and y <= btns.play.y + btns.play.h then
        GameState.current = "game"
    elseif x >= btns.shop.x and x <= btns.shop.x + btns.shop.w and y >= btns.shop.y and y <= btns.shop.y + btns.shop.h then
        GameState.current = "shop"
    elseif x >= btns.credits.x and x <= btns.credits.x + btns.credits.w and y >= btns.credits.y and y <= btns.credits.y + btns.credits.h then
        GameState.current = "credits"
    end
end

function lobby.touchmoved() end
function lobby.touchreleased() end

return lobby
