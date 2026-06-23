local shop = {}

local fontTitle, fontBtn
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnBuy  = { w = 220, h = 75, x = 0, y = 0 }
local btnEquip = { w = 140, h = 55, x = 0, y = 0 }
local btnUnequip = { w = 140, h = 55, x = 0, y = 0 }
local skinPrice = 100
local skinName = "AZUM CUBE"

-- текущие состояния (копируются из saveData)
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
    btnBuy.w  = 220 * scale
    btnBuy.h  = 75 * scale
    btnEquip.w = 140 * scale
    btnEquip.h = 55 * scale
    btnUnequip.w = 140 * scale
    btnUnequip.h = 55 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnBuy.x  = (w - btnBuy.w) / 2
    btnBuy.y  = h/2 + 80 * scale
    btnEquip.x = w/2 - btnEquip.w - 10 * scale
    btnEquip.y = h/2 + 80 * scale
    btnUnequip.x = w/2 + 10 * scale
    btnUnequip.y = h/2 + 80 * scale

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
    btnBuy.w  = 220 * scale
    btnBuy.h  = 75 * scale
    btnEquip.w = 140 * scale
    btnEquip.h = 55 * scale
    btnUnequip.w = 140 * scale
    btnUnequip.h = 55 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnBuy.x  = (w - btnBuy.w) / 2
    btnBuy.y  = h/2 + 80 * scale
    btnEquip.x = w/2 - btnEquip.w - 10 * scale
    btnEquip.y = h/2 + 80 * scale
    btnUnequip.x = w/2 + 10 * scale
    btnUnequip.y = h/2 + 80 * scale

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

    -- Кнопка BUY (если не куплен)
    if not isOwned then
        love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
        love.graphics.rectangle("fill", btnBuy.x + 5*scale, btnBuy.y + 6*scale, btnBuy.w, btnBuy.h, 16*scale, 16*scale)
        love.graphics.setColor(0.35, 0.15, 0.75, 1)
        love.graphics.rectangle("fill", btnBuy.x, btnBuy.y, btnBuy.w, btnBuy.h, 16*scale, 16*scale)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.rectangle("line", btnBuy.x, btnBuy.y, btnBuy.w, btnBuy.h, 16*scale, 16*scale)
        drawSpacedText("BUY", btnBuy.x, btnBuy.y + 20*scale, btnBuy.w, "center", fontBtn, nil, 1)
    end

    -- Кнопки EQUIP / UNEQUIP (если куплен)
    if isOwned then
        if not isEquipped then
            -- Кнопка EQUIP
            love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
            love.graphics.rectangle("fill", btnEquip.x + 4*scale, btnEquip.y + 5*scale, btnEquip.w, btnEquip.h, 14*scale, 14*scale)
            love.graphics.setColor(0.35, 0.15, 0.75, 1)
            love.graphics.rectangle("fill", btnEquip.x, btnEquip.y, btnEquip.w, btnEquip.h, 14*scale, 14*scale)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(3.4 * scale)
            love.graphics.rectangle("line", btnEquip.x, btnEquip.y, btnEquip.w, btnEquip.h, 14*scale, 14*scale)
            drawSpacedText("EQUIP", btnEquip.x, btnEquip.y + 14*scale, btnEquip.w, "center", fontBtn, nil, 1)
        else
            -- Кнопка UNEQUIP
            love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
            love.graphics.rectangle("fill", btnUnequip.x + 4*scale, btnUnequip.y + 5*scale, btnUnequip.w, btnUnequip.h, 14*scale, 14*scale)
            love.graphics.setColor(0.8, 0.2, 0.2, 1)
            love.graphics.rectangle("fill", btnUnequip.x, btnUnequip.y, btnUnequip.w, btnUnequip.h, 14*scale, 14*scale)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(3.4 * scale)
            love.graphics.rectangle("line", btnUnequip.x, btnUnequip.y, btnUnequip.w, btnUnequip.h, 14*scale, 14*scale)
            drawSpacedText("UNEQUIP", btnUnequip.x, btnUnequip.y + 14*scale, btnUnequip.w, "center", fontBtn, nil, 1)
        end
    end

    -- Кнопка Back (всегда)
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

    -- Кнопка BUY
    if not isOwned then
        if x >= btnBuy.x and x <= btnBuy.x + btnBuy.w and y >= btnBuy.y and y <= btnBuy.y + btnBuy.h then
            if coins >= skinPrice then
                coins = coins - skinPrice
                saveData.ownedSkin = skinName
                -- Обновляем локальные переменные
                ownedSkin = skinName
                changed = true
                print("Куплен скин " .. skinName)
            end
            return coins, changed
        end
    else
        -- Кнопка EQUIP
        if not isEquipped then
            if x >= btnEquip.x and x <= btnEquip.x + btnEquip.w and y >= btnEquip.y and y <= btnEquip.y + btnEquip.h then
                saveData.equippedSkin = skinName
                equippedSkin = skinName  -- обновляем локальную
                changed = true
                print("Надет скин " .. skinName)
                return coins, changed
            end
        else
            -- Кнопка UNEQUIP
            if x >= btnUnequip.x and x <= btnUnequip.x + btnUnequip.w and y >= btnUnequip.y and y <= btnUnequip.y + btnUnequip.h then
                saveData.equippedSkin = "NONE"
                equippedSkin = "NONE"   -- обновляем локальную
                changed = true
                print("Снят скин " .. skinName)
                return coins, changed
            end
        end
    end

    return coins, changed
end

return shop
