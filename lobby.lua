local lobby = {}

local btns = {
    play = { w = 220, h = 75, x = 0, y = 0 },
    shop = { w = 220, h = 75, x = 0, y = 0 },
    settings = { w = 220, h = 75, x = 0, y = 0 },
    credits = { w = 220, h = 75, x = 0, y = 0 }
}
local fontTitle, fontSub, fontBtn
local backgroundImage   -- загруженная картинка
local snowflakes = {}   -- синие снежинки

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function place()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()
    local gap = 20 * scale
    local btnW = 220 * scale
    local btnH = 75 * scale

    for _, b in pairs(btns) do
        b.w = btnW
        b.h = btnH
    end

    btns.play.x = w/2 - btnW - gap/2
    btns.play.y = h/2 + 80 * scale
    btns.shop.x = w/2 + gap/2
    btns.shop.y = h/2 + 80 * scale

    btns.settings.x = w/2 - btnW - gap/2
    btns.settings.y = h/2 + 80 * scale + btnH + gap
    btns.credits.x = w/2 + gap/2
    btns.credits.y = h/2 + 80 * scale + btnH + gap
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

-- Генерация синих снежинок (падают вниз)
local function generateSnowflakes(w, h)
    snowflakes = {}
    for i = 1, 120 do
        table.insert(snowflakes, {
            x = math.random(w),
            y = math.random(h),
            size = math.random(2, 5),
            speed = 30 + math.random(70),
            wobble = math.random() * 2 - 1,
            phase = math.random() * 2 * math.pi
        })
    end
end

function lobby.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    -- Загружаем фоновую картинку
    backgroundImage = love.graphics.newImage("Lobby_Snow.png")

    local titleSize = math.max(36, 72 * scale)
    local subSize   = math.max(18, 26 * scale)
    local btnSize   = math.max(22, 34 * scale)

    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontSub   = love.graphics.newFont("Fredoka-Bold.ttf", subSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)

    generateSnowflakes(w, h)
    place()
end

function lobby.resize(w, h)
    generateSnowflakes(w, h)
    place()
    local scale = getScale()
    local titleSize = math.max(36, 72 * scale)
    local subSize   = math.max(18, 26 * scale)
    local btnSize   = math.max(22, 34 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontSub   = love.graphics.newFont("Fredoka-Bold.ttf", subSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function lobby.update(dt)
    local w, h = love.graphics.getDimensions()
    for _, s in ipairs(snowflakes) do
        s.y = s.y + s.speed * dt
        s.x = s.x + math.sin(s.phase + love.timer.getTime() * 0.5) * 20 * dt
        if s.y > h + 10 then
            s.y = -10
            s.x = math.random(w)
        end
    end
end

function lobby.draw()
    -- Фон – картинка, растянутая на весь экран
    if backgroundImage then
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(backgroundImage, 0, 0, 0, w / backgroundImage:getWidth(), h / backgroundImage:getHeight())
    end

    -- Синие снежинки (поверх картинки)
    for _, s in ipairs(snowflakes) do
        local alpha = 0.4 + 0.6 * (1 - s.y / love.graphics.getHeight())
        love.graphics.setColor(0.5, 0.8, 1.0, alpha)
        love.graphics.circle("fill", s.x, s.y, s.size)
    end

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("Cubic Battle", 0, love.graphics.getHeight()/2 - 180*scale, w, "center", fontTitle)
    drawSpacedText("Touch & Dodge", 0, love.graphics.getHeight()/2 - 80*scale, w, "center", fontSub)

    -- Кнопки (синие, с чёрной обводкой)
    for name, btn in pairs(btns) do
        local label = name:gsub("^%l", string.upper)

        -- Тень
        love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
        love.graphics.rectangle("fill", btn.x + 5*scale, btn.y + 6*scale, btn.w, btn.h, 16*scale, 16*scale)

        -- Заливка синяя
        love.graphics.setColor(0.2, 0.5, 0.9, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)

        -- ЧЁРНАЯ ОБВОДКА
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.8 * scale)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)

        -- Текст
        drawSpacedText(label, btn.x, btn.y + 22*scale, btn.w, "center", fontBtn)
    end
end

function lobby.touchpressed(id, x, y)
    if x >= btns.play.x and x <= btns.play.x + btns.play.w and y >= btns.play.y and y <= btns.play.y + btns.play.h then
        playButtonSound()
        GameState.current = "mode_select"
    elseif x >= btns.shop.x and x <= btns.shop.x + btns.shop.w and y >= btns.shop.y and y <= btns.shop.y + btns.shop.h then
        playButtonSound()
        GameState.current = "shop"
    elseif x >= btns.settings.x and x <= btns.settings.x + btns.settings.w and y >= btns.settings.y and y <= btns.settings.y + btns.settings.h then
        playButtonSound()
        GameState.current = "settings"
    elseif x >= btns.credits.x and x <= btns.credits.x + btns.credits.w and y >= btns.credits.y and y <= btns.credits.y + btns.credits.h then
        playButtonSound()
        GameState.current = "credits"
    end
end

function lobby.touchmoved() end
function lobby.touchreleased() end

return lobby
