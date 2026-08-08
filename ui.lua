-- ui.lua – общие элементы интерфейса в стиле лобби
-- Все кнопки игры рисуются так же, как в главном меню (лобби):
-- широкая заливка, тонкая чёрная рамка и крупная подпись у левого края.
local ui = {}

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

function ui.getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

function ui.drawSpacedText(text, x, y, w, align, font, alpha)
    alpha = alpha or 1
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local startX = x
    if align == "center" then
        startX = x + (w - tw) / 2
    elseif align == "right" then
        startX = x + (w - tw)
    end
    local o = 2
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

-- Ширина и высота широкой кнопки как в лобби (610 × 100 при масштабе 1).
function ui.wideButton(w, h, scale)
    return math.min(610 * scale, w - 32 * scale), 100 * scale
end

-- Размер шрифта кнопки как в лобби (54 при масштабе 1).
function ui.buttonFontSize(scale)
    return math.max(22, 54 * scale)
end

-- Отрисовка кнопки в стиле лобби.
-- color – цвет заливки (по умолчанию бирюзовый #50BBBA, как в лобби);
-- align – выравнивание подписи ("left" как в лобби или "center" для маленьких кнопок).
function ui.drawButton(btn, label, isHover, color, font, align)
    local r, g, b = 0.31, 0.73, 0.72
    if color then
        r, g, b = color[1], color[2], color[3]
    end
    if isHover then
        r = math.min(1, r + 0.07)
        g = math.min(1, g + 0.07)
        b = math.min(1, b + 0.07)
    end

    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)

    love.graphics.setColor(0, 0, 0, 1)
    local scale = ui.getScale()
    love.graphics.setLineWidth(math.max(2, 3 * scale))
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

    local padding = 16 * scale
    align = align or "left"
    local textY = btn.y + (btn.h - font:getHeight()) / 2
    ui.drawSpacedText(label, btn.x + padding, textY, btn.w - padding * 2, align, font)
end

return ui
