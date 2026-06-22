local shop = {}

local fontTitle, fontBtn
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnBuy  = { w = 220, h = 75, x = 0, y = 0 }
local skinOwned = false
local skinPrice = 100
local skinName = "AZUM CUBE"

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
    skinOwned = saveData and saveData.hasAzumSkin or false
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w, h) / 800

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnBuy.w  = 220 * scale
    btnBuy.h  = 75 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnBuy.x  = (w - btnBuy.w) / 2
    btnBuy.y  = h/2 + 80 * scale

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

    btnBack.x = (w - btnBack.w) / 2
    btnBuy.x  = (w - btnBuy.w) / 2
    btnBuy.y  = h/2 + 80 * scale
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
    if skinOwned then
        drawSpacedText("OWNED", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
    else
        drawSpacedText("PRICE: " .. skinPrice .. " COINS", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
    end

    if not skinOwned then
        love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
        love.graphics.rectangle("fill", btnBuy.x + 5*scale, btnBuy.y + 6*scale, btnBuy.w, btnBuy.h, 16*scale, 16*scale)
        love.graphics.setColor(0.35, 0.15, 0.75, 1)
        love.graphics.rectangle("fill", btnBuy.x, btnBuy.y, btnBuy.w, btnBuy.h, 16*scale, 16*scale)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.rectangle("line", btnBuy.x, btnBuy.y, btnBuy.w, btnBuy.h, 16*scale, 16*scale)
        drawSpacedText("BUY", btnBuy.x, btnBuy.y + 20*scale, btnBuy.w, "center", fontBtn, nil, 1)
    end

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
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        GameState.current = "lobby"
        return coins, false
    end

    if not skinOwned and x >= btnBuy.x and x <= btnBuy.x + btnBuy.w and y >= btnBuy.y and y <= btnBuy.y + btnBuy.h then
        if coins >= skinPrice then
            coins = coins - skinPrice
            skinOwned = true
            saveData.hasAzumSkin = true
            saveData.coins = coins
            return coins, true
        end
    end
    return coins, false
end

return shop
