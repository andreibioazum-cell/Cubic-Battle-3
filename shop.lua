-- shop.lua – магазин
local ui = require("ui")
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
    local wideW, wideH, bScale = ui.wideButton(w, h, scale, 2)
    btnBack.w = wideW; btnBack.h = wideH
    btnMain.w = wideW; btnMain.h = wideH
    btnLeft.w = 72 * bScale
    btnLeft.h = 72 * bScale
    btnRight.w = 72 * bScale
    btnRight.h = 72 * bScale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - btnBack.h - 24 * scale
    btnMain.x = (w - btnMain.w) / 2
    btnMain.y = h/2 + 120 * bScale
    btnLeft.x = w/2 - 180 * bScale
    btnLeft.y = h/2 + 10 * bScale
    btnRight.x = w/2 + 108 * bScale
    btnRight.y = h/2 + 10 * bScale
    local titleSize = math.max(32, 48 * scale)
    local btnSize   = ui.buttonFontSize(bScale)
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

    ui.drawSpacedText("SHOP", 0, 100*scale, w, "center", fontTitle, nil, 1)
    ui.drawSpacedText("COINS: " .. coins, 0, 170*scale, w, "center", fontBtn, nil, 1)

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
    ui.drawSpacedText(skin.name, 0, infoY, w, "center", fontBtn, nil, 1)

    if isOwned then
        if isEquipped then
            ui.drawSpacedText("EQUIPPED", 0, infoY + 40*scale, w, "center", fontBtn, nil, 1)
        else
            ui.drawSpacedText("OWNED", 0, infoY + 40*scale, w, "center", fontBtn, nil, 1)
        end
    else
        ui.drawSpacedText("PRICE: " .. skin.price .. " COINS", 0, infoY + 40*scale, w, "center", fontBtn, nil, 1)
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

    -- Кнопки в стиле лобби; стрелки перелистывания – компактные квадраты
    -- с той же бирюзовой заливкой и рамкой, подпись по центру.
    local btnText, btnColor
    if not isOwned then
        btnText = "BUY"; btnColor = {0.2, 0.5, 0.9}
    elseif not isEquipped then
        btnText = "EQUIP"; btnColor = {0.2, 0.5, 0.9}
    else
        btnText = "UNEQUIP"; btnColor = {0.8, 0.2, 0.2}
    end

    ui.drawButton(btnMain, btnText, hoverBtn == "main", btnColor, fontBtn)
    ui.drawButton(btnLeft, "<", hoverBtn == "left", nil, fontBtn, "center")
    ui.drawButton(btnRight, ">", hoverBtn == "right", nil, fontBtn, "center")
    ui.drawButton(btnBack, "BACK", hoverBtn == "back", nil, fontBtn)
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
