-- shop.lua – магазин с обновлением скина в онлайне
local shop = {}

local fontTitle, fontBtn
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnMain = { w = 220, h = 75, x = 0, y = 0 }
local btnLeft = { w = 60, h = 60, x = 0, y = 0 }
local btnRight = { w = 60, h = 60, x = 0, y = 0 }
local online = require("online")

local SKINS = {
    { name = "AZUM CUBE", price = 500 },
    { name = "NASTYA CUBE", price = 350 },
    { name = "BUK CUBE", price = 400 },
}
local currentSkinIndex = 1
local ownedSkins = {}
local equippedSkin = "NONE"
local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
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

function shop.load(saveData)
    ownedSkins = {}
    if saveData and saveData.ownedSkins then
        for _, name in ipairs(saveData.ownedSkins) do
            table.insert(ownedSkins, name)
        end
    end
    equippedSkin = (saveData and saveData.equippedSkin) or "NONE"
    currentSkinIndex = 1
    shop.resize()
end

function shop.resize()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()
    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnMain.w = 220 * scale
    btnMain.h = 75 * scale
    btnLeft.w = 60 * scale
    btnLeft.h = 60 * scale
    btnRight.w = 60 * scale
    btnRight.h = 60 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnMain.x = (w - btnMain.w) / 2
    btnMain.y = h/2 + 120 * scale
    btnLeft.x = w/2 - 180 * scale
    btnLeft.y = h/2 + 10 * scale
    btnRight.x = w/2 + 120 * scale
    btnRight.y = h/2 + 10 * scale
    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function shop.draw(coins)
    coins = coins or 0
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("SHOP", 0, 100*scale, w, "center", fontTitle, nil, 1)
    drawSpacedText("COINS: " .. coins, 0, 170*scale, w, "center", fontBtn, nil, 1)

    local skin = SKINS[currentSkinIndex]
    local isOwned = false
    for _, name in ipairs(ownedSkins) do
        if name == skin.name then isOwned = true; break end
    end
    local isEquipped = (equippedSkin == skin.name)

    local infoY = love.graphics.getHeight()/2 - 60*scale
    drawSpacedText(skin.name, 0, infoY, w, "center", fontBtn, nil, 1)

    if isOwned then
        if isEquipped then
            drawSpacedText("EQUIPPED", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
        else
            drawSpacedText("OWNED", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
        end
    else
        drawSpacedText("PRICE: " .. skin.price .. " COINS", 0, infoY + 50*scale, w, "center", fontBtn, nil, 1)
    end

    local btnText, btnColor
    if not isOwned then
        btnText = "BUY"; btnColor = {0.2, 0.5, 0.9}
    elseif not isEquipped then
        btnText = "EQUIP"; btnColor = {0.2, 0.5, 0.9}
    else
        btnText = "UNEQUIP"; btnColor = {0.8, 0.2, 0.2}
    end

    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnMain.x + 5*scale, btnMain.y + 6*scale, btnMain.w, btnMain.h, 16*scale, 16*scale)
    love.graphics.setColor(btnColor[1], btnColor[2], btnColor[3], 1)
    love.graphics.rectangle("fill", btnMain.x, btnMain.y, btnMain.w, btnMain.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnMain.x, btnMain.y, btnMain.w, btnMain.h, 16*scale, 16*scale)
    drawSpacedText(btnText, btnMain.x, btnMain.y + 20*scale, btnMain.w, "center", fontBtn, nil, 1)

    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnLeft.x + 4*scale, btnLeft.y + 4*scale, btnLeft.w, btnLeft.h, 10*scale, 10*scale)
    love.graphics.setColor(0.2, 0.5, 0.9, 1)
    love.graphics.rectangle("fill", btnLeft.x, btnLeft.y, btnLeft.w, btnLeft.h, 10*scale, 10*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", btnLeft.x, btnLeft.y, btnLeft.w, btnLeft.h, 10*scale, 10*scale)
    drawSpacedText("<", btnLeft.x, btnLeft.y + 12*scale, btnLeft.w, "center", fontBtn, nil, 1)

    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnRight.x + 4*scale, btnRight.y + 4*scale, btnRight.w, btnRight.h, 10*scale, 10*scale)
    love.graphics.setColor(0.2, 0.5, 0.9, 1)
    love.graphics.rectangle("fill", btnRight.x, btnRight.y, btnRight.w, btnRight.h, 10*scale, 10*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", btnRight.x, btnRight.y, btnRight.w, btnRight.h, 10*scale, 10*scale)
    drawSpacedText(">", btnRight.x, btnRight.y + 12*scale, btnRight.w, "center", fontBtn, nil, 1)

    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.2, 0.5, 0.9, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function shop.touchpressed(id, x, y, coins, saveData)
    coins = coins or 0
    if not saveData then
        print("❌ saveData nil в shop.touchpressed")
        return coins, false
    end

    local changed = false

    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "lobby"
        return coins, changed
    end

    if x >= btnLeft.x and x <= btnLeft.x + btnLeft.w and y >= btnLeft.y and y <= btnLeft.y + btnLeft.h then
        playButtonSound()
        currentSkinIndex = currentSkinIndex - 1
        if currentSkinIndex < 1 then currentSkinIndex = #SKINS end
        return coins, false
    end

    if x >= btnRight.x and x <= btnRight.x + btnRight.w and y >= btnRight.y and y <= btnRight.y + btnRight.h then
        playButtonSound()
        currentSkinIndex = currentSkinIndex + 1
        if currentSkinIndex > #SKINS then currentSkinIndex = 1 end
        return coins, false
    end

    if x >= btnMain.x and x <= btnMain.x + btnMain.w and y >= btnMain.y and y <= btnMain.y + btnMain.h then
        playButtonSound()
        local skin = SKINS[currentSkinIndex]
        local isOwned = false
        for _, name in ipairs(ownedSkins) do
            if name == skin.name then isOwned = true; break end
        end
        local isEquipped = (equippedSkin == skin.name)

        if not isOwned then
            if coins >= skin.price then
                coins = coins - skin.price
                table.insert(ownedSkins, skin.name)
                changed = true
                print("✅ Куплен " .. skin.name)
            else
                print("❌ Не хватает монет!")
            end
        elseif not isEquipped then
            equippedSkin = skin.name
            changed = true
            print("✅ Надет " .. skin.name)
            -- ОБНОВЛЯЕМ СКИН В ОНЛАЙНЕ
            if online.isConnected and online.isConnected() then
                online.updateSkin(skin.name)
            end
        else
            equippedSkin = "NONE"
            changed = true
            print("✅ Снят " .. skin.name)
            if online.isConnected and online.isConnected() then
                online.updateSkin("NONE")
            end
        end
    end

    saveData.ownedSkins = {}
    for _, name in ipairs(ownedSkins) do
        table.insert(saveData.ownedSkins, name)
    end
    saveData.equippedSkin = equippedSkin

    return coins, changed
end

function shop.touchmoved() end
function shop.touchreleased() end

return shop
