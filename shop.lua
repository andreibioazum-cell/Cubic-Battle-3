local shop = {}

local fontTitle, fontBtn
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnAction = { w = 220, h = 75, x = 0, y = 0 }  -- общая кнопка для BUY/EQUIP/UNEQUIP
local skinPrice = 100
local skinName = "AZUM CUBE"

local ownedSkin = "NONE"
local equippedSkin = "NONE"

-- ========== ОТРИСОВКА ТЕКСТА С ТЕНЬЮ ==========
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

function shop.load(saveData)
    ownedSkin = saveData.ownedSkin or "NONE"
    equippedSkin = saveData.equippedSkin or "NONE"
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w, h) / 800

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnAction.w = 220 * scale
    btnAction.h = 75 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnAction.x = (w - btnAction.w) / 2
    btnAction.y = h/2 + 80 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function shop.resize()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w, h) / 800

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnAction.w = 220 * scale
    btnAction.h = 75 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnAction.x = (w - btnAction.w) / 2
    btnAction.y = h/2 + 80 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function shop.draw(coins)
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = math.min(w, love.graphics.getHeight()) / 800

    drawSpacedText("SHOP", 0, 100*scale, w, "center", fontTitle, nil, 1)
    drawSpacedText("COINS: " .. coins, 0, 170*scale, w, "center", fontBtn, nil, 1)

    local infoY = love.graphics.getHeight()/2 - 40*scale
    drawSpacedText(skinName, 0, infoY, w, "center", fontBtn, nil, 1)

    local isOwned = (ownedSkin == skinName)
    local isEquipped = (equippedSkin == skinName)

    if isOwned then
        if isEquipped then
            drawSpacedText("EQUIPPED", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
        else
            drawSpacedText("OWNED", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
        end
    else
        drawSpacedText("PRICE: " .. skinPrice .. " COINS", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
    end

    -- Определяем текст и цвет кнопки
    local btnText, btnColor
    if not isOwned then
        btnText = "BUY"
        btnColor = {0.35, 0.15, 0.75}  -- фиолетовый
    elseif isOwned and not isEquipped then
        btnText = "EQUIP"
        btnColor = {0.2, 0.7, 0.3}  -- зелёный
    else -- owned and equipped
        btnText = "UNEQUIP"
        btnColor = {0.8, 0.2, 0.2}  -- красный
    end

    -- Рисуем кнопку
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnAction.x + 5*scale, btnAction.y + 6*scale, btnAction.w, btnAction.h, 16*scale, 16*scale)
    love.graphics.setColor(btnColor[1], btnColor[2], btnColor[3], 1)
    love.graphics.rectangle("fill", btnAction.x, btnAction.y, btnAction.w, btnAction.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnAction.x, btnAction.y, btnAction.w, btnAction.h, 16*scale, 16*scale)
    drawSpacedText(btnText, btnAction.x, btnAction.y + 20*scale, btnAction.w, "center", fontBtn, nil, 1)

    -- Кнопка Back
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function shop.touchpressed(id, x, y, coins, saveData)
    local changed = false

    -- Кнопка Back
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        GameState.current = "lobby"
        return coins, changed
    end

    local isOwned = (saveData.ownedSkin == skinName)
    local isEquipped = (saveData.equippedSkin == skinName)

    -- Проверяем нажатие на главную кнопку
    if x >= btnAction.x and x <= btnAction.x + btnAction.w and y >= btnAction.y and y <= btnAction.y + btnAction.h then
        if not isOwned then
            -- Попытка купить
            if coins >= skinPrice then
                coins = coins - skinPrice
                saveData.ownedSkin = skinName
                -- автоматически не надеваем
                changed = true
                print("Куплен скин " .. skinName)
            end
        elseif isOwned and not isEquipped then
            -- Экипировать
            saveData.equippedSkin = skinName
            changed = true
            print("Надет скин " .. skinName)
        else -- owned and equipped
            -- Снять
            saveData.equippedSkin = "NONE"
            changed = true
            print("Снят скин " .. skinName)
        end
    end

    return coins, changed
end

return shop
