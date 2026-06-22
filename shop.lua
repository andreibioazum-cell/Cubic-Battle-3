local shop = {}

local fontTitle, fontBtn
local btnBack = { w=140, h=55, x=0, y=30 }
local btnBuy  = { w=220, h=75, x=0, y=0 }
local skinOwned = false
local skinPrice = 100
local skinName = "AZUM CUBE"

local function drawSpacedText(text, x, y, w, align, font, spacing)
    spacing = spacing or 0
    love.graphics.setFont(font)
    local totalW, widths = 0, {}
    for i=1, #text do
        local ch = text:sub(i,i)
        local cw = font:getWidth(ch)
        widths[i] = cw
        totalW = totalW + cw
    end
    totalW = totalW + spacing * (#text - 1)
    local startX = x
    if align == "center" then startX = x + (w - totalW)/2
    elseif align == "right" then startX = x + (w - totalW) end
    local outline = 2
    love.graphics.setColor(0,0,0,1)
    local cx = startX
    for i=1, #text do
        local ch = text:sub(i,i)
        for dx=-outline, outline, outline do
            for dy=-outline, outline, outline do
                if dx~=0 or dy~=0 then love.graphics.print(ch, cx+dx, y+dy) end
            end
        end
        cx = cx + widths[i] + spacing
    end
    love.graphics.setColor(1,1,1,1)
    cx = startX
    for i=1, #text do
        love.graphics.print(text:sub(i,i), cx, y)
        cx = cx + widths[i] + spacing
    end
end

function shop.load(saveData)
    skinOwned = saveData and saveData.hasAzumSkin or false
    local w, h = love.graphics.getDimensions()
    btnBack.x = (w - btnBack.w) / 2
    btnBuy.x  = (w - btnBuy.w) / 2
    btnBuy.y  = h/2 + 30
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", 48)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", 28)
end

function shop.resize()
    local w, h = love.graphics.getDimensions()
    btnBack.x = (w - btnBack.w) / 2
    btnBuy.x  = (w - btnBuy.w) / 2
    btnBuy.y  = h/2 + 30
end

function shop.draw(coins)
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    drawSpacedText("SHOP", 0, 70, love.graphics.getWidth(), "center", fontTitle, fontTitle:getWidth("A")*0.05)
    drawSpacedText("COINS: " .. coins, 0, 140, love.graphics.getWidth(), "center", fontBtn, fontBtn:getWidth("A")*0.05)

    local infoY = love.graphics.getHeight()/2 - 80
    drawSpacedText(skinName, 0, infoY, love.graphics.getWidth(), "center", fontBtn, fontBtn:getWidth("A")*0.05)
    if skinOwned then
        drawSpacedText("✅ OWNED", 0, infoY + 50, love.graphics.getWidth(), "center", fontBtn, fontBtn:getWidth("A")*0.05)
    else
        drawSpacedText("PRICE: " .. skinPrice .. " COINS", 0, infoY + 50, love.graphics.getWidth(), "center", fontBtn, fontBtn:getWidth("A")*0.05)
    end

    if not skinOwned then
        love.graphics.setColor(0.1,0.0,0.2,0.5)
        love.graphics.rectangle("fill", btnBuy.x+5, btnBuy.y+6, btnBuy.w, btnBuy.h, 16,16)
        love.graphics.setColor(0.35,0.15,0.75,1)
        love.graphics.rectangle("fill", btnBuy.x, btnBuy.y, btnBuy.w, btnBuy.h, 16,16)
        love.graphics.setColor(0,0,0,1)
        love.graphics.setLineWidth(3.4)
        love.graphics.rectangle("line", btnBuy.x, btnBuy.y, btnBuy.w, btnBuy.h, 16,16)
        drawSpacedText("BUY", btnBuy.x, btnBuy.y+20, btnBuy.w, "center", fontBtn, fontBtn:getWidth("A")*0.05)
    end

    love.graphics.setColor(0.1,0.0,0.2,0.5)
    love.graphics.rectangle("fill", btnBack.x+4, btnBack.y+5, btnBack.w, btnBack.h, 14,14)
    love.graphics.setColor(0.35,0.15,0.75,1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14,14)
    love.graphics.setColor(0,0,0,1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14,14)
    drawSpacedText("BACK", btnBack.x, btnBack.y+14, btnBack.w, "center", fontBtn, fontBtn:getWidth("A")*0.05)
end

function shop.touchpressed(id, x, y, coins, saveData)
    if x>=btnBack.x and x<=btnBack.x+btnBack.w and y>=btnBack.y and y<=btnBack.y+btnBack.h then
        GameState.current = "lobby"
        return coins, false
    end

    if not skinOwned and x>=btnBuy.x and x<=btnBuy.x+btnBuy.w and y>=btnBuy.y and y<=btnBuy.y+btnBuy.h then
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
