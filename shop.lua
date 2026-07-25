-- shop.lua – магазин
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
local hoverBtn = nil
local animTime = 0

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

function shop.update(dt)
    animTime = animTime + dt
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

    local function drawButton(btn, text, color, isHover)
        local r, g, b = color[1], color[2], color[3]
        if isHover then
            r = math.min(1, r + 0.15)
            g = math.min(1, g + 0.15)
            b = math.min(1, b + 0.15)
        end
        
        local shadowOffset = isHover and 4 or 5
        love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
        love.graphics.rectangle("fill", btn.x + shadowOffset * scale, btn.y + (shadowOffset + 1) * scale, btn.w, btn.h, 16*scale, 16*scale)
        
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)
        
        if isHover then
            love.graphics.setColor(0.6, 0.8, 1, 0.3 + 0.3 * math.sin(animTime * 3))
            love.graphics.setLineWidth(2 * scale)
            love.graphics.rectangle("line", btn.x + 2*scale, btn.y + 2*scale, btn.w - 4*scale, btn.h - 4*scale, 14*scale, 14*scale)
        end
        
        drawSpacedText(text, btn.x, btn.y + 20*scale, btn.w, "center", fontBtn, nil, 1)
    end

    local btnText, btnColor
    if not isOwned then
        btnText = "BUY"; btnColor = {0.2, 0.5, 0.9}
    elseif not isEquipped then
        btnText = "EQUIP"; btnColor = {0.2, 0.5, 0.9}
    else
        btnText = "UNEQUIP"; btnColor = {0.8, 0.2, 0.2}
    end

    drawButton(btnMain, btnText, btnColor, hoverBtn == "main")
    drawButton(btnLeft, "<", {0.2, 0.5, 0.9}, hoverBtn == "left")
    drawButton(btnRight, ">", {0.2, 0.5, 0.9}, hoverBtn == "right")
    drawButton(btnBack, "BACK", {0.2, 0.5, 0.9}, hoverBtn == "back")
end

function shop.mousemoved(x, y)
    if isMobile then return end
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnMain) then
        hoverBtn = "main"
    elseif isInside(btnLeft) then
        hoverBtn = "left"
    elseif isInside(btnRight) then
        hoverBtn = "right"
    elseif isInside(btnBack) then
        hoverBtn = "back"
    else
        hoverBtn = nil
    end
end

function shop.touchpressed(id, x, y, coins, saveData)
    coins = coins or 0
    if not saveData then
        print("❌ saveData nil в shop.touchpressed")
        return coins, false
    end

    local changed = false
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end

    if isInside(btnBack) then
        playButtonSound()
        GameState.current = "lobby"
        return coins, changed
    end

    if isInside(btnLeft) then
        playButtonSound()
        currentSkinIndex = currentSkinIndex - 1
        if currentSkinIndex < 1 then currentSkinIndex = #SKINS end
        return coins, false
    end

    if isInside(btnRight) then
        playButtonSound()
        currentSkinIndex = currentSkinIndex + 1
        if currentSkinIndex > #SKINS then currentSkinIndex = 1 end
        return coins, false
    end

    if isInside(btnMain) then
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

function shop.touchmoved(id, x, y)
    if isMobile then
        local function isInside(btn)
            return x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h
        end
        
        if isInside(btnMain) then
            hoverBtn = "main"
        elseif isInside(btnLeft) then
            hoverBtn = "left"
        elseif isInside(btnRight) then
            hoverBtn = "right"
        elseif isInside(btnBack) then
            hoverBtn = "back"
        else
            hoverBtn = nil
        end
    end
end

function shop.touchreleased(id, x, y)
    if isMobile then
        hoverBtn = nil
    end
end

return shop
