local controls = {}

-- ========== КЛАВИАТУРНОЕ УПРАВЛЕНИЕ ==========
local keys = {
    w = false,
    a = false,
    s = false,
    d = false,
    space = false
}

local aimDx, aimDy = 0, -1
local spacePressed = false
local spaceHeld = false

-- Кнопка назад (только для мобильных)
local back = { x=0, y=0, w=140, h=55 }
local showBack = false

function controls.load()
    local w, h = love.graphics.getDimensions()
    back.x = w - back.w - 20
    back.y = h - back.h - 20
    
    -- Показываем кнопку Back только на мобильных
    showBack = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
end

function controls.resize()
    local w, h = love.graphics.getDimensions()
    back.x = w - back.w - 20
    back.y = h - back.h - 20
end

function controls.update(dt)
    -- Обновляем состояние пробела
    spaceHeld = keys.space
end

function controls.getMove()
    local dx, dy = 0, 0
    
    if keys.w then dy = dy - 1 end
    if keys.s then dy = dy + 1 end
    if keys.a then dx = dx - 1 end
    if keys.d then dx = dx + 1 end
    
    -- Нормализуем вектор
    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then
        dx = dx / len
        dy = dy / len
        -- Запоминаем направление для прицела
        aimDx, aimDy = dx, dy
    end
    
    return dx, dy
end

function controls.isAiming()
    return keys.space
end

function controls.getAim()
    return aimDx, aimDy
end

function controls.touchpressed(id, x, y)
    -- Проверяем нажатие на кнопку Back (для мобильных)
    if showBack and x >= back.x and x <= back.x + back.w and
       y >= back.y and y <= back.y + back.h then
        GameState.current = "lobby"
        return true
    end
    return false
end

function controls.touchmoved(id, x, y)
    -- Не используется на ПК
end

function controls.touchreleased(id, x, y)
    -- Используется только для мобильных
    return false, aimDx, aimDy
end

-- ========== КЛАВИАТУРНЫЕ СОБЫТИЯ ==========
function controls.keypressed(key)
    if key == "w" then keys.w = true end
    if key == "a" then keys.a = true end
    if key == "s" then keys.s = true end
    if key == "d" then keys.d = true end
    if key == "space" then
        keys.space = true
        spacePressed = true
    end
end

function controls.keyreleased(key)
    if key == "w" then keys.w = false end
    if key == "a" then keys.a = false end
    if key == "s" then keys.s = false end
    if key == "d" then keys.d = false end
    if key == "space" then
        keys.space = false
        spacePressed = false
    end
end

-- ========== ПОЛУЧЕНИЕ СОБЫТИЯ ВЫСТРЕЛА ==========
function controls.getShot()
    -- Возвращает true только в момент нажатия пробела
    if keys.space and not spaceHeld then
        return true, aimDx, aimDy
    end
    return false, aimDx, aimDy
end

function controls.draw()
    -- Рисуем только кнопку Back для мобильных устройств
    if showBack then
        love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
        love.graphics.rectangle("fill", back.x+4, back.y+5, back.w, back.h, 14, 14)
        
        love.graphics.setColor(0.35, 0.15, 0.75, 1)
        love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 14, 14)
        
        love.graphics.setColor(0,0,0,1)
        love.graphics.setLineWidth(3.4)
        love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 14, 14)
        
        love.graphics.setColor(1,1,1,1)
        love.graphics.setFont(love.graphics.newFont("Fredoka-Bold.ttf", 24))
        love.graphics.printf("Back", back.x, back.y+14, back.w, "center")
    end
    
    love.graphics.setColor(1,1,1,1)
end

return controls
