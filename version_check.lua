-- version_check.lua – проверка обновлений
local version_check = {}

local online = require("online")
local VERSION = "13"
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local CONFIG_PATH = "config/version"

local showUpdatePopup = false
local latestVersion = ""
local updateChecked = false
local isChecking = false
local font = nil

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
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

function version_check.load()
    local scale = getScale()
    local fontSize = math.max(18, 26 * scale)
    font = love.graphics.newFont("Fredoka-Bold.ttf", fontSize)
end

function version_check.resize()
    version_check.load()
end

function version_check.drawPopup()
    if not showUpdatePopup then return end
    
    local w, h = love.graphics.getDimensions()
    local scale = getScale()
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    local popupW, popupH = 450 * scale, 300 * scale
    local popupX = (w - popupW) / 2
    local popupY = (h - popupH) / 2
    
    love.graphics.setColor(0.05, 0.05, 0.15, 0.95)
    love.graphics.rectangle("fill", popupX, popupY, popupW, popupH, 20 * scale, 20 * scale)
    
    love.graphics.setColor(0.2, 0.5, 0.9, 0.5)
    love.graphics.setLineWidth(2 * scale)
    love.graphics.rectangle("line", popupX, popupY, popupW, popupH, 20 * scale, 20 * scale)
    
    local titleSize = math.max(24, 36 * scale)
    local titleFont = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    local titleText = "UPDATE AVAILABLE"
    local tw = titleFont:getWidth(titleText)
    love.graphics.print(titleText, popupX + (popupW - tw) / 2, popupY + 30 * scale)
    
    local textFont = love.graphics.newFont("Fredoka-Bold.ttf", math.max(16, 22 * scale))
    love.graphics.setFont(textFont)
    
    local yOffset = popupY + 90 * scale
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local currentText = "Current version: " .. VERSION
    local ct = textFont:getWidth(currentText)
    love.graphics.print(currentText, popupX + (popupW - ct) / 2, yOffset)
    
    yOffset = yOffset + 35 * scale
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    local latestText = "New version: " .. latestVersion
    local lt = textFont:getWidth(latestText)
    love.graphics.print(latestText, popupX + (popupW - lt) / 2, yOffset)
    
    yOffset = yOffset + 40 * scale
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    local updateText = "Please update to continue playing"
    local ut = textFont:getWidth(updateText)
    love.graphics.print(updateText, popupX + (popupW - ut) / 2, yOffset)
    
    local btnW = 180 * scale
    local btnH = 55 * scale
    local btnX = popupX + (popupW - btnW) / 2
    local btnY = popupY + popupH - 80 * scale
    
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnX + 4 * scale, btnY + 5 * scale, btnW, btnH, 14 * scale, 14 * scale)
    
    love.graphics.setColor(0.2, 0.5, 0.9, 1)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 14 * scale, 14 * scale)
    
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3 * scale)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 14 * scale, 14 * scale)
    
    local btnFont = love.graphics.newFont("Fredoka-Bold.ttf", math.max(20, 28 * scale))
    drawSpacedText("UPDATE", btnX, btnY + 14 * scale, btnW, "center", btnFont, nil, 1)
    
    version_check._updateBtn = { x = btnX, y = btnY, w = btnW, h = btnH }
    version_check._laterBtn = nil
end

function version_check.touchpressed(x, y)
    if not showUpdatePopup then return false end
    
    if version_check._updateBtn then
        local btn = version_check._updateBtn
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            version_check.openStore()
            love.event.quit()
            return true
        end
    end
    
    return false
end

function version_check.check(callback)
    if isChecking then return end
    isChecking = true
    
    print("[VERSION_CHECK] Checking for updates...")
    
    local function onResponse(ok, data)
        isChecking = false
        
        if ok and data then
            latestVersion = data:gsub('"', ''):gsub(' ', '')
            updateChecked = true
            
            print("[VERSION_CHECK] Current version: " .. VERSION)
            print("[VERSION_CHECK] Latest version: " .. latestVersion)
            
            if latestVersion > VERSION then
                showUpdatePopup = true
                if _G.addDebugMessage then
                    _G.addDebugMessage("New version available: " .. latestVersion, {1, 0.8, 0.2, 1})
                end
                print("[VERSION_CHECK] New version available!")
            else
                showUpdatePopup = false
                if _G.addDebugMessage then
                    _G.addDebugMessage("Game is up to date (" .. VERSION .. ")", {0.2, 0.8, 0.2, 1})
                end
                print("[VERSION_CHECK] Game is up to date!")
            end
        else
            showUpdatePopup = false
            if _G.addDebugMessage then
                _G.addDebugMessage("Update check failed", {0.5, 0.5, 0.5, 1})
            end
            print("[VERSION_CHECK] Update check failed!")
        end
        
        if callback then 
            callback(showUpdatePopup, latestVersion) 
        end
    end
    
    if not online.isConnected() then
        print("[VERSION_CHECK] Not connected, trying to connect...")
        online.connect()
        local startTime = love.timer.getTime()
        while not online.isConnected() and love.timer.getTime() - startTime < 3 do
            love.timer.sleep(0.1)
        end
    end
    
    if online.isConnected() then
        print("[VERSION_CHECK] Sending request...")
        online.sendRequest("GET", CONFIG_PATH, nil, onResponse)
    else
        isChecking = false
        showUpdatePopup = false
        if _G.addDebugMessage then
            _G.addDebugMessage("No internet, skipping update check", {0.5, 0.5, 0.5, 1})
        end
        print("[VERSION_CHECK] No internet connection!")
        if callback then callback(false, "") end
    end
end

function version_check.showPopup()
    return showUpdatePopup
end

function version_check.getLatestVersion()
    return latestVersion
end

function version_check.getCurrentVersion()
    return VERSION
end

function version_check.openStore()
    local url = "https://www.rustore.ru/catalog/app/com.CB3"
    
    if love.system.getOS() == "Android" then
        local os = require("os")
        local cmd = 'am start -a android.intent.action.VIEW -d "' .. url .. '"'
        os.execute(cmd)
        print("[VERSION_CHECK] Opening store on Android: " .. url)
    else
        love.system.openURL(url)
        print("[VERSION_CHECK] Opening store on PC: " .. url)
    end
end

function version_check.forceCheck()
    showUpdatePopup = false
    latestVersion = ""
    updateChecked = false
    isChecking = false
    version_check.check()
end

return version_check
