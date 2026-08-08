-- shop.lua – магазин
local shop = {}

local fontTitle, fontBtn
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnMain = { w = 220, h = 75, x = 0, y = 0 }
local btnLeft = { w = 60, h = 60, x = 0, y = 0 }
local btnRight = { w = 60, h = 60, x = 0, y = 0 }
local online = require("online")

local SKINS = {
    { name = "AZUM CUBE", price = 500, file = "azum.png" },
    { name = "NASTYA CUBE", price = 350, file = "nastya.png" },
    { name = "BUK CUBE", price = 400, file = "buk.png" },
    { name = "FATHER FROST", price = 500, file = "FatherFrost.png" },
}
local skinImages = {}
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
    local o = math.max(1.5, math.floor(2 * (scale or 1)))
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

function shop.load(saveData)
    ownedSkins = {}
    if saveData and saveData.ownedSkins then
        for _, name in ipairs(saveData.ownedSkins) do
            table.insert(ownedSkins, name)
        end
    end
    equippedSkin = (saveData and saveData.equippedSkin) or "NONE"
    currentSkinIndex = 1

    for _, s in ipairs(SKINS) do
        if not skinImages[s.name] and s.file then
            local ok, img = pcall(love.graphics.newImage, s.file)
            if ok and img then
                img:setFilter("nearest", "nearest")
                skinImages[s.name] = img
            end
        end
    end

    shop.resize()
end

function shop.resize()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()
    local wideW = math.min(610 * scale, w - 32 * scale)
    local wideH = 100 * scale
    btnBack.w = wideW; btnBack.h = wideH
    btnMain.w = wideW; btnMain.h = wideH
    btnLeft.w = 60 * scale
    btnLeft.h = 60 * scale
    btnRight.w = 60 * scale
    btnRight.h = 60 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - btnBack.h - 24 * scale
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
        if name == skin.name or (skin.name == "FATHER FROST" and (name == "FatherFrost" or name == "FATHER FROST CUBE")) then
            isOwned = true
            break
        end
    end
    local isEquipped = (equippedSkin == skin.name) or (skin.name == "FATHER FROST" and (equippedSkin == "FatherFrost" or equippedSkin == "FATHER FROST CUBE"))

    local infoY = love.graphics.getHeight()/2 - 60*scale
    drawSpacedText(skin.name, 0, infoY, w, "center", fontBtn, nil, 1)

    if isOwned then
        if isEquipped then
            drawSpacedText("EQUIPPED", 0, infoY + 40*scale, w, "center", fontBtn, nil, 1)
        else
            drawSpacedText("OWNED", 0, infoY + 40*scale, w, "center", fontBtn, nil, 1)
        end
    else
        drawSpacedText("PRICE: " .. skin.price .. " COINS", 0, infoY + 40*scale, w, "center", fontBtn, nil, 1)
    end

    -- Отрисовка превью скина по центру между стрелками
    local img = skinImages[skin.name]
    if img then
        local previewSize = 65 * scale
        local cx = w / 2
        local cy = love.graphics.getHeight()/2 + 40 * scale
        local bob = math.sin(animTime * 3) * 3 * scale
        local sx = previewSize / img:getWidth()
        local sy = previewSize / img:getHeight()

        -- Тень
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.draw(img, cx + 3*scale, cy + 5*scale, 0, sx, sy, img:getWidth()/2, img:getHeight()/2)

        -- Сама текстура
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, cx, cy + bob, 0, sx, sy, img:getWidth()/2, img:getHeight()/2)
    end

    local function drawButton(btn, text, color, isHover)
        -- Основной бирюзовый цвет взят с референса; для действий
        -- (покупка, сложность и т. п.) сохраняется переданный цвет.
        local r, g, b = color[1], color[2], color[3]
        if isHover then
            r = math.min(1, r + 0.07)
            g = math.min(1, g + 0.07)
            b = math.min(1, b + 0.07)
        end

        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)

        love.graphics.setColor(0, 0, 0, 1)
        -- Тоньше прежней рамки: около 3 px при масштабе 1.
        love.graphics.setLineWidth(math.max(2, 3 * scale))
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

        drawSpacedText(text, btn.x + 16 * scale, btn.y + (btn.h - fontBtn:getHeight()) / 2, btn.w - 32 * scale, "left", fontBtn, nil, 1)
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
            if name == skin.name or (skin.name == "FATHER FROST" and (name == "FatherFrost" or name == "FATHER FROST CUBE")) then
                isOwned = true
                break
            end
        end
        local isEquipped = (equippedSkin == skin.name) or (skin.name == "FATHER FROST" and (equippedSkin == "FatherFrost" or equippedSkin == "FATHER FROST CUBE"))

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
