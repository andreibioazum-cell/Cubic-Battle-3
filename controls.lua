local controls = {}

local joy  = { id = nil, cx = 0, cy = 0, sx = 0, sy = 0, r = 45, sr = 18 }
local atk  = { id = nil, x = 0, y = 0, r = 52, hold = false, press = 0 }
local back = { x = 20, y = 20, w = 140, h = 55 }
local ability = { id = nil, x = 0, y = 0, r = 40, press = 0, triggered = false }

local keys = { w = false, a = false, s = false, d = false, space = false, e = false }
local font
local aimDx, aimDy = 0, -1
local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local spaceJustPressed = false
local abilityJustPressed = false

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

local function place()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w, h) / 800   -- базовый размер для 800px ширины

    -- Адаптивные размеры
    joy.r = 45 * scale
    joy.sr = 18 * scale
    atk.r = 52 * scale
    ability.r = 40 * scale
    back.w = 140 * scale
    back.h = 55 * scale

    -- Позиции (отступы тоже масштабируем)
    local margin = 80 * scale
    joy.cx = margin
    joy.cy = h - margin
    if not joy.id then joy.sx, joy.sy = joy.cx, joy.cy end

    atk.x = w - margin
    atk.y = h - margin

    ability.x = atk.x - 70 * scale
    ability.y = atk.y

    back.x = (w - back.w) / 2
    back.y = 30 * scale
end

function controls.load()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w, h) / 800
    -- Размер шрифта тоже масштабируем
    local fontSize = math.max(16, 24 * scale)  -- минимум 16px
    font = love.graphics.newFont("Fredoka-Bold.ttf", fontSize)
    place()
end

function controls.resize()
    place()
    -- шрифт пересоздавать не обязательно, можно обновить размер в love.resize
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w, h) / 800
    local fontSize = math.max(16, 24 * scale)
    font = love.graphics.newFont("Fredoka-Bold.ttf", fontSize)
end

function controls.update(dt)
    local target = atk.hold and 1 or 0
    atk.press = atk.press + (target - atk.press) * math.min(dt * 12, 1)
    ability.press = ability.press * 0.9
end

-- ... остальные функции без изменений (getMove, touchpressed, keypressed и т.д.) ...
-- (они не зависят от размеров, только от координат, которые уже адаптированы)

function controls.draw()
    -- здесь используем адаптированные радиусы и позиции
    if isMobile then
        love.graphics.setLineWidth(2.55 * scale)  -- толщина линии тоже масштабируется

        -- Джойстик
        love.graphics.setColor(0, 0, 0, 0.20)
        love.graphics.circle("fill", joy.cx, joy.cy, joy.r)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("line", joy.cx, joy.cy, joy.r)
        love.graphics.circle("fill", joy.sx, joy.sy, joy.sr)

        -- Кнопка Shot
        local scale = 1 - atk.press * 0.12
        local r = atk.r * scale
        local textScale = 1 - atk.press * 0.18
        local textAlpha = 1 - atk.press * 0.45

        love.graphics.setColor(0.55 - atk.press * 0.2, 0.20, 0.85 - atk.press * 0.3, 1)
        love.graphics.circle("fill", atk.x, atk.y, r)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.circle("line", atk.x, atk.y, r)

        love.graphics.push()
        love.graphics.translate(atk.x, atk.y)
        love.graphics.scale(textScale, textScale)
        drawSpacedText("Shot", -atk.r, -14 * scale, atk.r * 2, "center", font, nil, textAlpha)
        love.graphics.pop()

        -- Кнопка Resurrection
        local abScale = 1 - ability.press * 0.12
        local abR = ability.r * abScale
        love.graphics.setColor(0.8, 0.2, 0.9, 1)
        love.graphics.circle("fill", ability.x, ability.y, abR)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.circle("line", ability.x, ability.y, abR)

        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("R", ability.x - abR/2, ability.y - 14 * scale, abR * 2, "center")
    end

    -- Кнопка Back
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", back.x + 4*scale, back.y + 5*scale, back.w, back.h, 14*scale, 14*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 14*scale, 14*scale)
    drawSpacedText("Back", back.x, back.y + 14*scale, back.w, "center", font, nil, 1)

    love.graphics.setColor(1, 1, 1, 1)
end

return controls
